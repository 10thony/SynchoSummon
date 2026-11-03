using System.Collections.Concurrent;
using System.Diagnostics;
using Aviation.Shared.Entities;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Server.Telemetry;

namespace Aviation.Server.Services;

/// <summary>
/// Orchestrates in-process load runs, keeps a ring of run reports, and aggregates
/// per-client catch-up (DeltaPull / ClientApply) while a run is Running or CatchingUp.
/// </summary>
public sealed class LoadRunService(
    LoadPackageService packageService,
    InMemoryAviationStore store,
    ISyncTelemetry telemetry,
    ILogger<LoadRunService> logger) : ITelemetryListener
{
    public const double CatchupMaxSeconds = 45;
    public const double CatchupQuietSeconds = 3;

    private const int HistoryCapacity = 20;
    private const int LatencySampleCap = 2000;

    private readonly object _gate = new();
    private readonly List<LoadRunReportState> _runs = new(HistoryCapacity);
    private int _runInFlight;

    public bool IsRunning => Volatile.Read(ref _runInFlight) != 0;

    public IReadOnlyList<LoadProfileDescription> DescribeProfiles() =>
        LoadPackageGenerator.ProfileNames
            .Select(name =>
            {
                var profile = LoadPackageGenerator.GetProfile(name);
                return new LoadProfileDescription(
                    profile.Name,
                    profile.Description,
                    profile.TotalPackages,
                    profile.TotalEntities,
                    profile.Tiers
                        .Select(t => new LoadTierDescription(
                            t.Name,
                            t.PackageCount,
                            t.Facilities,
                            t.EquipmentPerFacility,
                            t.LogsPerEquipment,
                            t.PadBytes,
                            t.EntitiesPerPackage,
                            t.TotalEntities))
                        .ToArray());
            })
            .ToArray();

    public IReadOnlyList<LoadRunSummary> ListRuns()
    {
        lock (_gate)
        {
            FinalizeCatchupStatuses_NoLock(DateTimeOffset.UtcNow);
            return _runs
                .Select(r => r.ToSummary())
                .Reverse()
                .ToArray();
        }
    }

    public LoadRunReport? GetCurrent()
    {
        lock (_gate)
        {
            FinalizeCatchupStatuses_NoLock(DateTimeOffset.UtcNow);
            var current = _runs.LastOrDefault(r =>
                r.Status is LoadRunStatus.Running or LoadRunStatus.CatchingUp);
            return current?.ToReport();
        }
    }

    public LoadRunReport? GetRun(string runId)
    {
        lock (_gate)
        {
            FinalizeCatchupStatuses_NoLock(DateTimeOffset.UtcNow);
            return _runs.FirstOrDefault(r =>
                    string.Equals(r.RunId, runId, StringComparison.OrdinalIgnoreCase))
                ?.ToReport();
        }
    }

    public void OnTelemetry(SyncTelemetryEvent telemetryEvent)
    {
        if (telemetryEvent.Kind is not (SyncTelemetryKind.DeltaPull or SyncTelemetryKind.ClientApply))
        {
            return;
        }

        var ts = telemetryEvent.TimestampUtc;
        lock (_gate)
        {
            foreach (var run in _runs)
            {
                if (run.Status is not (LoadRunStatus.Running or LoadRunStatus.CatchingUp))
                {
                    continue;
                }

                var windowEnd = (run.EndedUtc ?? DateTimeOffset.UtcNow)
                    .AddSeconds(CatchupMaxSeconds);
                if (ts < run.StartedUtc || ts > windowEnd)
                {
                    continue;
                }

                run.ObserveClientEvent(telemetryEvent);
            }

            FinalizeCatchupStatuses_NoLock(DateTimeOffset.UtcNow);
        }
    }

    public async Task<LoadRunResult> RunAsync(string profileName, CancellationToken cancellationToken)
    {
        if (Interlocked.CompareExchange(ref _runInFlight, 1, 0) != 0)
        {
            throw new InvalidOperationException("A load run is already in progress on this server.");
        }

        LoadRunReportState? state = null;
        try
        {
            var profile = LoadPackageGenerator.GetProfile(profileName);
            var runId = DateTimeOffset.UtcNow.ToString("yyyyMMdd-HHmmss-fff");
            var startedUtc = DateTimeOffset.UtcNow;
            var overall = Stopwatch.StartNew();

            state = new LoadRunReportState(
                runId,
                profile.Name,
                startedUtc,
                profile.TotalPackages);

            lock (_gate)
            {
                _runs.Add(state);
                while (_runs.Count > HistoryCapacity)
                {
                    _runs.RemoveAt(0);
                }
            }

            long totalEntities = 0;
            long totalBytes = 0;
            double totalApplyMs = 0;
            var tierResults = new List<LoadRunTierResult>(profile.Tiers.Count);
            var packagesDone = 0;

            telemetry.Record(new SyncTelemetryEvent
            {
                Kind = SyncTelemetryKind.Write,
                Direction = "server",
                EntityName = "LoadRun",
                CorrelationId = runId,
                Summary =
                    $"LOAD profile={profile.Name} run={runId} start packages={profile.TotalPackages} entities≈{profile.TotalEntities}",
            });

            logger.LogInformation(
                "Load run {Run} profile={Profile} packages={Packages} approx-entities={Entities}",
                runId,
                profile.Name,
                profile.TotalPackages,
                profile.TotalEntities);

            foreach (var tier in profile.Tiers)
            {
                var tierSw = Stopwatch.StartNew();
                long tierEntities = 0;
                long tierBytes = 0;
                double tierApplyMs = 0;
                var packageResults = new List<LoadRunPackageResult>(tier.PackageCount);

                for (var i = 0; i < tier.PackageCount; i++)
                {
                    cancellationToken.ThrowIfCancellationRequested();

                    var package = LoadPackageGenerator.BuildPackage(runId, tier, i);

                    telemetry.Record(new SyncTelemetryEvent
                    {
                        Kind = SyncTelemetryKind.Write,
                        Direction = "server",
                        EntityName = "LoadPackage",
                        CorrelationId = runId,
                        Summary =
                            $"LOAD profile={profile.Name} package={package.PackageId} tier={tier.Name} start entities={tier.EntitiesPerPackage}",
                    });

                    var sw = Stopwatch.StartNew();
                    var result = await packageService.ApplyAsync(package, cancellationToken);
                    sw.Stop();

                    telemetry.Record(new SyncTelemetryEvent
                    {
                        Kind = SyncTelemetryKind.Write,
                        Direction = "server",
                        EntityName = "LoadPackage",
                        CorrelationId = runId,
                        FromVersion = result.FromVersion,
                        ToVersion = result.ToVersion,
                        ChangeCount = result.TotalEntities,
                        Bytes = result.ApproximatePayloadBytes,
                        LatencyMs = sw.Elapsed.TotalMilliseconds,
                        Summary =
                            $"LOAD profile={profile.Name} package={package.PackageId} tier={tier.Name} done " +
                            $"entities={result.TotalEntities} bytes={result.ApproximatePayloadBytes} applyMs={result.ServerApplyMs:F1}",
                    });

                    tierEntities += result.TotalEntities;
                    tierBytes += result.ApproximatePayloadBytes;
                    tierApplyMs += result.ServerApplyMs;
                    packagesDone++;
                    packageResults.Add(new LoadRunPackageResult(
                        package.PackageId,
                        result.TotalEntities,
                        result.ApproximatePayloadBytes,
                        result.ServerApplyMs,
                        result.FromVersion,
                        result.ToVersion));

                    state.UpdateProgress(
                        packagesDone,
                        totalEntities + tierEntities,
                        totalBytes + tierBytes);
                }

                tierSw.Stop();
                totalEntities += tierEntities;
                totalBytes += tierBytes;
                totalApplyMs += tierApplyMs;

                tierResults.Add(new LoadRunTierResult(
                    tier.Name,
                    tier.PackageCount,
                    tierEntities,
                    tierBytes,
                    tierApplyMs,
                    tierSw.Elapsed.TotalMilliseconds,
                    packageResults));
            }

            overall.Stop();

            var loadResult = new LoadRunResult(
                runId,
                profile.Name,
                totalEntities,
                totalBytes,
                totalApplyMs,
                overall.Elapsed.TotalMilliseconds,
                tierResults);

            state.CompleteServerPhase(loadResult, DateTimeOffset.UtcNow);

            telemetry.Record(new SyncTelemetryEvent
            {
                Kind = SyncTelemetryKind.Write,
                Direction = "server",
                EntityName = "LoadRun",
                CorrelationId = runId,
                ChangeCount = (int)Math.Min(int.MaxValue, totalEntities),
                Bytes = totalBytes,
                LatencyMs = overall.Elapsed.TotalMilliseconds,
                Summary =
                    $"LOAD profile={profile.Name} run={runId} finish entities={totalEntities} bytes={totalBytes} wallMs={overall.Elapsed.TotalMilliseconds:F0}",
            });

            logger.LogInformation(
                "Load run {Run} done entities={Entities} bytes={Bytes} wallMs={Wall:F0}",
                runId,
                totalEntities,
                totalBytes,
                overall.Elapsed.TotalMilliseconds);

            _ = Task.Run(() => WatchCatchupAsync(runId));

            return loadResult;
        }
        catch
        {
            if (state is not null)
            {
                lock (_gate)
                {
                    if (state.Status == LoadRunStatus.Running)
                    {
                        state.MarkFailed(DateTimeOffset.UtcNow);
                    }
                }
            }

            throw;
        }
        finally
        {
            Interlocked.Exchange(ref _runInFlight, 0);
        }
    }

    public async Task<LoadPingResult> PingAsync(CancellationToken cancellationToken)
    {
        var pingId = $"ping-{DateTimeOffset.UtcNow:yyyyMMddHHmmssfff}";
        var sw = Stopwatch.StartNew();
        await store.UpsertFacilityAsync(
            new Facility
            {
                FacilityId = pingId,
                FacilityCode = "PING",
                Name = $"telemetry ping {pingId}",
                FacilityTypeCode = "PING",
                City = "Des Moines",
                StateCode = "IA",
                ZipCode = "50321",
                Latitude = 41.5340m,
                Longitude = -93.6631m,
                OperationalStatus = "OPERATIONAL",
                MetadataJson = null,
            },
            cancellationToken);
        sw.Stop();

        var latencyMs = sw.Elapsed.TotalMilliseconds;
        telemetry.Record(new SyncTelemetryEvent
        {
            Kind = SyncTelemetryKind.Write,
            Direction = "server",
            EntityName = "LoadPing",
            LatencyMs = latencyMs,
            Summary = $"PING {pingId} applyMs={latencyMs:F1}",
        });

        return new LoadPingResult(pingId, latencyMs, DateTimeOffset.UtcNow);
    }

    private async Task WatchCatchupAsync(string runId)
    {
        try
        {
            var deadline = DateTimeOffset.UtcNow.AddSeconds(CatchupMaxSeconds + 5);
            while (DateTimeOffset.UtcNow < deadline)
            {
                await Task.Delay(500).ConfigureAwait(false);
                lock (_gate)
                {
                    FinalizeCatchupStatuses_NoLock(DateTimeOffset.UtcNow);
                    var run = _runs.FirstOrDefault(r => r.RunId == runId);
                    if (run is null || run.Status == LoadRunStatus.Complete)
                    {
                        return;
                    }
                }
            }

            lock (_gate)
            {
                var run = _runs.FirstOrDefault(r => r.RunId == runId);
                if (run is { Status: LoadRunStatus.CatchingUp })
                {
                    run.MarkComplete(DateTimeOffset.UtcNow);
                }
            }
        }
        catch
        {
            // Background watcher must not crash the host.
        }
    }

    private void FinalizeCatchupStatuses_NoLock(DateTimeOffset now)
    {
        foreach (var run in _runs)
        {
            if (run.Status != LoadRunStatus.CatchingUp || run.EndedUtc is null)
            {
                continue;
            }

            var sinceEnd = (now - run.EndedUtc.Value).TotalSeconds;
            if (sinceEnd >= CatchupMaxSeconds)
            {
                run.MarkComplete(now);
                continue;
            }

            var lastNonEmpty = run.LastNonEmptyPullUtc ?? run.EndedUtc.Value;
            if ((now - lastNonEmpty).TotalSeconds >= CatchupQuietSeconds && sinceEnd >= CatchupQuietSeconds)
            {
                run.MarkComplete(now);
            }
        }
    }

    private sealed class LoadRunReportState
    {
        private readonly ConcurrentDictionary<string, ClientCatchupAccumulator> _clients = new(StringComparer.OrdinalIgnoreCase);

        public LoadRunReportState(string runId, string profile, DateTimeOffset startedUtc, int packagesTotal)
        {
            RunId = runId;
            Profile = profile;
            StartedUtc = startedUtc;
            PackagesTotal = packagesTotal;
            Status = LoadRunStatus.Running;
        }

        public string RunId { get; }
        public string Profile { get; }
        public DateTimeOffset StartedUtc { get; }
        public DateTimeOffset? EndedUtc { get; private set; }
        public DateTimeOffset? CompletedUtc { get; private set; }
        public LoadRunStatus Status { get; private set; }
        public int PackagesTotal { get; }
        public int PackagesDone { get; private set; }
        public long EntitiesApplied { get; private set; }
        public long BytesApplied { get; private set; }
        public LoadRunResult? Result { get; private set; }
        public DateTimeOffset? LastNonEmptyPullUtc { get; private set; }

        public void UpdateProgress(int packagesDone, long entities, long bytes)
        {
            PackagesDone = packagesDone;
            EntitiesApplied = entities;
            BytesApplied = bytes;
        }

        public void CompleteServerPhase(LoadRunResult result, DateTimeOffset endedUtc)
        {
            Result = result;
            EndedUtc = endedUtc;
            PackagesDone = result.Tiers.Sum(t => t.Packages);
            EntitiesApplied = result.TotalEntities;
            BytesApplied = result.TotalApproximateBytes;
            Status = LoadRunStatus.CatchingUp;
        }

        public void MarkComplete(DateTimeOffset at)
        {
            Status = LoadRunStatus.Complete;
            CompletedUtc = at;
        }

        public void MarkFailed(DateTimeOffset at)
        {
            Status = LoadRunStatus.Complete;
            EndedUtc ??= at;
            CompletedUtc = at;
        }

        public void ObserveClientEvent(SyncTelemetryEvent e)
        {
            var clientId = string.IsNullOrWhiteSpace(e.ClientId) ? "unknown" : e.ClientId;
            var acc = _clients.GetOrAdd(clientId, id => new ClientCatchupAccumulator(id));
            acc.Observe(e);

            if (e.Kind == SyncTelemetryKind.DeltaPull && (e.ChangeCount ?? 0) > 0)
            {
                LastNonEmptyPullUtc = e.TimestampUtc;
            }
        }

        public LoadRunSummary ToSummary()
        {
            var entities = Result?.TotalEntities ?? EntitiesApplied;
            var bytes = Result?.TotalApproximateBytes ?? BytesApplied;
            var wall = Result?.TotalWallMs;
            return new LoadRunSummary(
                RunId,
                Profile,
                Status.ToString(),
                entities,
                bytes,
                wall,
                StartedUtc,
                EndedUtc,
                PackagesDone,
                PackagesTotal);
        }

        public LoadRunReport ToReport()
        {
            long? fromVersion = null;
            long? toVersion = null;
            if (Result is { Tiers.Count: > 0 })
            {
                var packages = Result.Tiers.SelectMany(t => t.PackageResults).ToArray();
                if (packages.Length > 0)
                {
                    fromVersion = packages.Min(p => p.FromVersion);
                    toVersion = packages.Max(p => p.ToVersion);
                }
            }

            var clients = _clients.Values
                .Select(c => c.ToSnapshot())
                .OrderBy(c => c.ClientId, StringComparer.OrdinalIgnoreCase)
                .ToArray();

            return new LoadRunReport(
                RunId,
                Profile,
                Status.ToString(),
                StartedUtc,
                EndedUtc,
                CompletedUtc,
                PackagesDone,
                PackagesTotal,
                EntitiesApplied,
                BytesApplied,
                Result?.TotalApplyMs,
                Result?.TotalWallMs,
                fromVersion,
                toVersion,
                Result?.Tiers ?? Array.Empty<LoadRunTierResult>(),
                clients,
                CatchupMaxSeconds);
        }
    }

    private sealed class ClientCatchupAccumulator(string clientId)
    {
        private readonly List<double> _pullLatencies = new();
        private readonly List<double> _applyLatencies = new();
        private readonly object _lock = new();

        public void Observe(SyncTelemetryEvent e)
        {
            lock (_lock)
            {
                FirstActivityUtc ??= e.TimestampUtc;
                LastActivityUtc = e.TimestampUtc;

                if (e.FromVersion is { } fv)
                {
                    MinFromVersion = MinFromVersion is null ? fv : Math.Min(MinFromVersion.Value, fv);
                }

                if (e.ToVersion is { } tv)
                {
                    MaxToVersion = MaxToVersion is null ? tv : Math.Max(MaxToVersion.Value, tv);
                }

                if (e.Kind == SyncTelemetryKind.DeltaPull)
                {
                    PullCount++;
                    var changes = e.ChangeCount ?? 0;
                    if (changes > 0)
                    {
                        NonEmptyPullCount++;
                    }

                    if (e.Bytes is { } b)
                    {
                        PullBytes += b;
                    }

                    if (e.LatencyMs is { } ms)
                    {
                        AddSample(_pullLatencies, ms);
                    }
                }
                else if (e.Kind == SyncTelemetryKind.ClientApply)
                {
                    ApplyCount++;
                    if (e.Bytes is { } b)
                    {
                        ApplyBytes += b;
                    }

                    if (e.LatencyMs is { } ms)
                    {
                        AddSample(_applyLatencies, ms);
                    }
                }
            }
        }

        private long PullCount { get; set; }
        private long NonEmptyPullCount { get; set; }
        private long PullBytes { get; set; }
        private long ApplyCount { get; set; }
        private long ApplyBytes { get; set; }
        private DateTimeOffset? FirstActivityUtc { get; set; }
        private DateTimeOffset? LastActivityUtc { get; set; }
        private long? MinFromVersion { get; set; }
        private long? MaxToVersion { get; set; }

        public LoadRunClientCatchup ToSnapshot()
        {
            lock (_lock)
            {
                return new LoadRunClientCatchup(
                    clientId,
                    PullCount,
                    NonEmptyPullCount,
                    PullBytes,
                    Percentile(_pullLatencies, 0.50),
                    Percentile(_pullLatencies, 0.95),
                    _pullLatencies.Count == 0 ? null : _pullLatencies.Max(),
                    ApplyCount,
                    ApplyBytes,
                    Percentile(_applyLatencies, 0.50),
                    Percentile(_applyLatencies, 0.95),
                    _applyLatencies.Count == 0 ? null : _applyLatencies.Max(),
                    FirstActivityUtc,
                    LastActivityUtc,
                    MinFromVersion,
                    MaxToVersion);
            }
        }

        private static void AddSample(List<double> samples, double value)
        {
            if (samples.Count >= LatencySampleCap)
            {
                samples.RemoveAt(0);
            }

            samples.Add(value);
        }

        private static double? Percentile(List<double> samples, double p)
        {
            if (samples.Count == 0)
            {
                return null;
            }

            var sorted = samples.OrderBy(x => x).ToArray();
            var idx = (int)Math.Clamp(Math.Ceiling(p * sorted.Length) - 1, 0, sorted.Length - 1);
            return sorted[idx];
        }
    }
}

