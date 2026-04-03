# Speelklok Museum

Interactieve installatie voor het Speelklok Museum.

## Project Structuur

Object-georiënteerd: elk onderdeel is een zelfstandige class.

### Mappenstructuur
```
scenes/
  main.gd + main.tscn                      ← flow controller (alleen fase-switching)
  fase_<naam>/
	fase_<naam>.gd + .tscn                  ← fase-scene (self-contained, eigen achtergrond)
	onderdelen/                             ← sub-scenes en scripts van deze fase
	  ...
```

### Fase-architectuur
- **Main** is alleen een flow controller: schakelt tussen fases, ESC, touch emulatie
- **Elke fase** is een zelfstandige scene met:
  - Eigen `Background` (TextureRect) als eerste child
  - Eigen `_resize_background()` voor viewport-vulling (editor + runtime)
  - `signal phase_completed` om Main te signaleren
  - `@tool` zodat de scene volledig bewerkbaar is in de editor
- Fase-bestanden hebben `fase_` prefix, sub-scenes zitten in `onderdelen/`
- Toets 1-9 wisselt tussen fases (development only)

## Godot Code Richtlijnen

### Scene Opbouw
- Elke scene is **self-contained** - geen externe dependencies
- Siblings mogen **nooit** naar elkaar verwijzen - parent medieert
- Nooit `get_parent()` in child scenes - gebruik signals of dependency injection
- Fase scene tree:
  ```
  FaseNaam (Node2D)
	Background (TextureRect)    -- eigen achtergrond
	Content (Node2D)            -- fase content
	UILayer (CanvasLayer)       -- UI boven alles
  ```

### Scripts
- `@tool` bovenaan elke script zodat nodes zichtbaar zijn in de editor
- `Engine.is_editor_hint()` guard voor runtime-only code
- `@export` met `@export_group()` voor alle instelbare waardes
- `@export` setters voor live editor preview updates
- `_get_configuration_warnings()` voor ontbrekende dependencies
- `##` voor doc comments (NIET `"""..."""` - dat is Python)

### Communicatie
- Signals voor losse koppeling: child emit, parent connect
- Signal namen in verleden tijd: `sticker_selected`, `health_changed`
- Dependency injection via `@export` voor node references

### Scene Files (.tscn)
- Maak nodes in .tscn bestanden, niet programmatisch
- Gebruik `ExtResource("id")` (NIET `preload()`)
- Typed arrays: `Array[Type]([...])`

### Input
- `_gui_input()` + `accept_event()` voor Control-based input
- `_input()` voor scene-brede events (ESC, touch tracking)
- `mouse_filter`: STOP vangt input, IGNORE laat door

## Editor Workflow

- Gebruik `@tool` scripts zodat nodes zichtbaar zijn in de Godot editor
- Maak scene nodes aan in .tscn bestanden (niet programmatisch) zodat ze aanpasbaar zijn
- Gebruik `@export` variabelen voor alle instelbare waardes
- Zorg dat alles modulair en visueel bewerkbaar is in de editor

## Bouwfasen

1. **fase_body_builder** - Lichaamsvorm (5 vragen bepalen contour) *placeholder*
2. **fase_sticker_placer** - Muziekinstrumenten (10 items plaatsen) *werkend*
3. Muziekdrager (1 uit 5) *nog te maken*
4. Techniek (automatisch) *nog te maken*
5. Aandrijving (1 uit 5) *nog te maken*
6. Slot (8 sec muziek + transport) *nog te maken*

## Hardware

- **PC**: Venoen H6 10310 (mini PC)
- 2 zuilen: touchscreen + geluid
- 1 wandscherm: toont collectie
- Staand formaat

## Ubuntu PC Setup (voor nieuwe zuilen)

Stap-voor-stap guide om een verse Ubuntu PC in te richten voor remote streaming.

### 1. Ubuntu installeren
- Installeer Ubuntu 24.04 LTS
- Gebruiker: `wotto`, wachtwoord: naar keuze

### 1b. SSH server (nodig voor alle volgende stappen)
```bash
sudo apt install -y openssh-server
```

