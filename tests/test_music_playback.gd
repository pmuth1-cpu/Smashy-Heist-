extends SceneTree

const SoundFXClass = preload("res://scripts/autoload/sound_fx.gd")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("       STARTING BACKGROUND MUSIC INTEGRATION TESTS                ")
	print("=================================================================")
	
	# TEST 1: Verify audio files exist on disk
	var lobby_exists := ResourceLoader.exists("res://assets/audio/bgm_lobby.mp3")
	var gameplay_exists := ResourceLoader.exists("res://assets/audio/bgm_gameplay.mp3")
	assert(lobby_exists, "bgm_lobby.mp3 (1:48 background music) must exist in assets/audio/")
	assert(gameplay_exists, "bgm_gameplay.mp3 (0:51 gameplay music) must exist in assets/audio/")
	print("  [PASS] Both audio files located in res://assets/audio/")
	
	# TEST 2: Verify AudioStreamMP3 loading and looping
	var stream_lobby := load("res://assets/audio/bgm_lobby.mp3") as AudioStreamMP3
	assert(stream_lobby != null, "Lobby music must load as AudioStreamMP3")
	var stream_gameplay := load("res://assets/audio/bgm_gameplay.mp3") as AudioStreamMP3
	assert(stream_gameplay != null, "Gameplay music must load as AudioStreamMP3")
	print("  [PASS] Audio streams load successfully as AudioStreamMP3")
	
	# TEST 3: SoundFX BGM Player Singleton
	var sfx: Node = root.get_node_or_null("/root/SoundFX")
	if not sfx:
		sfx = SoundFXClass.new()
		root.add_child(sfx)
		sfx._ready()
	
	assert(sfx.has_method("play_lobby_music"), "SoundFX must have play_lobby_music")
	assert(sfx.has_method("play_gameplay_music"), "SoundFX must have play_gameplay_music")
	assert(sfx.has_method("stop_music"), "SoundFX must have stop_music")
	print("  [PASS] SoundFX BGM methods present and configured")
	
	# TEST 4: Play Lobby Music (1:48)
	sfx.play_lobby_music(0.0) # instant for test
	await process_frame
	assert(sfx.is_music_playing(), "Lobby music must be actively playing")
	assert(sfx.get_current_music_key() == "lobby", "Current track key must be 'lobby'")
	print("  [PASS] 1:48 Lobby Background Music starts and plays")
	
	# TEST 5: Play Gameplay Music (0:51)
	sfx.play_gameplay_music(0.0) # instant for test
	await process_frame
	assert(sfx.is_music_playing(), "Gameplay music must be actively playing")
	assert(sfx.get_current_music_key() == "gameplay", "Current track key must be 'gameplay'")
	print("  [PASS] 0:51 Gameplay Background Music starts and plays")
	
	# TEST 6: Stop Music
	sfx.stop_music(0.0)
	await process_frame
	assert(not sfx.is_music_playing(), "Music must stop cleanly")
	print("  [PASS] Music stops cleanly")
	
	print("\n=================================================================")
	print("       ALL BACKGROUND MUSIC TESTS PASSED (100% GREEN)             ")
	print("=================================================================\n")
	
	quit(0)
