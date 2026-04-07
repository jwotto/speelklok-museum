shader_type canvas_item;

uniform sampler2D text_texture : hint_default_white;
uniform vec4 bg_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(text_texture, UV);
	// Waar tekst is (alpha > 0.5) = transparant (uitgeknipt)
	// Waar geen tekst is = witte achtergrond
	if (tex.a > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Transparant gat
	} else {
		COLOR = bg_color;
	}
}
