using System.Net;
using FocusBM.Core;
using FocusBM.Infrastructure.Windows.Browser;
using Xunit;

namespace FocusBM.Infrastructure.Windows.Tests;

public class ChromiumCdpCaptureTests
{
    [Fact]
    public async Task CaptureFirstPage_ReturnsBrowserStateFromJsonList()
    {
        var settings = new AppSettings(BrowserCdp: new BrowserCdpSettings(
            Enabled: true,
            Endpoint: "http://127.0.0.1:9222",
            ProfilePath: "C:/tmp/focusbm-cdp", RequireProfileMarker: false, RequireKnownBrowserOwner: false));
        var http = new HttpClient(new FakeHandler(req =>
        {
            Assert.EndsWith("/json/list", req.RequestUri!.ToString());
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("""
                [ { "id": "1", "type": "page", "title": "Example", "url": "https://example.test/path" } ]
                """)
            };
        }));
        var result = await new ChromiumCdpTabService(settings, http).CaptureFirstPageAsync("chrome");
        Assert.Equal(OperationStatus.Success, result.Status);
        var state = Assert.IsType<BrowserAppState>(result.State);
        Assert.Equal("https://example.test/path", state.Url);
        Assert.Equal("https://example.test", state.UrlPrefix);
        Assert.Equal("Example", state.Title);
    }

    [Fact]
    public async Task RestoreTab_ReusesListAndRefreshesWhenTabIdIsStale()
    {
        var settings = new AppSettings(BrowserCdp: new BrowserCdpSettings(
            Enabled: true,
            Endpoint: "http://127.0.0.1:9222",
            ProfilePath: "C:/tmp/focusbm-cdp", RequireProfileMarker: false, RequireKnownBrowserOwner: false));
        var listRequests = 0;
        var activateRequests = 0;
        var http = new HttpClient(new FakeHandler(req =>
        {
            if (req.RequestUri!.AbsolutePath == "/json/list")
            {
                listRequests++;
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(listRequests == 1
                        ? "[{\"id\":\"old\",\"type\":\"page\",\"url\":\"https://example.test/path\"}]"
                        : "[{\"id\":\"new\",\"type\":\"page\",\"url\":\"https://example.test/path\"}]")
                };
            }

            Assert.StartsWith("/json/activate/", req.RequestUri.AbsolutePath);
            activateRequests++;
            return new HttpResponseMessage(activateRequests == 1 ? HttpStatusCode.NotFound : HttpStatusCode.OK);
        }));
        var service = new ChromiumCdpTabService(settings, http);
        var state = new BrowserAppState("https://example.test/path", null, null, null);

        var first = await service.RestoreTabAsync(state);
        var second = await service.RestoreTabAsync(state);

        Assert.Equal(OperationStatus.Success, first.Status);
        Assert.Equal(OperationStatus.Success, second.Status);
        Assert.Equal(2, listRequests);
        Assert.Equal(3, activateRequests);
    }

    private sealed class FakeHandler : HttpMessageHandler
    {
        private readonly Func<HttpRequestMessage, HttpResponseMessage> _handler;
        public FakeHandler(Func<HttpRequestMessage, HttpResponseMessage> handler) => _handler = handler;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) => Task.FromResult(_handler(request));
    }
}
