#!/bin/bash
# Run from repo root: ./Scripts/extract_html.sh
# Extracts all sensor HTML files from CameraWebServer/camera_index.h
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - <<EOF
import re, gzip

with open("$REPO_ROOT/CameraWebServer/camera_index.h", "r") as f:
    content = f.read()

# Parse each sensor array block separately
pattern = re.compile(
    r'//File:\s*(\S+),\s*Size:\s*\d+\s*\n'
    r'#define\s+(\w+)_len\s+\d+\s*\n'
    r'const unsigned char \2\[\]\s*=\s*\{([^}]+)\}',
    re.DOTALL
)

for match in pattern.finditer(content):
    filename, array_name, hex_body = match.groups()
    hex_vals = re.findall(r'0x([0-9A-Fa-f]{2})', hex_body)
    gz_data = bytes(int(h, 16) for h in hex_vals)
    html = gzip.decompress(gz_data)

    # e.g. index_ov2640.html.gz → index_ov2640.html
    out_name = filename.replace(".gz", "")
    out_path = "$REPO_ROOT/Scripts/" + out_name
    with open(out_path, "wb") as f:
        f.write(html)

    print(f"  {filename} ({len(gz_data)} bytes gz) → {out_name} ({len(html)} bytes)")

print("Done. Edit the HTML files in Scripts/, then run pack_html.sh.")
EOF