### 2. Tailscale (remote toegang via VPN)
```bash
sudo apt update && sudo apt install -y curl
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
Volg de link om in te loggen op je Tailscale account. Check IP met `tailscale ip -4`.

### 3. SSH key kopiëren (vanaf Windows PC)
In PowerShell op je laptop:
```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh wotto@<TAILSCALE_IP> "mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
```

### 4. Remote Desktop (GNOME RDP)
Ingebouwde GNOME Remote Desktop — verbind via Windows Remote Desktop Connection (mstsc).

Op de Ubuntu PC via terminal:
```bash
# TLS certificaat genereren
mkdir -p ~/.local/share/gnome-remote-desktop
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
  -subj '/CN=wotto-pc1' \
  -keyout ~/.local/share/gnome-remote-desktop/rdp-tls.key \
  -out ~/.local/share/gnome-remote-desktop/rdp-tls.crt

# RDP configureren
grdctl rdp set-tls-cert ~/.local/share/gnome-remote-desktop/rdp-tls.crt
grdctl rdp set-tls-key ~/.local/share/gnome-remote-desktop/rdp-tls.key
grdctl rdp set-credentials wotto wotto
grdctl rdp disable-view-only
grdctl rdp enable

# RDP service activeren (nodig, staat standaard niet aan!)
systemctl --user enable gnome-remote-desktop
systemctl --user start gnome-remote-desktop
```

**Belangrijk: GNOME Keyring wachtwoord leeg maken** (anders werkt RDP niet na reboot met auto-login):
1. Open `seahorse` (Wachtwoorden en Sleutels)
2. Rechtermuisklik op **Default** keyring (met slotje) → Change Password
3. Oud wachtwoord: je login-wachtwoord
4. Nieuw wachtwoord: **leeg laten**
5. Bevestig (negeer waarschuwing)

Verbinden vanaf Windows: `mstsc` → `<TAILSCALE_IP>` → user: wotto, wachtwoord: wotto.
Toont portrait-scherm correct gedraaid.

### 5. Auto-login (zonder wachtwoord op scherm)
```bash
sudo mkdir -p /etc/gdm3 && sudo tee /etc/gdm3/custom.conf > /dev/null << 'EOF'
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=wotto
EOF
```

### 6. GRUB direct boot (geen OS-keuzemenu)
```bash
echo 'GRUB_DISABLE_OS_PROBER=true' | sudo tee -a /etc/default/grub
sudo update-grub
```

### 7. Boot optimalisatie (38s → 24s)
Splash screen uitzetten (bespaart ~20s):
```bash
sudo sed -i 's/quiet splash/quiet nosplash/g' /etc/default/grub
sudo update-grub
sudo systemctl disable plymouth-quit-wait.service
```

### 8. Scherm altijd aan (geen screensaver/lock/slaapstand)
```bash
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
```

### 9. Godot + Git installeren

**Godot** installeren via Ubuntu App Center (zoek "Godot") — wget vanaf GitHub werkt niet betrouwbaar.

**Git** staat niet standaard op Ubuntu, installeer via terminal:
```bash
sudo apt install -y git
```

Git repo clonen naar Desktop:
```bash
cd ~/Desktop
git clone https://github.com/jwotto/speelklok-museum.git
```

Laatste versie pullen (kan via SSH vanaf Windows):
```bash
ssh wotto@<TAILSCALE_IP> "cd ~/Desktop/speelklok-museum && git pull"
```

### 10. Portrait modus (touchscreen rotatie)
Display roteren via Settings → Displays → Orientation → Portrait.

Touchscreen input mee laten draaien via udev rule:
```bash
# Zoek vendor/model ID van je touchscreen
cat /proc/bus/input/devices | grep -A 4 -i touch

# Maak udev rule aan (pas vendor/model ID aan voor jouw device)
sudo tee /etc/udev/rules.d/99-touchscreen-rotation.rules << 'EOF'
ACTION!="remove", KERNEL=="event[0-9]*", \
ENV{ID_VENDOR_ID}=="2575", \
ENV{ID_MODEL_ID}=="7317", \
ENV{LIBINPUT_CALIBRATION_MATRIX}="0 -1 1 1 0 0"
EOF
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Calibration matrices per oriëntatie:
- **Landscape (normaal)**: `1 0 0 0 1 0`
- **Portrait 90° CW**: `0 -1 1 1 0 0`
- **Landscape 180°**: `-1 0 1 0 -1 1`
- **Portrait 90° CCW**: `0 1 0 -1 0 1`

