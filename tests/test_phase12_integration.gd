extends SceneTree

const LoginCalendarModalScene = preload("res://scenes/ui/login_calendar_modal.tscn")
const DailyQuestsDrawerScene = preload("res://scenes/ui/daily_quests_drawer.tscn")
const InventoryPanelScene = preload("res://scenes/ui/inventory_panel.tscn")
const FriendsSquadPanelScene = preload("res://scenes/ui/friends_squad_panel.tscn")
const BrawlMainMenuScene = preload("res://scenes/ui/brawl_main_menu.tscn")
const ArcadeCarScene = preload("res://scenes/vehicles/arcade_car.tscn")

var pm: Node = null
var sm: Node = null
var sfm: Node = null
var vab: Node = null

func _init() -> void:
	print("==================================================================")
	print("PHASE 12 INTEGRATION TEST SUITE: DAILY GETAWAY & SQUAD LOBBY")
	print("==================================================================")
	
	await process_frame
	_setup_autoloads()
	await process_frame
	
	test_progression_manager_calendar()
	test_daily_quests_and_heist_safe()
	await test_3_slot_gear_loadout_and_visuals()
	test_social_friends_and_squad_lobby()
	await test_ui_scenes_and_brawl_main_menu()
	
	print("\n==================================================================")
	print("ALL PHASE 12 TESTS PASSED SUCCESSFULLY! (100% PASS RATE)")
	print("==================================================================")
	quit(0)

func _setup_autoloads() -> void:
	# Resolve or mount required Autoloads
	if root.has_node("SaveManager"):
		sm = root.get_node("SaveManager")
	elif root.has_node("/root/SaveManager"):
		sm = root.get_node("/root/SaveManager")
	else:
		sm = load("res://scripts/autoload/save_manager.gd").new()
		sm.name = "SaveManager"
		root.add_child(sm)
	
	if root.has_node("ProgressionManager"):
		pm = root.get_node("ProgressionManager")
	elif root.has_node("/root/ProgressionManager"):
		pm = root.get_node("/root/ProgressionManager")
	else:
		pm = load("res://scripts/autoload/progression_manager.gd").new()
		pm.name = "ProgressionManager"
		root.add_child(pm)
	
	if root.has_node("SocialFriendManager"):
		sfm = root.get_node("SocialFriendManager")
	elif root.has_node("/root/SocialFriendManager"):
		sfm = root.get_node("/root/SocialFriendManager")
	else:
		sfm = load("res://scripts/autoload/social_friend_manager.gd").new()
		sfm.name = "SocialFriendManager"
		root.add_child(sfm)
	
	if root.has_node("VoxelAssetBuilder"):
		vab = root.get_node("VoxelAssetBuilder")
	elif root.has_node("/root/VoxelAssetBuilder"):
		vab = root.get_node("/root/VoxelAssetBuilder")
	else:
		vab = load("res://scripts/autoload/voxel_asset_builder.gd").new()
		vab.name = "VoxelAssetBuilder"
		root.add_child(vab)

func assert_true(condition: bool, msg: String) -> void:
	if not condition:
		printerr("FAILED ASSERTION: %s" % msg)
		quit(1)
	else:
		print("  [PASS] %s" % msg)

