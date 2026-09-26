# focusBM build targets
#
# Default `make` follows $PC (see ~/.dotfiles zsh env):
#   PC=wsl      → Windows FocusBM.exe (framework-dependent) in C:\takeda\tools\focusbm
#   otherwise   → macOS app rebuild + relaunch (scripts/dev-relaunch.sh)
#
# Windows 版 (.NET 8) は dotnet/FocusBM.sln 配下のプロジェクト群でビルドする。
# Directory.Build.props の EnableWindowsTargeting=true により、WSL/Linux 上でも
# restore / build / test / publish が可能（WPF を含む）。
# publish 引数は scripts/windows/publish-focusbm.ps1 と揃えている。

DOTNET     ?= dotnet
# WSL mise currently ships the .NET 10 SDK without a separate 8.0 runtime.
# Tests still target net8.0 (CI uses 8.0.x); roll forward so testhost can start.
export DOTNET_ROLL_FORWARD ?= LatestMajor
WIN_SLN    := dotnet/FocusBM.sln
WIN_CONFIG ?= Release
WIN_RID    ?= win-x64
ARTIFACTS  := artifacts
# Why: Run from local disk, not \\wsl.localhost — AV heuristics (Surfshark Drop.Win64.FakeProgSelfRun) flag UNC-launched exes.
RELEASE_DIR ?= /mnt/c/takeda/tools/focusbm
CLI_PROJ   := dotnet/FocusBM.Cli/FocusBM.Cli.csproj
APP_PROJ   := dotnet/FocusBM.App.Wpf/FocusBM.App.Wpf.csproj

# win-exe 用: 既定は self-contained 単一ファイル（.NET ランタイム非依存で実行できる .exe）
WIN_SELF_CONTAINED ?= true
WIN_SINGLE_FILE    ?= true

ifeq ($(PC),wsl)
.DEFAULT_GOAL := release
else
.DEFAULT_GOAL := relaunch
endif

.PHONY: help relaunch win-restore win-build win-test win-publish win-exe release win-clean

help: ## 利用可能なターゲット一覧を表示する
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

relaunch: ## macOS アプリを終了・再ビルド・再起動する（PC!=wsl の既定）
	@if [ "$$(uname -s)" != "Darwin" ]; then \
		echo "error: default make relaunches the macOS app. On WSL run: PC=wsl make" >&2; \
		exit 1; \
	fi
	./scripts/dev-relaunch.sh

win-restore: ## Windows 版ソリューションの NuGet 依存を復元する
	$(DOTNET) restore $(WIN_SLN)

win-build: win-restore ## Windows 版ソリューションをビルドする
	$(DOTNET) build $(WIN_SLN) -c $(WIN_CONFIG) --no-restore

win-test: win-build ## Windows 版の自動テストを実行する
	$(DOTNET) test $(WIN_SLN) -c $(WIN_CONFIG) --no-build

win-publish: ## CLI / WPF アプリを win-x64 向けに publish する (framework 依存, artifacts/ 配下)
	$(DOTNET) publish $(CLI_PROJ) -c $(WIN_CONFIG) -r $(WIN_RID) --self-contained false -o $(ARTIFACTS)/focusbm-cli
	$(DOTNET) publish $(APP_PROJ) -c $(WIN_CONFIG) -r $(WIN_RID) --self-contained false -o $(ARTIFACTS)/focusbm-app

win-exe: ## Windows 単体実行 exe を生成する (self-contained/single-file, artifacts/ 配下)
	$(DOTNET) publish $(CLI_PROJ) -c $(WIN_CONFIG) -r $(WIN_RID) --self-contained $(WIN_SELF_CONTAINED) -p:PublishSingleFile=$(WIN_SINGLE_FILE) -o $(ARTIFACTS)/focusbm-cli-exe
	$(DOTNET) publish $(APP_PROJ) -c $(WIN_CONFIG) -r $(WIN_RID) --self-contained $(WIN_SELF_CONTAINED) -p:PublishSingleFile=$(WIN_SINGLE_FILE) -o $(ARTIFACTS)/focusbm-app-exe

# Why: Framework-dependent folder publish, not self-extracting single-file — self-extraction looked like a dropper to AV.
# Why: Do not wipe RELEASE_DIR — colocated bookmarks.yml and focusbm.log live there.
release: ## FocusBM.exe を RELEASE_DIR（既定 C:\takeda\tools\focusbm）に framework 依存で生成する
	mkdir -p $(RELEASE_DIR)
	$(DOTNET) publish $(APP_PROJ) -c Release -r $(WIN_RID) --self-contained false \
		-p:PublishSingleFile=false \
		-p:DebugType=None \
		-p:CopyOutputSymbolsToPublishDirectory=false \
		-o $(RELEASE_DIR)
	mv -f $(RELEASE_DIR)/FocusBM.App.Wpf.exe $(RELEASE_DIR)/FocusBM.exe
	[ -f $(RELEASE_DIR)/bookmarks.yml ] || [ ! -f release/bookmarks.yml ] || cp release/bookmarks.yml $(RELEASE_DIR)/bookmarks.yml
	[ -f $(RELEASE_DIR)/bookmarks.yml ] || cp bookmarks.example.windows.yml $(RELEASE_DIR)/bookmarks.yml

win-clean: ## Windows 版のビルド生成物を削除する
	$(DOTNET) clean $(WIN_SLN) -c $(WIN_CONFIG)
	rm -rf $(ARTIFACTS)/focusbm-cli $(ARTIFACTS)/focusbm-app $(ARTIFACTS)/focusbm-cli-exe $(ARTIFACTS)/focusbm-app-exe
