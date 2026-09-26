namespace FocusBM.Core;

public enum NavigationCommand { Up, Down, Left, Right, Home, End }

public static class GridNavigator
{
    public static int Move(int currentIndex, int itemCount, int columns, NavigationCommand command)
    {
        if (itemCount <= 0) return -1;
        var cols = columns <= 1 ? 1 : 2;
        var i = Math.Clamp(currentIndex, 0, itemCount - 1);
        return command switch
        {
            NavigationCommand.Home => 0,
            NavigationCommand.End => itemCount - 1,
            NavigationCommand.Up => Math.Max(0, i - cols),
            NavigationCommand.Down => Math.Min(itemCount - 1, i + cols),
            NavigationCommand.Left => Math.Max(0, i - 1),
            NavigationCommand.Right => Math.Min(itemCount - 1, i + 1),
            _ => i
        };
    }

    /// <summary>
    /// True when the current cell is on the first grid row, including an empty list.
    /// Up from this row should return keyboard focus to the search box.
    /// </summary>
    public static bool IsOnFirstRow(int currentIndex, int itemCount, int columns)
    {
        if (itemCount <= 0) return true;
        var cols = columns <= 1 ? 1 : 2;
        var i = Math.Clamp(currentIndex, 0, itemCount - 1);
        return i < cols;
    }
}
