using FocusBM.Infrastructure.Windows.Browser;
using Xunit;

namespace FocusBM.Infrastructure.Windows.Tests;
public class BrowserCdpSafetyTests
{
    [Theory]
    [InlineData("http://127.0.0.1:9222", true)]
    [InlineData("ws://localhost:9222/devtools", false)]
    [InlineData("http://192.168.1.2:9222", false)]
    [InlineData("https://localhost:9222", false)]
    public void EndpointMustBeLoopbackHttpOrWs(string endpoint, bool expected) => Assert.Equal(expected, ChromiumCdpTabService.IsLoopbackEndpoint(endpoint));
}
