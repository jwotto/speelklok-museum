@tool
extends Node2D

## Tekent decoratieve elementen binnen de muziekkast-contour:
## orgelpijpen, boogjes, sierlijsten, paneel-kaders en vergulding.
## Wordt aangestuurd door parent BodyShape via update_decoration().

var _polygon: PackedVector2Array = PackedVector2Array()
var _base_color: Color = Color.WHITE
var _shape_height: float = 850.0

const MARGIN: float = 40.0
const MOLDING_INSET: float = 15.0

@export_group("Pijpen")
## Aantal orgelpijpen in de dak-zone
@export_range(5, 30) var pipe_count: int = 19:
	set(v):
		pipe_count = v
		queue_redraw()
## Afstand van het pijpenpaneel tot de dak-contour (kleiner = groter paneel)
@export_range(10.0, 150.0) var pipe_panel_inset: float = 40.0:
	set(v):
		pipe_panel_inset = v
		queue_redraw()

@export_group("Panelen")
## Aantal panelen in de buik-zone
@export_range(1, 5) var panel_count: int = 3:
	set(v):
		panel_count = v
		queue_redraw()
## Ruimte tussen panelen in pixels
@export var panel_gap: float = 25.0:
	set(v):
		panel_gap = v
		queue_redraw()

@export_group("Boogjes (kop)")
## Aantal sierlijke boogjes langs de kroonrand
@export_range(3, 20) var crown_arch_count: int = 11:
	set(v):
		crown_arch_count = v
		queue_redraw()
## Afstand van de boogjes tot de dak-contour
@export_range(10.0, 120.0) var crown_arch_offset: float = 48.0:
	set(v):
		crown_arch_offset = v
		queue_redraw()
## Hoogte van de kroonboogjes
@export_range(5.0, 80.0) var crown_arch_height: float = 30.0:
	set(v):
		crown_arch_height = v
		queue_redraw()
## Radius van de bolletjes op boog-kruispunten
@export_range(0.0, 15.0) var pendant_radius: float = 5.0:
	set(v):
		pendant_radius = v
		queue_redraw()

@export_group("Lijndikte")
## Hoofdlijn van de sierlijsten
@export_range(1.0, 12.0) var molding_width: float = 5.0:
	set(v):
		molding_width = v
		queue_redraw()
## Accentlijntjes naast de sierlijsten
@export_range(0.5, 8.0) var molding_accent_width: float = 2.0:
	set(v):
		molding_accent_width = v
		queue_redraw()
## Buitenrand van paneel-kaders
@export_range(1.0, 10.0) var panel_frame_width: float = 3.5:
	set(v):
		panel_frame_width = v
		queue_redraw()
## Binnenrand van paneel-kaders
@export_range(0.5, 6.0) var panel_inner_width: float = 1.5:
	set(v):
		panel_inner_width = v
		queue_redraw()
## Gouden binnentrim langs de hele contour
@export_range(1.0, 10.0) var gold_trim_width: float = 2.5:
	set(v):
		gold_trim_width = v
		queue_redraw()
## Lijndikte van decoratieve boogjes
@export_range(1.0, 10.0) var arch_line_width: float = 3.0:
	set(v):
		arch_line_width = v
		queue_redraw()
## Inset van de gouden trim t.o.v. de buitenrand
@export_range(4.0, 30.0) var gold_trim_inset: float = 10.0:
	set(v):
		gold_trim_inset = v
		queue_redraw()

@export_group("Texture: Kop")
@export var kop_texture: Texture2D:
	set(v):
		kop_texture = v
		queue_redraw()
@export_range(0.1, 10.0) var kop_texture_scale: float = 3.0:
	set(v):
		kop_texture_scale = v
		queue_redraw()
@export_range(0.0, 1.0) var kop_texture_opacity: float = 0.5:
	set(v):
		kop_texture_opacity = v
		queue_redraw()
@export_range(0.0, 1.0) var kop_color_blend: float = 0.3:
	set(v):
		kop_color_blend = v
		queue_redraw()
@export_range(0.0, 1.0) var kop_shading: float = 0.5:
	set(v):
		kop_shading = v
		queue_redraw()

@export_group("Texture: Lichaam")
@export var lichaam_texture: Texture2D:
	set(v):
		lichaam_texture = v
		queue_redraw()
@export_range(0.1, 10.0) var lichaam_texture_scale: float = 3.0:
	set(v):
		lichaam_texture_scale = v
		queue_redraw()
@export_range(0.0, 1.0) var lichaam_texture_opacity: float = 0.5:
	set(v):
		lichaam_texture_opacity = v
		queue_redraw()
@export_range(0.0, 1.0) var lichaam_color_blend: float = 0.3:
	set(v):
		lichaam_color_blend = v
		queue_redraw()
@export_range(0.0, 1.0) var lichaam_shading: float = 0.5:
	set(v):
		lichaam_shading = v
		queue_redraw()

@export_group("Texture: Rok")
@export var rok_texture: Texture2D:
	set(v):
		rok_texture = v
		queue_redraw()