### 11. Kiosk-modus (complete setup per zuil-PC)

Alle stappen om een zuil-PC in te richten voor kiosk gebruik. SSH naar de PC en voer blok voor blok uit.

**Let op**: fish shell ondersteunt geen `<< 'EOF'` heredocs — gebruik altijd `printf`.

#### Blok 1 — Git bijwerken
```bash
cd ~/Desktop/speelklok-museum
git fetch origin
git checkout master
git reset --hard origin/master
```

#### Blok 2 — .NET SDK (voorkomt Godot error)
```bash
sudo apt install -y dotnet-sdk-8.0
```

#### Blok 3 — GNOME settings + dock + window manager
```bash
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

# Hot corners, workspaces, notifications uit
gsettings set org.gnome.desktop.interface enable-hot-corners false
gsettings set org.gnome.mutter overlay-key ""
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 1
gsettings set org.gnome.desktop.notifications show-banners false

# Dock: autohide, links, verborgen in fullscreen
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
gsettings set org.gnome.shell.extensions.dash-to-dock autohide true
gsettings set org.gnome.shell.extensions.dash-to-dock autohide-in-fullscreen true
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT'
gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true

# Blokkeer drag-to-minimize/unmaximize (voorkomt swipe-omlaag minimize)
dconf write /org/gnome/mutter/edge-tiling false
dconf write /org/gnome/mutter/draggable-border-width 0
gsettings set org.gnome.desktop.wm.preferences action-double-click-titlebar 'none'
gsettings set org.gnome.desktop.wm.preferences action-middle-click-titlebar 'none'
gsettings set org.gnome.desktop.wm.preferences action-right-click-titlebar 'none'
gsettings set org.gnome.desktop.wm.keybindings minimize '[]'
gsettings set org.gnome.desktop.wm.keybindings unmaximize '[]'
```

#### Blok 4 — Extensies aanmaken

**Disable Gestures** (blokkeert swipes, verbergt top panel):
```bash
mkdir -p ~/.local/share/gnome-shell/extensions/disable-gestures@kiosk
printf '{"uuid":"disable-gestures@kiosk","name":"Disable Gestures","description":"Disables touchscreen/touchpad gestures for kiosk mode","shell-version":["46"]}\n' > ~/.local/share/gnome-shell/extensions/disable-gestures@kiosk/metadata.json
printf 'import {Extension} from "resource:///org/gnome/shell/extensions/extension.js";\nimport * as Main from "resource:///org/gnome/shell/ui/main.js";\n\nexport default class DisableGesturesExtension extends Extension {\n    enable() {\n        let st = Main.overview._swipeTracker;\n        if (st) { this._origSwipe = st.enabled; st.enabled = false; }\n        if (Main.panel) {\n            Main.panel.reactive = false;\n            Main.panel.track_hover = false;\n            Main.panel.hide();\n        }\n        if (Main.messageTray) {\n            if (Main.messageTray._edgeDragAction) Main.messageTray._edgeDragAction.enabled = false;\n        }\n    }\n    disable() {\n        let st = Main.overview._swipeTracker;\n        if (st && this._origSwipe !== undefined) st.enabled = this._origSwipe;\n        if (Main.panel) {\n            Main.panel.reactive = true;\n            Main.panel.track_hover = true;\n            Main.panel.show();\n        }\n        if (Main.messageTray && Main.messageTray._edgeDragAction) Main.messageTray._edgeDragAction.enabled = true;\n    }\n}\n' > ~/.local/share/gnome-shell/extensions/disable-gestures@kiosk/extension.js
```

