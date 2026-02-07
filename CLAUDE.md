# Speelklok Museum

Interactieve installatie voor het Speelklok Museum.

## Project Structuur

Object-georiënteerd: elk onderdeel is een zelfstandige class.

## Godot Code Richtlijnen

### Scene Opbouw
- Elke scene is **self-contained** - geen externe dependencies
- Siblings mogen **nooit** naar elkaar verwijzen - parent medieert
- Nooit `get_parent()` in child scenes - gebruik signals of dependency injection
- Scene tree:
  ```
  Main (Node2D)
    World/Stickers (Node2D)  -- game content
    UILayer (CanvasLayer)     -- UI boven alles
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

## Huidige Onderdelen

- `Sticker` - Verplaatsbaar, schaalbaar, roteerbaar object met touch
- `StickerPicker` - Grid overlay om stickers te kiezen
- `Main` - Scene controller met trash/add buttons

## Bouwfasen (nog te maken)

1. Vorm (5 vragen bepalen contour)
2. Muziekinstrumenten (10 items plaatsen)
3. Muziekdrager (1 uit 5)
4. Techniek (automatisch)
5. Aandrijving (1 uit 5)
6. Slot (8 sec muziek + transport)

## Hardware

- 2 zuilen: touchscreen + geluid
- 1 wandscherm: toont collectie
- Staand formaat
