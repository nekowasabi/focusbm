using System.Net.Http.Json;
using System.Runtime.InteropServices;
using System.Net;
using System.Diagnostics;
using System.Text.Json.Serialization;
using FocusBM.Core;

namespace FocusBM.Infrastructure.Windows.Browser;

public sealed class ChromiumCdpTabService : IBrowserTabService
{
    private readonly AppSettings _settings;
    private readonly HttpClient _http;
    private readonly object _tabsCacheGate = new();
    private CachedTabList? _tabsCache;
    private readonly IRestoreTimingSink? _timing;

    // A short TTL avoids repeated /json/list calls during a restore/capture sequence without treating tab IDs as durable.
    private static readonly TimeSpan TabsCacheTtl = TimeSpan.FromMilliseconds(250);

    public ChromiumCdpTabService(AppSettings settings, HttpClient? http = null, IRestoreTimingSink? timing = null)
    {
        _settings = settings;
        _http = http ?? new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
        _timing = timing;
    }

    public async Task<OperationResult> RestoreTabAsync(BrowserAppState state, CancellationToken cancellationToken = default)
    {
        var cdp = _settings.BrowserCdp ?? new BrowserCdpSettings();
        if (ValidateSettings(cdp) is { } invalid) return invalid;
        var endpoint = (cdp.Endpoint ?? string.Empty).TrimEnd('/');

        try
        {
            var timing = new RestoreTimingScope("browser:restore", _timing);
            timing.Mark("start");
            var tabs = await GetTabsAsync(endpoint, cancellationToken).ConfigureAwait(false);
            timing.Mark("list:complete", tabs.Count.ToString());
            var match = tabs.FirstOrDefault(t => Matches(t, state));
            if (match is null) return OperationResult.VisibleError(OperationStatus.NotFound, "matching Chromium tab not found");
            if (string.IsNullOrWhiteSpace(match.Id)) return OperationResult.VisibleError(OperationStatus.Failed, "matching Chromium tab has no id");
            var activationStatus = await ActivateTabAsync(endpoint, match.Id, cancellationToken).ConfigureAwait(false);
            timing.Mark("activate:complete", ((int)activationStatus).ToString());
            if ((int)activationStatus is >= 200 and <= 299)
            {
                return OperationResult.Success($"Chromium tab activated: {Redactor.Mask(match.Url ?? match.Title ?? match.Id)}", new ActivationTarget.BrowserTab("Chromium", state.Url, state.TabIndex, state.UrlPrefix, state.UrlPattern));
            }
            if (activationStatus != HttpStatusCode.NotFound) return OperationResult.VisibleError(OperationStatus.Failed, $"CDP activate failed: {(int)activationStatus}");

            // A cached tab ID may have been replaced between /json/list and activation; refresh once through the existing path.
            InvalidateTabsCache(endpoint);
            tabs = await GetTabsAsync(endpoint, cancellationToken).ConfigureAwait(false);
            timing.Mark("refresh-list:complete", tabs.Count.ToString());
            match = tabs.FirstOrDefault(t => Matches(t, state));
            if (match is null) return OperationResult.VisibleError(OperationStatus.NotFound, "matching Chromium tab not found");
            if (string.IsNullOrWhiteSpace(match.Id)) return OperationResult.VisibleError(OperationStatus.Failed, "matching Chromium tab has no id");
            var refreshedActivationStatus = await ActivateTabAsync(endpoint, match.Id, cancellationToken).ConfigureAwait(false);
            timing.Mark("refresh-activate:complete", ((int)refreshedActivationStatus).ToString());
            return (int)refreshedActivationStatus is >= 200 and <= 299
                ? OperationResult.Success($"Chromium tab activated: {Redactor.Mask(match.Url ?? match.Title ?? match.Id)}", new ActivationTarget.BrowserTab("Chromium", state.Url, state.TabIndex, state.UrlPrefix, state.UrlPattern))
                : OperationResult.VisibleError(OperationStatus.Failed, $"CDP activate failed: {(int)refreshedActivationStatus}");
        }
        catch (TaskCanceledException)
        {
            return OperationResult.VisibleError(OperationStatus.Timeout, "CDP request timed out");
        }
        catch (Exception ex)
        {
            return OperationResult.VisibleError(OperationStatus.Failed, Redactor.Mask(ex.Message));
        }
    }