**Block Caribou** (blokkeert on-screen keyboard):
```bash
mkdir -p ~/.local/share/gnome-shell/extensions/block-caribou@nicong.nfet.al
printf '{"uuid":"block-caribou@nicong.nfet.al","name":"Block Caribou","description":"Block caribou keyboard","shell-version":["46"]}\n' > ~/.local/share/gnome-shell/extensions/block-caribou@nicong.nfet.al/metadata.json
printf 'import {Extension} from "resource:///org/gnome/shell/extensions/extension.js";\nimport * as Keyboard from "resource:///org/gnome/shell/ui/keyboard.js";\n\nlet _origLastDeviceIsTouchscreen;\n\nexport default class BlockCaribouExtension extends Extension {\n    enable() {\n        _origLastDeviceIsTouchscreen = Keyboard.KeyboardManager.prototype._lastDeviceIsTouchscreen;\n        Keyboard.KeyboardManager.prototype._lastDeviceIsTouchscreen = function() { return false; };\n    }\n    disable() {\n        Keyboard.KeyboardManager.prototype._lastDeviceIsTouchscreen = _origLastDeviceIsTouchscreen;\n    }\n}\n' > ~/.local/share/gnome-shell/extensions/block-caribou@nicong.nfet.al/extension.js
```

#### Blok 5 — Eerste reboot
```bash
sudo reboot
```

#### Blok 6 — Na reboot: extensies activeren + autostart
```bash
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
gnome-extensions enable disable-gestures@kiosk
gnome-extensions enable block-caribou@nicong.nfet.al

mkdir -p ~/.config/autostart
printf '[Desktop Entry]\nType=Application\nName=Speelklok\nExec=/snap/godot-4/21/godot-4 --fullscreen --path /home/wotto/Desktop/speelklok-museum\nX-GNOME-Autostart-enabled=true\n' > ~/.config/autostart/speelklok.desktop
```

**Let op**: pas het Godot pad aan als de snap versie anders is (`ls /snap/godot-4/`).

#### Blok 7 — Laatste reboot
```bash
sudo reboot
```

Na deze reboot: Godot start fullscreen, geen keyboard, geen swipe gestures, geen top panel. Dock verschijnt alleen als je de app afsluit.

### 12. Reboot en test
```bash
sudo reboot
```
Verbind daarna via Windows Remote Desktop Connection (mstsc) op het Tailscale IP.

### 13. Fish shell + btop (terminal tools)

**Fish** — interactieve shell met autosuggestions en syntax highlighting:
```bash
sudo apt install -y fish
chsh -s /usr/bin/fish    # maak het de default shell
```
Bij volgende SSH-sessie start Fish automatisch. Terug naar bash: `chsh -s /bin/bash`.

**btop** — systeemmonitor (CPU, RAM, disk, netwerk + GPU):
```bash
sudo apt install -y btop rocm-smi
```
`rocm-smi` is nodig voor AMD GPU-monitoring (780M). Zonder rocm-smi toont btop geen GPU-data.

Start met `btop`, GPU-stats staan onderaan de CPU-box (gebruik %, VRAM, temperatuur).

**radeontop** — gedetailleerde AMD GPU-monitor:
```bash
sudo apt install -y radeontop
```
Start met `sudo radeontop`. Toont UNKNOWN_CHIP voor de 780M maar data klopt wel.

### Troubleshooting
- **RDP verbinding mislukt**: `gnome-remote-desktop` service staat standaard niet aan. Fix: `systemctl --user enable gnome-remote-desktop && systemctl --user start gnome-remote-desktop`
- **sudo via SSH werkt niet**: Commando's met `sudo` werken niet via niet-interactieve SSH (`ssh user@ip "sudo ..."`) — je moet eerst interactief inloggen (`ssh user@ip`) en dan sudo uitvoeren
- **Git niet gevonden**: Staat niet standaard op Ubuntu, installeer met `sudo apt install -y git`
- **Godot wget 404**: GitHub release URL's veranderen per versie — installeer Godot via Ubuntu App Center
- **Keyring popup bij RDP setup**: Bij `grdctl rdp set-credentials` verschijnt er een keyring-wachtwoord prompt op de PC — laat het wachtwoord leeg

### Tips
- **Remote Desktop**: `mstsc` op Windows → Tailscale IP → user/wachtwoord. Toont portrait correct.
- **Tailscale altijd aan (Android)**: Instellingen → Verbindingen → Meer verbindingsinstellingen → VPN → tandwiel naast Tailscale → "Altijd actieve VPN" aan
- **SSH**: `ssh wotto@<TAILSCALE_IP>` voor terminal-toegang
