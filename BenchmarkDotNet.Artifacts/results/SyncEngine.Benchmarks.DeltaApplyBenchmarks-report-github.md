```

BenchmarkDotNet v0.15.4, Windows 11 (10.0.26200.9711)
13th Gen Intel Core i7-13800H 2.50GHz, 1 CPU, 20 logical and 14 physical cores
.NET SDK 10.0.401
  [Host]     : .NET 10.0.12 (10.0.12, 10.0.1226.42308), X64 RyuJIT x86-64-v3
  Job-WWFMMQ : .NET 10.0.12 (10.0.12, 10.0.1226.42308), X64 RyuJIT x86-64-v3

IterationCount=3  WarmupCount=1  

```
| Method                                           | ChangeCount | Mean     | Error    | StdDev   | Gen0    | Allocated |
|------------------------------------------------- |------------ |---------:|---------:|---------:|--------:|----------:|
| &#39;Apply 1k MemoryPack facility upserts to SQLite&#39; | 1000        | 20.04 ms | 11.60 ms | 0.636 ms | 93.7500 |   1.21 MB |
