class_name AssetChromaLoaderClass
extends Node

## AssetChromaLoader: Autoload for loading 2D visual assets with automatic chroma-key background removal.
## Strips solid white or custom chroma backgrounds into crisp RGBA8 transparent ImageTextures,
## and provides procedural vector fallback textures if an image file is not present on disk.

var _texture_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Alias for load_transparent_texture
func load_texture(path: String, key_color: Color = Color(1, 0, 1), tolerance: float = 0.18) -> ImageTexture:
	return load_transparent_texture(path, key_color, tolerance)

## Loads an image from path, converts to FORMAT_RGBA8, strips solid background color to alpha 0.0,
## and caches the resulting ImageTexture.
func load_transparent_texture(path: String, key_color: Color = Color(1, 0, 1), tolerance: float = 0.18) -> ImageTexture:
	if _texture_cache.has(path):
		return _texture_cache[path] as ImageTexture
	
	var actual_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var img: Image = null
	
	if FileAccess.file_exists(actual_path) or FileAccess.file_exists(path):
		img = Image.new()
		var err := img.load(actual_path)
		if err != OK:
			err = img.load(path)
		if err != OK:
			img = null
	
	if img == null:
		# Fallback procedural generation
		var fallback_tex := _create_procedural_fallback(path)
		_texture_cache[path] = fallback_tex
		return fallback_tex
	
	# Convert to RGBA8 for pixel manipulation
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	
	# Determine chroma-key color: top-left corner if default magenta or white
	var target_bg: Color = key_color
	var top_left := img.get_pixel(0, 0)
	if key_color == Color(1, 0, 1) or key_color == Color.WHITE:
		if top_left.a > 0.8:
			target_bg = top_left
	
	var tol_sum: float = tolerance * 3.0
	for y in range(h):
		for x in range(w):
			var px := img.get_pixel(x, y)
			var dist := absf(px.r - target_bg.r) + absf(px.g - target_bg.g) + absf(px.b - target_bg.b)
			if dist < tol_sum:
				img.set_pixel(x, y, Color(px.r, px.g, px.b, 0.0))
			elif dist < tol_sum * 1.5:
				# Smooth edge feathering
				var alpha_factor := (dist - tol_sum) / (tol_sum * 0.5)
				img.set_pixel(x, y, Color(px.r, px.g, px.b, clampf(alpha_factor, 0.0, 1.0)))
	
	var tex := ImageTexture.create_from_image(img)
	_texture_cache[path] = tex
	return tex

## Synthesizes a crisp vector-like fallback ImageTexture when image files are missing on disk
func _create_procedural_fallback(path: String) -> ImageTexture:
	var base_name: String = path.get_file().get_basename()
	var size := Vector2i(128, 128)
	if "loading_bg" in base_name or "banner" in base_name or "stamp" in base_name or "btn_smash" in base_name:
		size = Vector2i(256, 144)
	
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var primary_col := Color("f1c40f") # Default Gold
	if "green_tire" in base_name or "cash" in base_name or "trophy" in base_name or "play" in base_name:
		primary_col = Color("2ecc71")
	elif "red_missile" in base_name or "fake_box" in base_name or "wasted" in base_name or "flame" in base_name or "streak" in base_name:
		primary_col = Color("e74c3c")
	elif "blue_drone" in base_name or "busted" in base_name or "police" in base_name:
		primary_col = Color("3498db")
	elif "emp" in base_name or "lightning" in base_name:
		primary_col = Color("00d2d3")
	elif "oil_slick" in base_name or "gold_star" in base_name:
		primary_col = Color("f1c40f")
	elif "triple_nitro" in base_name or "gear" in base_name or "gacha" in base_name:
		primary_col = Color("e67e22")
	elif "roulette" in base_name or "flag" in base_name:
		primary_col = Color("fbc531")
	elif "pause" in base_name:
		primary_col = Color("70a1ff")
	
	# Draw rounded central badge / icon
	var cx := float(size.x) * 0.5
	var cy := float(size.y) * 0.5
	var rx := float(size.x) * 0.42
	var ry := float(size.y) * 0.42
	
	for y in range(size.y):
		for x in range(size.x):
			var nx := (float(x) - cx) / rx
			var ny := (float(y) - cy) / ry
			var dist_sq := nx * nx + ny * ny
			if dist_sq <= 1.0:
				if dist_sq > 0.82:
					# Black comic outline
					img.set_pixel(x, y, Color(0.08, 0.08, 0.1, 1.0))
				else:
					# Gradient fill with glossy top highlight
					var highlight: float = 0.25 if ny < -0.2 else 0.0
					var col := primary_col.lightened(highlight)
					img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	
	var tex := ImageTexture.create_from_image(img)
	return tex
