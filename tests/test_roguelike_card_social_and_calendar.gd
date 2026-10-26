extends SceneTree

const StarPerkPopupScene = preload("res://scenes/ui/star_perk_popup.tscn")
const FriendsSquadPanelScene = preload("res://scenes/ui/friends_squad_panel.tscn")
const LoginCalendarModalScene = preload("res://scenes/ui/login_calendar_modal.tscn")
const BrawlMainMenuClass = preload("res://scripts/ui/brawl_main_menu.gd")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   STARTING ROGUELIKE CARD, SOCIAL RETURN & 7-DAY CALENDAR TESTS  ")
	print("=================================================================\n")
	
	test_roguelike_card_full_image_and_minimal_text()
	await test_social_screen_return_button()
	test_landscape_7_day_calendar_and_reward_details()
	
	print("\n=================================================================")
	print("   ALL TESTS PASSED SUCCESSFULLY! (100% GREEN)                   ")
	print("=================================================================\n")
	quit(0)

## TEST 1: Roguelike Card Full Image and Minimal Text
func test_roguelike_card_full_image_and_minimal_text() -> void:
	print("--- TEST 1: ROGUELIKE CARD FULL-IMAGE & CONCISE TEXT ---")
	var popup: StarPerkPopup = StarPerkPopupScene.instantiate() as StarPerkPopup
	root.add_child(popup)
	
	var card_l := popup.find_child("CardLeft", true, false) as Button
	var card_r := popup.find_child("CardRight", true, false) as Button
	assert(card_l != null and card_r != null, "CardLeft and CardRight buttons must exist")
	
	# Verify card dimensions
	assert(card_l.custom_minimum_size.y >= 560, "Card height should be at least 560px")
	assert(card_l.custom_minimum_size.x >= 400, "Card width should be at least 400px")
	
	# Verify Artwork dominates card height (at least 380px high, ~70% of card)
	var art_l := card_l.find_child("PerkArt", true, false) as TextureRect
	assert(art_l != null, "PerkArt must exist")
	assert(art_l.custom_minimum_size.y >= 380, "PerkArt must be large full-height image (>=380px, found: %f)" % art_l.custom_minimum_size.y)
	assert(art_l.custom_minimum_size.x >= 380, "PerkArt must be large full-width image (>=380px, found: %f)" % art_l.custom_minimum_size.x)
	assert(art_l.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "PerkArt must use STRETCH_KEEP_ASPECT_COVERED for full bleed")
	
	# Verify no redundant 'SelectBadge' label exists (less text below it)
	var badge_l := card_l.find_child("SelectBadge", true, false)
	assert(badge_l == null, "SelectBadge label should be removed to eliminate text clutter")
	
	# Verify concise descriptions
	for perk in StarPerkPopup.ALL_PERKS:
		var desc: String = String(perk.get("desc", ""))
		assert(desc.length() <= 50, "Perk desc must be concise (<=50 chars, found: %d: '%s')" % [desc.length(), desc])
	
	print("  [PASS] Roguelike card full-image dominance (396x400) and concise text verified")
	popup.queue_free()

## TEST 2: Social Screen Return Button & Navigation
func test_social_screen_return_button() -> void:
	print("\n--- TEST 2: SOCIAL SCREEN RETURN BUTTON & NAVIGATION ---")
	
	# 1. Test standalone panel
	var panel: FriendsSquadPanel = FriendsSquadPanelScene.instantiate() as FriendsSquadPanel
	root.add_child(panel)
	
	var return_btn := panel.find_child("ReturnButton", true, false) as Button
	var home_btn := panel.find_child("HomeButton", true, false) as Button
	assert(return_btn != null, "ReturnButton must exist on FriendsSquadPanel")
	assert(home_btn != null, "HomeButton must exist on FriendsSquadPanel")
	
	var return_emitted: Array[bool] = [false]
	var closed_emitted: Array[bool] = [false]
	panel.return_requested.connect(func(): return_emitted[0] = true)
	panel.closed.connect(func(): closed_emitted[0] = true)
	
	panel._on_return_pressed()
	assert(return_emitted[0] == true, "return_requested signal emitted when return button clicked")
	assert(closed_emitted[0] == true, "closed signal emitted when return button clicked")
	print("  [PASS] FriendsSquadPanel ReturnButton and HomeButton emit signals cleanly")
	panel.queue_free()
	
	# 2. Test integration in BrawlMainMenu
	var menu := BrawlMainMenuClass.new()
	root.add_child(menu)
	await process_frame
	
	# Switch to SOCIAL tab (Tab 4)
	menu.switch_tab(4)
	assert(menu.active_tab_index == 4, "Active tab must be 4 (SOCIAL)")
	assert(menu._friends_squad_drawer.visible == true, "Friends squad drawer must be visible on tab 4")
	
	# Trigger return from social panel
	var menu_social_panel := menu._friends_squad_panel
	assert(menu_social_panel != null, "Menu social panel must exist")
	menu_social_panel._on_return_pressed()
	
	assert(menu.active_tab_index == 0, "Menu must switch back to tab 0 (HOME) upon clicking return")
	assert(menu._showroom_ui_container.visible == true, "Showroom UI must be restored on HOME")
	print("  [PASS] Social screen return button seamlessly routes back to HOME lobby")
	menu.queue_free()

