#!/bin/bash
# Run from repo root: ./Scripts/extract_html.sh
# Extracts sensor HTML files from CameraWebServer/camera_index.h into index/
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - <<EOF
import re, gzip

with open("$REPO_ROOT/CameraWebServer/camera_index.h", "r") as f:
    content = f.read()

pattern = re.compile(
    r'//File:\s*(\S+),\s*Size:\s*\d+\s*\n'
    r'#define\s+(\w+)_len\s+\d+\s*\n'
    r'const unsigned char \2\[\]\s*=\s*\{([^}]+)\}',
    re.DOTALL
)

# e.g. index_ov2640.html.gz → ov2640
def sensor_name(filename):
    return re.search(r'index_(\w+)\.html', filename).group(1)

for match in pattern.finditer(content):
    filename, array_name, hex_body = match.groups()
    hex_vals = re.findall(r'0x([0-9A-Fa-f]{2})', hex_body)
    gz_data = bytes(int(h, 16) for h in hex_vals)
    html = gzip.decompress(gz_data).decode("utf-8")

    sensor = sensor_name(filename)
    out_path = "$REPO_ROOT/index/" + sensor + ".html"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"  {filename} → index/{sensor}.html ({len(html)} bytes)")

print("Done. Edit HTML files in index/, common files in index/common/.")
print("Run ./Scripts/pack_html.sh when ready.")
EOF
