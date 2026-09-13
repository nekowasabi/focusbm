import Testing
@testable import FocusBMLib

// MARK: - ProcessSnapshot.parse テスト

@Test func test_processSnapshot_parse_basicFields() {
    let output = """
      1     0 ??       Ss   /sbin/launchd
    100     1 ttys000  Ss+  -zsh
    200   100 ttys000  S+   claude --foo bar
    300     1 ??       Z    <defunct>
    """
    let snap = ProcessSnapshot.parse(output)
    #expect(snap.entries.count == 4)
    #expect(snap.byPid[1]?.args == "/sbin/launchd")
    #expect(snap.byPid[1]?.tty == nil)
    #expect(snap.byPid[100]?.tty == "ttys000")
    #expect(snap.byPid[200]?.ppid == 100)
    #expect(snap.byPid[300]?.isZombie == true)
    #expect(snap.byPid[100]?.isZombie == false)
}

@Test func test_processSnapshot_parse_stripsDevPrefix() {
    let output = "  5   1 /dev/ttys003  Ss   /bin/zsh\n"
    let snap = ProcessSnapshot.parse(output)
    #expect(snap.byPid[5]?.tty == "ttys003")
}

@Test func test_processSnapshot_parse_trimsLeadingSpacesInArgs() {
    // 列パディング由来の先頭空白が args に残ると (^|/)name アンカーが効かない
    let output = "  7   1 ttys000   Ss    devin --permission-mode dangerous\n"
    let snap = ProcessSnapshot.parse(output)
    #expect(snap.byPid[7]?.args == "devin --permission-mode dangerous")
    let pattern = ProcessProvider.processNamePattern("devin")
    let args = snap.byPid[7]?.args ?? ""
    #expect(args.range(of: pattern, options: .regularExpression) != nil)
}

@Test func test_processSnapshot_parse_skipsMalformedLines() {
    let output = "garbage\n\n  12  1 ttys000 Ss zsh --x\n"
    let snap = ProcessSnapshot.parse(output)
    #expect(snap.entries.count == 1)
    #expect(snap.byPid[12]?.args == "zsh --x")
}

@Test func test_processSnapshot_entries_sortedByPid() {
    let output = """
    300 1 ?? S c
    100 1 ?? S a
    200 1 ?? S b
    """
    let snap = ProcessSnapshot.parse(output)
    #expect(snap.entries.map(\.pid) == [100, 200, 300])
}

// MARK: - pids(onTTY:) テスト

@Test func test_processSnapshot_pidsOnTTY() {
    let output = """
    10  1 ttys000 Ss  /bin/zsh
    11 10 ttys000 S   vim
    12  1 ttys001 Ss  /bin/zsh
    13  1 ??      Ss  /usr/sbin/cron
    """
    let snap = ProcessSnapshot.parse(output)
    #expect(Set(snap.pids(onTTY: "ttys000")) == [10, 11])
    #expect(Set(snap.pids(onTTY: "/dev/ttys000")) == [10, 11])
    #expect(snap.pids(onTTY: "ttys999").isEmpty)
}

// MARK: - descendants(of:) テスト

@Test func test_processSnapshot_descendants_bfs() {
    let output = """
    1 0 ?? Ss init
    2 1 ?? S  zsh
    3 2 ?? S  zsh
    4 3 ?? S  node codex
    5 4 ?? S  deep
    6 1 ?? S  other
    """
    let snap = ProcessSnapshot.parse(output)
    #expect(snap.descendants(of: 1, maxDepth: 3).sorted() == [2, 3, 4, 6])
    #expect(snap.descendants(of: 1, maxDepth: 4).sorted() == [2, 3, 4, 5, 6])
    #expect(snap.descendants(of: 2, maxDepth: 3).sorted() == [3, 4, 5])
    #expect(snap.descendants(of: 5).isEmpty)
}

@Test func test_processSnapshot_descendants_cycleSafe() {
    // ppid ループ（pid reuse 等）でも無限ループしない
    let output = """
    1 2 ?? S a
    2 1 ?? S b
    """
    let snap = ProcessSnapshot.parse(output)
    #expect(snap.descendants(of: 1).sorted() == [2])
}

@Test func test_processSnapshot_commandLine() {
    let output = "  42  1 ?? S  node /opt/bin/codex --full-auto\n"
    let snap = ProcessSnapshot.parse(output)
    #expect(snap.commandLine(for: 42) == "node /opt/bin/codex --full-auto")
    #expect(snap.commandLine(for: 99) == nil)
}

// MARK: - 実機スモーク（macOS の ps 出力と互換）

@Test func test_processSnapshot_capture_returnsCurrentProcess() {
    let snap = ProcessSnapshot.capture()
    let selfPid = ProcessInfo.processInfo.processIdentifier
    #expect(snap.byPid[selfPid] != nil)
}
