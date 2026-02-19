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

### 5. Sunshine (streaming server)
```bash
sudo apt install -y wget
wget https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine-ubuntu-24.04-amd64.deb
sudo dpkg -i sunshine-ubuntu-24.04-amd64.deb && sudo apt install -f -y
```

Credentials instellen (gebruikersnaam + wachtwoord voor web UI):
```bash
sunshine --creds wotto wotto
```

### 6. Sunshine autostart + PIN uitzetten
Service aanmaken:
```bash
sudo tee /etc/systemd/system/sunshine.service > /dev/null << 'EOF'
[Unit]
Description=Sunshine Game Streaming Server
After=graphical.target

[Service]
User=wotto
ExecStart=/usr/bin/sunshine
Restart=on-failure

[Install]
WantedBy=graphical.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable sunshine
```

Eerste keer pairen per apparaat: open Moonlight, voer de getoonde PIN in via de Sunshine web UI op `https://<TAILSCALE_IP>:47990` (login: wotto/wotto). Daarna onthoudt hij het apparaat permanent.

### 7. Auto-login (zonder wachtwoord op scherm)
```bash
sudo mkdir -p /etc/gdm3 && sudo tee /etc/gdm3/custom.conf > /dev/null << 'EOF'
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=wotto
EOF
```

### 8. GRUB direct boot (geen OS-keuzemenu)
```bash
echo 'GRUB_DISABLE_OS_PROBER=true' | sudo tee -a /etc/default/grub
sudo update-grub
```

### 9. Boot optimalisatie (38s → 24s)
Splash screen uitzetten (bespaart ~20s):
```bash
sudo sed -i 's/quiet splash/quiet nosplash/g' /etc/default/grub
sudo update-grub
sudo systemctl disable plymouth-quit-wait.service
```
**Let op**: `NetworkManager-wait-online` NIET disablen — Sunshine heeft netwerk nodig bij boot.

### 10. Scherm altijd aan (geen screensaver/lock/slaapstand)
```bash
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
```

### 11. Reboot en test
```bash
sudo reboot
```
Verbind daarna via Moonlight (laptop/telefoon) op het Tailscale IP.

### Tips
- **Moonlight via mobiel data**: voeg host handmatig toe in Moonlight met het Tailscale IP (autodiscovery werkt alleen op lokaal netwerk)
- **Tailscale altijd aan (Android)**: Instellingen → Verbindingen → Meer verbindingsinstellingen → VPN → tandwiel naast Tailscale → "Altijd actieve VPN" aan
- **Sunshine web UI**: bereikbaar op `https://localhost:47990` (op de Ubuntu PC zelf) of via SSH tunnel: `ssh -L 47990:localhost:47990 wotto@<TAILSCALE_IP>` en dan `https://localhost:47990` op je laptop
- **Pairen**: eerste keer per apparaat PIN invoeren via Sunshine web UI, daarna permanent onthouden