    public async Task<ForegroundContextResult> CaptureFirstPageAsync(string appName, CancellationToken cancellationToken = default)
    {
        var cdp = _settings.BrowserCdp ?? new BrowserCdpSettings();
        if (ValidateSettings(cdp) is { } invalid) return new ForegroundContextResult(invalid.Status, invalid.Message, appName, string.Empty);
        var endpoint = (cdp.Endpoint ?? string.Empty).TrimEnd('/');
        try
        {
            var tabs = await GetTabsAsync(endpoint, cancellationToken).ConfigureAwait(false);
            var page = tabs.FirstOrDefault(t => string.Equals(t.Type, "page", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(t.Url))
                       ?? tabs.FirstOrDefault(t => !string.IsNullOrWhiteSpace(t.Url));
            if (page is null || string.IsNullOrWhiteSpace(page.Url))
            {
                return new ForegroundContextResult(OperationStatus.NotFound, "No Chromium page tab found", appName, string.Empty);
            }
            var state = new BrowserAppState(page.Url, UrlPrefixFrom(page.Url), null, page.Title);
            return new ForegroundContextResult(OperationStatus.Success, $"Captured Chromium tab: {Redactor.Mask(page.Url)}", appName, page.Title ?? page.Url, appName, state);
        }
        catch (TaskCanceledException)
        {
            return new ForegroundContextResult(OperationStatus.Timeout, "CDP request timed out", appName, string.Empty);
        }
        catch (Exception ex)
        {
            return new ForegroundContextResult(OperationStatus.Failed, Redactor.Mask(ex.Message), appName, string.Empty);
        }
    }

    private static string? UrlPrefixFrom(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri)) return null;
        return $"{uri.Scheme}://{uri.Host}";
    }

    private async Task<IReadOnlyList<CdpTab>> GetTabsAsync(string endpoint, CancellationToken cancellationToken)
    {
        lock (_tabsCacheGate)
        {
            if (_tabsCache is { } cache
                && string.Equals(cache.Endpoint, endpoint, StringComparison.OrdinalIgnoreCase)
                && DateTimeOffset.UtcNow - cache.CreatedAt <= TabsCacheTtl)
            {
                return cache.Tabs;
            }
        }

        var timing = new RestoreTimingScope("browser:list", _timing);
        timing.Mark("start");
        var tabs = await _http.GetFromJsonAsync<List<CdpTab>>($"{endpoint}/json/list", cancellationToken).ConfigureAwait(false) ?? new();
        var snapshot = tabs.ToArray();
        lock (_tabsCacheGate) _tabsCache = new CachedTabList(endpoint, DateTimeOffset.UtcNow, snapshot);
        timing.Mark("complete", snapshot.Length.ToString());
        return snapshot;
    }

    private async Task<HttpStatusCode> ActivateTabAsync(string endpoint, string tabId, CancellationToken cancellationToken)
    {
        var timing = new RestoreTimingScope("browser:activate", _timing);
        timing.Mark("start");
        using var response = await _http.GetAsync($"{endpoint}/json/activate/{Uri.EscapeDataString(tabId)}", cancellationToken).ConfigureAwait(false);
        timing.Mark("complete", ((int)response.StatusCode).ToString());
        return response.StatusCode;
    }

    private void InvalidateTabsCache(string endpoint)
    {
        lock (_tabsCacheGate)
        {
            if (_tabsCache is { } cache && string.Equals(cache.Endpoint, endpoint, StringComparison.OrdinalIgnoreCase)) _tabsCache = null;
        }
    }


    public static OperationResult? ValidateSettings(BrowserCdpSettings cdp)
    {
        if (!cdp.Enabled) return OperationResult.VisibleError(OperationStatus.Unsupported, "Chromium CDP is disabled unless explicitly opted in");
        var endpoint = (cdp.Endpoint ?? string.Empty).TrimEnd('/');
        if (!IsLoopbackEndpoint(endpoint)) return OperationResult.VisibleError(OperationStatus.ValidationError, "CDP endpoint must be loopback HTTP endpoint");
        if (string.IsNullOrWhiteSpace(cdp.ProfilePath)) return OperationResult.VisibleError(OperationStatus.ValidationError, "CDP profile path is required");
        if (cdp.RequireProfileMarker)
        {
            var marker = Path.Combine(cdp.ProfilePath, string.IsNullOrWhiteSpace(cdp.MarkerFileName) ? ".focusbm-cdp-profile" : cdp.MarkerFileName);
            if (!File.Exists(marker)) return OperationResult.VisibleError(OperationStatus.ValidationError, $"CDP profile marker is missing: {marker}");
        }
        if (OperatingSystem.IsWindows() && cdp.RequireKnownBrowserOwner)
        {
            if (!TryGetEndpointPort(endpoint, out var port)) return OperationResult.VisibleError(OperationStatus.ValidationError, "CDP endpoint port is invalid");
            if (!IsKnownBrowserOwner(port, out var owner)) return OperationResult.VisibleError(OperationStatus.ValidationError, $"CDP endpoint owner is not a known browser: {owner ?? "unknown"}");
        }
        return null;
    }

    public static void EnsureProfileMarker(string profilePath, string markerFileName = ".focusbm-cdp-profile")
    {
        Directory.CreateDirectory(profilePath);
        var marker = Path.Combine(profilePath, string.IsNullOrWhiteSpace(markerFileName) ? ".focusbm-cdp-profile" : markerFileName);
        if (!File.Exists(marker)) File.WriteAllText(marker, "focusbm CDP opt-in profile marker\n");
    }


    private static bool TryGetEndpointPort(string endpoint, out int port)
    {
        port = 0;
        if (!Uri.TryCreate(endpoint, UriKind.Absolute, out var uri)) return false;
        port = uri.Port;
        return port > 0 && port <= 65535;
    }

    private static bool IsKnownBrowserOwner(int port, out string? owner)
    {
        owner = null;
        try
        {
            var pid = FindTcpListenerOwnerPid(port);
            if (pid is null) return false;
            using var process = Process.GetProcessById(pid.Value);
            owner = process.ProcessName;
            var normalized = owner.Replace(" ", "", StringComparison.OrdinalIgnoreCase).ToLowerInvariant();
            return normalized.Contains("chrome") || normalized.Contains("chromium") || normalized.Contains("msedge") || normalized.Contains("edge");
        }
        catch (Exception ex)
        {
            owner = Redactor.Mask(ex.Message);
            return false;
        }
    }

    private static int? FindTcpListenerOwnerPid(int port)
    {
        var size = 0;
        _ = GetExtendedTcpTable(IntPtr.Zero, ref size, true, AF_INET, TCP_TABLE_CLASS.TCP_TABLE_OWNER_PID_LISTENER, 0);
        if (size <= 0) return null;
        var buffer = Marshal.AllocHGlobal(size);
        try
        {
            var result = GetExtendedTcpTable(buffer, ref size, true, AF_INET, TCP_TABLE_CLASS.TCP_TABLE_OWNER_PID_LISTENER, 0);
            if (result != 0) return null;
            var count = Marshal.ReadInt32(buffer);
            var rowPtr = IntPtr.Add(buffer, 4);
            var rowSize = Marshal.SizeOf<MIB_TCPROW_OWNER_PID>();
            for (var i = 0; i < count; i++)
            {
                var row = Marshal.PtrToStructure<MIB_TCPROW_OWNER_PID>(IntPtr.Add(rowPtr, i * rowSize));
                var localPort = IPAddress.NetworkToHostOrder((short)(row.localPort & 0xFFFF));
                if (localPort == port) return (int)row.owningPid;
            }
            return null;
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    private const int AF_INET = 2;
    private enum TCP_TABLE_CLASS { TCP_TABLE_BASIC_LISTENER, TCP_TABLE_BASIC_CONNECTIONS, TCP_TABLE_BASIC_ALL, TCP_TABLE_OWNER_PID_LISTENER, TCP_TABLE_OWNER_PID_CONNECTIONS, TCP_TABLE_OWNER_PID_ALL }
    [StructLayout(LayoutKind.Sequential)] private struct MIB_TCPROW_OWNER_PID
    {
        public uint state;
        public uint localAddr;
        public uint localPort;
        public uint remoteAddr;
        public uint remotePort;
        public uint owningPid;
    }
    [DllImport("iphlpapi.dll", SetLastError = true)] private static extern uint GetExtendedTcpTable(IntPtr tcpTable, ref int tcpTableLength, bool sort, int ipVersion, TCP_TABLE_CLASS tcpTableType, uint reserved);

    private static bool Matches(CdpTab tab, BrowserAppState state)
    {
        var url = tab.Url ?? string.Empty;
        var title = tab.Title ?? string.Empty;
        if (!string.IsNullOrWhiteSpace(state.UrlPrefix) && url.StartsWith(state.UrlPrefix, StringComparison.OrdinalIgnoreCase)) return true;
        if (!string.IsNullOrWhiteSpace(state.UrlPattern) && url.Contains(state.UrlPattern, StringComparison.OrdinalIgnoreCase)) return true;
        if (!string.IsNullOrWhiteSpace(state.Url) && string.Equals(url, state.Url, StringComparison.OrdinalIgnoreCase)) return true;
        if (!string.IsNullOrWhiteSpace(state.Title) && title.Contains(state.Title, StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }

    public static bool IsLoopbackEndpoint(string endpoint)
        => Uri.TryCreate(endpoint, UriKind.Absolute, out var uri)
           && (uri.Host is "127.0.0.1" or "localhost" or "[::1]" or "::1")
           && uri.Scheme == "http";

    private sealed record CdpTab(
        [property: JsonPropertyName("id")] string? Id,
        [property: JsonPropertyName("title")] string? Title,
        [property: JsonPropertyName("url")] string? Url,
        [property: JsonPropertyName("type")] string? Type);

    private sealed record CachedTabList(string Endpoint, DateTimeOffset CreatedAt, IReadOnlyList<CdpTab> Tabs);
}
