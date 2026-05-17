#!/usr/bin/env bash
# Builds a static GitHub Pages demo from index/ HTML sources.
# Usage: ./Scripts/build_demo.sh [output_dir]
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-${REPO_ROOT}/demo_out}"

rm -rf "$OUT"
mkdir -p "$OUT"

python3 - "$REPO_ROOT" "$OUT" <<'PYEOF'
import re, os, sys

repo_root = sys.argv[1]
out_dir   = sys.argv[2]
index_dir = os.path.join(repo_root, "index")

# ── Demo overlay CSS ──────────────────────────────────────────────────────────
DEMO_CSS = """\
<style>
#demo-banner {
  position: fixed; top: 0; left: 0; right: 0; z-index: 9999;
  background: #18140a; border-bottom: 1px solid #3a2e00;
  color: #f0c040; font-size: 12px; font-family: monospace;
  padding: 7px 16px; text-align: center; letter-spacing: .02em;
}
#demo-banner a { color: #f0c040; }
#topbar  { top: 30px !important; }
#layout  { min-height: calc(100vh - 80px) !important; }
</style>"""

# ── Demo stream placeholder (SVG data URL) ────────────────────────────────────
DEMO_IMG = (
  "data:image/svg+xml,"
  "%3Csvg xmlns='http://www.w3.org/2000/svg' width='640' height='480'%3E"
  "%3Crect width='640' height='480' fill='%230c0c11'/%3E"
  "%3Ccircle cx='320' cy='220' r='72' fill='none' stroke='%23ff3034' stroke-width='2' opacity='.45'/%3E"
  "%3Ccircle cx='320' cy='220' r='50' fill='none' stroke='%23ff3034' stroke-width='1.5' opacity='.3'/%3E"
  "%3Ctext x='320' y='226' fill='%23ff3034' font-family='monospace' font-size='14'"
  " text-anchor='middle' opacity='.65'%3E%E2%97%89 DEMO FEED%3C/text%3E"
  "%3Ctext x='320' y='336' fill='%237c7f96' font-family='monospace' font-size='11'"
  " text-anchor='middle'%3ENo real ESP32-CAM connected%3C/text%3E%3C/svg%3E"
)

# ── Demo JS (injected before </head>) ────────────────────────────────────────
DEMO_JS = """\
<script>
(function(){
  function mockJson(d){
    return Promise.resolve(new Response(JSON.stringify(d),
      {status:200,headers:{'Content-Type':'application/json'}}));
  }
  var _fetch=window.fetch;
  window.fetch=function(url,opts){
    var path=new URL(String(url),location.href).pathname;
    if(path==='/status')
      return mockJson({framesize:6,quality:10,brightness:0,contrast:0,
        saturation:0,special_effect:0,wb_mode:0,awb:1,awb_gain:1,
        aec:1,aec2:1,ae_level:0,aec_value:204,agc:1,agc_gain:0,
        gainceiling:0,bpc:0,wpc:1,raw_gma:1,lenc:1,vflip:0,hmirror:0,
        dcw:1,colorbar:0,led_intensity:0});
    if(path==='/info')
      return mockJson({ip:'192.168.1.100',rssi:-62,uptime_s:3721,
        heap_free:187456,heap_min:145032,sensor_pid:'0x2646'});
    if(['/control','/cert','/restart','/update','/xclk','/reg','/greg','/resolution']
        .some(function(p){return path.startsWith(p);}))
      return mockJson({result:'ok',note:'Demo mode — no real device'});
    return _fetch(url,opts);
  };
  document.addEventListener('DOMContentLoaded',function(){
    var img=document.getElementById('stream');
    if(!img)return;
    var DEMO='""" + DEMO_IMG + """';
    new MutationObserver(function(){
      var s=img.getAttribute('src');
      if(s&&!s.startsWith('data:'))img.src=DEMO;
    }).observe(img,{attributes:true,attributeFilter:['src']});
  });
})();
</script>"""

# ── Demo banner HTML ──────────────────────────────────────────────────────────
REPO_URL = "https://github.com/inha-fc/inhaino-esp32cam"
DEMO_BANNER = (
  '<div id="demo-banner">'
  '&#x26A1; Demo Mode &mdash; controls are simulated, no real ESP32-CAM connected'
  ' &nbsp;&middot;&nbsp; '
  '<a href="' + REPO_URL + '" target="_blank" rel="noopener">GitHub</a>'
  '</div>'
)