@export_range(0.1, 10.0) var rok_texture_scale: float = 3.0:
	set(v):
		rok_texture_scale = v
		queue_redraw()
@export_range(0.0, 1.0) var rok_texture_opacity: float = 0.5:
	set(v):
		rok_texture_opacity = v
		queue_redraw()
@export_range(0.0, 1.0) var rok_color_blend: float = 0.3:
	set(v):
		rok_color_blend = v
		queue_redraw()
@export_range(0.0, 1.0) var rok_shading: float = 0.5:
	set(v):
		rok_shading = v
		queue_redraw()

@export_group("Texture: Pijpenpaneel")
@export var pipe_panel_texture: Texture2D:
	set(v):
		pipe_panel_texture = v
		queue_redraw()
@export_range(0.1, 10.0) var pipe_panel_texture_scale: float = 3.0:
	set(v):
		pipe_panel_texture_scale = v
		queue_redraw()
@export_range(0.0, 1.0) var pipe_panel_texture_opacity: float = 0.5:
	set(v):
		pipe_panel_texture_opacity = v
		queue_redraw()
@export_range(0.0, 1.0) var pipe_panel_color_blend: float = 0.3:
	set(v):
		pipe_panel_color_blend = v
		queue_redraw()
@export_range(0.0, 1.0) var pipe_panel_shading: float = 0.5:
	set(v):
		pipe_panel_shading = v
		queue_redraw()

@export_group("Texture: Buik-panelen")
@export var panel_texture: Texture2D:
	set(v):
		panel_texture = v
		queue_redraw()
@export_range(0.1, 10.0) var panel_texture_scale: float = 3.0:
	set(v):
		panel_texture_scale = v
		queue_redraw()
@export_range(0.0, 1.0) var panel_texture_opacity: float = 0.5:
	set(v):
		panel_texture_opacity = v
		queue_redraw()
@export_range(0.0, 1.0) var panel_color_blend: float = 0.3:
	set(v):
		panel_color_blend = v
		queue_redraw()
@export_range(0.0, 1.0) var panel_shading: float = 0.5:
	set(v):
		panel_shading = v
		queue_redraw()

@export_group("Texture: Pijpen")
@export var copper_texture: Texture2D:
	set(v):
		copper_texture = v
		queue_redraw()
@export_range(0.1, 10.0) var copper_texture_scale: float = 1.0:
	set(v):
		copper_texture_scale = v
		queue_redraw()
@export_range(0.0, 1.0) var copper_texture_opacity: float = 0.5:
	set(v):
		copper_texture_opacity = v
		queue_redraw()
@export_range(0.0, 1.0) var copper_color_blend: float = 0.3:
	set(v):
		copper_color_blend = v
		queue_redraw()
@export_range(0.0, 1.0) var copper_shading: float = 0.5:
	set(v):
		copper_shading = v
		queue_redraw()

@export_group("3D Shading")
## Sterkte van de rechts-licht/links-donker gradient (cilindrisch volume)
@export_range(0.0, 1.0) var shading_strength: float = 0.6:
	set(v):
		shading_strength = v
		queue_redraw()
## Sterkte van de lichte rand langs de lichtrichting
@export_range(0.0, 1.0) var highlight_strength: float = 0.4:
	set(v):
		highlight_strength = v
		queue_redraw()
## Sterkte van de glansspot (specular highlight)
@export_range(0.0, 1.0) var specular_strength: float = 0.35:
	set(v):
		specular_strength = v
		queue_redraw()
## Grootte van de glansspot in pixels
@export_range(30.0, 500.0) var specular_size: float = 180.0:
	set(v):
		specular_size = v
		queue_redraw()
## Breedte van het beveled edge (3D randeffect)
@export_range(0.0, 40.0) var bevel_width: float = 14.0:
	set(v):
		bevel_width = v
		queue_redraw()


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func update_decoration(polygon: PackedVector2Array, base_color: Color, shape_height: float) -> void:
	_polygon = polygon
	_base_color = base_color
	_shape_height = shape_height
	queue_redraw()


func _draw() -> void:
	if _polygon.size() < 3:
		return
	var shoulder_y: float = _shape_height * 0.25
	var hip_y: float = _shape_height * 0.75
	var base_y: float = _shape_height

	_draw_zone_textures(shoulder_y, hip_y, base_y)
	_draw_3d_shading()
	_draw_pipe_panel(shoulder_y)
	_draw_crown_arches(shoulder_y)
	_draw_moldings(shoulder_y, hip_y)
	_draw_panels_with_arches(shoulder_y, hip_y)
	_draw_gold_trim()
	_draw_3d_edge()


# ── Zone textures ────────────────────────────────────────────────────

