extends SceneTree

func _init() -> void:
	var vdb = load("res://scripts/autoload/vehicle_database.gd").new()
	var cars = vdb.VEHICLES
	
	print("\n--- VEHICLE STATS & GADGET AUDIT (%d cars) ---" % cars.size())
	
	var gadgets = {}
	var hp_values = {}
	var speed_values = {}
	
	for id in cars:
		var c = cars[id]
		var gid = String(c.get("gadget_id", "NONE"))
		var gname = String(c.get("gadget_name", "NONE"))
		var hp = float(c.get("max_hp", 180.0))
		var spd = float(c.get("speed", 0.65))
		
		gadgets[gid] = gadgets.get(gid, 0) + 1
		hp_values[hp] = hp_values.get(hp, 0) + 1
		speed_values[spd] = speed_values.get(spd, 0) + 1
	
	print("\nDistinct Gadget IDs: %d" % gadgets.size())
	for gid in gadgets:
		print("  - %-25s : used by %d cars" % [gid, gadgets[gid]])
		
	print("\nDistinct Max HP values: %d" % hp_values.size())
	for hp in hp_values:
		print("  - HP %5.1f : %d cars" % [hp, hp_values[hp]])
		
	print("\nDistinct Speed values: %d" % speed_values.size())
	for spd in speed_values:
		print("  - Speed %4.2f : %d cars" % [spd, speed_values[spd]])
		
	quit(0)
