#!/usr/bin/env bash
# SessionStart hook: docs/STATE.md'yi Claude'un context'ine ekler (stdout context'e girer).
# Dosya yoksa sessizce cikar. 60 satirdan uzunsa kirpar ve uyari ekler (butce 40 satir).
STATE="${CLAUDE_PROJECT_DIR:-.}/docs/STATE.md"
[ -f "$STATE" ] || exit 0
LINES=$(wc -l < "$STATE")
echo "=== docs/STATE.md (devir teslim notu, otomatik eklendi) ==="
head -n 60 "$STATE"
if [ "$LINES" -gt 60 ]; then
  echo "(STATE.md $LINES satir, butce 40. doc-hygiene onerilir.)"
fi
echo "=== Once bunu kullaniciya 3 satirda ozetle ve onay al. ==="
