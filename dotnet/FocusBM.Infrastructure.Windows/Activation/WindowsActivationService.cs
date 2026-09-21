using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using FocusBM.Core;

namespace FocusBM.Infrastructure.Windows.Activation;

public sealed class WindowsActivationService : IActivationService
{
    private readonly bool _virtuawinEnabled;
    private readonly IRestoreTimingSink? _timing;

    public WindowsActivationService(bool virtuawinEnabled = true, IRestoreTimingSink? timing = null)
    {
        _virtuawinEnabled = virtuawinEnabled;
        _timing = timing;
    }

    public Task<OperationResult> ActivateAsync(ActivationTarget target, CancellationToken cancellationToken = default)
    {
        if (!OperatingSystem.IsWindows()) return Task.FromResult(OperationResult.VisibleError(OperationStatus.Unsupported, "Windows activation is unavailable on this OS"));
        var timing = new RestoreTimingScope($"activation:{target.GetType().Name}", _timing);
        timing.Mark("start");
        var result = target switch
        {
            ActivationTarget.App app => ActivateApp(app, timing),
            ActivationTarget.BrowserTab tab => ActivateBrowserTab(tab, timing),
            ActivationTarget.TmuxPane => OperationResult.VisibleError(OperationStatus.Unsupported, "tmux restore requires WSL/tmux provider"),
            _ => OperationResult.VisibleError(OperationStatus.Unsupported, "unsupported activation target")
        };
        timing.Mark("complete", result.Status.ToString());
        return Task.FromResult(result);
    }

    private OperationResult ActivateApp(ActivationTarget.App target, RestoreTimingScope timing)
    {
        var candidates = FindCandidateProcesses(target.AppName, target.BundleIdPattern).ToList();
        timing.Mark("process-scan:complete", candidates.Count.ToString());
        if (candidates.Count == 0)
        {
            try
            {
                Process.Start(new ProcessStartInfo(target.AppName) { UseShellExecute = true });
                return OperationResult.Success($"起動要求を送信しました: {target.AppName}", target);
            }
            catch (Exception ex)
            {
                return OperationResult.VisibleError(OperationStatus.NotFound, $"起動/切替対象が見つかりません: {target.AppName} ({Redactor.Mask(ex.Message)})");
            }
        }

        var withWindow = candidates.Where(p => p.MainWindowHandle != IntPtr.Zero).ToList();
        if (!string.IsNullOrWhiteSpace(target.WindowTitle))
        {
            var titleMatch = withWindow.FirstOrDefault(p => SafeTitle(p).Contains(target.WindowTitle, StringComparison.OrdinalIgnoreCase));
            if (titleMatch is not null) withWindow = new List<Process> { titleMatch };
        }
        var proc = withWindow.FirstOrDefault() ?? candidates.First();
        if (IsHigherIntegrityThanCurrent(proc))
        {
            return OperationResult.VisibleError(OperationStatus.ValidationError, $"高整合性プロセスへの暗黙の前面化を拒否しました: {proc.ProcessName}");
        }

        var hwnd = ResolveTopLevelHwnd(candidates, target.AppName);
        FocusBmLog.Write("activation", $"{target.AppName} processes={candidates.Count} main={proc.MainWindowHandle} hwnd={hwnd}");
        var switchedDesktop = false;
        if (_virtuawinEnabled)
        {
            timing.Mark("virtuawin:start");
            switchedDesktop = TrySwitchVirtuaWinDesktop(ref hwnd, candidates, target.AppName);
            timing.Mark("virtuawin:complete", switchedDesktop ? "switched" : "skip");
        }
        if (hwnd == IntPtr.Zero)
        {
            return OperationResult.VisibleError(OperationStatus.NotFound, $"表示可能なウィンドウが見つかりません: {target.AppName}");
        }
        if (IsIconic(hwnd)) ShowWindow(hwnd, SW_RESTORE);
        else ShowWindow(hwnd, SW_SHOW);
        var ok = SetForegroundWindow(hwnd);
        if (!ok)
        {
            SwitchToThisWindow(hwnd, true);
            ok = SetForegroundWindow(hwnd);
        }
        timing.Mark("foreground:complete", ok ? "success" : switchedDesktop ? "virtuawin" : "failed");
        return ok || switchedDesktop
            ? OperationResult.Success($"切り替えました: {proc.ProcessName}", target)
            : OperationResult.VisibleError(OperationStatus.Failed, $"前面化に失敗しました: {proc.ProcessName}");
    }

