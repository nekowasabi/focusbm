using System.Runtime.InteropServices;
using FocusBM.Core;

namespace FocusBM.Infrastructure.Windows.Hotkeys;

/// <summary>
/// RegisterHotKey based hotkey service. WH_KEYBOARD_LL is intentionally not used.
/// The hwnd must outlive panel Hide() — use a message-only window, not the search panel.
/// </summary>
public sealed class WindowsHotkeyService : IHotkeyService
{
    private const int WM_HOTKEY = 0x0312;
    private readonly IntPtr _hwnd;
    private readonly Action? _ensureMessageHook;
    private int _registeredId;
    public event EventHandler? Pressed;

    public WindowsHotkeyService(IntPtr hwnd = default, Action? ensureMessageHook = null)
    {
        _hwnd = hwnd;
        _ensureMessageHook = ensureMessageHook;
    }

    public Task<OperationResult> RegisterAsync(ParsedHotkey hotkey, CancellationToken cancellationToken = default)
    {
        if (!OperatingSystem.IsWindows()) return Task.FromResult(OperationResult.VisibleError(OperationStatus.Unsupported, "RegisterHotKey is Windows-only"));
        if (_hwnd == IntPtr.Zero) return Task.FromResult(OperationResult.VisibleError(OperationStatus.ValidationError, "HwndSource handle is required for RegisterHotKey"));
        if (_registeredId != 0) return Task.FromResult(OperationResult.VisibleError(OperationStatus.Duplicate, "Hotkey already registered"));
        var vk = VirtualKeyFromString(hotkey.Key);
        if (vk == 0) return Task.FromResult(OperationResult.VisibleError(OperationStatus.ValidationError, $"Unsupported hotkey key: {hotkey.Key}"));
        var id = Math.Abs(HashCode.Combine(hotkey.Key, hotkey.Modifiers, _hwnd.ToInt64()));
        if (id == 0) id = 1;
        if (!RegisterHotKey(_hwnd, id, ToNativeModifiers(hotkey.Modifiers), vk))
        {
            return Task.FromResult(OperationResult.VisibleError(OperationStatus.Duplicate, $"Hotkey registration failed: {Marshal.GetLastWin32Error()}"));
        }
        _registeredId = id;
        _ensureMessageHook?.Invoke();
        return Task.FromResult(OperationResult.Success($"Hotkey registered: {hotkey.Modifiers}+{hotkey.Key}"));
    }

    public bool ProcessWindowMessage(int msg, IntPtr wParam)
    {
        if (msg == WM_HOTKEY && _registeredId != 0 && wParam.ToInt32() == _registeredId)
        {
            Pressed?.Invoke(this, EventArgs.Empty);
            return true;
        }
        return false;
    }

    public Task UnregisterAsync(CancellationToken cancellationToken = default)
    {
        if (_registeredId != 0 && OperatingSystem.IsWindows()) UnregisterHotKey(_hwnd, _registeredId);
        _registeredId = 0;
        return Task.CompletedTask;
    }

    public ValueTask DisposeAsync() => new(UnregisterAsync());
    internal void RaisePressedForTest() => Pressed?.Invoke(this, EventArgs.Empty);

    private static uint ToNativeModifiers(HotkeyModifiers modifiers)
    {
        uint native = 0;
        if (modifiers.HasFlag(HotkeyModifiers.Control)) native |= 0x0002;
        if (modifiers.HasFlag(HotkeyModifiers.Option)) native |= 0x0001;
        if (modifiers.HasFlag(HotkeyModifiers.Shift)) native |= 0x0004;
        if (modifiers.HasFlag(HotkeyModifiers.Windows) || modifiers.HasFlag(HotkeyModifiers.Command)) native |= 0x0008;
        return native;
    }

    private static uint VirtualKeyFromString(string key)
    {
        if (string.IsNullOrWhiteSpace(key)) return 0;
        if (key.Length == 1)
        {
            var ch = char.ToUpperInvariant(key[0]);
            if (ch is >= 'A' and <= 'Z') return ch;
            if (ch is >= '0' and <= '9') return ch;
            if (ch == ',') return 0xBC; // VK_OEM_COMMA
        }
        return key.ToLowerInvariant() switch
        {
            "space" => 0x20,
            "enter" or "return" => 0x0D,
            "escape" or "esc" => 0x1B,
            "tab" => 0x09,
            "comma" or "oemcomma" => 0xBC,
            "f1" => 0x70, "f2" => 0x71, "f3" => 0x72, "f4" => 0x73,
            "f5" => 0x74, "f6" => 0x75, "f7" => 0x76, "f8" => 0x77,
            "f9" => 0x78, "f10" => 0x79, "f11" => 0x7A, "f12" => 0x7B,
            _ => 0
        };
    }

    [DllImport("user32.dll", SetLastError = true)] private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
