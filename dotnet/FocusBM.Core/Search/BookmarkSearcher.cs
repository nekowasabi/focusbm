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
        // 状態列（表示ラベル＋enum 名）と端末名も agent の検索対象に加え、"実行中" や "wez" で絞り込めるようにする。
        // Why: 表の1行（状態・名前・アプリ／端末・PR／URL）を表示順に連結した文字列も対象にし、"plafocuclaude" のように列をまたいだ曖昧検索を可能にする
        var texts = bm.State switch
        {
            WslProcessState { TmuxSession: not null } state => new[] { bm.Id, bm.AppName, bm.Shortcut ?? string.Empty, state.Terminal ?? string.Empty, StatusText(state), RowText(bm) },
            WslProcessState state => new[] { bm.Id, bm.AppName, $"{state.Command} {state.WorkingDirectory} {state.Terminal}", bm.Shortcut ?? string.Empty, state.Terminal ?? string.Empty, StatusText(state), RowText(bm) },
            _ => new[] { bm.Id, bm.AppName, bm.Context, bm.Shortcut ?? string.Empty, RowText(bm) },
        };
        // Why: 状態・端末・ディレクトリを別フィールドに持つため、"wez 実行中" のように語順を問わず AND で絞り込めるようにする
        var tokens = query.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (tokens.Length == 0) return 0;
        var total = 0;
        foreach (var token in tokens)
        {
            var scores = texts.Select(t => FuzzyScore(t, token)).OfType<int>().ToList();
            if (scores.Count == 0) return null;
            total += scores.Max();
        }
        return total;
    }

    private static string StatusText(WslProcessState state) =>
        state.AgentStatus is { } status ? $"{AgentStatusText.Label(status)} {status}" : string.Empty;

    private static string RowText(Bookmark bm) =>
        string.Join(" ", new[]
        {
            bm.State is WslProcessState state ? StatusText(state) : null,
            bm.ListName, bm.ListDetail, bm.PullRequestLabel, bm.UrlHint,
        }.Where(p => !string.IsNullOrEmpty(p)));
}