public enum LoadRunStatus
{
    Running = 1,
    CatchingUp = 2,
    Complete = 3,
}

public sealed record LoadRunRequest(string? Profile);

public sealed record LoadRunResult(
    string RunId,
    string Profile,
    long TotalEntities,
    long TotalApproximateBytes,
    double TotalApplyMs,
    double TotalWallMs,
    IReadOnlyList<LoadRunTierResult> Tiers);

public sealed record LoadRunTierResult(
    string Tier,
    int Packages,
    long Entities,
    long ApproximateBytes,
    double ApplyMs,
    double WallMs,
    IReadOnlyList<LoadRunPackageResult> PackageResults);

public sealed record LoadRunPackageResult(
    string PackageId,
    int Entities,
    long ApproximateBytes,
    double ApplyMs,
    long FromVersion,
    long ToVersion);

public sealed record LoadProfileDescription(
    string Name,
    string Description,
    int TotalPackages,
    long TotalEntities,
    IReadOnlyList<LoadTierDescription> Tiers);

public sealed record LoadTierDescription(
    string Name,
    int Packages,
    int FacilitiesPerPackage,
    int EquipmentPerFacility,
    int LogsPerEquipment,
    int PadBytes,
    int EntitiesPerPackage,
    int TotalEntities);

public sealed record LoadPingResult(string PingId, double ServerLatencyMs, DateTimeOffset TimestampUtc);

