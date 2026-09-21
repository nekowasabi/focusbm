using System.Collections.Concurrent;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.Versioning;
using FocusBM.Core;

namespace FocusBM.Infrastructure.Windows.Icons;

public sealed class WindowsIconProvider : IIconProvider
{
    private readonly ConcurrentDictionary<string, IconResult> _cache = new(StringComparer.OrdinalIgnoreCase);

    public Task<IconResult> GetIconAsync(string appNameOrPath, CancellationToken cancellationToken = default)
    {
        if (!OperatingSystem.IsWindows()) return Task.FromResult(Fallback("Icon extraction is Windows-only"));
        if (string.IsNullOrWhiteSpace(appNameOrPath)) return Task.FromResult(Fallback("empty app/path"));
        return Task.FromResult(_cache.GetOrAdd(appNameOrPath, ResolveIcon));
    }

    [SupportedOSPlatform("windows")]
    private static IconResult ResolveIcon(string appNameOrPath)
    {
        try
        {
            var path = File.Exists(appNameOrPath) ? appNameOrPath : FindExecutable(appNameOrPath);
            if (path is null) return Fallback($"executable not found: {appNameOrPath}");
            using var icon = Icon.ExtractAssociatedIcon(path);
            if (icon is null) return Fallback($"icon not found: {path}", path);
            using var bitmap = icon.ToBitmap();
            using var ms = new MemoryStream();
            bitmap.Save(ms, ImageFormat.Png);
            return new IconResult(OperationStatus.Success, "icon extracted", ms.ToArray(), path);
        }
        catch (Exception ex)
        {
            return Fallback(Redactor.Mask(ex.Message));
        }
    }

    private static string? FindExecutable(string appName)
    {
        var candidates = Process.GetProcesses()
            .Where(p => SafeProcessName(p).Contains(Normalize(appName), StringComparison.OrdinalIgnoreCase) || Normalize(appName).Contains(SafeProcessName(p), StringComparison.OrdinalIgnoreCase))
            .Select(SafeMainModulePath)
            .Where(p => !string.IsNullOrWhiteSpace(p) && File.Exists(p))
            .Cast<string>()
            .ToList();
        if (candidates.Count > 0) return candidates[0];
        var pathExt = (Environment.GetEnvironmentVariable("PATHEXT") ?? ".exe").Split(';', StringSplitOptions.RemoveEmptyEntries);
        var pathDirs = (Environment.GetEnvironmentVariable("PATH") ?? string.Empty).Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries);
        foreach (var dir in pathDirs)
        foreach (var ext in pathExt)
        {
            var candidate = Path.Combine(dir, appName.EndsWith(ext, StringComparison.OrdinalIgnoreCase) ? appName : appName + ext);
            if (File.Exists(candidate)) return candidate;
        }
        return null;
    }

    private static string SafeProcessName(Process p) { try { return Normalize(p.ProcessName); } catch { return string.Empty; } }
    private static string? SafeMainModulePath(Process p) { try { return p.MainModule?.FileName; } catch { return null; } }
    private static string Normalize(string s) => new(s.Where(char.IsLetterOrDigit).Select(char.ToLowerInvariant).ToArray());

    private static IconResult Fallback(string message, string? source = null)
        => new(OperationStatus.NoOp, message, FallbackPng, source);

    private static readonly byte[] FallbackPng = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mN8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=");
}
