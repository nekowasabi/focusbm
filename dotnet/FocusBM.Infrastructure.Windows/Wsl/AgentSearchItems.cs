using FocusBM.Core;

namespace FocusBM.Infrastructure.Windows.Wsl;

/// <summary>Turns live tmux panes and WSL AI processes into search-panel bookmarks.</summary>
public static class AgentSearchItems
{
    public static IReadOnlyList<Bookmark> Build(
        IReadOnlyList<TmuxPaneInfo> panes,
        IReadOnlyList<WslProcessInfo> processes,
        bool showTmuxAgents,
        bool showWslAgents,
        bool tmuxDiscoverySucceeded,
        IReadOnlyDictionary<string, string>? sessionTerminals = null,
        bool processDiscoverySucceeded = true)
    {
        var bookmarks = new List<Bookmark>();
        var agentProcesses = processes.Where(WslProcessService.IsAgentProcess).ToArray();
        var agentsByPane = agentProcesses
            .Where(process => process.TmuxPaneId is not null)
            .GroupBy(process => process.TmuxPaneId!, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.Ordinal);
        if (showTmuxAgents)
        {
            // Why: tmux pane_current_command can stay "claude" after exit; only fall back to heuristics when ps failed, not when it returned zero agents.
            foreach (var pane in WslTmuxService.FilterPanesByAgent(panes, agentsByPane, allowHeuristicFallback: !showWslAgents || !processDiscoverySucceeded))
            {
                agentsByPane.TryGetValue(pane.PaneId, out var agent);
                bookmarks.Add(CreateTmuxBookmark(pane, agent, sessionTerminals));
            }
        }
        if (showWslAgents)
        {
            var knownPanes = panes.Select(pane => pane.PaneId).ToHashSet(StringComparer.Ordinal);
            var hideMappedTmuxProcesses = showTmuxAgents && tmuxDiscoverySucceeded;
            var mappedAgentKeys = agentProcesses
                .Where(process => process.TmuxPaneId is not null && knownPanes.Contains(process.TmuxPaneId))
                .Select(process => (process.AgentCommand, process.CurrentDirectory ?? ""))
                .ToHashSet();
            bookmarks.AddRange(agentProcesses
                .Where(process =>
                {
                    if (!hideMappedTmuxProcesses) return true;
                    if (process.TmuxPaneId is not null && knownPanes.Contains(process.TmuxPaneId)) return false;
                    // Why: Codex is node wrapper + rust child; the wrapper has no TMUX_PANE and would show a no-tmux row.
                    return process.TmuxPaneId is not null
                        || !mappedAgentKeys.Contains((process.AgentCommand, process.CurrentDirectory ?? ""));
                })
                .Select(CreateWslBookmark));
        }
        return bookmarks;
    }

    private static string ResolveTerminalForPane(
        TmuxPaneInfo pane,
        WslProcessInfo? agent,
        IReadOnlyDictionary<string, string>? sessionTerminals)
    {
        if (sessionTerminals is not null && sessionTerminals.TryGetValue(pane.Session, out var terminal))
            return terminal;
        return agent?.Terminal ?? "tmux";
    }

    public static Bookmark CreateTmuxBookmark(
        TmuxPaneInfo pane,
        WslProcessInfo? agent,
        IReadOnlyDictionary<string, string>? sessionTerminals = null)
    {
        var command = agent?.Command ?? pane.CurrentCommand ?? "tmux";
        var directory = agent?.CurrentDirectory ?? pane.CurrentDirectory;
        var terminal = ResolveTerminalForPane(pane, agent, sessionTerminals);
        var appName = AgentIdentity.FormatAppName(
            WslProcessService.GetAgentDisplayName(command),
            terminal,
            directory);
        var details = new List<string> { $"{pane.Session}:{pane.Window}.{pane.PaneId}" };
        if (!string.IsNullOrWhiteSpace(pane.WindowName)) details.Add($"window {pane.WindowName}");
        if (!string.IsNullOrWhiteSpace(directory)) details.Add($"cwd {Redactor.Mask(directory)}");
        if (!string.IsNullOrWhiteSpace(command)) details.Add($"process {Redactor.Mask(command)}");
        return new Bookmark(
            Id: $"tmux:{pane.Session}:{pane.Window}:{pane.PaneId}",
            AppName: appName,
            Context: string.Join(" · ", details),
            State: new WslProcessState(
                agent?.Pid ?? 0,
                agent?.AgentCommand ?? WslProcessService.GetAgentCommand(command) ?? WslProcessService.GetCommandName(command),
                terminal,
                pane.PaneId,
                pane.Session,
                pane.Window,
                directory,
                pane.AgentStatus,
                pane.CaptureText),
            LowPriority: true);
    }

    public static Bookmark CreateWslBookmark(WslProcessInfo process)
    {
        var appName = AgentIdentity.FormatAppName(process.AgentName, process.Terminal ?? "WSL", process.CurrentDirectory);
        var details = new List<string>();
        if (!string.IsNullOrWhiteSpace(process.TmuxPaneId)) details.Add($"tmux pane {process.TmuxPaneId}");
        else details.Add("no tmux");
        if (!string.IsNullOrWhiteSpace(process.CurrentDirectory)) details.Add($"cwd {Redactor.Mask(process.CurrentDirectory)}");
        details.Add($"process {Redactor.Mask(process.Command)}");
        details.Add($"PID {process.Pid}");
        return new Bookmark(
            Id: $"wsl:{process.Pid}",
            AppName: appName,
            Context: string.Join(" · ", details),
            State: new WslProcessState(process.Pid, process.AgentCommand, process.Terminal, process.TmuxPaneId, WorkingDirectory: process.CurrentDirectory),
            LowPriority: true);
    }
}