public sealed record LoadRunSummary(
    string RunId,
    string Profile,
    string Status,
    long TotalEntities,
    long TotalApproximateBytes,
    double? TotalWallMs,
    DateTimeOffset StartedUtc,
    DateTimeOffset? EndedUtc,
    int PackagesDone,
    int PackagesTotal);

public sealed record LoadRunClientCatchup(
    string ClientId,
    long PullCount,
    long NonEmptyPullCount,
    long PullBytes,
    double? PullP50Ms,
    double? PullP95Ms,
    double? PullMaxMs,
    long ApplyCount,
    long ApplyBytes,
    double? ApplyP50Ms,
    double? ApplyP95Ms,
    double? ApplyMaxMs,
    DateTimeOffset? FirstActivityUtc,
    DateTimeOffset? LastActivityUtc,
    long? FromVersion,
    long? ToVersion);

public sealed record LoadRunReport(
    string RunId,
    string Profile,
    string Status,
    DateTimeOffset StartedUtc,
    DateTimeOffset? EndedUtc,
    DateTimeOffset? CompletedUtc,
    int PackagesDone,
    int PackagesTotal,
    long EntitiesApplied,
    long BytesApplied,
    double? TotalApplyMs,
    double? TotalWallMs,
    long? FromVersion,
    long? ToVersion,
    IReadOnlyList<LoadRunTierResult> Tiers,
    IReadOnlyList<LoadRunClientCatchup> Clients,
    double CatchupWindowSeconds);