func test_progression_manager_calendar() -> void:
	print("\n--- TEST 1: 7-DAY LOGIN CALENDAR SYSTEM ---")
	assert_true(pm != null, "ProgressionManager autoload is active")
	assert_true(sm != null, "SaveManager autoload is active")
	
	# Verify 7 reward definitions
	for day in range(1, 8):
		var r: Dictionary = pm.get_reward_for_day(day)
		assert_true(not r.is_empty(), "Day %d reward definition exists: %s" % [day, r.get("title", "")])
	
	# Reset calendar to Day 1 unspent state for deterministic testing
	pm.login_day_index = 1
	pm.last_claimed_login_utc = "2020-01-01"
	pm.claimed_login_days.clear()
	assert_true(pm.can_claim_today_login(), "Calendar recognizes unclaimed login today")
	
	# Claim Day 1 (+250 Cash)
	var cash_before: int = sm.total_cash
	var day1_rew: Dictionary = pm.claim_today_login()
	assert_true(day1_rew.get("amount", 0) == 250, "Day 1 awards +250 Cash")
	assert_true(sm.total_cash == cash_before + 250, "SaveManager total_cash incremented by +250")
	assert_true(pm.login_day_index == 2, "login_day_index advanced to 2")
	assert_true(not pm.can_claim_today_login(), "Cannot claim again on the same UTC day")
	
	# Force Day 2 claim ("underglow_cyan")
	pm.last_claimed_login_utc = "2020-01-01"
	var day2_rew: Dictionary = pm.claim_today_login()
	assert_true(day2_rew.get("item_id", "") == "underglow_cyan", "Day 2 awards Neon Cyan Underglow")
	assert_true("underglow_cyan" in sm.unlocked_items, "underglow_cyan unlocked in SaveManager")
	
	# Force Day 7 Grand Prize claim ("f1_street_kart" + 1000 cash)
	pm.login_day_index = 7
	pm.last_claimed_login_utc = "2020-01-01"
	var cash_pre7: int = sm.total_cash
	var day7_rew: Dictionary = pm.claim_today_login()
	assert_true(day7_rew.get("car_id", "") == "f1_street_kart", "Day 7 awards Apex Street F1")
	assert_true("f1_street_kart" in sm.unlocked_cars, "f1_street_kart unlocked in SaveManager")
	assert_true(sm.total_cash == cash_pre7 + 1000, "Day 7 grants +1,000 Cash bonus")
	assert_true(pm.login_day_index == 1, "Calendar loops back to Day 1 after Day 7 Grand Prize")

func test_daily_quests_and_heist_safe() -> void:
	print("\n--- TEST 2: 3 ROTATING DAILY QUESTS & DAILY HEIST SAFE ---")
	pm.check_daily_reset()
	assert_true(pm.daily_quests.size() == 3, "ProgressionManager maintains exactly 3 daily quests")
	
	# Reset quests for clean testing
	for q in pm.daily_quests:
		q["current"] = 0
		q["claimed"] = false
	pm.daily_heist_safe_claimed = false
	
	# Test Cop Wreck quest progression
	pm.add_quest_progress("cop_wreck", 3)
	assert_true(pm.daily_quests[0]["current"] == 3, "Cop Wreck quest received +3 progress")
	pm.add_quest_progress("cop_wreck", 3) # Reaches target 6
	assert_true(pm.daily_quests[0]["current"] == 6, "Cop Wreck quest reached target 6")
	
	# Claim Quest 1 reward
	var cash_pre_quest: int = sm.total_cash
	var claim_q1_success: bool = pm.claim_quest_reward("quest_cops")
	assert_true(claim_q1_success, "Successfully claimed completed quest_cops reward")
	assert_true(sm.total_cash == cash_pre_quest + 150, "SaveManager awarded +150 Cash for quest")
	
	# Complete Quest 2 (drift_time 20s) and Quest 3 (prop_smash 25)
	pm.add_drift_seconds(20.5)
	assert_true(pm.daily_quests[1]["current"] >= 20, "Drift quest completed via add_drift_seconds")
	pm.claim_quest_reward("quest_drift")
	
	pm.add_quest_progress("prop_smash", 25)
	assert_true(pm.daily_quests[2]["current"] >= 25, "Prop smash quest reached target 25")
	pm.claim_quest_reward("quest_props")
	
	assert_true(pm.get_claimed_quests_count() == 3, "All 3 daily quests claimed")
	assert_true(pm.can_claim_heist_safe(), "Heist Safe is unlocked and claimable (3/3 quests)")
	
	# Claim Heist Safe
	var cash_pre_safe: int = sm.total_cash
	var safe_res: Dictionary = pm.claim_heist_safe()
	assert_true(safe_res.get("cash", 0) >= 400, "Heist Safe awarded +400 Cash")
	assert_true(sm.total_cash >= cash_pre_safe + 400, "Total cash increased after cracking safe")
	assert_true(pm.daily_heist_safe_claimed, "daily_heist_safe_claimed flag marked true")

