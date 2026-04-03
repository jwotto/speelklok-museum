shader_type canvas_item;

// Hue shift in graden (0-360), 0 = originele kleur
uniform float hue_shift : hint_range(0.0, 360.0) = 0.0;
// Hoeveel van de nieuwe kleur zichtbaar is (0 = 100% origineel, 1 = maximaal gekleurd)
uniform float color_strength : hint_range(0.0, 1.0) = 0.85;

vec3 rgb_to_hsv(vec3 c) {
	float cmax = max(c.r, max(c.g, c.b));
	float cmin = min(c.r, min(c.g, c.b));
	float delta = cmax - cmin;
	float h = 0.0;
	if (delta > 0.001) {
		if (cmax == c.r) {
			h = mod((c.g - c.b) / delta, 6.0);
		} else if (cmax == c.g) {
			h = (c.b - c.r) / delta + 2.0;
		} else {
			h = (c.r - c.g) / delta + 4.0;
		}
		h /= 6.0;
		if (h < 0.0) h += 1.0;
	}
	float s = (cmax > 0.001) ? delta / cmax : 0.0;
	return vec3(h, s, cmax);
}

vec3 hsv_to_rgb(vec3 c) {
	float h = c.x * 6.0;
	float s = c.y;
	float v = c.z;
	float i = floor(h);
	float f = h - i;
	float p = v * (1.0 - s);
	float q = v * (1.0 - s * f);
	float t = v * (1.0 - s * (1.0 - f));
	int hi = int(mod(i, 6.0));
	if (hi == 0) return vec3(v, t, p);
	if (hi == 1) return vec3(q, v, p);
	if (hi == 2) return vec3(p, v, t);
	if (hi == 3) return vec3(p, q, v);
	if (hi == 4) return vec3(t, p, v);
	return vec3(v, p, q);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 original = tex.rgb;

	// Draai alleen de hue, behoud originele verzadiging en helderheid
	vec3 hsv = rgb_to_hsv(original);
	hsv.x = mod(hsv.x + hue_shift / 360.0, 1.0);
	vec3 shifted = hsv_to_rgb(hsv);

	// Blend tussen origineel hout en verschoven kleur
	// Zo blijft het houtpatroon en contrast altijd zichtbaar
	vec3 result = mix(original, shifted, color_strength);

	COLOR = vec4(result, tex.a);
}