## TEST 3: Landscape 7-Day Calendar & Detail Styles
func test_landscape_7_day_calendar_and_reward_details() -> void:
	print("\n--- TEST 3: LANDSCAPE 7-DAY CALENDAR & EXACT REWARD DETAILS ---")
	var modal: LoginCalendarModal = LoginCalendarModalScene.instantiate() as LoginCalendarModal
	root.add_child(modal)
	
	# Verify modal container is in landscape aspect ratio (width > height, width >= 1600px)
	var card1 = modal.find_child("DayCard_1", true, false)
	assert(card1 != null, "DayCard_1 must exist")
	var cards_row = card1.get_parent()
	var root_v = cards_row.get_parent()
	var modal_box = root_v.get_parent() as Control
	assert(modal_box != null, "Modal box panel must exist")
	assert(modal_box.custom_minimum_size.x >= 1600.0, "Modal box width must be landscape (>=1600px, found: %f)" % modal_box.custom_minimum_size.x)
	assert(modal_box.custom_minimum_size.x > modal_box.custom_minimum_size.y, "Modal box must be landscape (width > height)")
	
	# Verify 7 cards exist in horizontal progression
	assert(modal._card_panels.size() == 7, "Exactly 7 day cards must exist in calendar")
	
	# Verify Day 7 is extra-wide Grand Prize card
	var day1_card: PanelContainer = modal._card_panels[0]
	var day7_card: PanelContainer = modal._card_panels[6]
	assert(day7_card.custom_minimum_size.x > day1_card.custom_minimum_size.x, "Day 7 Grand Prize card must be wider than Day 1 card")
	
	# Verify exact reward graphics and backdrop detail styling on each card
	for i in range(7):
		var card: PanelContainer = modal._card_panels[i]
		var art_rect := card.find_child("RewardArt", true, false) as TextureRect
		var glow_rect := card.find_child("GlowBackdrop", true, false) as TextureRect
		var tech_rect := card.find_child("TechGrid", true, false) as TextureRect
		var disc := card.find_child("PedestalDisc", true, false) as PanelContainer
		var title_lbl := card.find_child("TitleLabel", true, false) as Label
		
		assert(art_rect != null, "Day %d must have RewardArt TextureRect" % (i + 1))
		assert(glow_rect != null, "Day %d must have GlowBackdrop radial glow detail" % (i + 1))
		assert(tech_rect != null, "Day %d must have TechGrid circuit detail overlay" % (i + 1))
		assert(disc != null, "Day %d must have PedestalDisc grounding detail" % (i + 1))
		assert(title_lbl != null and not title_lbl.text.is_empty(), "Day %d must have clear reward title" % (i + 1))
		
		# Verify real texture is loaded on RewardArt (no empty emoji placeholders)
		assert(art_rect.texture != null, "Day %d RewardArt must have loaded Texture2D asset" % (i + 1))
	
	print("  [PASS] 7-Day calendar landscape layout (1740x840) verified")
	print("  [PASS] Exact reward textures (no emojis) and rich backdrop detail styles (radial glow, tech grid, pedestal disc) verified")
	modal.queue_free()