def resolve_includes(html, base_dir):
    def repl(m):
        path = os.path.join(base_dir, m.group(1).strip())
        with open(path, encoding="utf-8") as f:
            return f.read()
    return re.sub(r'<!--\s*@include\s+(.+?)\s*-->', repl, html)

for sensor in ["ov2640", "ov3660", "ov5640"]:
    src = os.path.join(index_dir, sensor + ".html")
    with open(src, encoding="utf-8") as f:
        html = f.read()
    html = resolve_includes(html, index_dir)
    html = html.replace("</head>", DEMO_CSS + "\n" + DEMO_JS + "\n</head>")
    html = html.replace("<body>", "<body>\n    " + DEMO_BANNER)
    dst = os.path.join(out_dir, sensor + ".html")
    with open(dst, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"  Built {sensor}.html ({len(html)} bytes)")

print(f"Done → {out_dir}/")
PYEOF

# ── Landing page ──────────────────────────────────────────────────────────────
REPO_URL="https://github.com/inha-fc/inhaino-esp32cam"
cat > "$OUT/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>ESP32-CAM — Live UI Demo</title>
  <style>
    :root{--bg:#0c0c11;--surface:#15151d;--surface2:#1c1c27;
          --border:rgba(255,255,255,.08);--accent:#ff3034;
          --text:#eef0f6;--muted:#7c7f96;--radius:10px;}
    *{box-sizing:border-box;}
    body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
         background:var(--bg);color:var(--text);min-height:100vh;
         display:flex;flex-direction:column;align-items:center;justify-content:center;
         padding:24px;}
    header{text-align:center;margin-bottom:40px;}
    .cam-dot{display:inline-block;width:10px;height:10px;border-radius:50%;
             background:var(--accent);box-shadow:0 0 10px rgba(255,48,52,.5);
             animation:pulse 2.4s ease-in-out infinite;vertical-align:middle;
             margin-right:8px;}
    @keyframes pulse{0%,100%{opacity:1;box-shadow:0 0 6px rgba(255,48,52,.4);}
      50%{opacity:.7;box-shadow:0 0 18px rgba(255,48,52,.7);}}
    h1{font-size:26px;font-weight:700;margin:0 0 8px;letter-spacing:-.02em;}
    p{color:var(--muted);font-size:14px;margin:0;}
    .cards{display:flex;gap:16px;flex-wrap:wrap;justify-content:center;margin:0 auto;}
    .card{background:var(--surface);border:1px solid var(--border);
          border-radius:var(--radius);padding:24px 32px;text-decoration:none;
          color:var(--text);text-align:center;transition:border-color .2s,transform .15s,box-shadow .2s;
          min-width:160px;}
    .card:hover{border-color:var(--accent);transform:translateY(-3px);
                box-shadow:0 8px 24px rgba(255,48,52,.15);}
    .card .sensor{font-size:22px;font-weight:700;color:var(--accent);margin-bottom:6px;}
    .card .desc{font-size:12px;color:var(--muted);}
    footer{margin-top:48px;font-size:12px;color:var(--muted);text-align:center;}
    footer a{color:var(--muted);}
  </style>
</head>
<body>
  <header>
    <h1><span class="cam-dot"></span>ESP32-CAM Web UI</h1>
    <p>Interactive demo &mdash; no real device needed. Pick a camera sensor below.</p>
  </header>
  <div class="cards">
    <a class="card" href="ov2640.html">
      <div class="sensor">OV2640</div>
      <div class="desc">2MP &middot; Most common</div>
    </a>
    <a class="card" href="ov3660.html">
      <div class="sensor">OV3660</div>
      <div class="desc">3MP &middot; High quality</div>
    </a>
    <a class="card" href="ov5640.html">
      <div class="sensor">OV5640</div>
      <div class="desc">5MP &middot; Auto-focus</div>
    </a>
  </div>
  <footer>
    <a href="${REPO_URL}" target="_blank" rel="noopener">inha-fc/inhaino-esp32cam</a>
    &nbsp;&middot;&nbsp; Controls are simulated
  </footer>
</body>
</html>
HTML

echo "Landing page → $OUT/index.html"