func _draw_zone_textures(shoulder_y: float, hip_y: float, base_y: float) -> void:
	## Tekent per zone een aparte texture + zone-specifieke 3D shading
	var kop_poly: PackedVector2Array = _clip_polygon_to_band(0.0, shoulder_y)
	if kop_poly.size() >= 3:
		_draw_textured_poly(kop_poly, kop_texture,
			_make_tint(kop_texture_opacity, kop_color_blend), kop_texture_scale)
		_draw_zone_3d(kop_poly, kop_shading)

	var lichaam_poly: PackedVector2Array = _clip_polygon_to_band(shoulder_y, hip_y)
	if lichaam_poly.size() >= 3:
		_draw_textured_poly(lichaam_poly, lichaam_texture,
			_make_tint(lichaam_texture_opacity, lichaam_color_blend), lichaam_texture_scale)
		_draw_zone_3d(lichaam_poly, lichaam_shading)

	var rok_poly: PackedVector2Array = _clip_polygon_to_band(hip_y, base_y)
	if rok_poly.size() >= 3:
		_draw_textured_poly(rok_poly, rok_texture,
			_make_tint(rok_texture_opacity, rok_color_blend), rok_texture_scale)
		_draw_zone_3d(rok_poly, rok_shading)


# ── 3D Volume shading ────────────────────────────────────────────────

func _draw_3d_shading() -> void:
	## Tekent 3D volume-shading: licht van rechtsboven, schaduw linksonder.
	## Gebruikt veel smalle verticale strips voor vloeiende overgangen.
	if _polygon.size() < 3:
		return

	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	for p in _polygon:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
	var x_span: float = max_x - min_x
	if x_span < 1.0:
		return

	# Pass 1: Cilindrische highlight + shadow via smalle verticale strips
	var strip_count: int = 24
	var strip_w: float = x_span / float(strip_count)

	for s in strip_count:
		var x0: float = min_x + float(s) * strip_w
		var x1: float = x0 + strip_w
		var tx: float = (float(s) + 0.5) / float(strip_count)

		# Licht van rechts: highlight rechts, schaduw links
		var hi_alpha: float = 0.0
		if tx > 0.3 and shading_strength > 0.01:
			hi_alpha = ((tx - 0.3) / 0.7) * 0.22 * shading_strength

		var sh_alpha: float = 0.0
		if tx < 0.55 and shading_strength > 0.01:
			sh_alpha = ((0.55 - tx) / 0.55) * 0.32 * shading_strength

		if hi_alpha < 0.005 and sh_alpha < 0.005:
			continue

		var strip: PackedVector2Array = _clip_x_range(_polygon, x0, x1)
		if strip.size() < 3:
			continue
		if hi_alpha > 0.005:
			draw_colored_polygon(strip, Color(1, 1, 0.95, clampf(hi_alpha, 0.0, 0.55)))
		if sh_alpha > 0.005:
			draw_colored_polygon(strip, Color(0, 0, 0.02, clampf(sh_alpha, 0.0, 0.45)))

	# Pass 2: Specular spot via concentrische cirkels (artefact-vrij)
	if specular_strength > 0.01:
		var spec_x: float = min_x + x_span * 0.72
		var spec_y: float = min_y + _shape_height * 0.22
		var rings: int = 12
		var per_ring: float = specular_strength * 0.45 / float(rings)
		for r in range(rings, 0, -1):
			var radius: float = specular_size * float(r) / float(rings)
			draw_circle(Vector2(spec_x, spec_y), radius, Color(1, 1, 0.95, per_ring))

	# Pass 3: Bottom darkening via horizontale banden
	if shading_strength > 0.01:
		var band_count: int = 8
		var band_start_y: float = min_y + _shape_height * 0.75
		var band_end_y: float = min_y + _shape_height
		var band_h: float = (band_end_y - band_start_y) / float(band_count)
		for b in band_count:
			var y0: float = band_start_y + float(b) * band_h
			var y1: float = y0 + band_h
			var bt: float = (float(b) + 0.5) / float(band_count)
			var alpha: float = bt * 0.12 * shading_strength
			if alpha > 0.005:
				var band: PackedVector2Array = _clip_polygon_to_band(y0, y1)
				if band.size() >= 3:
					draw_colored_polygon(band, Color(0, 0, 0.02, alpha))


# ── Pijpenpaneel (dak-zone) ───────────────────────────────────────────

