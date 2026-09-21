namespace FocusBM.Core;

public static class BookmarkPaths
{
    public static string ResolveDefaultYamlPath(string? executableDirectory = null)
    {
        var env = Environment.GetEnvironmentVariable("FOCUSBM_YAML");
        if (!string.IsNullOrWhiteSpace(env)) return env;
        IReadOnlyList<string> localCandidates = executableDirectory is not null
            ? new[] { Path.Combine(executableDirectory, "bookmarks.yml") }
            : ColocatedYamlCandidates();
        // Why: Prefer a colocated configuration over AppData so a deployed app and its bookmarks stay manageable together.
        foreach (var local in localCandidates)
        {
            if (File.Exists(local)) return local;
        }
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        if (string.IsNullOrWhiteSpace(appData)) appData = Environment.CurrentDirectory;
        return Path.Combine(appData, "focusbm", "bookmarks.yml");
    }

    public static string ResolveDefaultLogPath(string? executableDirectory = null)
    {
        var env = Environment.GetEnvironmentVariable("FOCUSBM_LOG");
        if (!string.IsNullOrWhiteSpace(env)) return env;
        var yaml = ResolveDefaultYamlPath(executableDirectory);
        var directory = Path.GetDirectoryName(yaml);
        return Path.Combine(string.IsNullOrWhiteSpace(directory) ? AppContext.BaseDirectory : directory, "focusbm.log");
    }

    private static IReadOnlyList<string> ColocatedYamlCandidates()
    {
        var candidates = new List<string> { Path.Combine(AppContext.BaseDirectory, "bookmarks.yml") };
        var processDirectory = Path.GetDirectoryName(Environment.ProcessPath);
        if (!string.IsNullOrWhiteSpace(processDirectory))
        {
            var processLocal = Path.Combine(processDirectory, "bookmarks.yml");
            if (!candidates.Contains(processLocal, StringComparer.OrdinalIgnoreCase)) candidates.Add(processLocal);
        }
        return candidates;
    }
}
