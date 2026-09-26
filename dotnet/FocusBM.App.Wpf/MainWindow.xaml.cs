using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Diagnostics;
using FocusBM.Core;
using Forms = System.Windows.Forms;

namespace FocusBM.App.Wpf;

public partial class MainWindow : Window
{
    private SearchPanelViewModel ViewModel => (SearchPanelViewModel)DataContext;
    private readonly IRestoreTimingSink _timing = new TraceRestoreTimingSink();
    public bool AllowClose { get; set; }

    public MainWindow(SearchPanelViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
        viewModel.AutoExecuteRequested += () => Dispatcher.Invoke(() => _ = RestoreAndMaybeHideAsync());
        viewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(SearchPanelViewModel.IsPreviewVisible))
                SyncPreviewChrome();
        };
        IsVisibleChanged += (_, _) =>
        {
            FocusBmLog.Write("panel", IsVisible ? "shown" : "hidden");
            if (!IsVisible)
            {
                ViewModel.DismissPreview();
                ViewModel.ClearQuery();
            }
        };
    }

    protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
    {
        if (!AllowClose)
        {
            e.Cancel = true;
            Hide();
            if (System.Windows.Application.Current is App app)
            {
                app.StopAgentStatusMonitoring();
                _ = app.RestoreImeIfNeededAsync();
            }
            return;
        }
        base.OnClosing(e);
    }


    private static string? ShortcutFromKey(Key key) => key switch
    {
        >= Key.D0 and <= Key.D9 => ((int)(key - Key.D0)).ToString(),
        >= Key.NumPad0 and <= Key.NumPad9 => ((int)(key - Key.NumPad0)).ToString(),
        >= Key.A and <= Key.Z => key.ToString().ToLowerInvariant(),
        _ => null
    };

    public void FocusSearchBox(bool selectAll = true)
    {
        SearchBox.Focus();
        Keyboard.Focus(SearchBox);
        if (selectAll) SearchBox.SelectAll();
    }

    public void ApplyPanelLayout(AppSettings settings)
    {
        Width = settings.EffectivePanelWidth + 32;
        Height = settings.EffectivePanelHeight + 32;
        ResultList.FontSize = settings.EffectiveListFontSize;
        if (!string.IsNullOrWhiteSpace(settings.FontName))
        {
            try { ResultList.FontFamily = new System.Windows.Media.FontFamily(settings.FontName); }
            catch { /* missing font: keep default */ }
        }
        _displayNumber = settings.DisplayNumber;
    }

    private int? _displayNumber;
    private bool _previewExpanded;

    public void Present()
    {
        _suppressDeactivate = true;
        Show();
        WindowState = WindowState.Normal;
        BringToForegroundAndFocusSearch();
        Dispatcher.BeginInvoke(() => _suppressDeactivate = false, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
    }

    private bool _suppressDeactivate;

    public void BringToForegroundAndFocusSearch()
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        if (hwnd != IntPtr.Zero) SetForegroundWindow(hwnd);
        Activate();
        FocusSearchBox();
        Dispatcher.BeginInvoke(System.Windows.Threading.DispatcherPriority.Input, () => FocusSearchBox());
    }

    private void Header_OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.OriginalSource is System.Windows.Controls.TextBox) return;
        if (e.ChangedButton == MouseButton.Left) DragMove();
    }

    private async void ShortcutBar_OnMouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is not ShortcutAssignment assignment || assignment.Shortcut is null) return;
        e.Handled = true;
        await RestoreShortcutAndMaybeHideAsync(assignment.Shortcut);
    }

    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    private const uint SwpNosize = 0x0001;
    private const uint SwpNozorder = 0x0004;
    private const uint SwpNoactivate = 0x0010;

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left, Top, Right, Bottom;
    }

    public void CenterOnPrimaryScreen() => PlaceOnConfiguredDisplay();

    public void PlaceOnConfiguredDisplay()
    {
        var screen = ResolveScreen(_displayNumber);
        if (screen is null) return;
        var hwnd = new WindowInteropHelper(this).EnsureHandle();
        GetWindowRect(hwnd, out var rect);
        var width = rect.Right - rect.Left;
        var height = rect.Bottom - rect.Top;
        if (width <= 0) width = (int)Math.Max(Width, 1);
        if (height <= 0) height = (int)Math.Max(Height, 1);
        var wa = screen.WorkingArea;
        var x = wa.Left + (wa.Width - width) / 2;
        var y = wa.Top + (wa.Height - height) / 2;
        SetWindowPos(hwnd, IntPtr.Zero, x, y, 0, 0, SwpNosize | SwpNozorder | SwpNoactivate);
    }

    private static Forms.Screen? ResolveScreen(int? displayNumber)
    {
        var ordered = Forms.Screen.AllScreens
            .OrderBy(s => s.Primary ? 0 : 1)
            .ThenBy(s => s.Bounds.X)
            .ThenBy(s => s.Bounds.Y)
            .ToArray();
        if (ordered.Length == 0) return Forms.Screen.PrimaryScreen;
        return ordered[DisplayTarget.ResolveIndex(displayNumber, ordered.Length)];
    }

    private void SyncPreviewChrome()
    {
        if (ViewModel.IsPreviewVisible)
            ExpandToMonitorForPreview();
        else if (_previewExpanded)
            RestorePanelFromPreview();
    }

    private void PreviewScroll_OnLoaded(object sender, RoutedEventArgs e)
    {
        if (sender is not ScrollViewer viewer) return;
        viewer.Dispatcher.BeginInvoke(() => viewer.ScrollToEnd());
    }

    private void ExpandToMonitorForPreview()
    {
        var screen = ResolveScreen(_displayNumber);
        if (screen is null) return;
        var bounds = screen.Bounds;
        var hwnd = new WindowInteropHelper(this).EnsureHandle();
        SetWindowPos(hwnd, IntPtr.Zero, bounds.Left, bounds.Top, bounds.Width, bounds.Height, SwpNozorder | SwpNoactivate);
        var (monitorDipW, monitorDipH) = PixelsToDip(bounds.Width, bounds.Height);
        var (cardW, cardH) = PreviewLayout.SizeOnMonitor(
            monitorDipW, monitorDipH, ViewModel.Settings.PreviewWidth, ViewModel.Settings.PreviewHeight,
            fillMonitor: ViewModel.IsTiledPreview);
        PreviewCard.Width = cardW;
        PreviewCard.Height = cardH;
        _previewExpanded = true;
    }

    private void RestorePanelFromPreview()
    {
        ApplyPanelLayout(ViewModel.Settings);
        var screen = ResolveScreen(_displayNumber);
        if (screen is null)
        {
            _previewExpanded = false;
            return;
        }
        var (pixelW, pixelH) = DipToPixels(Width, Height);
        var wa = screen.WorkingArea;
        var x = wa.Left + (wa.Width - pixelW) / 2;
        var y = wa.Top + (wa.Height - pixelH) / 2;
        var hwnd = new WindowInteropHelper(this).EnsureHandle();
        SetWindowPos(hwnd, IntPtr.Zero, x, y, pixelW, pixelH, SwpNozorder | SwpNoactivate);
        _previewExpanded = false;
    }

    private (double Width, double Height) PixelsToDip(int pixelsX, int pixelsY)
    {
        var (sx, sy) = DeviceScale();
        return (pixelsX / sx, pixelsY / sy);
    }

    private (int Width, int Height) DipToPixels(double dipX, double dipY)
    {
        var (sx, sy) = DeviceScale();
        return ((int)Math.Round(dipX * sx), (int)Math.Round(dipY * sy));
    }

    private (double ScaleX, double ScaleY) DeviceScale()
    {
        var source = PresentationSource.FromVisual(this);
        if (source is null)
        {
            var hwnd = new WindowInteropHelper(this).EnsureHandle();
            source = HwndSource.FromHwnd(hwnd);
        }
        var m = source?.CompositionTarget?.TransformToDevice;
        return (m?.M11 ?? 1.0, m?.M22 ?? 1.0);
    }

    private void FocusResults()
    {
        if (ViewModel.Results.Count == 0) return;
        ResultList.Focus();
        Keyboard.Focus(ResultList);
    }

    private void MoveResult(NavigationCommand command)
    {
        ViewModel.Move(command);
        FocusResults();
    }

    private static int? DigitFromKey(Key key) => key switch
    {
        >= Key.D0 and <= Key.D9 => (int)(key - Key.D0),
        >= Key.NumPad0 and <= Key.NumPad9 => (int)(key - Key.NumPad0),
        _ => null
    };

    private static string? AlphabetLabel(System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key is < Key.A or > Key.Z) return null;
        var letter = e.Key.ToString().ToLowerInvariant();
        var mods = e.KeyboardDevice.Modifiers;
        return AlphabetShortcutLabel.FromKey(
            letter,
            mods.HasFlag(ModifierKeys.Control),
            mods.HasFlag(ModifierKeys.Shift),
            mods.HasFlag(ModifierKeys.Alt),
            mods.HasFlag(ModifierKeys.Windows),
            false);
    }

    private bool NumberModifiersOk(ModifierKeys mods)
    {
        var direct = ViewModel.Settings.EffectiveDirectNumberKeys;
        var onlyControl = mods == ModifierKeys.Control;
        var none = mods == ModifierKeys.None;
        return direct ? none || onlyControl : onlyControl;
    }

    private bool IsFindSearchHotkey(System.Windows.Input.KeyEventArgs e) =>
        e.Key == Key.F && e.KeyboardDevice.Modifiers == ModifierKeys.Control;

    // Why: 絞り込み画面は1行1件の表なので、列数設定に関わらず先頭行は先頭の1件
    private bool IsOnFirstResultRow() =>
        GridNavigator.IsOnFirstRow(ViewModel.SelectedIndex, ViewModel.Results.Count, 1);

    private async void Window_OnPreviewKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            e.Handled = true;
            if (ViewModel.DismissPreview()) return;
            await DismissPanelAsync();
            return;
        }
        if (!ViewModel.IsPreviewVisible && IsFindSearchHotkey(e))
        {
            e.Handled = true;
            FocusSearchBox();
            return;
        }
        if (await TryActivatePreviewByDigitAsync(e)) return;
        if (TryShowAgentPreview(e)) return;
        if (await TryHandleEmptyQueryLaunchAsync(e)) return;
        if (await TryHandleFilteredDigitAsync(e)) return;
    }

    private async Task<bool> TryHandleFilteredDigitAsync(System.Windows.Input.KeyEventArgs e)
    {
        // Why: 絞り込み中は振り直した番号を Ctrl+数字で選ぶ。filteredNumberKeys: true なら候補2件以上の
        // 絞り込み中は素の数字でも振り直した番号を選ぶ。既定は検索語として入力
        if (string.IsNullOrEmpty(ViewModel.Query)) return false;
        if (DigitFromKey(e.Key) is not (int digit and >= 1 and <= 9)) return false;
        var mods = e.KeyboardDevice.Modifiers;
        var plainSelect = ViewModel.Settings.EffectiveFilteredNumberKeys
            && ViewModel.Results.Count >= 2
            && NumberModifiersOk(mods);
        if (mods != ModifierKeys.Control && !plainSelect) return false;
        e.Handled = true;
        if (ViewModel.SelectByDigit(digit)) await RestoreAndMaybeHideAsync();
        return true;
    }

    private async Task DismissPanelAsync()
    {
        Hide();
        if (System.Windows.Application.Current is App app)
        {
            app.StopAgentStatusMonitoring();
            await app.RestoreImeIfNeededAsync();
        }
    }

    public async Task ExecuteToggleRepressAsync()
    {
        var target = ViewModel.ToggleRepressTarget ?? ViewModel.SelectedBookmark;
        if (target is null)
        {
            await DismissPanelAsync();
            return;
        }
        await RestoreAndMaybeHideAsync(target);
    }

    private async Task<bool> TryHandleEmptyQueryLaunchAsync(System.Windows.Input.KeyEventArgs e)
    {
        if (!string.IsNullOrEmpty(ViewModel.Query)) return false;
        if (DigitFromKey(e.Key) is int digit and >= 1 and <= 9 && NumberModifiersOk(e.KeyboardDevice.Modifiers))
        {
            e.Handled = true;
            if (ViewModel.SelectByDigit(digit)) await RestoreAndMaybeHideAsync();
            return true;
        }
        if (AlphabetLabel(e) is { } label
            && ViewModel.ShortcutBar.Any(a => string.Equals(a.Shortcut, label, StringComparison.Ordinal)))
        {
            e.Handled = true;
            var timing = new RestoreTimingScope("ui:shortcut", _timing);
            timing.Mark("start");
            await RestoreShortcutAndMaybeHideAsync(label);
            timing.Mark("restore:complete");
            return true;
        }
        return false;
    }

    private async void SearchBox_OnKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (await TryOpenSessionPullRequestAsync(e)) return;
        switch (e.Key)
        {
            case Key.Tab when ViewModel.Results.Count > 0 && !Keyboard.Modifiers.HasFlag(ModifierKeys.Shift):
                FocusResults();
                e.Handled = true;
                break;
            case Key.Enter:
                e.Handled = true;
                await RestoreAndMaybeHideAsync();
                break;
            case Key.Escape:
                e.Handled = true;
                await DismissPanelAsync();
                break;
            case Key.Up:
                ViewModel.Move(NavigationCommand.Up);
                e.Handled = true;
                break;
            case Key.Down:
                MoveResult(NavigationCommand.Down);
                e.Handled = true;
                break;
            case Key.Left:
                MoveResult(NavigationCommand.Left);
                e.Handled = true;
                break;
            case Key.Right:
                MoveResult(NavigationCommand.Right);
                e.Handled = true;
                break;
        }
    }

    private async void ResultList_OnPreviewKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (await TryOpenSessionPullRequestAsync(e)) return;
        switch (e.Key)
        {
            case Key.Enter:
                e.Handled = true;
                await RestoreAndMaybeHideAsync();
                break;
            case Key.Escape:
                e.Handled = true;
                await DismissPanelAsync();
                break;
            case Key.Up:
                if (IsOnFirstResultRow()) FocusSearchBox(selectAll: false);
                else ViewModel.Move(NavigationCommand.Up);
                e.Handled = true;
                break;
            case Key.Down:
                ViewModel.Move(NavigationCommand.Down);
                e.Handled = true;
                break;
            case Key.Left:
                ViewModel.Move(NavigationCommand.Left);
                e.Handled = true;
                break;
            case Key.Right:
                ViewModel.Move(NavigationCommand.Right);
                e.Handled = true;
                break;
        }
    }

    private async void Window_OnDeactivated(object? sender, EventArgs e)
    {
        if (!PanelVisibility.ShouldHideOnDeactivate(IsVisible, AllowClose, _suppressDeactivate)) return;
        Hide();
        if (System.Windows.Application.Current is App app)
        {
            app.StopAgentStatusMonitoring();
            await app.RestoreImeIfNeededAsync();
        }
    }

    private async void ResultList_OnMouseDoubleClick(object sender, MouseButtonEventArgs e) => await RestoreAndMaybeHideAsync();

    private async Task<bool> TryOpenSessionPullRequestAsync(System.Windows.Input.KeyEventArgs e)
    {
        if (!MatchesPanelHotkey(e, ViewModel.Settings.OpenSessionPullRequestHotkey) || ViewModel.SelectedBookmark is not { } bookmark || !ViewModel.CanResolveSessionPullRequest(bookmark)) return false;
        e.Handled = true;
        var url = await ViewModel.ResolveSessionPullRequestAsync(bookmark);
        if (url is null)
        {
            ViewModel.SetStatus("GitHub プルリクエストが見つかりません");
            return true;
        }

        try
        {
            Process.Start(new ProcessStartInfo(url.AbsoluteUri) { UseShellExecute = true });
            Hide();
            if (System.Windows.Application.Current is App app) app.StopAgentStatusMonitoring();
        }
        catch (Exception ex)
        {
            ViewModel.SetStatus($"プルリクエストを開けません: {ex.Message}");
        }
        return true;
    }

    private async Task<bool> TryActivatePreviewByDigitAsync(System.Windows.Input.KeyEventArgs e)
    {
        if (!ViewModel.IsPreviewVisible) return false;
        if (DigitFromKey(e.Key) is not int digit) return false;
        if (digit < 1 || digit > 9) return false;
        if (!NumberModifiersOk(e.KeyboardDevice.Modifiers)) return false;
        e.Handled = true;
        if (ViewModel.BookmarkForPreviewDigit(digit) is { } bookmark)
            await RestoreAndMaybeHideAsync(bookmark);
        return true;
    }

    private bool TryShowAgentPreview(System.Windows.Input.KeyEventArgs e)
    {
        try
        {
            if (MatchesPanelHotkey(e, ViewModel.Settings.PreviewHoveredAgentHotkey)
                && ViewModel.ShowHoveredPreview())
            {
                e.Handled = true;
                return true;
            }
            if (MatchesPanelHotkey(e, ViewModel.Settings.PreviewAllAgentsHotkey)
                && ViewModel.ShowAllPreviews())
            {
                e.Handled = true;
                return true;
            }
            return false;
        }
        catch (Exception ex)
        {
            ViewModel.SetStatus($"プレビューを開けません: {ex.Message}");
            e.Handled = true;
            return true;
        }
    }

    private void ResultItem_OnMouseEnter(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (sender is ListBoxItem item)
            ViewModel.HoveredIndex = ResultList.ItemContainerGenerator.IndexFromContainer(item);
    }

    private void PreviewOverlay_OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        ViewModel.DismissPreview();
        e.Handled = true;
    }

    private bool MatchesSessionPullRequestHotkey(System.Windows.Input.KeyEventArgs e) =>
        MatchesPanelHotkey(e, ViewModel.Settings.OpenSessionPullRequestHotkey);

    private bool MatchesPanelHotkey(System.Windows.Input.KeyEventArgs e, string hotkey)
    {
        ParsedHotkey parsed;
        try
        {
            parsed = HotkeyParser.Parse(hotkey, ViewModel.Settings.CmdMapping);
        }
        catch (ArgumentException)
        {
            return false;
        }

        var key = ShortcutFromKey(e.Key);
        if (key is null || !string.Equals(key, parsed.Key, StringComparison.OrdinalIgnoreCase)) return false;
        if (e.Key is Key.Enter or Key.Escape or Key.Tab or Key.Up or Key.Down or Key.Left or Key.Right
            || e.Key is >= Key.D0 and <= Key.D9
            || e.Key is >= Key.NumPad0 and <= Key.NumPad9) return false;
        var actual = e.KeyboardDevice.Modifiers;
        var expectedControl = parsed.Modifiers.HasFlag(HotkeyModifiers.Control);
        var expectedAlt = parsed.Modifiers.HasFlag(HotkeyModifiers.Option);
        var expectedShift = parsed.Modifiers.HasFlag(HotkeyModifiers.Shift);
        var expectedWindows = parsed.Modifiers.HasFlag(HotkeyModifiers.Windows) || parsed.Modifiers.HasFlag(HotkeyModifiers.Command);
        return actual.HasFlag(ModifierKeys.Control) == expectedControl
            && actual.HasFlag(ModifierKeys.Alt) == expectedAlt
            && actual.HasFlag(ModifierKeys.Shift) == expectedShift
            && actual.HasFlag(ModifierKeys.Windows) == expectedWindows;
    }

    private async Task RestoreShortcutAndMaybeHideAsync(string shortcut)
    {
        _suppressDeactivate = true;
        try
        {
            Topmost = false;
            if (System.Windows.Application.Current is App app) app.StopAgentStatusMonitoring();
            var result = await ViewModel.RestoreShortcutAsync(shortcut);
            await FinishRestoreAsync(result);
        }
        finally
        {
            _suppressDeactivate = false;
        }
    }

    private async Task RestoreAndMaybeHideAsync(Bookmark? bookmark = null)
    {
        var target = bookmark ?? ViewModel.SelectedBookmark;
        _suppressDeactivate = true;
        try
        {
            var timing = new RestoreTimingScope($"ui:{target?.State?.Type ?? "none"}", _timing);
            timing.Mark("start");
            Topmost = false;
            if (System.Windows.Application.Current is App app) app.StopAgentStatusMonitoring();
            var result = target is null ? await ViewModel.RestoreSelectedAsync() : await ViewModel.RestoreBookmarkAsync(target);
            timing.Mark("restore:complete", result.Status.ToString());
            await FinishRestoreAsync(result);
        }
        finally
        {
            _suppressDeactivate = false;
        }
    }

    // Why: Hide() before restore makes WezTerm (the previous foreground app) the foreground
    // process. Windows then denies SetForegroundWindow for Firefox / Windows Terminal, so
    // every bookmark appears to "focus WezTerm". Restore while the panel still owns
    // foreground, then hide. Drop Topmost first so the target can actually become foreground.
    private async Task FinishRestoreAsync(OperationResult? result)
    {
        if (result is { IsSuccess: true })
        {
            Hide();
            Topmost = true;
            if (System.Windows.Application.Current is App app) await app.RestoreImeIfNeededAsync();
            return;
        }
        Topmost = true;
        Present();
    }
}
