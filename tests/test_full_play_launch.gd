extends SceneTree

const BrawlMainMenuScene = preload("res://scenes/ui/brawl_main_menu.tscn")
const MainGameScene = preload("res://scenes/world/main_game.tscn")

const GameModeManagerScript = preload("res://scripts/autoload/game_mode_manager.gd")
const AssetChromaLoaderScript = preload("res://scripts/autoload/asset_chroma_loader.gd")

func _init() -> void:
	print("\n--- TESTING FULL PLAY LAUNCH FOR ALL 4 MODES ---")
	if not root.has_node("AssetChromaLoader"):
		var acl := AssetChromaLoaderScript.new()
		acl.name = "AssetChromaLoader"
		root.add_child(acl)
	
	if not root.has_node("GameModeManager"):
		var gmm := GameModeManagerScript.new()
		gmm.name = "GameModeManager"
		root.add_child(gmm)
	
	_run_suite()

func _run_suite() -> void:
	await process_frame
	await process_frame
	
	var gmm = root.get_node_or_null("GameModeManager")
	assert(gmm != null, "GameModeManager must be autoloaded")
	
	for mode_id in range(4):
		print("\nTesting launch for Mode %d..." % mode_id)
		gmm.set_mode(mode_id)
		var game: MainGame = MainGameScene.instantiate() as MainGame
		root.add_child(game)
		
		# Give physics/processes a moment
		await process_frame
		await process_frame
		
		match mode_id:
			0:
				assert(not game.hot_loot_mode.is_hot_loot_mode, "Mode 0: Hot Loot must be inactive")
				print("  [PASS] Mode 0 (Daily Getaway) launched successfully")
			1:
				assert(game.boss_escape_mode != null, "Mode 1: Boss escape mode must exist")
				print("  [PASS] Mode 1 (Mega Boss Escape) launched successfully")
			2:
				assert(game.hot_loot_mode.is_hot_loot_mode, "Mode 2: Hot Loot must be active")
				print("  [PASS] Mode 2 (Hot Loot Tag) launched successfully")
			3:
				assert(game.smashy_kart_mode != null, "Mode 3: Smashy Kart mode must exist")
				assert(game.smashy_kart_mode.is_countdown_active or game.smashy_kart_mode.is_race_active or game.smashy_kart_mode.all_racers.size() == 6, "Mode 3: Racers initialized")
				print("  [PASS] Mode 3 (Smashy Kart GP) launched successfully")
		
		game.queue_free()
		await process_frame
	
	print("\n--- ALL 4 MODES LAUNCH AND PLAY CLEANLY (100%) ---")
	quit(0)
