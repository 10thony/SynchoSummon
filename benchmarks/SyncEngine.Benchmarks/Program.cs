using BenchmarkDotNet.Running;
using SyncEngine.Benchmarks;

if (args.Any(a => string.Equals(a, "--gates", StringComparison.OrdinalIgnoreCase)))
{
    return await GateRunner.RunAsync();
}

BenchmarkSwitcher.FromAssembly(typeof(Program).Assembly).Run(args);
return 0;