func test_3_slot_gear_loadout_and_visuals() -> void:
	print("\n--- TEST 3: 3-SLOT GEAR LOADOUT & 3D VISUAL ATTACHMENT ---")
	assert_true(vab != null, "VoxelAssetBuilder autoload is active")
	
	# Verify SaveManager methods
	sm.unlock_item("emp_dome")
	sm.unlock_item("trail_gold_flame")
	sm.unlock_item("armor_titanium")
	assert_true("emp_dome" in sm.unlocked_items, "emp_dome unlocked in SaveManager")
	
	sm.equip_gear_item("weapon_mod", "emp_dome")
	sm.equip_gear_item("drift_trail", "trail_gold_flame")
	sm.equip_gear_item("armor_mod", "armor_titanium")
	
	assert_true(sm.equipped_loadout["weapon_mod"] == "emp_dome", "Equipped weapon_mod emp_dome in SaveManager")
	assert_true(sm.equipped_loadout["drift_trail"] == "trail_gold_flame", "Equipped drift_trail trail_gold_flame")
	assert_true(sm.equipped_loadout["armor_mod"] == "armor_titanium", "Equipped armor_mod armor_titanium")
	
	# Test VoxelAssetBuilder.attach_gear_loadout on ArcadeCar
	var car: ArcadeCar = ArcadeCarScene.instantiate() as ArcadeCar
	root.add_child(car)
	await process_frame
	
	var gear_node: Node3D = vab.attach_gear_loadout(car.car_pivot, sm.equipped_loadout)
	assert_true(gear_node != null, "attach_gear_loadout created GearLoadoutNode on car pivot")
	assert_true(gear_node.get_node_or_null("EmpDomeLight") != null, "EmpDomeLight OmniLight3D mounted on roof")
	assert_true(gear_node.get_node_or_null("NeonUnderglowLight") != null, "NeonUnderglowLight mounted under chassis")
	
	# Verify ArcadeCar stat buffs
	car._apply_gear_stats(sm.equipped_loadout)
	assert_true(car.max_hp >= 200.0, "Titanium roll-cage increased max HP (+65 HP)")
	assert_true(car.gear_damage_reduction == 0.25, "Titanium armor grants 25% collision damage reduction")
	
	# Test Spiked Bumper knockback bonus
	sm.unlock_item("bumper_spiked")
	sm.equip_gear_item("armor_mod", "bumper_spiked")
	car._apply_gear_stats(sm.equipped_loadout)
	assert_true(car.gear_ram_knockback_bonus == 0.35, "Spiked bullbar grants +35% ram knockback on cops")
	
	car.queue_free()

func test_social_friends_and_squad_lobby() -> void:
	print("\n--- TEST 4: SOCIAL FRIEND CODES & 3D SQUAD LOBBY ---")
	assert_true(sfm != null, "SocialFriendManager autoload is active")
	
	# Friend Code check & clipboard
	var my_code: String = sfm.get_player_friend_code()
	assert_true(my_code.begins_with("#SH-"), "Generated valid Friend Code format: %s" % my_code)
	var copied: String = sfm.copy_friend_code_to_clipboard()
	assert_true(copied == my_code, "Clipboard correctly copied player friend code")
	
	# Add friend by code
	var added_buddy: Dictionary = sfm.add_friend_by_code("#SH-9021")
	assert_true(not added_buddy.is_empty(), "Successfully added friend by code #SH-9021")
	assert_true(sfm.get_friends_list().size() >= 4, "Friends list includes 3 demo buddies + new added buddy")
	
	# Invite to squad
	sfm.clear_squad()
	assert_true(sfm.active_squad_members.is_empty(), "Squad cleared to 0 peers")
	
	var invite_ok: bool = sfm.invite_friend_to_squad(added_buddy)
	assert_true(invite_ok, "Invited friend to active squad")
	assert_true(sfm.active_squad_members.size() == 1, "Squad now has 1 active peer (2 total with host)")
	assert_true(sfm.is_friend_in_squad(String(added_buddy.get("code", ""))), "is_friend_in_squad reports true")
	
	# Remove from squad
	sfm.remove_squad_member(0)
	assert_true(sfm.active_squad_members.is_empty(), "Removed member; squad is empty")

