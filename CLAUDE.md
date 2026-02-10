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

- 2 zuilen: touchscreen + geluid
- 1 wandscherm: toont collectie
- Staand formaat