func _draw_pipe_panel(shoulder_y: float) -> void:
	## Tekent een paneel dat de dak-contour volgt met orgelpijpen erin
	var panel_bottom: float = shoulder_y - MARGIN * 0.3

	# Breedte op panel_bottom niveau
	var x_range: Vector2 = _get_x_range_at_y(panel_bottom)
	var panel_left: float = x_range.x + pipe_panel_inset
	var panel_right: float = x_range.y - pipe_panel_inset
	if panel_right - panel_left < 80.0:
		return

	# Bouw paneel-polygon: top volgt dak, bottom is recht
	var samples: int = 35
	var panel_pts: PackedVector2Array = PackedVector2Array()

	# Top edge: volg het dak van links naar rechts (clamp zodat top nooit onder bottom komt)
	var max_top_y: float = panel_bottom - 10.0
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var x: float = lerpf(panel_left, panel_right, t)
		var roof_y: float = _get_top_y_at_x(x)
		var top_y: float = minf(roof_y + pipe_panel_inset, max_top_y)
		panel_pts.append(Vector2(x, top_y))

	# Bottom edge: recht van rechts naar links
	panel_pts.append(Vector2(panel_right, panel_bottom))
	panel_pts.append(Vector2(panel_left, panel_bottom))

	# Teken paneel achtergrond + texture
	if panel_pts.size() >= 3:
		draw_colored_polygon(panel_pts, Color(0, 0, 0, 0.08))
		_draw_textured_poly(panel_pts, pipe_panel_texture,
			_make_tint(pipe_panel_texture_opacity, pipe_panel_color_blend), pipe_panel_texture_scale)

		# 3D shading op pijpenpaneel (per-zone control)
		_draw_zone_3d(panel_pts, pipe_panel_shading)

	# Teken paneel rand (goud)
	var gold: Color = Color(0.85, 0.7, 0.3, 0.6)
	var outline_pts: PackedVector2Array = panel_pts.duplicate()
	outline_pts.append(panel_pts[0])
	draw_polyline(outline_pts, gold, panel_frame_width, true)

	# Teken pijpen binnen het paneel
	_draw_pipes_in_panel(panel_left, panel_right, panel_bottom)


func _draw_pipes_in_panel(panel_left: float, panel_right: float, panel_bottom: float) -> void:
	## Tekent orgelpijpen binnen het pijpenpaneel, begrensd door de dak-contour
	var pipe_margin: float = MARGIN * 0.5
	var zone_left: float = panel_left + pipe_margin
	var zone_right: float = panel_right - pipe_margin
	var zone_width: float = zone_right - zone_left
	if zone_width < 80.0:
		return

	var count: int = pipe_count
	if count % 2 == 0:
		count -= 1
	var gap_ratio: float = 0.25
	var pw: float = zone_width / (float(count) * (1.0 + gap_ratio) - gap_ratio)
	var pg: float = pw * gap_ratio

	var col_body: Color = Color(0.78, 0.68, 0.42, 0.9)
	var col_cap: Color = Color(0.88, 0.78, 0.38, 1.0)
	var col_mouth: Color = Color(0.1, 0.08, 0.04, 0.5)
	@warning_ignore("integer_division")
	var center_i: int = count / 2

	var pipe_bottom_y: float = panel_bottom - pipe_margin * 0.5

	for i in count:
		var x: float = zone_left + float(i) * (pw + pg)
		var pipe_cx: float = x + pw / 2.0

		# Top van de pijp is begrensd door het paneel (dak + inset + marge)
		var roof_y: float = _get_top_y_at_x(pipe_cx)
		var pipe_top_limit: float = roof_y + pipe_panel_inset + pipe_margin

		var dist: float = absf(float(i - center_i)) / float(maxi(center_i, 1))
		var h_factor: float = 1.0 - dist * 0.5
		var max_h: float = pipe_bottom_y - pipe_top_limit
		var pipe_h: float = max_h * h_factor
		if pipe_h < 20.0:
			continue

		var pipe_y: float = pipe_bottom_y - pipe_h

		draw_rect(Rect2(x, pipe_y, pw, pipe_h), col_body)
		_draw_textured_rect(Rect2(x, pipe_y, pw, pipe_h), copper_texture,
			_make_tint(copper_texture_opacity, copper_color_blend), copper_texture_scale)
		# Vloeiende 3D schaduw gradient (links, per-zone control)
		var cs: float = copper_shading
		if cs > 0.01:
			draw_rect(Rect2(x, pipe_y, pw * 0.08, pipe_h), Color(0, 0, 0, 0.28 * cs))
			draw_rect(Rect2(x + pw * 0.08, pipe_y, pw * 0.10, pipe_h), Color(0, 0, 0, 0.18 * cs))
			draw_rect(Rect2(x + pw * 0.18, pipe_y, pw * 0.12, pipe_h), Color(0, 0, 0, 0.07 * cs))
			# Vloeiende 3D highlight gradient (rechts)
			draw_rect(Rect2(x + pw * 0.70, pipe_y, pw * 0.14, pipe_h), Color(1, 1, 1, 0.07 * cs))
			draw_rect(Rect2(x + pw * 0.84, pipe_y, pw * 0.10, pipe_h), Color(1, 1, 1, 0.18 * cs))
			draw_rect(Rect2(x + pw * 0.94, pipe_y, pw * 0.06, pipe_h), Color(1, 1, 1, 0.30 * cs))
		# Cap met highlight
		var cap_h: float = maxf(4.0, pw * 0.22)
		var cap_extra: float = pw * 0.12
		var cap_w: float = pw + cap_extra * 2.0
		draw_rect(Rect2(x - cap_extra, pipe_y, cap_w, cap_h), col_cap)
		if cs > 0.01:
			draw_rect(Rect2(x - cap_extra, pipe_y, cap_w * 0.3, cap_h), Color(0, 0, 0, 0.15 * cs))
			draw_rect(Rect2(x - cap_extra + cap_w * 0.65, pipe_y, cap_w * 0.35, cap_h), Color(1, 1, 1, 0.20 * cs))
		var mouth_y: float = pipe_y + pipe_h * 0.72
		var mouth_h: float = maxf(2.0, pipe_h * 0.03)
		draw_rect(Rect2(x + pw * 0.1, mouth_y, pw * 0.8, mouth_h), col_mouth)