func test_ui_scenes_and_brawl_main_menu() -> void:
	print("\n--- TEST 5: UI SCENES & BRAWL MAIN MENU 5-TAB DOCK ---")
	
	# 1. LoginCalendarModal
	var calendar: Control = LoginCalendarModalScene.instantiate() as Control
	root.add_child(calendar)
	await process_frame
	assert_true(calendar != null, "LoginCalendarModal instantiated cleanly")
	calendar.refresh_calendar()
	calendar.queue_free()
	
	# 2. DailyQuestsDrawer
	var quests_drawer: Control = DailyQuestsDrawerScene.instantiate() as Control
	root.add_child(quests_drawer)
	await process_frame
	assert_true(quests_drawer != null, "DailyQuestsDrawer instantiated cleanly")
	quests_drawer.refresh_quests()
	quests_drawer.queue_free()
	
	# 3. InventoryPanel
	var inv_panel: Control = InventoryPanelScene.instantiate() as Control
	root.add_child(inv_panel)
	await process_frame
	assert_true(inv_panel != null, "InventoryPanel instantiated cleanly")
	inv_panel.refresh_inventory()
	inv_panel.queue_free()
	
	# 4. FriendsSquadPanel
	var squad_panel: Control = FriendsSquadPanelScene.instantiate() as Control
	root.add_child(squad_panel)
	await process_frame
	assert_true(squad_panel != null, "FriendsSquadPanel instantiated cleanly")
	squad_panel.refresh_all()
	squad_panel.queue_free()
	
	# 5. BrawlMainMenu 5-Tab Navigation Dock & Showroom Squad Stage
	var menu: Control = BrawlMainMenuScene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	assert_true(menu != null, "BrawlMainMenu instantiated cleanly")
	
	# Verify 5 tabs in bottom dock
	assert_true(menu._tab_buttons.size() == 5, "BrawlMainMenu has exactly 5 bottom tabs: HOME, CARS, GEAR, GACHA, SOCIAL")
	
	# Verify switching across all 5 tabs works without crashing or overlapping
	menu.switch_tab(0) # HOME
	assert_true(menu._showroom_ui_container.visible, "Tab 0: Showroom active")
	menu.switch_tab(1) # CARS
	assert_true((menu._cars_screen != null and menu._cars_screen.visible) or (menu._cars_drawer != null and menu._cars_drawer.visible), "Tab 1: Cars active")
	menu.switch_tab(2) # GEAR
	assert_true((menu._gear_screen != null and menu._gear_screen.visible) or (menu._inventory_drawer != null and menu._inventory_drawer.visible), "Tab 2: Gear active")
	menu.switch_tab(3) # GACHA
	assert_true((menu._gacha_screen != null and menu._gacha_screen.visible) or (menu._gacha_drawer != null and menu._gacha_drawer.visible), "Tab 3: Gacha active")
	menu.switch_tab(4) # SOCIAL
	assert_true(menu._friends_squad_drawer != null and menu._friends_squad_drawer.visible, "Tab 4: Social & squad drawer active")
	
	# Verify 3D Squad Pedestals in Showroom
	assert_true(menu._squad_pedestals.size() == 3, "Showroom world has 3 3D squad pedestals for invited friends")
	
	menu.queue_free()
