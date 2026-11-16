#!/usr/bin/env bash
# Same scripted path for the before and after recordings.
# Usage: sequence.sh <out.webm> <width> <height>   (server: python -m http.server 8137 --directory dist)
set -u
OUT=$1; W=${2:-1440}; H=${3:-900}; B=http://127.0.0.1:8137
export AGENT_BROWSER_SESSION=msmotion-rec
ab(){ agent-browser "$@" >/dev/null 2>&1; }
ab set viewport "$W" "$H"
ab open "$B/index.html"; ab wait 4500
ab eval "localStorage.setItem('martha-parity-newsletter-dismissed','true')"
agent-browser record start "$OUT" --cursor ${FPS:+--fps $FPS} || exit 1
ab wait 1500
ab scroll down 700; ab wait 900; ab scroll down 700; ab wait 900
ab hover ".product-image"; ab wait 1200
ab open "$B/catalogo.html"; ab wait 1800
ab hover ".product-image"; ab wait 1000
ab eval "[...document.querySelectorAll('button')].find(b=>/^Filtros/.test(b.textContent.trim()))?.click()"; ab wait 1200
ab press Escape; ab wait 900
ab click "a[href='/producto-rosa.html']"; ab wait 2200
ab click "input[name=variant]:not(:disabled)"; ab wait 500
ab click "button[data-add]"; ab wait 1800
ab press Escape; ab wait 800
ab click "a.bag-link"; ab wait 2000
ab scroll down 400; ab wait 900
agent-browser record stop
