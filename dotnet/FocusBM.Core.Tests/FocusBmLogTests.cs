using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

public class FocusBmLogTests
{
    [Fact]
    public void Write_AppendsTimestampedLine()
    {
        var directory = Path.Combine(Path.GetTempPath(), "focusbm-log-" + Guid.NewGuid());
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, "focusbm.log");
        try
        {
            FocusBmLog.Open(path);
            FocusBmLog.Write("restore", "firefox-2 app=Firefox -> Success");
            var text = File.ReadAllText(path);
            Assert.Contains("[log] opened", text);
            Assert.Contains("[restore] firefox-2 app=Firefox -> Success", text);
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }
}
