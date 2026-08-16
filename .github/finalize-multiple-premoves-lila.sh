#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path

path = Path('ui/round/src/ctrl.ts')
text = path.read_text()
old = """  private readonly onUserMove = (orig: Key, dest: Key, meta: MoveMetadata) => {
    if (!this.keyboardMove?.usedSan && !this.opts.noab) ab.move(this, meta, pubsub.emit);
    if (!this.startPromotion(orig, dest, meta)) this.sendMove(orig, dest, undefined, meta);
  };
"""
new = """  private readonly onUserMove = (orig: Key, dest: Key, meta: MoveMetadata) => {
    if (!this.keyboardMove?.usedSan && !this.opts.noab) ab.move(this, meta, pubsub.emit);
    if (this.startPromotion(orig, dest, meta)) {
      // Promotion choice lives in Lila rather than Chessground, so a queued tail
      // can no longer be treated as a safe continuation of the speculative chain.
      if (meta.premove) this.chessground.cancelPremove();
    } else this.sendMove(orig, dest, undefined, meta);
  };
"""
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('expected onUserMove block not found')
path.write_text(text)

path = Path('modules/pref/src/main/PrefSingleChange.scala')
text = path.read_text()
old = """    changing(_.premove): v =>
      _.copy(premove = v == 1),
"""
new = """    changing(_.premove): v =>
      _.copy(
        premove = v != Pref.PremoveMode.DISABLED,
        multiplePremove = v == Pref.PremoveMode.MULTIPLE
      ),
"""
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('expected single-change premove block not found')
path.write_text(text)
PY

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add ui/round/src/ctrl.ts modules/pref/src/main/PrefSingleChange.scala
if ! git diff --cached --quiet; then
  git commit -m 'Handle multiple premoves in single-setting updates'
  git push
fi
