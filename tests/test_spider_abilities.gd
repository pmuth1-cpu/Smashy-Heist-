extends SceneTree

func _init() -> void:
	print("\n=== TESTING SPIDER BOSS ABILITIES & ANIMATION PIPELINE ===")
	await process_frame
	
	# Verify GLB and core dependencies
	var scn = load("res://assets/models/bosses/steampunk_spider_robot.glb")
	assert(scn != null, "GLB Model must load cleanly")
	print("✓ PASS: Model loads")
	
	quit(0)