# ── Kroon-boogjes (tierelantijntjes bovenaan) ────────────────────────

func _draw_crown_arches(shoulder_y: float) -> void:
	## Boogjes die precies tussen het pijpenpaneel en de buitenrand passen
	var panel_bottom: float = shoulder_y - MARGIN * 0.3
	var max_top_y: float = panel_bottom - 10.0

	# Gebruik dezelfde panel breedte als het pijpenpaneel
	var x_range: Vector2 = _get_x_range_at_y(panel_bottom)
	var panel_left: float = x_range.x + pipe_panel_inset
	var panel_right: float = x_range.y - pipe_panel_inset
	var panel_width: float = panel_right - panel_left
	if panel_width < 80.0 or crown_arch_count < 1:
		return

	var arch_span: float = panel_width / float(crown_arch_count)
	var gold: Color = Color(0.85, 0.7, 0.3, 0.7)

	for i in crown_arch_count:
		var x_left: float = panel_left + float(i) * arch_span
		var x_right: float = x_left + arch_span

		# Baseline = bovenkant pijpenpaneel (dak + inset, geclampt)
		var roof_left: float = _get_top_y_at_x(x_left)
		var roof_right: float = _get_top_y_at_x(x_right)
		var bl_left: float = minf(roof_left + pipe_panel_inset, max_top_y)
		var bl_right: float = minf(roof_right + pipe_panel_inset, max_top_y)

		_draw_tilted_arch(
			Vector2(x_left, bl_left), Vector2(x_right, bl_right),
			crown_arch_height, gold
		)

	# Pendanten (bolletjes) op de snijpunten
	if pendant_radius > 0.5:
		for i in range(crown_arch_count + 1):
			var px: float = panel_left + float(i) * arch_span
			var p_roof_y: float = _get_top_y_at_x(px)
			var py: float = minf(p_roof_y + pipe_panel_inset, max_top_y)
			draw_circle(Vector2(px, py), pendant_radius, gold)


# ── Sierlijsten ──────────────────────────────────────────────────────

func _draw_moldings(shoulder_y: float, hip_y: float) -> void:
	_draw_straight_molding(shoulder_y)
	_draw_straight_molding(hip_y)


func _draw_straight_molding(y: float) -> void:
	var x_range: Vector2 = _get_x_range_at_y(y)
	var left: float = x_range.x + MOLDING_INSET
	var right: float = x_range.y - MOLDING_INSET
	if right - left < 30.0:
		return

	var gold: Color = Color(0.85, 0.7, 0.3, 0.8)
	var dark_gold: Color = Color(0.55, 0.42, 0.15, 0.6)

	# 3D molding: highlight boven, schaduw onder = verhoogd profiel
	if shading_strength > 0.01:
		draw_line(Vector2(left, y - 7), Vector2(right, y - 7),
			Color(1, 1, 0.9, 0.15 * shading_strength), molding_width * 0.6)
	draw_line(Vector2(left, y - 5), Vector2(right, y - 5), dark_gold, molding_accent_width)
	draw_line(Vector2(left, y), Vector2(right, y), gold, molding_width)
	draw_line(Vector2(left, y + 5), Vector2(right, y + 5), dark_gold, molding_accent_width)
	if shading_strength > 0.01:
		draw_line(Vector2(left, y + 7), Vector2(right, y + 7),
			Color(0, 0, 0, 0.12 * shading_strength), molding_width * 0.6)


# ── Panelen met boogjes ──────────────────────────────────────────────

