@tool
extends RefCounted
class_name OutlinedIcon

## Maakt een Sprite2D met een witte rand eromheen, in dezelfde stijl als het
## sleep-handje. Gedeeld zodat alle icoon-hints er hetzelfde uitzien en het
## icoon-pad en de shader maar op één plek staan.

const OUTLINE_SHADER := preload("res://scenes/fase_sticker_placer/onderdelen/sticker_outline.gdshader")


## `size_px` is de gewenste grootte op het scherm, `outline_px` de randdikte
## in scherm-pixels (die blijft dus gelijk, ongeacht de schaal van het icoon)
static func create(texture: Texture2D, size_px: float, outline_px: float = 8.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	if texture == null:
		return sprite
	sprite.texture = texture

	var tex_size := maxf(texture.get_width(), texture.get_height())
	var s := size_px / tex_size if tex_size > 0.0 else 1.0
	sprite.scale = Vector2(s, s)

	# De shader rekent in texels, dus delen door de schaal geeft een vaste rand
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("show_outline", true)
	mat.set_shader_parameter("outline_color", Color.WHITE)
	mat.set_shader_parameter("outline_width", outline_px / s if s > 0.0 else outline_px)
	sprite.material = mat

	return sprite
