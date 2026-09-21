using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using FocusBM.Core;

namespace FocusBM.Infrastructure.Windows.Activation;

public sealed class WindowsForegroundContextService : IForegroundContextService
{
    public Task<ForegroundContextResult> CaptureAsync(AppSettings settings, CancellationToken cancellationToken = default)
    {
        if (!OperatingSystem.IsWindows())
        {
            return Task.FromResult(new ForegroundContextResult(OperationStatus.Unsupported, "Foreground capture is Windows-only", "", ""));
        }

        var hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return Task.FromResult(new ForegroundContextResult(OperationStatus.NotFound, "No foreground window", "", ""));
        var title = GetWindowTitle(hwnd);
        GetWindowThreadProcessId(hwnd, out var pid);
        string appName;
        try { appName = Process.GetProcessById((int)pid).ProcessName; }
        catch { appName = "Unknown"; }
        var state = new AppOnlyState(string.IsNullOrWhiteSpace(title) ? null : title);
        return Task.FromResult(new ForegroundContextResult(OperationStatus.Success, $"Captured foreground app: {appName}", appName, title, appName, state));
    }

    private static string GetWindowTitle(IntPtr hwnd)
    {
        var len = GetWindowTextLength(hwnd);
        if (len <= 0) return string.Empty;
        var sb = new StringBuilder(len + 1);
        GetWindowText(hwnd, sb, sb.Capacity);
        return Redactor.Mask(sb.ToString());
    }

    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", SetLastError = true)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll", SetLastError = true)] private static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError = true)] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
