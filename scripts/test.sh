#!/bin/bash
# swift test を実行し、中断・タイムアウト時に残留するテスト子プロセスを掃除するスクリプト
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_BUNDLE="focusbmPackageTests"
test_pid=""

# Why: timeout や Ctrl-C が殺すのは直接の子(swift-test)のみで、孫の
#      swiftpm-testing-helper / xctest バンドルが孤児として残る。
#      残留プロセスは .build ロックを保持し CPU を占有し続け、
#      後続実行のデッドライン系テストを大量失敗させる。
#      リポジトリ固有のバンドル名で絞り、他プロジェクトの swift test は殺さない。
cleanup() {
    if [ -n "$test_pid" ]; then
        kill "$test_pid" 2>/dev/null
    fi
    pkill -f "swiftpm-testing-helper.*${TEST_BUNDLE}" 2>/dev/null
    pkill -f "${TEST_BUNDLE}\.xctest" 2>/dev/null
    # Why: kill 後に退出途中・spawn途中の孫プロセスを取りこぼす競合があるため二回掃除する
    sleep 0.5
    pkill -f "swiftpm-testing-helper.*${TEST_BUNDLE}" 2>/dev/null
    pkill -f "${TEST_BUNDLE}\.xctest" 2>/dev/null
    return 0
}

# 過去の中断実行で残った孤児が .build ロックを握っている場合に備えて先行掃除
cleanup
trap 'status=$?; cleanup; exit $status' EXIT

cd "$PROJECT_DIR"
swift test "$@" &
test_pid=$!
wait "$test_pid"
