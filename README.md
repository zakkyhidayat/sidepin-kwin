# SidePin — KWin Script

Pin any window as a floating side panel on KDE Plasma 6.

When pinned, a window docks to the **right edge** of the screen: always-on-top, visible on all desktops, and auto-hidden when you're not using it. Hover the edge to peek it out. Think of it like **SideHover** or **Rectangle Pro's Stash** on macOS — but for KDE Wayland.

> **Heads up:** This project was built with vibecoding (AI-assisted development). The code works but may not be perfectly idiomatic. **Forks and contributions are very welcome** — feel free to clean it up, extend it, or adapt it for your workflow.

---

## Features

- Pin any normal window to the right screen edge
- Auto-hide (stash) when focus moves away — hover edge to reveal
- Smooth slide animation in/out
- Restores pre-pin size and centers the window when unpinned
- Drag the pinned panel to unpin and restore original size
- Two assignable shortcuts: **Pin** and **Stash**
- Configurable: dock strip size and panel height percentage

---

## Requirements

- KDE Plasma 6
- KWin 6.6 or later (Wayland or X11)

---

## Installation

### Clone and install

```bash
git clone https://github.com/zakkyhidayat/sidepin-kwin.git
cd sidepin-kwin
kpackagetool6 --type=KWin/Script --install kwin-script/
```

To update after pulling changes:

```bash
git pull
kpackagetool6 --type=KWin/Script --upgrade kwin-script/
```

### Enable the script

1. Open **System Settings → Window Management → KWin Scripts**
2. Find **SidePin** in the list and check the box
3. Click **Apply**

> **Important:** After installing or upgrading, KWin caches the compiled script in memory. The new version fully takes effect only after a **logout and login**.

---

## Setup

### Assign keyboard shortcuts

Open **System Settings → Keyboard → Shortcuts** and search for **SidePin**.

Both shortcuts come with a default — you can change them anytime.

| Action | Default shortcut | What it does |
|---|---|---|
| `SidePin: Pin` | `Ctrl+Meta+S` | Pin / unpin the active window to the right edge |
| `SidePin: Stash` | `Meta+S` | Toggle hide / show the pinned panel |

### Configure panel size

Open **System Settings → Window Management → KWin Scripts**, click the **⚙** (settings) button next to SidePin.

| Setting | Default | Description |
|---|---|---|
| Dock size | 8 px | Width of the peek strip visible when panel is stashed |
| Window height | 80 % | Height of the pinned panel relative to your work area |

Click **Apply** — no restart needed for size changes.

---

## Usage

1. Focus the window you want to pin
2. Press your **Pin** shortcut → window snaps to the right edge, 40% wide
3. Click another window → panel auto-hides to a thin strip at the edge
4. Move cursor to the right edge (or the strip) → panel slides out
5. Press **Stash** shortcut to manually hide/show the panel
6. Press **Pin** again (or drag the panel) → unpins and restores original window size, centered on screen

---

## Uninstall

```bash
kpackagetool6 --type=KWin/Script --remove sidepin
```

Then uncheck it in **System Settings → KWin Scripts** if it still appears.

---

## File structure

```
sidepin-kwin/
├── README.md
└── kwin-script/
    ├── metadata.json
    └── contents/
        ├── config/
        │   └── main.xml          # KConfigXT schema (enables ⚙ settings button)
        └── ui/
            ├── main.qml          # Main script logic (QML + JS)
            └── config.ui         # Settings UI
```

---

## Known limitations

- Panel always pins to the **right edge only** (left-side support was removed to simplify the code)
- Titlebar buttons cannot be hidden (not exposed in KWin scripting API)
- Resize cursor still appears at panel edges while pinned (KWin limitation)

---

## License

GPL-3.0
