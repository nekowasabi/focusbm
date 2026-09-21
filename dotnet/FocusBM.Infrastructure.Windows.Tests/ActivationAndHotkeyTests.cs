using FocusBM.Core;
using FocusBM.Infrastructure.Windows.Activation;
using FocusBM.Infrastructure.Windows.Hotkeys;
using Xunit;

namespace FocusBM.Infrastructure.Windows.Tests;

public class ActivationAndHotkeyTests
{
    [Fact] public async Task Activation_ReturnsUnsupportedOnNonWindows()
    {
        var result = await new WindowsActivationService().ActivateAsync(new ActivationTarget.App("notepad"));
        if (!OperatingSystem.IsWindows()) Assert.Equal(OperationStatus.Unsupported, result.Status);
    }

    [Fact] public async Task Hotkey_RequiresWindowsAndHwnd()
    {
        var service = new WindowsHotkeyService();
        var result = await service.RegisterAsync(new ParsedHotkey("Space", HotkeyModifiers.Control));
        if (!OperatingSystem.IsWindows()) Assert.Equal(OperationStatus.Unsupported, result.Status);
        else Assert.Equal(OperationStatus.ValidationError, result.Status);
    }

    [Fact]
    public async Task HotkeyService_RejectsMissingHwndOnWindows()
    {
        if (!OperatingSystem.IsWindows()) return;
        var result = await new WindowsHotkeyService(IntPtr.Zero).RegisterAsync(new ParsedHotkey(",", HotkeyModifiers.Control));
        Assert.Equal(OperationStatus.ValidationError, result.Status);
    }
}
