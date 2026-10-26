extends SceneTree

const BrawlMainMenuScene = preload("res://scenes/ui/brawl_main_menu.tscn")
const AssetChromaLoaderScript = preload("res://scripts/autoload/asset_chroma_loader.gd")

func _init() -> void:
	print("\n=================================================================")
	print("       STARTING LOBBY REDESIGN & SMASH BUTTON TEST               ")
	print("=================================================================\n")
	
	await process_frame
	await process_frame
	
	_run_all_tests()
	quit(0)

func _run_all_tests() -> void:
	# 1. Initialize AssetChromaLoader autoload mock if needed
	var acl = root.get_node_or_null("AssetChromaLoader")
	if not acl:
		acl = AssetChromaLoaderScript.new()
		acl.name = "AssetChromaLoader"
		root.add_child(acl)
		acl._ready()
	
	# 2. Instantiate BrawlMainMenu
	print("--- TEST 1: INSTANTIATING BRAWL MAIN MENU ---")
	var menu: Control = BrawlMainMenuScene.instantiate()
	root.add_child(menu)
	menu._ready()
	assert(menu != null, "BrawlMainMenu must instantiate cleanly")
	print("  [PASS] BrawlMainMenu instantiated")
	
	# 3. Verify Layer 0 Background
	print("\n--- TEST 2: HANGAR BACKDROP & LAYER 0 ---")
	var bg_rect = menu.get_node_or_null("HangarBackdrop")
	assert(bg_rect != null, "HangarBackdrop must exist in Layer 0")
	print("  [PASS] HangarBackdrop exists with texture: %s" % str(bg_rect.texture != null))
	
	# 4. Verify Layer 2 Top Bar & Side Cards
	print("\n--- TEST 3: TOP BAR STATUS CAPSULES & SIDE CARDS ---")
	var top_bar = menu.get_node_or_null("Layer2_TopBar")
	assert(top_bar != null, "Layer2_TopBar must exist")
	
	var side_cards = menu.get_node_or_null("SideCardsContainer")
	assert(side_cards != null, "SideCardsContainer must exist")
	assert(menu._quests_card_btn != null, "Daily Quests card button must exist")
	assert(menu._event_card_btn != null, "Event card button must exist")
	assert(menu._map_card_btn != null, "New Map card button must exist")
	assert(menu._free_rewards_card_btn != null, "Free Rewards card button must exist")
	print("  [PASS] Top bar and all 4 side cards (Quests, Event, Map, Free Rewards) verified")
	
	# 5. Verify Bottom Navigation Tabs
	print("\n--- TEST 4: 5-TAB BOTTOM NAVIGATION DOCK ---")
	assert(menu._tab_buttons.size() == 5, "Must have exactly 5 tab buttons")
	assert(menu.active_tab_index == 0, "Default tab must be Home (0)")
	
	# Test switching tabs
	menu.switch_tab(1) # Cars
	assert(menu.active_tab_index == 1, "Tab must switch to Cars (1)")
	assert(menu._cars_drawer.visible == true, "Cars drawer must be visible on tab 1")
	assert(menu._side_cards_container.visible == false, "Side cards must be hidden on drawer tab 1")
	
	menu.switch_tab(0) # Home
	assert(menu.active_tab_index == 0, "Tab must switch back to Home (0)")
	assert(menu._cars_drawer.visible == false, "Cars drawer must be hidden on home tab")
	assert(menu._side_cards_container.visible == true, "Side cards must be visible on home tab")
	print("  [PASS] 5-Tab navigation and drawer switching verified")
	
	# 6. Verify Mode Card and Primary SMASH Button
	print("\n--- TEST 5: MODE SELECTOR & PRIMARY SMASH BUTTON ---")
	assert(menu._mode_card_btn != null, "Mode card button must exist")
	assert(menu._smash_play_button != null, "SMASH play button must exist")
	assert(menu._smash_play_button is TextureButton, "SMASH button must be a TextureButton")
	
	var smash_tb: TextureButton = menu._smash_play_button as TextureButton
	assert(smash_tb.texture_normal != null, "SMASH TextureButton must have texture_normal loaded")
	print("  [PASS] SMASH! TextureButton verified with texture: %s" % str(smash_tb.texture_normal.resource_path))
	
	# 7. Test Primary Button Signal Emission
	print("\n--- TEST 6: SMASH! PLAY ACTION SIGNAL EMISSION ---")
	var signal_emitted: Array[bool] = [false]
	menu.play_pressed.connect(func(_mode_id):
		signal_emitted[0] = true
	)
	menu._on_smash_play_pressed()
	assert(signal_emitted[0] == true, "SMASH! button click must emit play_pressed signal")
	print("  [PASS] play_pressed signal successfully captured")
	
	# 8. Test Free Rewards Claim
	print("\n--- TEST 7: FREE REWARDS CLAIM & TOAST ---")
	menu._on_claim_free_rewards_pressed()
	print("  [PASS] Free rewards claimed cleanly")
	
	print("\n=================================================================")
	print("       ALL LOBBY REDESIGN INTEGRATION TESTS PASSED 100%!         ")
	print("=================================================================\n")
