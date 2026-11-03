#!/usr/bin/env python3
"""Inject minimal iPhone-visible diagnostics into the Godot HTML export."""
from pathlib import Path

p = Path("build/web/index.html")
html = p.read_text(encoding="utf-8")
script = r"""
<script>
(function () {
  const box = document.createElement('div');
  box.id = 'ns-diagnostic';
  box.style.cssText = 'position:fixed;z-index:2147483647;left:12px;right:12px;bottom:12px;padding:12px 15px;border-radius:10px;background:#321e2be8;color:#fff;font:14px/1.5 -apple-system,Arial,sans-serif;display:none;white-space:pre-wrap;max-height:45vh;overflow:auto';
  const show = (msg) => { box.style.display='block'; box.textContent='NACHTSIEGEL · Startdiagnose\n'+msg; };
  document.addEventListener('DOMContentLoaded', () => document.body.appendChild(box));
  window.addEventListener('error', e => show('JavaScript-Fehler: '+(e.message || 'Unbekannt')));
  window.addEventListener('unhandledrejection', e => show('Startfehler: '+String(e.reason)));
  setTimeout(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas) show('Kein Godot-Canvas gefunden.');
    else if (canvas.width === 0 || canvas.height === 0) show('Godot-Canvas ohne Größe.');

  }, 10000);
})();
</script>
"""
if "</head>" not in html:
    raise SystemExit("Cannot inject diagnostics: </head> missing")
p.write_text(html.replace("</head>", script + "\n</head>", 1), encoding="utf-8")
