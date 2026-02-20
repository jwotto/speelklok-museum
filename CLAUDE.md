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

### Auto Power On (Venoen H6)
PC automatisch opstarten na stroomuitval — belangrijk voor museuminstallatie.

**BIOS heeft deze optie NIET** bij dit model. Moet via hardware jumper:

1. Open de behuizing (schroefjes onderkant)
2. Zoek **PWRON1** jumper op het moederbord (3 pinnetjes met jumpercap)
3. **Standaard**: jumpercap op pin 1-2 (auto power on UIT)
4. **Verplaats** jumpercap naar **pin 2-3** (auto power on AAN)

**Let op**: de GPIO pins aan de voorkant (SW0-SW9) zijn NIET de PWRON1 jumper — die zijn voor externe knoppen.

Officiële instructies: https://www.venoen.com/H6-How-to-set-Auto-Power-On-External-switch-button-extension.html

## Ubuntu PC Setup (voor nieuwe zuilen)

Stap-voor-stap guide om een verse Ubuntu PC in te richten voor remote streaming.

### 1. Ubuntu installeren
- Installeer Ubuntu 24.04 LTS
- Gebruiker: `wotto`, wachtwoord: naar keuze

### 2. Tailscale (remote toegang via VPN)
```bash
sudo apt update && sudo apt install -y curl
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
Volg de link om in te loggen op je Tailscale account. Check IP met `tailscale ip -4`.

### 3. SSH server
```bash
sudo apt install -y openssh-server
```

### 4. SSH key kopiëren (vanaf Windows PC)
In PowerShell op je laptop:
```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh wotto@<TAILSCALE_IP> "mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
```

### 5. Remote Desktop (GNOME RDP)
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
```

**Belangrijk: GNOME Keyring wachtwoord leeg maken** (anders werkt RDP niet na reboot met auto-login):
1. Open `seahorse` (Wachtwoorden en Sleutels)
2. Rechtermuisklik op **Default** keyring (met slotje) → Change Password
3. Oud wachtwoord: je login-wachtwoord
4. Nieuw wachtwoord: **leeg laten**
5. Bevestig (negeer waarschuwing)

Verbinden vanaf Windows: `mstsc` → `<TAILSCALE_IP>` → user: wotto, wachtwoord: wotto.
Toont portrait-scherm correct gedraaid.

### 6. Auto-login (zonder wachtwoord op scherm)
```bash
sudo mkdir -p /etc/gdm3 && sudo tee /etc/gdm3/custom.conf > /dev/null << 'EOF'
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=wotto
EOF
```

### 7. GRUB direct boot (geen OS-keuzemenu)
```bash
echo 'GRUB_DISABLE_OS_PROBER=true' | sudo tee -a /etc/default/grub
sudo update-grub
```

### 8. Boot optimalisatie (38s → 24s)
Splash screen uitzetten (bespaart ~20s):
```bash
sudo sed -i 's/quiet splash/quiet nosplash/g' /etc/default/grub
sudo update-grub
sudo systemctl disable plymouth-quit-wait.service
```

### 9. Scherm altijd aan (geen screensaver/lock/slaapstand)
```bash
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
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

### 11. Reboot en test
```bash
sudo reboot
```
Verbind daarna via Windows Remote Desktop Connection (mstsc) op het Tailscale IP.

### Tips
- **Remote Desktop**: `mstsc` op Windows → Tailscale IP → user/wachtwoord. Toont portrait correct.
- **Tailscale altijd aan (Android)**: Instellingen → Verbindingen → Meer verbindingsinstellingen → VPN → tandwiel naast Tailscale → "Altijd actieve VPN" aan
- **SSH**: `ssh wotto@<TAILSCALE_IP>` voor terminal-toegang
