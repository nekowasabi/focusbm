// Renders the real MainWindow tiled agent preview with sample panes to a PNG (README screenshot).
// Usage (Windows): dotnet PreviewScreenshot.dll <output.png> [tiled|two|single]
using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using FocusBM.App.Wpf;
using FocusBM.Core;

internal static class Program
{
    private const int Width = 1600;
    private const int Height = 900;

    private static string Rgb(int r, int g, int b) => $"\u001b[38;2;{r};{g};{b}m";
    private const string Reset = "\u001b[0m";
    private static readonly string Dim = Rgb(110, 118, 129), Acc = Rgb(210, 168, 255), Add = Rgb(126, 231, 135),
        Del = Rgb(255, 161, 152), Warn = Rgb(227, 179, 65), Cyan = Rgb(121, 192, 255);

    private static Bookmark Agent(int pid, string command, string directory, TmuxAgentStatus status, string screen) =>
        new($"tmux:%{pid}", command, directory,
            new WslProcessState(pid, command, TmuxPaneId: $"%{pid}", WorkingDirectory: $"/home/me/repos/{directory}",
                AgentStatus: status, ScreenCapture: screen));

    private static IReadOnlyList<Bookmark> Samples() =>
    [
        Agent(1, "claude", "focusbm", TmuxAgentStatus.Running, string.Join('\n',
            $"{Dim}> プレビューのフォントサイズを YAML で指定できるようにして{Reset}",
            "",
            $"{Acc}●{Reset} Read(Sources/FocusBMApp/AgentScreenPreview.swift)",
            $"{Dim}  ⎿  Read 191 lines{Reset}",
            $"{Acc}●{Reset} Update(Sources/FocusBMLib/Models.swift)",
            $"{Dim}  ⎿  Updated with 3 additions{Reset}",
            $"{Dim}     42 {Add}+    public var previewFontSize: Double?{Reset}",
            $"{Dim}     43 {Add}+    public var previewFontName: String?{Reset}",
            $"{Dim}     51 {Del}-    let size = 14{Reset}",
            $"{Acc}●{Reset} Bash(swift test --filter Preview)",
            $"{Dim}  ⎿  {Add}Test Suite passed{Dim} (12 tests, 0.42s){Reset}",
            "",
            $"{Warn}✻ Compiling… {Dim}(18s · ↑ 2.1k tokens · esc to interrupt){Reset}")),
        Agent(2, "codex", "api-server", TmuxAgentStatus.Idle, string.Join('\n',
            $"{Dim}› テストが落ちている原因を調べて{Reset}",
            "",
            $"{Acc}•{Reset} Ran {Cyan}go test ./internal/...{Reset}",
            $"{Dim}  └ {Del}FAIL internal/auth  TestTokenRefresh{Reset}",
            $"{Dim}      expected 200, got 401{Reset}",
            $"{Acc}•{Reset} Explored",
            $"{Dim}  └ Read auth/refresh.go, auth/clock.go{Reset}",
            "",
            "原因は clock.Now() をテストで固定していないことです。",
            "修正方針を 2 つ提示します:",
            $"  1. clock を注入する  {Dim}(推奨){Reset}",
            "  2. 期限判定に許容幅を持たせる",
            "",
            $"{Warn}▌ どちらで進めますか?{Reset}")),
        Agent(3, "claude", "dotfiles", TmuxAgentStatus.PlanMode, string.Join('\n',
            $"{Acc}●{Reset} Plan: tmux のステータスバーにブランチを表示する",
            "",
            $"{Dim}  1. tmux/tmux.conf に status-right を追加{Reset}",
            $"{Dim}  2. zsh/.zshrc の未使用 alias を削除{Reset}",
            $"{Dim}  3. espanso のスニペットを 2 件追加{Reset}",
            "",
            $"{Cyan}  feat(tmux):{Reset} ステータスバーにブランチを表示する",
            $"{Cyan}  chore(zsh):{Reset} 未使用の alias を削除する",
            "",
            $"{Dim}⏸ plan mode on (shift+tab to cycle){Reset}")),
        Agent(4, "codex", "blog", TmuxAgentStatus.Running, string.Join('\n',
            $"{Acc}•{Reset} Ran {Cyan}npm run build{Reset}",
            $"{Dim}  └ {Del}Error: Cannot find module 'remark-gfm'{Reset}",
            $"{Dim}      at Module._resolveFilename (node:internal){Reset}",
            "",
            "依存が lockfile と一致していません。",
            $"{Acc}•{Reset} Ran {Cyan}npm ci{Reset}",
            $"{Dim}  └ added 412 packages in 9s{Reset}",
            $"{Acc}•{Reset} Ran {Cyan}npm run build{Reset}",
            $"{Dim}  └ {Add}✓ built in 3.2s{Reset}",
            "",
            $"{Warn}◦ Working {Dim}(24s • esc to interrupt){Reset}")),
    ];

    [STAThread]
    private static int Main(string[] args)
    {
        var output = Path.GetFullPath(args.Length > 0 ? args[0] : "preview.png");
        _ = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        var vm = new SearchPanelViewModel(sendPrompt: (_, _, _) => throw new NotSupportedException());
        var mode = args.Length > 1 ? args[1] : "tiled";
        var samples = mode == "two" ? Samples().Take(2).ToArray() : Samples();
        vm.Load(new BookmarkStore(new AppSettings(PreviewFontName: "Cascadia Mono"), samples), announce: false);
        // Why: open the preview before the window exists so MainWindow does not move itself onto a real monitor.
        var single = mode == "single";
        if (single)
        {
            vm.HoveredIndex = 1;
            if (!vm.ShowHoveredPreview()) return 1;
        }
        else if (!vm.ShowAllPreviews() || !vm.SetPromptTarget(2)) return 1;

        var window = new MainWindow(vm)
        {
            Left = -20000, Top = -20000, Width = Width, Height = Height,
            ShowActivated = false, Topmost = false,
        };
        if (window.FindName("PreviewCard") is FrameworkElement card)
        {
            card.Width = single ? 1200 : Width;
            card.Height = single ? 800 : Height;
        }
        window.Show();
        window.Dispatcher.Invoke(() => { }, DispatcherPriority.ApplicationIdle);
        window.UpdateLayout();

        var bitmap = new RenderTargetBitmap(Width, Height, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render((Visual)window.Content);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using (var stream = File.Create(output)) encoder.Save(stream);
        Console.WriteLine(output);
        window.AllowClose = true;
        window.Close();
        return 0;
    }
}
