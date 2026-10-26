extends SceneTree

const BrawlMainMenuScene = preload("res://scenes/ui/brawl_main_menu.tscn")
const GameModeManagerScript = preload("res://scripts/autoload/game_mode_manager.gd")
const AssetChromaLoaderScript = preload("res://scripts/autoload/asset_chroma_loader.gd")

func _init() -> void:
	print("\n=================================================================")
	print("       STARTING MODE SELECTION & NO-BANK-HEIST VERIFICATION      ")
	print("=================================================================\n")
	
	if not root.has_node("AssetChromaLoader"):
		var acl := AssetChromaLoaderScript.new()
		acl.name = "AssetChromaLoader"
		root.add_child(acl)
		acl._ready()
	
	if not root.has_node("GameModeManager"):
		var gmm := GameModeManagerScript.new()
		gmm.name = "GameModeManager"
		root.add_child(gmm)
		gmm._ready()
	
	await process_frame
	await process_frame
	
	_run_tests()
	quit(0)

func _run_tests() -> void:
	# TEST 1: GameModeManager has NO Bank Heist and has 4 clean modes
	print("--- TEST 1: GAMEMODEMANAGER MODES (NO BANK HEIST) ---")
	var gmm = root.get_node("GameModeManager")
	
	assert(gmm.get_mode_count() == 4, "Must have exactly 4 game modes (found %d)" % gmm.get_mode_count())
	assert(GameModeManagerClass.GameMode.DAILY_ENDLESS_GETAWAY == 0, "Mode 0 is Daily Endless")
	assert(GameModeManagerClass.GameMode.ESCAPE_MEGA_BOSS == 1, "Mode 1 is Escape Mega Boss")
	assert(GameModeManagerClass.GameMode.HOT_LOOT_4P_TAG == 2, "Mode 2 is Hot Loot 4P Tag")
	assert(GameModeManagerClass.GameMode.SMASHY_KART_GP == 3, "Mode 3 is Smashy Kart GP")
	
	for mid in range(4):
		var info: Dictionary = gmm.get_mode_info(mid)
		assert(not "BANK HEIST" in str(info.get("title", "")), "Bank Heist must not be in mode %d" % mid)
		print("  [PASS] Mode %d: %s" % [mid, str(info.get("title", ""))])
	
	# TEST 2: BrawlMainMenu Mode Selection Drawer
	print("\n--- TEST 2: BRAWL MAIN MENU MODE SELECTION MODAL ---")
	var menu: BrawlMainMenu = BrawlMainMenuScene.instantiate() as BrawlMainMenu
	root.add_child(menu)
	menu._ready()
	
	assert(BrawlMainMenu.MODE_DEFS.size() == 4, "MODE_DEFS must have 4 entries (found %d)" % BrawlMainMenu.MODE_DEFS.size())
	for def in BrawlMainMenu.MODE_DEFS:
		assert(not "BANK HEIST" in str(def.get("name", "")), "Bank Heist must not be in MODE_DEFS")
	print("  [PASS] MODE_DEFS verified without Bank Heist")
	
	# Verify mode card button and modal
	assert(menu._mode_card_btn != null, "_mode_card_btn must exist")
	assert(menu._mode_drawer_panel != null, "_mode_drawer_panel must exist")
	assert(not menu._mode_drawer_panel.visible, "Modal must start hidden")
	
	# Toggle open
	menu._toggle_mode_drawer()
	assert(menu._mode_drawer_panel.visible, "Modal must become visible when toggled")
	assert(menu._mode_drawer_panel.z_index >= 200, "Modal must have high z_index (found %d)" % menu._mode_drawer_panel.z_index)
	print("  [PASS] Modal opens on top with high z-index (z=%d)" % menu._mode_drawer_panel.z_index)
	
	# Select Mode 1 (Boss Escape)
	gmm.set_mode(1)
	menu.current_mode_index = 1
	menu._refresh_mode_display()
	assert(menu._mode_title_label.text == "🕷️ BOSS ESCAPE", "Title must reflect Boss Escape")
	print("  [PASS] Selecting Mode 1 (Boss Escape) updates display: %s" % menu._mode_title_label.text)
	
	# Select Mode 3 (Smashy Kart GP) and set track
	gmm.set_mode(3)
	gmm.set_kart_cup_track(GameModeManagerClass.KartCupTrack.CHINATOWN_DRAGON_LOOP)
	menu.current_mode_index = 3
	menu._refresh_mode_display()
	assert("KART" in menu._mode_title_label.text and "Dragon" in menu._mode_title_label.text, "Title must reflect Chinatown Dragon Loop")
	print("  [PASS] Selecting Kart GP and Cup Track updates display: %s" % menu._mode_title_label.text)
	
	# Toggle close
	menu._toggle_mode_drawer()
	assert(not menu._mode_drawer_panel.visible, "Modal must close when toggled off")
	print("  [PASS] Modal close verified")

	print("\n=================================================================")
	print("     ALL MODE SELECTION & NO-BANK-HEIST TESTS PASSED! (100%)     ")
	print("=================================================================\n")
