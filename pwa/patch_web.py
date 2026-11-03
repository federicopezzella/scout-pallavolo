"""Ritocchi alla webapp generata da Flutter.

Uso:
  python3 pwa/patch_web.py pre            # prima della build: nome, colori, registrazione service worker
  python3 pwa/patch_web.py post VERSIONE  # dopo la build: service worker con l'elenco dei file
"""
import json
import os
import sys

NAME = "Scout Volley"
BG = "#10141A"


def pre():
    m_path = "web/manifest.json"
    with open(m_path) as f:
        m = json.load(f)
    m.update({
        "name": NAME,
        "short_name": NAME,
        "description": "Scout di pallavolo",
        "background_color": BG,
        "theme_color": BG,
        "display": "standalone",
        "orientation": "any",
    })
    with open(m_path, "w") as f:
        json.dump(m, f, indent=2)

    i_path = "web/index.html"
    with open(i_path) as f:
        html = f.read()
    html = html.replace("<title>scout_pallavolo</title>", f"<title>{NAME}</title>")
    html = html.replace('content="scout_pallavolo"', f'content="{NAME}"')
    extra = """
  <meta name="theme-color" content="#10141A">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
"""
    if 'name="theme-color"' not in html:
        html = html.replace("</head>", extra + "</head>", 1)
    script = """
  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', function () {
        navigator.serviceWorker.register('flutter_service_worker.js');
      });
    }
    if (navigator.storage && navigator.storage.persist) {
      navigator.storage.persist();
    }
  </script>
"""
    if "navigator.storage.persist" not in html:
        html = html.replace("</body>", script + "</body>", 1)
    with open(i_path, "w") as f:
        f.write(html)


def post(version):
    root = "build/web"
    files = ["./"]
    for d, _, names in os.walk(root):
        for n in names:
            rel = os.path.relpath(os.path.join(d, n), root).replace(os.sep, "/")
            if rel in ("flutter_service_worker.js",) or rel.endswith(".map"):
                continue
            files.append(rel)
    with open("pwa/sw.js") as f:
        sw = f.read()
    sw = sw.replace("__VERSION__", version).replace("__PRECACHE__", json.dumps(sorted(files)))
    with open(os.path.join(root, "flutter_service_worker.js"), "w") as f:
        f.write(sw)
    print(f"Service worker con {len(files)} file in cache")


if __name__ == "__main__":
    if sys.argv[1] == "pre":
        pre()
    else:
        post(sys.argv[2])
