# SidePin — TODO

KWin Script for stashing a window to the right screen edge.
Target: Plasma 6.6 / KWin 6.6 (Wayland).

**Current state: v3.0.0 (`kwin-script/metadata.json`).** The v1.0 build was verified on Wayland; v3.0.0 has not been noted as verified in a live session.
Not yet tested against Plasma 6.7.x or 6.8 — needs a live session test.

---

## Next session

- [ ] Create GitHub Release for `v1.0` (files already in repo — just tag and publish)

---

## Backlog

- [x] Optional config: toggle hover-to-show on/off
- [x] Optional config: configurable pinned width ratio (up to 50% of screen width)
- [ ] Re-track pinned windows after script reload (currently lost on reload; user must re-pin)
- [ ] Publish to KDE Store — waiting for final MVP

---

## Architecture notes

**Right-only layout**
- Right edge only (left-side support intentionally removed)
- State: `pinned: Map` (at most 1 entry), `isPinned: bool`, `pinnedKey: string`
- `pinGeometry(entry)` always right-side only: configurable width (10–50%), configured height, flush-right, vertically centered
- Arrow functions inside QML methods must use `root.` prefix — Item context is lost in closures
- `entry.applying` guards geometry writes to prevent resize-snap re-entrancy
- `entry.sticky = true` prevents hover-out auto-hide (set by Stash shortcut show action)
- `entry.hoverArmed = false` prevents hover-in after manual stash (reset when cursor leaves edge zone)

**Install/upgrade:**
```bash
kpackagetool6 --type=KWin/Script --upgrade kwin-script/
gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure
```

**KWin QML cache:** disk cache (`.mjsc` in `~/.cache/kwin/qmlcache/`) can be cleared,
but in-memory compiled component persists across reloads within the same KWin process.
Only logout+login fully reloads the script from disk.

**History:** the left/right-side version (v2.4.1) is not kept in this repo; use git history (`git log`) to find it.
