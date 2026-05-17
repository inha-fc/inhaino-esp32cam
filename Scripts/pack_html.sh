#!/bin/bash
# Run from repo root: ./Scripts/pack_html.sh
# Packs index/ov*.html back into CameraWebServer/camera_index.h
#
# Supports include directives inside HTML files:
#   <!-- @include common/style.css -->
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - <<EOF
import re, gzip, os

index_dir  = "$REPO_ROOT/index"
header_path = "$REPO_ROOT/CameraWebServer/camera_index.h"

def resolve_includes(html, base_dir):
    """Replace <!-- @include path --> with file contents."""
    def replacer(m):
        path = os.path.join(base_dir, m.group(1).strip())
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    return re.sub(r'<!--\s*@include\s+(.+?)\s*-->', replacer, html)

with open(header_path, "r") as f:
    content = f.read()

# Match each sensor array block
pattern = re.compile(
    r'(//File:\s*(index_(\w+)\.html\.gz),\s*Size:\s*)\d+(\s*\n'
    r'#define\s+(\w+)_len\s+)\d+(\s*\n'
    r'const unsigned char \5\[\]\s*=\s*\{)[^}]+(\})',
    re.DOTALL
)

def make_replacement(sensor, match):
    html_path = os.path.join(index_dir, sensor + ".html")
    if not os.path.exists(html_path):
        print(f"  Skipping {sensor} (index/{sensor}.html not found)")
        return match.group(0)

    with open(html_path, "r", encoding="utf-8") as f:
        html = f.read()

    html = resolve_includes(html, index_dir)
    gz_data = gzip.compress(html.encode("utf-8"), compresslevel=9)

    hex_lines = []
    for i in range(0, len(gz_data), 26):
        chunk = gz_data[i:i+26]
        hex_lines.append("  " + ", ".join(f"0x{b:02X}" for b in chunk) + ",")
    if hex_lines:
        hex_lines[-1] = hex_lines[-1].rstrip(",")

    gz_size = len(gz_data)
    print(f"  index/{sensor}.html ({len(html)} bytes) → index_{sensor}.html.gz ({gz_size} bytes gz)")

    return (
        match.group(1) + str(gz_size) +
        match.group(4) + str(gz_size) +
        match.group(6) + "\n" +
        "\n".join(hex_lines) + "\n" +
        match.group(7)
    )

def replacer(match):
    sensor = match.group(3)
    return make_replacement(sensor, match)

new_content = pattern.sub(replacer, content)

with open(header_path, "w") as f:
    f.write(new_content)

print("Done. CameraWebServer/camera_index.h updated.")
EOF
