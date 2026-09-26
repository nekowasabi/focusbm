namespace FocusBM.Core;

/// <summary>絞り込み表の「状態」列の表示文字列。検索対象にも同じ文字列を使う。</summary>
public static class AgentStatusText
{
    public static string Label(TmuxAgentStatus status) => status switch
    {
        TmuxAgentStatus.Running => "実行中",
        TmuxAgentStatus.PlanMode => "Plan",
        TmuxAgentStatus.AcceptEdits => "Accept edits",
        _ => "入力待ち"
    };
}
