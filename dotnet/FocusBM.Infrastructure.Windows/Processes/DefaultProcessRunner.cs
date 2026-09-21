using System.Diagnostics;
using FocusBM.Core;

namespace FocusBM.Infrastructure.Windows.Processes;

public sealed class DefaultProcessRunner : IProcessRunner
{
    private readonly IRestoreTimingSink? _timing;

    public DefaultProcessRunner(IRestoreTimingSink? timing = null) => _timing = timing;

    public async Task<ProcessRunResult> RunAsync(string fileName, IReadOnlyList<string> arguments, TimeSpan timeout, CancellationToken cancellationToken = default)
    {
        var timing = new RestoreTimingScope($"process:{fileName}", _timing);
        timing.Mark("start");
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        cts.CancelAfter(timeout);
        // Why: UseShellExecute=false alone does not prevent console-hosted helpers from flashing on Windows, so explicitly hide the child window.
        using var p = new Process
        {
            StartInfo = new ProcessStartInfo(fileName)
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            }
        };
        foreach (var arg in arguments) p.StartInfo.ArgumentList.Add(arg);
        p.Start();
        timing.Mark("started");
        try
        {
            var stdout = p.StandardOutput.ReadToEndAsync(cts.Token);
            var stderr = p.StandardError.ReadToEndAsync(cts.Token);
            await p.WaitForExitAsync(cts.Token).ConfigureAwait(false);
            var result = new ProcessRunResult(p.ExitCode, await stdout.ConfigureAwait(false), await stderr.ConfigureAwait(false), false);
            timing.Mark("complete", result.ExitCode.ToString());
            return result;
        }
        catch (OperationCanceledException)
        {
            try { if (!p.HasExited) p.Kill(entireProcessTree: true); } catch { }
            var result = new ProcessRunResult(-1, string.Empty, "timeout", true);
            timing.Mark("complete", "timeout");
            return result;
        }
    }
}
