extends SceneTree

const StarPerkPopupScene = preload("res://scenes/ui/star_perk_popup.tscn")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   STARTING ROGUELIKE STAR-UP SLOW-MOTION INTEGRATION TESTS      ")
	print("=================================================================")
	
	var popup: StarPerkPopup = StarPerkPopupScene.instantiate() as StarPerkPopup
	root.add_child(popup)
	await process_frame
	
	# Initial check
	assert(Engine.time_scale == 1.0, "Initial time_scale should be 1.0")
	assert(not popup.is_showing, "Popup should not be showing initially")
	
	# Step 1: Trigger 2-star Roguelike Upgrade
	print("\n--- STEP 1: TRIGGERING 2-STAR ROGUELIKE UPGRADE ---")
	popup.show_star_perks(2)
	assert(popup.is_showing, "Popup should be showing after show_star_perks")
	assert(popup.visible, "Popup should be visible")
	
	# Simulate process frames to verify smooth deceleration
	for i in range(15):
		await process_frame
		popup._process(0.016)
	
	print("  Current time_scale during slow-motion: %f" % Engine.time_scale)
	assert(Engine.time_scale < 0.35, "Engine.time_scale must decelerate into slow-motion (got: %f)" % Engine.time_scale)
	print("  [PASS] Slow-motion successfully active during Roguelike star perk choice!")
	
	# Step 2: Select Perk & Verify Smooth Acceleration back to 1.0x
	print("\n--- STEP 2: SELECTING PERK & RESTORING GAME SPEED ---")
	popup._select_perk(0)
	assert(not popup.is_showing, "Popup should no longer be showing")
	
	# Simulate process frames until time scale returns to normal
	for i in range(30):
		await process_frame
		popup._process(0.016)
	
	print("  Restored time_scale after perk selection: %f" % Engine.time_scale)
	assert(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale must return to 1.0 (got: %f)" % Engine.time_scale)
	print("  [PASS] Smooth return to normal time scale verified!")
	
	popup.queue_free()
	await process_frame
	
	# Ensure time_scale remains 1.0 after cleanup
	assert(Engine.time_scale == 1.0, "Engine.time_scale must be 1.0 after popup destruction")
	
	print("\n=================================================================")
	print("   ROGUELIKE STAR-UP SLOW-MOTION TESTS PASSED (100% GREEN)       ")
	print("=================================================================\n")
	quit(0)
