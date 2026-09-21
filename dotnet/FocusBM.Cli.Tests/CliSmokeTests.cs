using Xunit;

namespace FocusBM.Cli.Tests;

public class CliSmokeTests
{
    [Fact] public async Task Help_ReturnsZero()
    {
        using var stdout = new StringWriter(); using var stderr = new StringWriter();
        var code = await FocusBmCli.RunAsync(new [] { "help" }, stdout, stderr);
        Assert.Equal(0, code);
        Assert.Contains("commands", stdout.ToString());
    }

    [Fact] public async Task AddListRestoreContextSwitchDelete_UseYamlAndReportStatus()
    {
        var temp = Path.Combine(Path.GetTempPath(), "focusbm-cli-" + Guid.NewGuid() + ".yml");
        Environment.SetEnvironmentVariable("FOCUSBM_YAML", temp);
        try
        {
            await RunOk("add", "docs", "notepad", "work memo");
            await RunOk("add", "term", "terminal", "dev shell");

            var list = await RunCapture(0, "list");
            Assert.Contains("docs\tnotepad\twork memo", list.Stdout);
            Assert.Contains("term\tterminal\tdev shell", list.Stdout);

            var where = await RunCapture(0, "where");
            Assert.Contains(temp, where.Stdout);

            var restoreByQuery = await RunCapture(OperatingSystem.IsWindows() ? null : 3, "restore-context", "memo");
            if (!OperatingSystem.IsWindows()) Assert.Contains("Unsupported", restoreByQuery.Stderr);

            var switchResult = await RunCapture(OperatingSystem.IsWindows() ? null : 3, "switch", "docs");
            if (!OperatingSystem.IsWindows()) Assert.Contains("Unsupported", switchResult.Stderr);

            await RunOk("delete", "term");
            var afterDelete = await RunCapture(0, "list");
            Assert.DoesNotContain("term\tterminal", afterDelete.Stdout);
        }
        finally
        {
            Environment.SetEnvironmentVariable("FOCUSBM_YAML", null);
            if (File.Exists(temp)) File.Delete(temp);
        }
    }

    [Fact] public async Task SaveAndTmuxList_ReportUnsupportedOrDisabledWithoutCrashing()
    {
        var temp = Path.Combine(Path.GetTempPath(), "focusbm-cli-" + Guid.NewGuid() + ".yml");
        Environment.SetEnvironmentVariable("FOCUSBM_YAML", temp);
        try
        {
            var save = await RunCapture(OperatingSystem.IsWindows() ? null : 3, "save", "current");
            if (!OperatingSystem.IsWindows()) Assert.Contains("Unsupported", save.Stderr);

            var tmux = await RunCapture(2, "tmux-list");
            Assert.Contains("disabled", tmux.Stderr);
        }
        finally
        {
            Environment.SetEnvironmentVariable("FOCUSBM_YAML", null);
            if (File.Exists(temp)) File.Delete(temp);
        }
    }



    [Fact] public async Task ConfigAndSample_PersistSettingsAndSampleBookmark()
    {
        var temp = Path.Combine(Path.GetTempPath(), "focusbm-cli-" + Guid.NewGuid() + ".yml");
        Environment.SetEnvironmentVariable("FOCUSBM_YAML", temp);
        try
        {
            await RunOk("config", "set", "hotkeyKey", "F8");
            await RunOk("config", "set", "hotkeyModifiers", "Control+Shift");
            await RunOk("config", "set", "imeRestoreEnabled", "true");
            await RunOk("config", "set", "virtuawinEnabled", "true");
            var profile = Path.Combine(Path.GetTempPath(), "focusbm-cdp-" + Guid.NewGuid());
            await RunOk("config", "init-cdp", profile, "http://127.0.0.1:9222");
            Assert.True(File.Exists(Path.Combine(profile, ".focusbm-cdp-profile")));
            await RunOk("sample");
            var config = await RunCapture(0, "config", "get");
            Assert.Contains("hotkeyKey=F8", config.Stdout);
            Assert.Contains("imeRestoreEnabled=True", config.Stdout);
            Assert.Contains("virtuawinEnabled=True", config.Stdout);
            Assert.Contains("browserCdpEnabled=True", config.Stdout);
            Assert.Contains("browserCdpRequireKnownBrowserOwner=True", config.Stdout);
            var list = await RunCapture(0, "list");
            Assert.Contains("memo\tnotepad", list.Stdout);
        }
        finally
        {
            Environment.SetEnvironmentVariable("FOCUSBM_YAML", null);
            if (File.Exists(temp)) File.Delete(temp);
        }
    }

    private static async Task RunOk(params string[] args)
    {
        var result = await RunCapture(0, args);
        Assert.Equal(0, result.Code);
    }

    private static async Task<(int Code, string Stdout, string Stderr)> RunCapture(int? expectedCode, params string[] args)
    {
        using var stdout = new StringWriter();
        using var stderr = new StringWriter();
        var code = await FocusBmCli.RunAsync(args, stdout, stderr);
        if (expectedCode is not null) Assert.Equal(expectedCode.Value, code);
        return (code, stdout.ToString(), stderr.ToString());
    }
}
