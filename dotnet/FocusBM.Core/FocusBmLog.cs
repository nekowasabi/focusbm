namespace FocusBM.Core;

/// <summary>
/// Append-only operation log for panel show/hide and restore/focus.
/// Open once at startup; Write is a no-op until then.
/// </summary>
public static class FocusBmLog
{
    private static readonly object Gate = new();
    private static string? _path;
    private const long MaxBytes = 2 * 1024 * 1024;

    public static string? Path => _path;

    public static void Open(string path)
    {
        var directory = System.IO.Path.GetDirectoryName(path);
        if (!string.IsNullOrWhiteSpace(directory)) Directory.CreateDirectory(directory);
        lock (Gate)
        {
            _path = path;
        }
        Write("log", "opened");
    }

    public static void Write(string category, string message)
    {
        string? path;
        lock (Gate) path = _path;
        if (path is null) return;
        var line = $"{DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss.fff} [{category}] {Redactor.Mask(message)}{Environment.NewLine}";
        lock (Gate)
        {
            try
            {
                if (File.Exists(path) && new FileInfo(path).Length > MaxBytes)
                {
                    var previous = path + ".old";
                    File.Delete(previous);
                    File.Move(path, previous);
                }
                File.AppendAllText(path, line);
            }
            catch
            {
                // Logging must never break restore or the panel.
            }
        }
    }
}
