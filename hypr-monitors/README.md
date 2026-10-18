# Hyprland Monitor Manager (`rigelyon/hypr-monitors`)

Aesthetic, native visual display manager plugin for [Noctalia](https://github.com/noctalia-dev/noctalia) on the Hyprland Wayland compositor.

![Thumbnail](thumbnail.webp)

## Features
- **Proportional Visual Canvas**: Drag and visually inspect active screens scaled to their real aspect ratios in a clean, modern interface.
- **Gapless Snap Alignment**: Single-click alignment tools (*Snap Left*, *Snap Right*, *Above*, *Below*, *Align Tops/Bottoms*) that calculate exact virtual offsets to prevent mouse cursor traps and subpixel seams.
- **Instant Display Presets**: Quickly toggle between *Extend*, *Duplicate/Mirror*, *Single Screen (Laptop Only)*, and *External Screen Only*.
- **Per-Monitor Inspector**: Granular control of detected hardware resolutions, refresh rates, fractional scaling (1.0x to 2.0x), and 4-way orientation (0°, 90°, 180°, 270°).
- **15-Second Safety Revert Timer**: Live apply changes instantly with automatic fallback if unconfirmed, completely protecting you against black screens or unsupported display timings.
- **Persistent Config Generation**: One-click writing to `~/.config/hypr/monitors.conf` with automatic `.bak` backups and detection of whether the file is properly sourced in `hyprland.conf`.
- **Display Profiles & Auto-Switching**: Automatically activates matching named display profiles ("Office Dual", "Presentation Mirror", "Mobile Laptop") upon plugging or unplugging external monitors.
- **Dual-Action Status Bar Widget**: Status bar icon with active screen counter and rich summary tooltips; left-click offers quick presets, right-click opens the full manager panel.

## Installation & Setup
1. Enable the plugin in your Noctalia settings or `plugins` configuration.
2. Ensure your `~/.config/hypr/hyprland.conf` includes the generated monitors configuration:
```hyprlang
source = ~/.config/hypr/monitors.conf
```
3. Open the plugin via the status bar widget or with the IPC command:
```bash
noctalia-shell ipc "panel:toggle rigelyon/hypr-monitors:panel"
```

## License
MIT © rigelyon
