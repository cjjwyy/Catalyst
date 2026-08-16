#!/usr/bin/env bash
set -euo pipefail

# 用法: ./tools/itch_push.sh <butler路径> <itch用户名/游戏名>
# 示例: ./tools/itch_push.sh butler cjjwyy/catalyst
BUTLER="${1:?缺少 butler 路径}"
TARGET="${2:?缺少 itch 目标}"

mkdir -p build
godot --headless --path . --export-release "Windows Desktop" build/windows/Catalyst.exe
godot --headless --path . --export-release "Linux/X11" build/linux/Catalyst.x86_64
godot --headless --path . --export-release "Web" build/web/index.html

"$BUTLER" push build/windows "$TARGET:windows"
"$BUTLER" push build/linux "$TARGET:linux"
"$BUTLER" push build/web "$TARGET:web"
