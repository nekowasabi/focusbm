namespace FocusBM.Core;

public sealed record ShortcutAssignment(Bookmark Bookmark, string? Shortcut, bool IsDirectNumber)
{
    public string DisplayLabel =>
        Shortcut is { Length: > 1 } && Shortcut[0] == '^' ? "⌃" + Shortcut[1..] : Shortcut ?? string.Empty;
}

public static class ShortcutAssigner
{
    /// <summary>絞り込み中（query 非空・2件以上）は表示順に "1"〜"9" を振り直す。null は通常の割り当てを使う。</summary>
    public static IReadOnlyList<string?>? FilteredNumberLabels(string? query, int count)
    {
        if (string.IsNullOrEmpty(query) || count < 2) return null;
        return Enumerable.Range(0, count).Select(i => i < 9 ? (i + 1).ToString() : null).ToList();
    }

    public static IReadOnlyList<ShortcutAssignment> Assign(IReadOnlyList<Bookmark> bookmarks, AppSettings? settings = null)
    {
        var skipAI = settings?.ShowAIAgentShortcut == false;
        var reserved = bookmarks
            .Where(bm => !bm.NoShortcut && !string.IsNullOrWhiteSpace(bm.Shortcut))
            .Select(bm => bm.Shortcut!)
            .ToHashSet(StringComparer.Ordinal);
        var usedYaml = new HashSet<string>(StringComparer.Ordinal);
        var results = new List<ShortcutAssignment>();
        var number = 1;
        var toggleRepressTarget = bookmarks.FirstOrDefault(bm => bm.ExecuteOnToggleRepress);
        foreach (var bm in bookmarks)
        {
            if (bm.NoShortcut)
            {
                results.Add(new ShortcutAssignment(bm, null, false));
                continue;
            }
            // The toggle-repress target is shown as a hotkey chip in the shortcut bar, so it must not consume an auto number.
            if (bm == toggleRepressTarget && string.IsNullOrWhiteSpace(bm.Shortcut))
            {
                results.Add(new ShortcutAssignment(bm, null, false));
                continue;
            }
            if (skipAI && bm.IsAIAgent)
            {
                results.Add(new ShortcutAssignment(bm, null, false));
                continue;
            }
            if (!string.IsNullOrWhiteSpace(bm.Shortcut))
            {
                var label = bm.Shortcut!;
                if (!usedYaml.Add(label)) results.Add(new ShortcutAssignment(bm, null, false));
                else results.Add(new ShortcutAssignment(bm, label, false));
                continue;
            }
            while (number <= 9 && reserved.Contains(number.ToString())) number++;
            if (number <= 9)
            {
                var label = number.ToString();
                number++;
                results.Add(new ShortcutAssignment(bm, label, true));
            }
            else results.Add(new ShortcutAssignment(bm, null, false));
        }
        return results;
    }
}
