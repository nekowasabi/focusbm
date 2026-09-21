using System.Diagnostics;

namespace FocusBM.Core;

public sealed record RestoreTimingSample(
    string Operation,
    string Stage,
    double ElapsedMilliseconds,
    string? Outcome = null);

public interface IRestoreTimingSink
{
    void Record(RestoreTimingSample sample);
}

public sealed class TraceRestoreTimingSink : IRestoreTimingSink
{
    public void Record(RestoreTimingSample sample)
    {
        var line = $"operation={sample.Operation} stage={sample.Stage} elapsedMs={sample.ElapsedMilliseconds:F1} outcome={sample.Outcome ?? ""}";
        Trace.WriteLine("focusbm.restore " + line);
        if (!sample.Operation.StartsWith("process:", StringComparison.Ordinal))
            FocusBmLog.Write("timing", line);
    }
}

public sealed class RestoreTimingScope
{
    private readonly string _operation;
    private readonly IRestoreTimingSink? _sink;
    private readonly Stopwatch _clock = Stopwatch.StartNew();

    public RestoreTimingScope(string operation, IRestoreTimingSink? sink)
    {
        _operation = operation;
        _sink = sink;
    }

    public void Mark(string stage, string? outcome = null) =>
        _sink?.Record(new RestoreTimingSample(_operation, stage, _clock.Elapsed.TotalMilliseconds, outcome));
}
