#!/usr/bin/env bash
set -euo pipefail

version="${1:-0.3.1-alpha.3}"
if [[ ! "$version" =~ ^[0-9A-Za-z][0-9A-Za-z.-]*$ ]]; then
    echo "Invalid release version: $version" >&2
    exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$repo_root/build/AstralArena-$version"
archive="$repo_root/dist/AstralArena-$version.zip"

rm -rf "$build_root"
mkdir -p "$build_root/Mods" "$repo_root/dist"
cp -R "$repo_root/src/Mods/AstralArena" "$build_root/Mods/AstralArena"
cp "$repo_root/scripts/Install-Playtest.ps1" "$build_root/Install-Playtest.ps1"
cp "$repo_root/scripts/Uninstall-Playtest.ps1" "$build_root/Uninstall-Playtest.ps1"
cp "$repo_root/scripts/Enable-SE-Console.ps1" "$build_root/Enable-SE-Console.ps1"
cp "$repo_root/PLAYTEST.md" "$build_root/PLAYTEST.md"
cp "$repo_root/README.md" "$build_root/README.md"
cp "$repo_root/CHANGELOG.md" "$build_root/CHANGELOG.md"
cp "$repo_root/CONTRIBUTING.md" "$build_root/CONTRIBUTING.md"
cp "$repo_root/LICENSE" "$build_root/LICENSE"
cp -R "$repo_root/docs" "$build_root/docs"

rm -f "$archive"
(cd "$repo_root/build" && zip -qr "$archive" "AstralArena-$version")
echo "$archive"
