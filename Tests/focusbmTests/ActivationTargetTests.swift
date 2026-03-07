import Testing
import AppKit
@testable import FocusBMLib

// MARK: - ActivationTarget Tests

/// .none の activate() が安全に実行される（クラッシュしない）
@Test func test_activationTarget_none_doesNotCrash() {
    let target = ActivationTarget.none
    // クラッシュしないことのみを検証する。副作用なし
    target.activate()
}

/// 無効な PID でも activate() がクラッシュしない
@Test func test_activationTarget_pid_invalidPid() {
    // pid_t(-1) は無効な PID。NSRunningApplication(processIdentifier:) が nil を返す
    let target = ActivationTarget.pid(-1)
    // クラッシュしないことを確認
    target.activate()
}

/// pid=0 (無効) でも activate() がクラッシュしない
@Test func test_activationTarget_pid_zeroPid() {
    let target = ActivationTarget.pid(0)
    target.activate()
}

/// 存在しない大きな PID でも activate() がクラッシュしない
@Test func test_activationTarget_pid_nonExistentPid() {
    let target = ActivationTarget.pid(99999999)
    target.activate()
}

/// .bundleId ケースが正しく構築される
@Test func test_activationTarget_bundleId_creation() {
    let bundleId = "com.googlecode.iterm2"
    let appName = "iTerm2"
    let target = ActivationTarget.bundleId(bundleId, appName: appName)

    // パターンマッチで値を取り出して検証
    if case .bundleId(let id, let name) = target {
        #expect(id == bundleId)
        #expect(name == appName)
    } else {
        Issue.record("Expected .bundleId case")
    }
}

/// 異なる bundleId でも正しく構築される
@Test func test_activationTarget_bundleId_creation_ghostty() {
    let target = ActivationTarget.bundleId("com.mitchellh.ghostty", appName: "Ghostty")
    if case .bundleId(let id, let name) = target {
        #expect(id == "com.mitchellh.ghostty")
        #expect(name == "Ghostty")
    } else {
        Issue.record("Expected .bundleId case")
    }
}

/// .bundleId の activate() がクラッシュしない（該当アプリが起動していない場合）
@Test func test_activationTarget_bundleId_notRunning_doesNotCrash() {
    // 存在しない bundleId でも activate() はクラッシュしない
    let target = ActivationTarget.bundleId("com.nonexistent.app", appName: "NonExistentApp")
    target.activate()
}

/// .runningApp ケースが正しく構築される（NSRunningApplication.current を使用）
@Test func test_activationTarget_runningApp_creation() {
    let app = NSRunningApplication.current
    let target = ActivationTarget.runningApp(app)

    if case .runningApp(let runningApp) = target {
        #expect(runningApp.processIdentifier == app.processIdentifier)
    } else {
        Issue.record("Expected .runningApp case")
    }
}

/// .runningApp の activate() が NSRunningApplication.current で安全に実行される
@Test func test_activationTarget_runningApp_doesNotCrash() {
    let app = NSRunningApplication.current
    let target = ActivationTarget.runningApp(app)
    // 自プロセスをアクティベートしようとする。クラッシュしないことを確認
    target.activate()
}

// MARK: - ActivationTarget enum case 識別テスト

/// 各ケースが distinct であることを確認
@Test func test_activationTarget_noneCase_isNone() {
    let target = ActivationTarget.none
    if case .none = target {
        // 期待通り
    } else {
        Issue.record("Expected .none case")
    }
}

@Test func test_activationTarget_pidCase_isPid() {
    let target = ActivationTarget.pid(12345)
    if case .pid(let p) = target {
        #expect(p == 12345)
    } else {
        Issue.record("Expected .pid case")
    }
}
