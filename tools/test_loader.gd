extends SceneTree

func _init() -> void:
	var paths = [
		"res://assets/ribbons/ribbon_header_paused.png",
		"res://assets/ribbons/ribbon_header_rewards.png",
		"res://assets/ribbons/ribbon_header_quests.png",
		"res://assets/ui/btn_round_close_x.png",
		"res://assets/ui/btn_candy_green.png"
	]
	for p in paths:
		var f_exists = FileAccess.file_exists(p)
		var r_exists = ResourceLoader.exists(p)
		var tex = load(p) if r_exists else null
		print("Path: ", p, " | FileExists: ", f_exists, " | ResExists: ", r_exists, " | Tex: ", tex)
	quit(0)
