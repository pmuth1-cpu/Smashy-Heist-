class_name DailySeedManagerClass
extends Node

## Seed modes supported by the game
enum SeedMode {
	DAILY_CHALLENGE,
	ENDLESS_RANDOM
}

const MODIFIER_NAMES: Array[String] = [
	"Standard Getaway",
	"Turbo Drift (1.25x Speed & Extra Slippery Roads)",
	"Heavy Bumper (2x Knockback on Props & Rivals)",
	"Bridge Mayhem (Double River & Jump Ramp Frequency)"
]

const MODIFIER_DETAILS: Array[Dictionary] = [
	{
		"index": 0,
		"name": "Standard Getaway",
		"description": "Standard rules and physics balance.",
		"speed_multiplier": 1.0,
		"grip_multiplier": 1.0,
		"knockback_multiplier": 1.0,
		"ramp_frequency": 1.0
	},
	{
		"index": 1,
		"name": "Turbo Drift (1.25x Speed & Extra Slippery Roads)",
		"description": "1.25x Speed and extra slippery roads for high-speed slides.",
		"speed_multiplier": 1.25,
		"grip_multiplier": 0.65,
		"knockback_multiplier": 1.0,
		"ramp_frequency": 1.0
	},
	{
		"index": 2,
		"name": "Heavy Bumper (2x Knockback on Props & Rivals)",
		"description": "2x knockback on collision impacts against props and police.",
		"speed_multiplier": 1.0,
		"grip_multiplier": 1.0,
		"knockback_multiplier": 2.0,
		"ramp_frequency": 1.0
	},
	{
		"index": 3,
		"name": "Bridge Mayhem (Double River & Jump Ramp Frequency)",
		"description": "Double the frequency of stunt jump ramps, rivers, and canal crossings.",
		"speed_multiplier": 1.0,
		"grip_multiplier": 1.0,
		"knockback_multiplier": 1.0,
		"ramp_frequency": 2.0
	}
]

signal seed_initialized(mode: SeedMode, seed_value: int, modifier_index: int)

var current_mode: SeedMode = SeedMode.DAILY_CHALLENGE
var base_seed: int = 0
var daily_modifier_index: int = 0
var utc_date_string: String = ""

func _ready() -> void:
	init_seed(SeedMode.DAILY_CHALLENGE)

## Initializes the seed according to the selected mode.
func init_seed(mode: SeedMode, custom_seed: int = 0) -> void:
	current_mode = mode
	
	if current_mode == SeedMode.DAILY_CHALLENGE:
		utc_date_string = Time.get_date_string_from_system(true)
		base_seed = utc_date_string.hash()
		daily_modifier_index = absi(base_seed) % 4
	else:
		utc_date_string = "ENDLESS"
		base_seed = custom_seed if custom_seed != 0 else randi()
		daily_modifier_index = absi(base_seed) % 4
	
	seed_initialized.emit(current_mode, base_seed, daily_modifier_index)
	print("DailySeedManager: Mode=%s, BaseSeed=%d, Modifier=%s" % [
		"DAILY_CHALLENGE" if current_mode == SeedMode.DAILY_CHALLENGE else "ENDLESS_RANDOM",
		base_seed,
		get_modifier_name()
	])

## Deterministic RNG generator for any world chunk (chunk_coord.x, chunk_coord.y).
## Guarantees that chunk (x, z) always generates the exact same layout regardless of travel route.
func get_chunk_rng(chunk_coord: Vector2i) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(chunk_coord.x, chunk_coord.y, base_seed))
	return rng

## Returns the active Daily Wanted Modifier title.
func get_modifier_name() -> String:
	return MODIFIER_NAMES[daily_modifier_index]

## Returns the dictionary containing gameplay tuning variables for the active modifier.
func get_modifier_data() -> Dictionary:
	return MODIFIER_DETAILS[daily_modifier_index]

## Returns a formatted string suitable for the HUD badge (e.g. "DAILY 2026-10-15").
func get_daily_badge_text() -> String:
	if current_mode == SeedMode.DAILY_CHALLENGE:
		return "DAILY " + utc_date_string
	return "SEED #%04d" % (absi(base_seed) % 10000)
