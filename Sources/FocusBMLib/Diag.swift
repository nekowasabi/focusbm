import os

// ponytail: temporary diagnostics for the post-selection freeze investigation; remove once diagnosed.
// Read with: log show --last 1h --predicate 'subsystem == "com.focusbm.app" AND category == "diag"'
public enum Diag {
    public static let log = Logger(subsystem: "com.focusbm.app", category: "diag")
}