func _draw_panels_with_arches(shoulder_y: float, hip_y: float) -> void:
	var zone_margin: float = MARGIN * 2.0
	var arch_space: float = zone_margin * 0.7
	var panel_top: float = shoulder_y + zone_margin + arch_space
	var panel_bottom: float = hip_y - zone_margin
	if panel_bottom - panel_top < 40.0 or panel_count < 1:
		return

	# Beschikbare breedte (smalste punt in het panel-gebied)
	var x_top: Vector2 = _get_x_range_at_y(panel_top)
	var x_bottom: Vector2 = _get_x_range_at_y(panel_bottom)
	var left: float = maxf(x_top.x, x_bottom.x) + zone_margin
	var right: float = minf(x_top.y, x_bottom.y) - zone_margin
	var total_w: float = right - left
	if total_w < 60.0:
		return

	# Bereken individuele paneelbreedte
	var gaps_total: float = panel_gap * float(panel_count - 1)
	var pw: float = (total_w - gaps_total) / float(panel_count)
	if pw < 30.0:
		return

	var gold: Color = Color(0.85, 0.7, 0.3, 0.6)
	var gold_fill: Color = Color(0.15, 0.1, 0.02, 0.25)
	var gold_inner: Color = Color(0.85, 0.7, 0.3, 0.25)

	for i in panel_count:
		var panel_left: float = left + float(i) * (pw + panel_gap)
		var panel_cx: float = panel_left + pw / 2.0

		# ── Boogje boven het paneel ──
		var arch_half_w: float = pw / 2.0
		var arch_h: float = minf(arch_space * 0.85, arch_half_w * 0.4)
		var arch_baseline: float = panel_top
		if arch_h > 10.0:
			_draw_arch(panel_cx, arch_baseline, arch_half_w, arch_h, gold, gold_fill)
			# Sleutelstuk (bolletje bovenaan de boog)
			if pendant_radius > 0.5:
				draw_circle(Vector2(panel_cx, arch_baseline - arch_h), pendant_radius, gold)

		# ── Paneel-kader ──
		var rect: Rect2 = Rect2(panel_left, panel_top, pw, panel_bottom - panel_top)
		draw_rect(rect, Color(1, 1, 1, 0.06))
		_draw_textured_rect(rect, panel_texture,
			_make_tint(panel_texture_opacity, panel_color_blend), panel_texture_scale)

		# 3D paneel-shading (verhoogd effect, licht van rechts)
		if panel_shading > 0.01:
			var ph: float = panel_bottom - panel_top
			var ew: float = pw * 0.08
			# Schaduw links
			draw_rect(Rect2(panel_left, panel_top, ew, ph), Color(0, 0, 0, 0.18 * panel_shading))
			draw_rect(Rect2(panel_left + ew, panel_top, ew, ph), Color(0, 0, 0, 0.08 * panel_shading))
			# Highlight rechts + boven
			draw_rect(Rect2(panel_left + pw - ew * 2, panel_top, ew, ph), Color(1, 1, 1, 0.08 * panel_shading))
			draw_rect(Rect2(panel_left + pw - ew, panel_top, ew, ph), Color(1, 1, 1, 0.18 * panel_shading))
			draw_rect(Rect2(panel_left, panel_top, pw, ew * 0.7), Color(1, 1, 1, 0.12 * panel_shading))
			# Schaduw onder
			draw_rect(Rect2(panel_left, panel_bottom - ew * 0.7, pw, ew * 0.7), Color(0, 0, 0, 0.12 * panel_shading))

		draw_rect(rect, gold, false, panel_frame_width)

		var inner: Rect2 = rect.grow(-12.0)
		if inner.size.x > 30 and inner.size.y > 30:
			draw_rect(inner, gold_inner, false, panel_inner_width)


# ── Gouden trim ──────────────────────────────────────────────────────

func _draw_gold_trim() -> void:
	if _polygon.size() < 3:
		return
	var inset_poly: PackedVector2Array = _inset_polygon(gold_trim_inset)
	if inset_poly.size() < 3:
		return

	var gold: Color = Color(0.85, 0.7, 0.3, 0.4)
	var to_light: Vector2 = Vector2(0.7, -0.7).normalized()
	var n: int = inset_poly.size()
	for i in n:
		var p1: Vector2 = inset_poly[i]
		var p2: Vector2 = inset_poly[(i + 1) % n]
		draw_line(p1, p2, gold, gold_trim_width)

		# 3D trim: highlight/schaduw per segment op basis van lichtrichting
		if shading_strength > 0.01 and gold_trim_width >= 2.0:
			var edge: Vector2 = p2 - p1
			if edge.length() > 0.5:
				var ed: Vector2 = edge.normalized()
				var normal: Vector2 = Vector2(ed.y, -ed.x)
				var facing: float = normal.dot(to_light)
				if facing > 0.15:
					draw_line(p1, p2, Color(1, 1, 0.8, facing * 0.2 * shading_strength),
						gold_trim_width * 0.5)
				elif facing < -0.15:
					draw_line(p1, p2, Color(0, 0, 0, -facing * 0.15 * shading_strength),
						gold_trim_width * 0.5)


# ── Boog-tekenfunctie (herbruikbaar) ─────────────────────────────────

func _draw_arch(cx: float, baseline_y: float, half_w: float, height: float, color: Color, fill_color: Color = Color.TRANSPARENT) -> void:
	## Tekent een elliptische boog (∩) met optionele vulling
	var segments: int = 14
	var points: PackedVector2Array = PackedVector2Array()
	for j in range(segments + 1):
		var t: float = float(j) / float(segments)
		var angle: float = PI * t
		var x: float = cx - half_w * cos(angle)
		var y: float = baseline_y - height * sin(angle)
		points.append(Vector2(x, y))

	# Optionele vulling
	if fill_color.a > 0.01:
		var fill_pts: PackedVector2Array = points.duplicate()
		fill_pts.append(Vector2(cx + half_w, baseline_y))
		draw_colored_polygon(fill_pts, fill_color)

	draw_polyline(points, color, arch_line_width, true)