    private OperationResult ActivateBrowserTab(ActivationTarget.BrowserTab tab, RestoreTimingScope timing)
    {
        var activated = ActivateApp(new ActivationTarget.App(tab.AppName), timing);
        if (!activated.IsSuccess) return activated;
        if (tab.TabIndex is int index)
        {
            var mapped = BrowserTabIndex.ControlDigit(index);
            if (mapped is null) return OperationResult.VisibleError(OperationStatus.ValidationError, $"tabIndex は 1 以上が必要です: {index}");
            Thread.Sleep(50);
            if (!SendControlDigit(mapped.Value))
                return OperationResult.VisibleError(OperationStatus.Failed, $"タブ切替キーの送信に失敗しました: Ctrl+{mapped.Value}");
            return OperationResult.Success($"切り替えました: {tab.AppName} タブ {mapped.Value}", tab);
        }
        var openUrl = BrowserOpenUrl.Resolve(tab.Url, tab.UrlPattern);
        if (openUrl is null) return activated;
        return OpenNewBrowserTab(tab, openUrl);
    }

    private static bool SendControlDigit(int digit)
    {
        var vkDigit = (ushort)('0' + digit);
        INPUT[] inputs =
        [
            Key(0x11, 0),
            Key(vkDigit, 0),
            Key(vkDigit, KEYEVENTF_KEYUP),
            Key(0x11, KEYEVENTF_KEYUP)
        ];
        return SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>()) == (uint)inputs.Length;
    }

    private OperationResult OpenNewBrowserTab(ActivationTarget.BrowserTab tab, string url)
    {
        var flag = tab.AppName.Contains("firefox", StringComparison.OrdinalIgnoreCase) ? "-new-tab" : "--new-tab";
        var exe = FindBrowserExecutable(tab.AppName);
        try
        {
            // Why: UseShellExecute=false (CreateProcess of firefox.exe) is a common VPN/AV
            // heuristic for process injection and can terminate this tray app.
            Process.Start(new ProcessStartInfo
            {
                FileName = exe ?? url,
                Arguments = exe is null ? "" : $"{flag} {url}",
                UseShellExecute = true
            });
            FocusBmLog.Write("browser", $"new-tab {tab.AppName} {url}");
            return OperationResult.Success($"opened {url}", tab);
        }
        catch (Exception ex)
        {
            return OperationResult.VisibleError(OperationStatus.Failed, $"URL を開けません: {Redactor.Mask(ex.Message)}");
        }
    }

    private static string? FindBrowserExecutable(string appName)
    {
        foreach (var p in FindCandidateProcesses(appName, null))
        {
            try
            {
                var path = p.MainModule?.FileName;
                if (!string.IsNullOrWhiteSpace(path)) return path;
            }
            catch { /* 64-bit MainModule can throw */ }
            if (!string.IsNullOrWhiteSpace(p.ProcessName)) return p.ProcessName;
        }
        return null;
    }

    private static INPUT Key(ushort vk, uint flags) => new()
    {
        type = 1,
        U = new InputUnion { ki = new KEYBDINPUT { wVk = vk, dwFlags = flags } }
    };

    private const uint KEYEVENTF_KEYUP = 0x0002;

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion U;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    private static string SafeTitle(Process p)
    {
        try { return p.MainWindowTitle ?? string.Empty; } catch { return string.Empty; }
    }

    private static IEnumerable<Process> FindCandidateProcesses(string appName, string? bundleIdPattern)
    {
        var normalized = NormalizeName(appName);
        var pattern = NormalizeName(bundleIdPattern ?? string.Empty);
        foreach (var p in Process.GetProcesses())
        {
            string name;
            try { name = p.ProcessName; } catch { continue; }
            var n = NormalizeName(name);
            if (n.Contains(normalized, StringComparison.OrdinalIgnoreCase)
                || normalized.Contains(n, StringComparison.OrdinalIgnoreCase)
                || (!string.IsNullOrEmpty(pattern) && n.Contains(pattern, StringComparison.OrdinalIgnoreCase)))
            {
                yield return p;
            }
        }
    }

    private static string NormalizeName(string value)
    {
        var sb = new StringBuilder(value.Length);
        foreach (var ch in value)
        {
            if (char.IsLetterOrDigit(ch)) sb.Append(char.ToLowerInvariant(ch));
        }
        return sb.ToString();
    }

    private static IntPtr ResolveTopLevelHwnd(List<Process> candidates, string appName)
    {
        var hwnds = EnumerateCandidateHwnds(IntPtr.Zero, candidates, appName);
        return hwnds.Count > 0 ? hwnds[0] : IntPtr.Zero;
    }

    private static bool TrySwitchVirtuaWinDesktop(ref IntPtr targetWindow, List<Process> candidates, string appName)
    {
        var virtuawin = FindWindow("VirtuaWinMainClass", null);
        if (virtuawin == IntPtr.Zero)
        {
            FocusBmLog.Write("virtuawin", "skip no-window");
            return false;
        }
        if (!IsVirtuaWinProcess(virtuawin))
            FocusBmLog.Write("virtuawin", "window-class matched with unexpected process name");

        var hwnds = EnumerateCandidateHwnds(targetWindow, candidates, appName);
        var currentDesk = SendMessageTimeout(virtuawin, VW_CURDESK, IntPtr.Zero, IntPtr.Zero, SMTO_ABORTIFHUNG, VIRTUAWIN_TIMEOUT_MS, out var deskResult);
        var desk = currentDesk == IntPtr.Zero ? 0 : (int)deskResult.ToInt64();
        foreach (var hwnd in hwnds)
        {
            if (AccessVirtuaWinWindow(virtuawin, hwnd, desk))
            {
                targetWindow = hwnd;
                FocusBmLog.Write("virtuawin", $"switched hwnd={hwnd}");
                return true;
            }
        }
        FocusBmLog.Write("virtuawin", "skip not-managed");
        return false;
    }

    private static List<IntPtr> EnumerateCandidateHwnds(IntPtr preferred, List<Process> candidates, string? appName = null)
    {
        var pids = new HashSet<int>();
        foreach (var p in candidates)
        {
            try { pids.Add(p.Id); } catch { }
        }
        var wantCascadia = appName is not null && NormalizeName(appName).Contains("windowsterminal", StringComparison.Ordinal);
        var found = new List<IntPtr>();
        if (preferred != IntPtr.Zero) found.Add(preferred);
        EnumWindows((hwnd, _) =>
        {
            GetWindowThreadProcessId(hwnd, out uint pid);
            var pidOk = pids.Contains(unchecked((int)pid));
            var cascadia = wantCascadia && string.Equals(WindowClass(hwnd), "CASCADIA_HOSTING_WINDOW_CLASS", StringComparison.Ordinal);
            if (!pidOk && !cascadia) return true;
            if (GetWindow(hwnd, GwOwner) != IntPtr.Zero) return true;
            if (!found.Contains(hwnd)) found.Add(hwnd);
            return true;
        }, IntPtr.Zero);
        return found;
    }

    private static string WindowClass(IntPtr hwnd)
    {
        var sb = new StringBuilder(256);
        return GetClassName(hwnd, sb, sb.Capacity) > 0 ? sb.ToString() : string.Empty;
    }

    private static bool AccessVirtuaWinWindow(IntPtr virtuawin, IntPtr hwnd, int currentDesk)
    {
        var delivered = SendMessageTimeout(virtuawin, VW_WINGETINFO, hwnd, IntPtr.Zero, SMTO_ABORTIFHUNG, VIRTUAWIN_TIMEOUT_MS, out var info);
        if (delivered != IntPtr.Zero && info != IntPtr.Zero)
        {
            var bits = info.ToInt64();
            var windowDesk = (int)((bits >> 24) & 0xff);
            if (currentDesk != 0 && windowDesk == currentDesk)
            {
                FocusBmLog.Write("virtuawin", $"hwnd={hwnd} already desk={windowDesk}");
                return false;
            }
        }
        if (SendAccess(virtuawin, hwnd)) return true;
        SendMessageTimeout(virtuawin, VW_WINMANAGE, hwnd, new IntPtr(1), SMTO_ABORTIFHUNG, VIRTUAWIN_TIMEOUT_MS, out _);
        return SendAccess(virtuawin, hwnd);
    }

    private static bool SendAccess(IntPtr virtuawin, IntPtr hwnd)
    {
        var delivered = SendMessageTimeout(virtuawin, VW_ACCESS_WINDOW, hwnd, new IntPtr(VW_ACCESS_SWITCH_TO_WINDOW_DESKTOP), SMTO_ABORTIFHUNG, VIRTUAWIN_TIMEOUT_MS, out var result);
        FocusBmLog.Write("virtuawin", $"access hwnd={hwnd} delivered={delivered != IntPtr.Zero} result={result}");
        return delivered != IntPtr.Zero && result != IntPtr.Zero;
    }

    private static bool IsVirtuaWinProcess(IntPtr window)
    {
        _ = GetWindowThreadProcessId(window, out var processId);
        try
        {
            using var process = Process.GetProcessById((int)processId);
            return process.ProcessName.Contains("virtua", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }


    private static bool IsHigherIntegrityThanCurrent(Process target)
    {
        try
        {
            var current = GetProcessIntegrityLevel(Process.GetCurrentProcess());
            var other = GetProcessIntegrityLevel(target);
            return other > current && other >= SECURITY_MANDATORY_HIGH_RID;
        }
        catch
        {
            return false;
        }
    }

    private static int GetProcessIntegrityLevel(Process process)
    {
        if (!OpenProcessToken(process.Handle, TOKEN_QUERY, out var token)) return SECURITY_MANDATORY_MEDIUM_RID;
        try
        {
            GetTokenInformation(token, TOKEN_INFORMATION_CLASS.TokenIntegrityLevel, IntPtr.Zero, 0, out var length);
            if (length <= 0) return SECURITY_MANDATORY_MEDIUM_RID;
            var buffer = Marshal.AllocHGlobal(length);
            try
            {
                if (!GetTokenInformation(token, TOKEN_INFORMATION_CLASS.TokenIntegrityLevel, buffer, length, out _)) return SECURITY_MANDATORY_MEDIUM_RID;
                var label = Marshal.PtrToStructure<TOKEN_MANDATORY_LABEL>(buffer);
                var sid = label.Label.Sid;
                var subAuthCount = Marshal.ReadByte(GetSidSubAuthorityCount(sid));
                var ridPtr = GetSidSubAuthority(sid, subAuthCount - 1);
                return Marshal.ReadInt32(ridPtr);
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }
        finally
        {
            CloseHandle(token);
        }
    }

    private const int SW_RESTORE = 9;
    private const int SW_SHOW = 5;
    private const uint VW_ACCESS_WINDOW = 1063; // WM_USER+39
    private const uint VW_CURDESK = 1048; // WM_USER+24
    private const uint VW_WINGETINFO = 1064; // WM_USER+40
    private const uint VW_WINMANAGE = 1069; // WM_USER+45
    private const int VW_ACCESS_SWITCH_TO_WINDOW_DESKTOP = 3;
    private const uint SMTO_ABORTIFHUNG = 0x0002;
    private const uint VIRTUAWIN_TIMEOUT_MS = 1000;
    private const uint GaRootOwner = 3;
    private const uint GwOwner = 4;
    private const int TOKEN_QUERY = 0x0008;
    private const int SECURITY_MANDATORY_MEDIUM_RID = 0x00002000;
    private const int SECURITY_MANDATORY_HIGH_RID = 0x00003000;

    private enum TOKEN_INFORMATION_CLASS { TokenUser = 1, TokenGroups, TokenPrivileges, TokenOwner, TokenPrimaryGroup, TokenDefaultDacl, TokenSource, TokenType, TokenImpersonationLevel, TokenStatistics, TokenRestrictedSids, TokenSessionId, TokenGroupsAndPrivileges, TokenSessionReference, TokenSandBoxInert, TokenAuditPolicy, TokenOrigin, TokenElevationType, TokenLinkedToken, TokenElevation, TokenHasRestrictions, TokenAccessInformation, TokenVirtualizationAllowed, TokenVirtualizationEnabled, TokenIntegrityLevel }
    [StructLayout(LayoutKind.Sequential)] private struct SID_AND_ATTRIBUTES { public IntPtr Sid; public int Attributes; }
    [StructLayout(LayoutKind.Sequential)] private struct TOKEN_MANDATORY_LABEL { public SID_AND_ATTRIBUTES Label; }

    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr FindWindow(string lpClassName, string? lpWindowName);
    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] private static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);
    [DllImport("user32.dll")] private static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("advapi32.dll", SetLastError = true)] private static extern bool OpenProcessToken(IntPtr ProcessHandle, int DesiredAccess, out IntPtr TokenHandle);
    [DllImport("advapi32.dll", SetLastError = true)] private static extern bool GetTokenInformation(IntPtr TokenHandle, TOKEN_INFORMATION_CLASS TokenInformationClass, IntPtr TokenInformation, int TokenInformationLength, out int ReturnLength);
    [DllImport("advapi32.dll", SetLastError = true)] private static extern IntPtr GetSidSubAuthority(IntPtr pSid, int nSubAuthority);
    [DllImport("advapi32.dll", SetLastError = true)] private static extern IntPtr GetSidSubAuthorityCount(IntPtr pSid);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool CloseHandle(IntPtr hObject);
}
