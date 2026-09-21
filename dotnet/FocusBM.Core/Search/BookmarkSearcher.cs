namespace FocusBM.Core;

/// <summary>Swift FocusBMLib BookmarkSearcher 互換の fuzzy search。</summary>
public static class BookmarkSearcher
{
    public static int? FuzzyScore(string? text, string? query)
    {
        var t = (text ?? string.Empty).ToLowerInvariant();
        var q = (query ?? string.Empty).ToLowerInvariant();
        if (q.Length == 0) return 0;
        var score = 0;
        var textIdx = 0;
        foreach (var queryChar in q)
        {
            var found = t.IndexOf(queryChar, textIdx);
            if (found < 0) return null;
            if (found == 0) score += 10;
            else if (" -_".Contains(t[found - 1])) score += 5;
            score += 1;
            textIdx = found + 1;
        }
        return score;
    }

    public static IReadOnlyList<Bookmark> Filter(IReadOnlyList<Bookmark> bookmarks, string? query)
    {
        if (string.IsNullOrEmpty(query)) return bookmarks;
        return bookmarks
            .Select(bm => (bm, score: ScoreBookmark(bm, query)))
            .Where(x => x.score.HasValue)
            .OrderByDescending(x => x.score!.Value)
            .ThenBy(x => x.bm.LowPriority)
            .Select(x => x.bm)
            .ToList();
    }

    public static int? ScoreBookmark(Bookmark bm, string query)
    {
        // Why: agent Context packs diagnostics (window name, masked cwd, masked command line)
        // whose scattered tokens cause false positives (e.g. "claudoctrine" kept a "changelog"
        // pane via window claude + repos/changelog + <redacted-user-path>/bin/claude). Match
        // macOS: tmux agents search the display name only, standalone agents search
        // "command cwd terminal"; Context stays searchable for regular bookmarks only.
        var texts = bm.State switch
        {
            WslProcessState { TmuxSession: not null } => new[] { bm.Id, bm.AppName, bm.Shortcut ?? string.Empty },
            WslProcessState state => new[] { bm.Id, bm.AppName, $"{state.Command} {state.WorkingDirectory} {state.Terminal}", bm.Shortcut ?? string.Empty },
            _ => new[] { bm.Id, bm.AppName, bm.Context, bm.Shortcut ?? string.Empty },
        };
        var scores = texts.Select(t => FuzzyScore(t, query)).OfType<int>().ToList();
        return scores.Count == 0 ? null : scores.Max();
    }
}
