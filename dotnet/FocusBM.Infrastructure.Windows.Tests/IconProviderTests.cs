using FocusBM.Core;
using FocusBM.Infrastructure.Windows.Icons;
using Xunit;

namespace FocusBM.Infrastructure.Windows.Tests;

public class IconProviderTests
{
    [Fact]
    public async Task GetIcon_ReturnsFallbackOnNonWindowsWithoutThrowing()
    {
        var result = await new WindowsIconProvider().GetIconAsync("notepad");
        if (!OperatingSystem.IsWindows())
        {
            Assert.Equal(OperationStatus.NoOp, result.Status);
            Assert.NotNull(result.PngBytes);
            Assert.True(result.PngBytes!.Length > 0);
        }
    }
}
