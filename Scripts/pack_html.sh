#!/bin/bash
# Run from repo root: ./Scripts/pack_html.sh
# Packs all Scripts/index_ov*.html files back into CameraWebServer/camera_index.h
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - <<EOF
import re, gzip, os

scripts_dir = "$REPO_ROOT/Scripts"
header_path = "$REPO_ROOT/CameraWebServer/camera_index.h"

with open(header_path, "r") as f:
    content = f.read()

pattern = re.compile(
    r'(//File:\s*(\S+),\s*Size:\s*)\d+(\s*\n'
    r'#define\s+(\w+)_len\s+)\d+(\s*\n'
    r'const unsigned char \4\[\]\s*=\s*\{)[^}]+(\})',
    re.DOTALL
)

def replacement(match):
    filename = match.group(2)                       # e.g. index_ov2640.html.gz
    html_name = filename.replace(".gz", "")         # e.g. index_ov2640.html
    html_path = os.path.join(scripts_dir, html_name)

    if not os.path.exists(html_path):
        print(f"  Skipping {html_name} (not found in Scripts/)")
        return match.group(0)

    with open(html_path, "rb") as f:
        html = f.read()

    gz_data = gzip.compress(html, compresslevel=9)

    hex_lines = []
    for i in range(0, len(gz_data), 26):
        chunk = gz_data[i:i+26]
        hex_lines.append("  " + ", ".join(f"0x{b:02X}" for b in chunk) + ",")
    if hex_lines:
        hex_lines[-1] = hex_lines[-1].rstrip(",")

    print(f"  {html_name} ({len(html)} bytes) → {filename} ({len(gz_data)} bytes gz)")
    return (
        match.group(1) + str(len(gz_data)) +
        match.group(3) + str(len(gz_data)) +
        match.group(5) + "\n" +
        "\n".join(hex_lines) + "\n" +
        match.group(6)
    )

new_content = pattern.sub(replacement, content)

with open(header_path, "w") as f:
    f.write(new_content)

print("Done. CameraWebServer/camera_index.h updated.")
EOF
