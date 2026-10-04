using System.Runtime.InteropServices;
using FocusBM.Core;

namespace FocusBM.Infrastructure.Windows.Activation;

public sealed class WindowsImeService : IImeService
{
    private IntPtr _lastHwnd;
    private int _lastConversion;
    private int _lastSentence;
    private bool _hasSnapshot;

    public Task<OperationResult> DisableImeAsync(CancellationToken cancellationToken = default)
    {
        if (!OperatingSystem.IsWindows()) return Task.FromResult(OperationResult.VisibleError(OperationStatus.Unsupported, "IME control is Windows-only"));
        var hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return Task.FromResult(OperationResult.VisibleError(OperationStatus.NotFound, "No foreground window for IME"));
        var himc = ImmGetContext(hwnd);
        if (himc == IntPtr.Zero) return Task.FromResult(OperationResult.VisibleError(OperationStatus.Unsupported, "No IME context"));
        try
        {
            if (!ImmGetConversionStatus(himc, out _lastConversion, out _lastSentence))
                return Task.FromResult(OperationResult.VisibleError(OperationStatus.Failed, "ImmGetConversionStatus failed"));
            _lastHwnd = hwnd;
            _hasSnapshot = true;
            var ok = ImmSetConversionStatus(himc, 0, _lastSentence);
            return Task.FromResult(ok ? OperationResult.Success("IME disabled") : OperationResult.VisibleError(OperationStatus.Failed, "ImmSetConversionStatus failed"));
        }
        finally
        {
            ImmReleaseContext(hwnd, himc);
        }
    }

    public Task<OperationResult> RestoreImeAsync(CancellationToken cancellationToken = default)
    {
        if (!OperatingSystem.IsWindows()) return Task.FromResult(OperationResult.VisibleError(OperationStatus.Unsupported, "IME control is Windows-only"));
        if (!_hasSnapshot || _lastHwnd == IntPtr.Zero) return Task.FromResult(OperationResult.Success("IME restore skipped: no snapshot"));
        var himc = ImmGetContext(_lastHwnd);
        if (himc == IntPtr.Zero) return Task.FromResult(OperationResult.VisibleError(OperationStatus.Unsupported, "No IME context to restore"));
        try
        {
            var ok = ImmSetConversionStatus(himc, _lastConversion, _lastSentence);
            _hasSnapshot = false;
            return Task.FromResult(ok ? OperationResult.Success("IME restored") : OperationResult.VisibleError(OperationStatus.Failed, "IME restore failed"));
        }
        finally
        {
            ImmReleaseContext(_lastHwnd, himc);
        }
    }

    // Why: ImmGetContext fails for another process's window, and the foreground window is that after activating
    //      another app. WM_IME_CONTROL to the default IME window works for any IME (MS-IME, ATOK) without a per-process context.
    public static bool TurnOffForForeground()
    {
        if (!OperatingSystem.IsWindows()) return false;
        var hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return false;
        var imeWnd = ImmGetDefaultIMEWnd(hwnd);
        if (imeWnd == IntPtr.Zero) return false;
        return SendMessageTimeout(imeWnd, WM_IME_CONTROL, new IntPtr(IMC_SETOPENSTATUS), IntPtr.Zero, SMTO_ABORTIFHUNG, 200, out _) != IntPtr.Zero;
    }

    private const uint WM_IME_CONTROL = 0x0283;
    private const int IMC_SETOPENSTATUS = 0x0006;
    private const uint SMTO_ABORTIFHUNG = 0x0002;

    [DllImport("imm32.dll")] private static extern IntPtr ImmGetDefaultIMEWnd(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("imm32.dll")] private static extern IntPtr ImmGetContext(IntPtr hWnd);
    [DllImport("imm32.dll")] private static extern bool ImmReleaseContext(IntPtr hWnd, IntPtr hIMC);
    [DllImport("imm32.dll")] private static extern bool ImmGetConversionStatus(IntPtr hIMC, out int lpfdwConversion, out int lpfdwSentence);
    [DllImport("imm32.dll")] private static extern bool ImmSetConversionStatus(IntPtr hIMC, int fdwConversion, int fdwSentence);
}