func _draw_tilted_arch(p_left: Vector2, p_right: Vector2, height: float, color: Color) -> void:
	## Tekent een ronde boog tussen twee punten die op verschillende hoogtes kunnen liggen.
	## De lift staat loodrecht op de basislijn zodat de boog altijd rond blijft.
	var segments: int = 14
	var baseline_dir: Vector2 = (p_right - p_left).normalized()
	var normal: Vector2 = Vector2(-baseline_dir.y, baseline_dir.x)
	# Zorg dat normaal omhoog wijst (negatieve y)
	if normal.y > 0:
		normal = -normal

	var points: PackedVector2Array = PackedVector2Array()
	for j in range(segments + 1):
		var t: float = float(j) / float(segments)
		var base_pt: Vector2 = p_left.lerp(p_right, t)
		var lift: float = sin(t * PI) * height
		points.append(base_pt + normal * lift)

	draw_polyline(points, color, arch_line_width, true)


# ── 3D Beveled edge ─────────────────────────────────────────────────

func _draw_3d_edge() -> void:
	## Tekent een beveled rand langs de contour: helder aan de lichtzijde,
	## donker aan de schaduwzijde, voor een 3D diepte-effect.
	if _polygon.size() < 3 or bevel_width < 0.5:
		return

	var n: int = _polygon.size()
	var to_light: Vector2 = Vector2(0.7, -0.7).normalized()

	for i in n:
		var p1: Vector2 = _polygon[i]
		var p2: Vector2 = _polygon[(i + 1) % n]
		var edge: Vector2 = p2 - p1
		if edge.length() < 0.5:
			continue
		var edge_dir: Vector2 = edge.normalized()
		# Outward normal (clockwise polygon)
		var normal: Vector2 = Vector2(edge_dir.y, -edge_dir.x)
		var facing: float = normal.dot(to_light)

		if facing > 0.1:
			# Rand naar het licht: helder highlight
			var alpha: float = facing * highlight_strength * 0.5
			draw_line(p1, p2, Color(1, 1, 0.9, alpha), bevel_width, true)
		elif facing < -0.1:
			# Rand weg van licht: schaduw
			var alpha: float = -facing * shading_strength * 0.4
			draw_line(p1, p2, Color(0, 0, 0, alpha), bevel_width * 0.7, true)


# ── Zone 3D shading helper ──────────────────────────────────────────

func _draw_zone_3d(zone_poly: PackedVector2Array, strength: float) -> void:
	## Tekent vloeiende 3D highlight/shadow op een zone-polygon.
	## Licht van rechts, veel smalle strips voor zachte overgangen.
	if zone_poly.size() < 3 or strength < 0.01:
		return

	var min_x: float = INF
	var max_x: float = -INF
	for p in zone_poly:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
	var span: float = max_x - min_x
	if span < 1.0:
		return

	var strip_count: int = 20
	var strip_w: float = span / float(strip_count)

	for s in strip_count:
		var x0: float = min_x + float(s) * strip_w
		var x1: float = x0 + strip_w
		var tx: float = (float(s) + 0.5) / float(strip_count)

		# Licht van rechts: highlight rechts, schaduw links
		var hi_alpha: float = 0.0
		if tx > 0.35:
			hi_alpha = ((tx - 0.35) / 0.65) * 0.20 * strength

		var sh_alpha: float = 0.0
		if tx < 0.55:
			sh_alpha = ((0.55 - tx) / 0.55) * 0.25 * strength

		if hi_alpha < 0.005 and sh_alpha < 0.005:
			continue

		var strip: PackedVector2Array = _clip_x_range(zone_poly, x0, x1)
		if strip.size() < 3:
			continue
		if hi_alpha > 0.005:
			draw_colored_polygon(strip, Color(1, 1, 0.95, hi_alpha))
		if sh_alpha > 0.005:
			draw_colored_polygon(strip, Color(0, 0, 0, sh_alpha))


# ── Texture helpers ──────────────────────────────────────────────────

func _make_tint(opacity: float, blend: float) -> Color:
	## Berekent de kleur-modulatie op basis van per-zone blend en opacity
	var c: Color = Color.WHITE.lerp(_base_color, blend)
	c.a = opacity
	return c


func _draw_textured_poly(points: PackedVector2Array, tex: Texture2D, tint: Color, scale: float) -> void:
	## Tekent een getiled texture-polygon met kleur-modulatie en eigen schaal
	if not tex or tint.a < 0.01 or points.size() < 3:
		return
	var tex_size: Vector2 = Vector2(tex.get_width(), tex.get_height()) * scale
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for p in points:
		uvs.append(p / tex_size)
		colors.append(tint)
	draw_polygon(points, colors, uvs, tex)


func _draw_textured_rect(rect: Rect2, tex: Texture2D, tint: Color, scale: float) -> void:
	## Tekent een getiled texture-rect met kleur-modulatie en eigen schaal
	if not tex or tint.a < 0.01:
		return
	var pts: PackedVector2Array = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	])
	_draw_textured_poly(pts, tex, tint, scale)


# ── Helpers ───────────────────────────────────────────────────────────

