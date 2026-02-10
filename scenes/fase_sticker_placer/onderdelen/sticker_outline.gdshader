shader_type canvas_item;

uniform bool show_outline = false;
uniform float outline_width : hint_range(0.0, 50.0) = 30.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (show_outline && col.a < 0.1) {
		vec2 s = TEXTURE_PIXEL_SIZE * outline_width;
		float a = texture(TEXTURE, UV + vec2(s.x, 0.0)).a;
		a = max(a, texture(TEXTURE, UV + vec2(-s.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, s.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, -s.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(s.x, s.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-s.x, s.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(s.x, -s.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-s.x, -s.y)).a);
		if (a > 0.1) {
			col = outline_color;
		}
	}
	COLOR = col;
}
