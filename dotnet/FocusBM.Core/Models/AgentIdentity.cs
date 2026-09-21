namespace FocusBM.Core;

/// <summary>Resolves AI agent command lines to a display emoji. Mirrors WslProcessService.GetAgentCommand without taking an Infrastructure dependency.</summary>
public static class AgentIdentity
{
    private static readonly string[] Agents = ["claude", "aider", "gemini", "copilot", "codex", "devin", "hermes", "opencode", "pi", "grok", "cursor-agent"];

    public static string? Emoji(string? command)
    {
        var agent = Normalize(command);
        return agent switch
        {
            "copilot" => "✈️",
            "codex" => "📖",
            "devin" => "☕",
            "hermes" => "📨",
            "grok" => "🔫",
            "cursor-agent" => "➡️",
            "claude" or "aider" or "gemini" or "opencode" or "pi" => "🤖",
            _ => null
        };
    }

    public static string? Normalize(string? command)
    {
        if (string.IsNullOrWhiteSpace(command)) return null;
        var firstToken = command.Split((char[]?)null, 2, StringSplitOptions.RemoveEmptyEntries)[0];
        var separator = Math.Max(firstToken.LastIndexOf('/'), firstToken.LastIndexOf('\\'));
        var commandName = (separator >= 0 ? firstToken[(separator + 1)..] : firstToken).ToLowerInvariant();
        if (Agents.Contains(commandName, StringComparer.OrdinalIgnoreCase)) return commandName;
        if (commandName.StartsWith("grok-", StringComparison.OrdinalIgnoreCase)
            && commandName.Length > 5
            && char.IsDigit(commandName[5])) return "grok";
        if (!IsWrapperRuntime(commandName)) return null;
        if (command.Contains("copilot-language-server", StringComparison.OrdinalIgnoreCase)) return null;
        foreach (var candidate in Agents)
        {
            if (candidate == "grok")
            {
                if (System.Text.RegularExpressions.Regex.IsMatch(command, @"(^|/)grok-[0-9]", System.Text.RegularExpressions.RegexOptions.IgnoreCase))
                    return candidate;
                continue;
            }
            if (command.Contains("bin/" + candidate, StringComparison.OrdinalIgnoreCase)
                || command.Contains("/" + candidate + " ", StringComparison.OrdinalIgnoreCase))
                return candidate;
        }
        return null;
    }

    // Why: mirrors WslProcessService.IsWrapperRuntime; Homebrew hermes-agent runs as `python .../bin/hermes`.
    private static bool IsWrapperRuntime(string commandName) =>
        commandName is "node" or "deno" or "bun" or "npx" or "python" or "python3"
        || (commandName.StartsWith("python3.", StringComparison.Ordinal)
            && commandName.Length > "python3.".Length
            && char.IsDigit(commandName["python3.".Length]));

    public static string FormatTerminalLabel(string? terminal) => terminal switch
    {
        null or "" => "WSL",
        "WindowsTerminal" => "Windows Terminal",
        "WezTerm" => "WezTerm",
        "tmux" => "tmux",
        _ => terminal
    };

    public static string FormatAppName(string agentName, string terminal, string? workingDirectory)
    {
        var label = $"{agentName} @ {FormatTerminalLabel(terminal)}";
        var directory = DirectoryLeaf(workingDirectory);
        return directory is null ? label : $"{label} — {directory}";
    }

    public static string? DirectoryLeaf(string? path)
    {
        if (string.IsNullOrWhiteSpace(path)) return null;
        var trimmed = path.Trim().TrimEnd('/', '\\');
        if (trimmed.Length == 0) return null;
        var slash = Math.Max(trimmed.LastIndexOf('/'), trimmed.LastIndexOf('\\'));
        var name = slash >= 0 ? trimmed[(slash + 1)..] : trimmed;
        return string.IsNullOrWhiteSpace(name) || name is "~" or "." ? null : name;
    }
}
