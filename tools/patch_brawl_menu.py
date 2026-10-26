import os
import re

MENU_PATH = r"D:\My project\smashy heist\scripts\ui\brawl_main_menu.gd"

with open(MENU_PATH, "r", encoding="utf-8") as f:
    code = f.read()

# 1. Variables
old_vars = """# Layer 2 (Top Bar)
var _trophy_label: Label = null
var _streak_label: Label = null
var _cash_label: Label = null

# Layer 3 (Home Dock)
var _home_dock_container: Control = null
var _mode_card_btn: Button = null
var _mode_title_label: Label = null
var _mode_desc_label: Label = null
var _smash_play_button: Button = null
var _mode_drawer_panel: PanelContainer = null

# Layer 4 (Bottom Dock)
var _bottom_dock_container: PanelContainer = null
var _tab_buttons: Array[Button] = []
var _tab_highlight_bar: ColorRect = null
var _highlight_tween: Tween = null"""

new_vars = """# Layer 2 (Top Bar & Side Cards)
var _trophy_label: Label = null
var _streak_label: Label = null
var _cash_label: Label = null
var _level_label: Label = null
var _level_progress_bar: ProgressBar = null
var _shop_btn: Button = null

# Side Cards (Left & Right)
var _side_cards_container: Control = null
var _quests_card_btn: Button = null
var _quests_progress_bar: ProgressBar = null
var _quests_progress_label: Label = null
var _event_card_btn: Button = null
var _event_timer_label: Label = null
var _map_card_btn: Button = null
var _free_rewards_card_btn: Button = null

# Layer 3 (Home Dock)
var _home_dock_container: Control = null
var _mode_card_btn: Button = null
var _mode_title_label: Label = null
var _mode_desc_label: Label = null
var _mode_thumb_rect: TextureRect = null
var _smash_play_button: Control = null
var _mode_drawer_panel: PanelContainer = null

# Layer 4 (Bottom Dock)
var _bottom_dock_container: PanelContainer = null
var _tab_buttons: Array[Button] = []
var _tab_labels: Array[Label] = []
var _tab_icons: Array[TextureRect] = []
var _tab_highlight_bar: ColorRect = null
var _highlight_tween: Tween = null"""

if old_vars in code:
    code = code.replace(old_vars, new_vars)
    print("Variables replaced successfully")
else:
    print("Variables already modified or not found")

# 2. Layer 0 Background
old_l0 = """func _build_layer_0_background() -> void:
\tvar backdrop := ColorRect.new()
\tbackdrop.name = "Layer0_Backdrop"
\tbackdrop.set_anchors_preset(PRESET_FULL_RECT)
\tbackdrop.color = Color("0a1931")
\tbackdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tadd_child(backdrop)
\t
\t# Subtle gradient overlay
\tvar grad_rect := TextureRect.new()
\tgrad_rect.set_anchors_preset(PRESET_FULL_RECT)
\tgrad_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
\tgrad_rect.stretch_mode = TextureRect.STRETCH_SCALE
\tgrad_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t
\tvar grad := Gradient.new()
\tgrad.colors = PackedColorArray([Color("150050"), Color("0a1931"), Color("050814")])
\tgrad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
\tvar grad_tex := GradientTexture2D.new()
\tgrad_tex.gradient = grad
\tgrad_tex.fill = GradientTexture2D.FILL_RADIAL
\tgrad_tex.fill_from = Vector2(0.5, 0.42)
\tgrad_tex.fill_to = Vector2(0.85, 0.85)
\tgrad_rect.texture = grad_tex
\tadd_child(grad_rect)"""

new_l0 = """func _build_layer_0_background() -> void:
\tvar backdrop := ColorRect.new()
\tbackdrop.name = "Layer0_Backdrop"
\tbackdrop.set_anchors_preset(PRESET_FULL_RECT)
\tbackdrop.color = Color("0a1931")
\tbackdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tadd_child(backdrop)
\t
\t# High quality cyber hangar backdrop matching the exact design specification
\tvar acl = get_node_or_null("/root/AssetChromaLoader")
\tvar bg_tex: Texture2D = null
\tif acl:
\t\tbg_tex = acl.load_texture("res://assets/splash/lobby_hangar_bg.png")
\telif ResourceLoader.exists("res://assets/splash/lobby_hangar_bg.png"):
\t\tbg_tex = load("res://assets/splash/lobby_hangar_bg.png")
\t
\tif bg_tex:
\t\tvar bg_rect := TextureRect.new()
\t\tbg_rect.name = "HangarBackdrop"
\t\tbg_rect.set_anchors_preset(PRESET_FULL_RECT)
\t\tbg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
\t\tbg_rect.stretch_mode = TextureRect.STRETCH_SCALE
\t\tbg_rect.texture = bg_tex
\t\tbg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t\tadd_child(bg_rect)
\t
\t# Subtle vignette gradient overlay
\tvar grad_rect := TextureRect.new()
\tgrad_rect.set_anchors_preset(PRESET_FULL_RECT)
\tgrad_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
\tgrad_rect.stretch_mode = TextureRect.STRETCH_SCALE
\tgrad_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t
\tvar grad := Gradient.new()
\tgrad.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), Color("050b16", 0.45), Color("03060c", 0.85)])
\tgrad.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
\tvar grad_tex := GradientTexture2D.new()
\tgrad_tex.gradient = grad
\tgrad_tex.fill = GradientTexture2D.FILL_RADIAL
\tgrad_tex.fill_from = Vector2(0.5, 0.45)
\tgrad_tex.fill_to = Vector2(0.9, 0.9)
\tgrad_rect.texture = grad_tex
\tadd_child(grad_rect)"""

if old_l0 in code:
    code = code.replace(old_l0, new_l0)
    print("Layer 0 replaced successfully")
else:
    print("Layer 0 not found or already modified")

with open(MENU_PATH, "w", encoding="utf-8") as f:
    f.write(code)

print("Patch 1 done")
