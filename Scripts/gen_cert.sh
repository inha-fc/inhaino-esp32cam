#!/usr/bin/env bash
# Generates a self-signed TLS certificate and writes CameraWebServer/default_cert.h
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/../CameraWebServer/default_cert.h"
TMPKEY="$(mktemp /tmp/cam_key.XXXXXX.pem)"
TMPCRT="$(mktemp /tmp/cam_crt.XXXXXX.pem)"

cleanup() { rm -f "$TMPKEY" "$TMPCRT"; }
trap cleanup EXIT

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$TMPKEY" \
  -out    "$TMPCRT" \
  -days   3650 \
  -subj   "/CN=esp32cam/O=InhaIno" \
  2>/dev/null

python3 - "$TMPCRT" "$TMPKEY" "$OUT" <<'EOF'
import sys

def pem_to_c_str(path, varname):
    with open(path) as f:
        lines = f.read().strip().splitlines()
    body = "\n".join(f'  "{line}\\n"' for line in lines)
    return f"static const char {varname}[] =\n{body}\n  ;\n"

cert_path, key_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(out_path, "w") as f:
    f.write("#pragma once\n\n")
    f.write(pem_to_c_str(cert_path, "DEFAULT_CERT_PEM"))
    f.write("\n")
    f.write(pem_to_c_str(key_path, "DEFAULT_KEY_PEM"))
EOF

echo "Generated: $OUT"
