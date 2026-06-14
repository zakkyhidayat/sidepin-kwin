// SidePin — Stash any window at the right screen edge (Plasma 6.6 / KWin 6.6 Wayland)
// Declarative QML KWin script.
//
// Shortcuts (assign in System Settings → Keyboard Shortcuts):
//   "SidePin: Pin"   → pin/unpin the active window
//   "SidePin: Stash" → stash/unstash (hide/show) the pinned panel
//
// Hover: push cursor to right edge or hover the peek strip → panel slides out.
// Cursor leaves unfocused panel → slides back after a short grace period.

import QtQuick
import org.kde.kwin

Item {
    id: root

    Component.onCompleted:
        log("v3.0.0 loaded — dock=" + peekPx() + "px height=" + Math.round(pinHeightRatio() * 100) + "%")

    // ── Constants ─────────────────────────────────────────────────────────
    readonly property real pinWidthRatio:   0.40
    readonly property int  hoverGraceTicks: 3

    // ── Config (read per call so ⚙ Apply takes effect without script reload) ─
    function peekPx() {
        return Math.min(48, Math.max(8, KWin.readConfig("dockSize", 8)));
    }
    function pinHeightRatio() {
        return Math.min(100, Math.max(20, KWin.readConfig("heightPercent", 80))) / 100;
    }

    // ── State ─────────────────────────────────────────────────────────────
    property var    pinned:    new Map()  // key (String internalId) → entry; at most 1
    property bool   isPinned:  false      // reactive mirror of pinned.size > 0
    property string pinnedKey: ""         // key of the currently pinned window

    // ── Helpers ───────────────────────────────────────────────────────────
    function winKey(w)  { return String(w.internalId); }
    function log(msg)   { console.info("SIDEPIN: " + msg); }
    function workArea(w){ return Workspace.clientArea(KWin.PlacementArea, w); }

    function isPinnable(w) {
        return w && w.normalWindow && w.resizeable && !w.specialWindow;
    }

    function syncState() {
        isPinned  = pinned.size > 0;
        pinnedKey = isPinned ? [...pinned.keys()][0] : "";
    }

    function setGeo(entry, x, y, w, h) {
        entry.applying = true;
        entry.window.frameGeometry = { x: x, y: y, width: w, height: h };
        entry.applying = false;
    }

    // Right-side geometry: 40% wide × configHeight tall, flush-right, vertically centered.
    function pinGeometry(entry) {
        const area    = workArea(entry.window);
        const peek    = peekPx();
        const w       = Math.round(area.width  * pinWidthRatio);
        const h       = Math.round(area.height * pinHeightRatio());
        const y       = area.y + Math.round((area.height - h) / 2);
        const shownX  = area.x + area.width - w;
        const hiddenX = area.x + area.width - peek;
        return { w, h, y, shownX, hiddenX, x: entry.isHidden ? hiddenX : shownX };
    }

    // Snap to constrained geometry instantly (resize / output-change guard).
    function applyConstraints(entry) {
        const g   = pinGeometry(entry);
        const geo = entry.window.frameGeometry;
        entry.targetX = null;
        if (geo.x !== g.x || geo.y !== g.y || geo.width !== g.w || geo.height !== g.h)
            setGeo(entry, g.x, g.y, g.w, g.h);
    }

    // ── Slide animation ───────────────────────────────────────────────────
    function slideTo(entry, targetX) {
        const g = pinGeometry(entry);
        setGeo(entry, entry.window.frameGeometry.x, g.y, g.w, g.h);
        entry.targetX = targetX;
        animTimer.running = true;
    }

    Timer {
        id: animTimer
        interval: 16
        repeat: true
        onTriggered: {
            let active = false;
            for (const entry of root.pinned.values()) {
                if (entry.targetX == null) continue;
                const geo  = entry.window.frameGeometry;
                const diff = entry.targetX - geo.x;
                if (Math.abs(diff) <= 2) {
                    root.setGeo(entry, entry.targetX, geo.y, geo.width, geo.height);
                    entry.targetX = null;
                } else {
                    root.setGeo(entry, geo.x + Math.round(diff * 0.35), geo.y, geo.width, geo.height);
                    active = true;
                }
            }
            if (!active) animTimer.running = false;
        }
    }

    // ── Show / hide (stash to edge, peek strip stays visible) ────────────
    function showEntry(entry) {
        if (!entry.isHidden) return;
        entry.isHidden     = false;
        entry.outsideTicks = 0;
        entry.window.keepAbove = true;
        slideTo(entry, pinGeometry(entry).shownX);
        log("show: " + entry.window.caption);
    }

    function hideEntry(entry) {
        if (entry.isHidden) return;
        entry.isHidden = true;
        entry.sticky   = false;
        slideTo(entry, pinGeometry(entry).hiddenX);
        log("hide: " + entry.window.caption);
    }

    // ── Hover: cursor poll (runs only while something is pinned) ─────────
    Timer {
        id: pollTimer
        interval: 100
        repeat: true
        running: root.isPinned
        onTriggered: {
            const pos = Workspace.cursorPos;
            for (const entry of root.pinned.values()) {
                const g = root.pinGeometry(entry);
                if (entry.isHidden) {
                    const area = root.workArea(entry.window);
                    const zone = root.peekPx() * 2;
                    if (pos.x >= area.x + area.width - zone
                            && pos.y >= g.y && pos.y <= g.y + g.h) {
                        if (entry.hoverArmed) root.showEntry(entry);
                    } else {
                        entry.hoverArmed = true;
                    }
                } else {
                    const geo    = entry.window.frameGeometry;
                    const margin = 24;
                    const inside = pos.x >= geo.x - margin && pos.x <= geo.x + geo.width  + margin
                                && pos.y >= geo.y - margin && pos.y <= geo.y + geo.height + margin;
                    const focused = Workspace.activeWindow
                        && root.winKey(Workspace.activeWindow) === entry.key;
                    if (entry.sticky || inside || focused) {
                        entry.outsideTicks = 0;
                    } else if (++entry.outsideTicks >= root.hoverGraceTicks) {
                        root.hideEntry(entry);
                    }
                }
            }
        }
    }

    // ── Hover: screen-edge event (complements the poll) ──────────────────
    ScreenEdgeHandler {
        edge: ScreenEdgeHandler.RightEdge
        enabled: root.isPinned
        onActivated: {
            const entry = root.pinned.get(root.pinnedKey);
            if (entry && entry.isHidden && entry.hoverArmed) root.showEntry(entry);
        }
    }

    // ── Auto-hide on window activation change ─────────────────────────────
    Connections {
        target: Workspace
        enabled: root.isPinned
        function onWindowActivated(win) {
            if (!win) { for (const e of root.pinned.values()) root.hideEntry(e); return; }
            const k = root.winKey(win);
            for (const entry of root.pinned.values()) {
                if (k === entry.key) root.showEntry(entry);
                else                 root.hideEntry(entry);
            }
        }
    }

    // Re-apply geometry when dock/height config changes (⚙ Apply).
    Connections {
        target: Workspace
        function onConfigChanged() {
            root.log("config changed — dock=" + root.peekPx()
                + "px height=" + Math.round(root.pinHeightRatio() * 100) + "%");
            for (const e of root.pinned.values()) root.applyConstraints(e);
        }
    }

    // ── Pin ───────────────────────────────────────────────────────────────
    function pin(win) {
        if (!isPinnable(win)) return;
        const key = winKey(win);

        // Same window already pinned → unpin
        if (pinned.has(key)) { unpin(win); return; }

        // Replace any existing pinned window
        if (pinnedKey) {
            const old = pinned.get(pinnedKey);
            if (old) unpin(old.window);
        }

        const entry = {
            window:       win,
            key:          key,
            applying:     false,
            isHidden:     false,
            targetX:      null,
            outsideTicks: 0,
            hoverArmed:   true,
            sticky:       false,
            saved: {
                keepAbove:     win.keepAbove,
                onAllDesktops: win.onAllDesktops,
                skipTaskbar:   win.skipTaskbar,
                geometry: {
                    x: win.frameGeometry.x,     y: win.frameGeometry.y,
                    width: win.frameGeometry.width, height: win.frameGeometry.height
                }
            },
            handlers: {}
        };

        if (win.fullScreen) win.fullScreen = false;
        if (win.maximizeMode !== undefined && win.maximizeMode !== 0 && win.setMaximize)
            win.setMaximize(false, false);

        win.keepAbove     = true;
        win.onAllDesktops = true;
        win.skipTaskbar   = true;
        win.minimized     = false;

        root.applyConstraints(entry);

        // Drag → unpin; restore pre-pin size at drag position
        entry.handlers.moveStarted = () => {
            if (win.move) {
                const sw = entry.saved.geometry.width;
                const sh = entry.saved.geometry.height;
                root.unpin(win, false);
                const geo = win.frameGeometry;
                win.frameGeometry = { x: geo.x, y: geo.y, width: sw, height: sh };
            }
        };
        win.interactiveMoveResizeStarted.connect(entry.handlers.moveStarted);

        // Resize → snap back to pinned size
        entry.handlers.resizeFinished = () => {
            if (!entry.applying) root.applyConstraints(entry);
        };
        win.interactiveMoveResizeFinished.connect(entry.handlers.resizeFinished);

        // Block minimize (stash instead)
        entry.handlers.minimized = () => { if (win.minimized) win.minimized = false; };
        win.minimizedChanged.connect(entry.handlers.minimized);

        // Block maximize
        if (win.maximizedChanged !== undefined) {
            entry.handlers.maximized = () => { if (!entry.applying) root.applyConstraints(entry); };
            win.maximizedChanged.connect(entry.handlers.maximized);
        }

        // Block fullscreen
        entry.handlers.fullScreen = () => {
            if (win.fullScreen) { win.fullScreen = false; root.applyConstraints(entry); }
        };
        win.fullScreenChanged.connect(entry.handlers.fullScreen);

        // Follow output / resolution changes
        entry.handlers.outputChanged = () => root.applyConstraints(entry);
        win.outputChanged.connect(entry.handlers.outputChanged);

        // Cleanup on close
        entry.handlers.closed = () => { root.pinned.delete(key); root.syncState(); };
        win.closed.connect(entry.handlers.closed);

        pinned.set(key, entry);
        syncState();
        log("pinned: " + win.caption);
    }

    // ── Unpin ─────────────────────────────────────────────────────────────
    // restoreGeo: true (default) → center at pre-pin size; false → leave geometry as-is
    function unpin(win, restoreGeo) {
        const key   = winKey(win);
        const entry = pinned.get(key);
        if (!entry) return;

        pinned.delete(key);
        syncState();

        try { win.interactiveMoveResizeStarted.disconnect(entry.handlers.moveStarted); }     catch(_){}
        try { win.interactiveMoveResizeFinished.disconnect(entry.handlers.resizeFinished); } catch(_){}
        try { win.minimizedChanged.disconnect(entry.handlers.minimized); }                   catch(_){}
        if (entry.handlers.maximized && win.maximizedChanged !== undefined)
            try { win.maximizedChanged.disconnect(entry.handlers.maximized); } catch(_){}
        try { win.fullScreenChanged.disconnect(entry.handlers.fullScreen); } catch(_){}
        try { win.outputChanged.disconnect(entry.handlers.outputChanged); }  catch(_){}
        try { win.closed.disconnect(entry.handlers.closed); }                catch(_){}

        win.keepAbove     = entry.saved.keepAbove;
        win.onAllDesktops = entry.saved.onAllDesktops;
        win.skipTaskbar   = entry.saved.skipTaskbar;

        if (restoreGeo !== false) {
            const area = workArea(win);
            const w    = entry.saved.geometry.width;
            const h    = entry.saved.geometry.height;
            win.frameGeometry = {
                x:      area.x + Math.round((area.width  - w) / 2),
                y:      area.y + Math.round((area.height - h) / 2),
                width:  w,
                height: h
            };
        }
        log("unpinned: " + win.caption);
    }

    // ── Shortcuts ─────────────────────────────────────────────────────────
    ShortcutHandler {
        name: "SidePin: Pin"
        text: "SidePin: Pin/unpin the active window"
        sequence: "Ctrl+Meta+S"
        onActivated: { const w = Workspace.activeWindow; if (w) root.pin(w); }
    }

    ShortcutHandler {
        name: "SidePin: Stash"
        text: "SidePin: Stash/unstash the pinned panel"
        sequence: "Meta+S"
        onActivated: {
            const entry = root.pinned.get(root.pinnedKey);
            if (!entry) return;
            if (entry.isHidden) {
                root.showEntry(entry);
                Workspace.activeWindow = entry.window;
                entry.sticky = true;
            } else {
                root.hideEntry(entry);
                entry.hoverArmed = false;
            }
        }
    }
}
