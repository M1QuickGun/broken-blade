#!/bin/sh
# Builds the game and the demo for Windows into export/ (needs Godot's export templates:
# Editor > Manage Export Templates). Run from the project root:
#     sh tools/export.sh [path to the Godot console executable]
GODOT="${1:-/c/Users/miche/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe}"
set -e
mkdir -p export/windows export/demo
"$GODOT" --headless --path . --export-release "Windows Desktop" export/windows/BrokenBlade.exe
"$GODOT" --headless --path . --export-release "Windows Demo" export/demo/BrokenBladeDemo.exe
echo "Built export/windows/BrokenBlade.exe and export/demo/BrokenBladeDemo.exe"