func _get_top_y_at_x(x: float) -> float:
	## Vindt de bovenste y-coördinaat (laagste y) van de polygon op x-positie
	var min_y: float = INF
	var n: int = _polygon.size()
	for i in n:
		var p1: Vector2 = _polygon[i]
		var p2: Vector2 = _polygon[(i + 1) % n]
		if (p1.x <= x and p2.x >= x) or (p1.x >= x and p2.x <= x):
			if absf(p2.x - p1.x) < 0.001:
				min_y = minf(min_y, minf(p1.y, p2.y))
			else:
				var t: float = (x - p1.x) / (p2.x - p1.x)
				var y: float = p1.y + t * (p2.y - p1.y)
				min_y = minf(min_y, y)
	return min_y if min_y < INF else 0.0


func _get_x_range_at_y(y: float) -> Vector2:
	var min_x: float = INF
	var max_x: float = -INF
	var n: int = _polygon.size()
	for i in n:
		var p1: Vector2 = _polygon[i]
		var p2: Vector2 = _polygon[(i + 1) % n]
		if (p1.y <= y and p2.y >= y) or (p1.y >= y and p2.y <= y):
			if absf(p2.y - p1.y) < 0.001:
				min_x = minf(min_x, minf(p1.x, p2.x))
				max_x = maxf(max_x, maxf(p1.x, p2.x))
			else:
				var t: float = (y - p1.y) / (p2.y - p1.y)
				var x: float = p1.x + t * (p2.x - p1.x)
				min_x = minf(min_x, x)
				max_x = maxf(max_x, x)
	if min_x == INF:
		return Vector2.ZERO
	return Vector2(min_x, max_x)


func _clip_polygon_to_band(y_min: float, y_max: float) -> PackedVector2Array:
	var clipped: PackedVector2Array = _clip_below(_polygon, y_max)
	return _clip_above(clipped, y_min)


func _clip_below(poly: PackedVector2Array, y_max: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var n: int = poly.size()
	if n < 3:
		return result
	for i in n:
		var c: Vector2 = poly[i]
		var nx: Vector2 = poly[(i + 1) % n]
		var c_in: bool = c.y <= y_max
		var n_in: bool = nx.y <= y_max
		if c_in:
			result.append(c)
		if c_in != n_in and absf(nx.y - c.y) > 0.001:
			var t: float = (y_max - c.y) / (nx.y - c.y)
			result.append(c.lerp(nx, t))
	return result


func _clip_above(poly: PackedVector2Array, y_min: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var n: int = poly.size()
	if n < 3:
		return result
	for i in n:
		var c: Vector2 = poly[i]
		var nx: Vector2 = poly[(i + 1) % n]
		var c_in: bool = c.y >= y_min
		var n_in: bool = nx.y >= y_min
		if c_in:
			result.append(c)
		if c_in != n_in and absf(nx.y - c.y) > 0.001:
			var t: float = (y_min - c.y) / (nx.y - c.y)
			result.append(c.lerp(nx, t))
	return result


func _clip_x_left(poly: PackedVector2Array, x_max: float) -> PackedVector2Array:
	## Houdt het deel van de polygon waar x <= x_max (links van x_max)
	var result: PackedVector2Array = PackedVector2Array()
	var n: int = poly.size()
	if n < 3:
		return result
	for i in n:
		var c: Vector2 = poly[i]
		var nx: Vector2 = poly[(i + 1) % n]
		var c_in: bool = c.x <= x_max
		var n_in: bool = nx.x <= x_max
		if c_in:
			result.append(c)
		if c_in != n_in and absf(nx.x - c.x) > 0.001:
			var t: float = (x_max - c.x) / (nx.x - c.x)
			result.append(c.lerp(nx, t))
	return result


func _clip_x_right(poly: PackedVector2Array, x_min: float) -> PackedVector2Array:
	## Houdt het deel van de polygon waar x >= x_min (rechts van x_min)
	var result: PackedVector2Array = PackedVector2Array()
	var n: int = poly.size()
	if n < 3:
		return result
	for i in n:
		var c: Vector2 = poly[i]
		var nx: Vector2 = poly[(i + 1) % n]
		var c_in: bool = c.x >= x_min
		var n_in: bool = nx.x >= x_min
		if c_in:
			result.append(c)
		if c_in != n_in and absf(nx.x - c.x) > 0.001:
			var t: float = (x_min - c.x) / (nx.x - c.x)
			result.append(c.lerp(nx, t))
	return result


func _clip_x_range(poly: PackedVector2Array, x_min: float, x_max: float) -> PackedVector2Array:
	## Clipt polygon tot het bereik x_min <= x <= x_max
	return _clip_x_left(_clip_x_right(poly, x_min), x_max)


func _inset_polygon(amount: float) -> PackedVector2Array:
	var n: int = _polygon.size()
	if n < 3:
		return _polygon
	var centroid: Vector2 = Vector2.ZERO
	for p in _polygon:
		centroid += p
	centroid /= float(n)
	var result: PackedVector2Array = PackedVector2Array()
	for p in _polygon:
		var dir: Vector2 = (centroid - p).normalized()
		result.append(p + dir * amount)
	return result
