namespace FocusBM.Core;

/// <summary>
/// 1-based displayNumber. Index 0 is the primary monitor after screens are ordered
/// primary-first, so 1 (and omit) both mean the main display.
/// </summary>
public static class DisplayTarget
{
    public static int ResolveIndex(int? displayNumber, int screenCount)
    {
        if (screenCount <= 0) return 0;
        if (displayNumber is >= 1 && displayNumber.Value <= screenCount)
            return displayNumber.Value - 1;
        return 0;
    }
}
