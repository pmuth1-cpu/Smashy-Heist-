extends Node

## Procedural Arcade Sound Synthesizer Singleton (AudioStreamGenerator)
## Registered as Autoload "SoundFX" in project.godot
## Generates 100% self-contained dynamic audio waveforms with zero external audio assets.

const MIX_RATE: int = 22050
const BUFFER_LENGTH: float = 0.25
const POOL_SIZE: int = 6

var _players: Array[AudioStreamPlayer] = []
var _generators: Array[AudioStreamGenerator] = []
var _playbacks: Array[AudioStreamGeneratorPlayback] = []
var _pending_buffers: Array[PackedVector2Array] = []
var _pending_indices: Array[int] = []
var _current_player_idx: int = 0

var _ui_click_frames: PackedVector2Array = PackedVector2Array()
var _smash_hit_frames: PackedVector2Array = PackedVector2Array()
var _explosion_frames: PackedVector2Array = PackedVector2Array()
var _drift_boost_frames: PackedVector2Array = PackedVector2Array()
var _star_up_frames: PackedVector2Array = PackedVector2Array()
var _bass_impact_frames: PackedVector2Array = PackedVector2Array()
var _gunshot_frames: PackedVector2Array = PackedVector2Array()
var _spike_frames: PackedVector2Array = PackedVector2Array()
var _low_hp_frames: PackedVector2Array = PackedVector2Array()

const LOBBY_MUSIC_PATH: String = "res://assets/audio/bgm_lobby.mp3"
const GAMEPLAY_MUSIC_PATH: String = "res://assets/audio/bgm_gameplay.mp3"

var _music_player: AudioStreamPlayer = null
var _current_music_key: String = ""
var _music_fade_tween: Tween = null
var _music_volume_db: float = -6.0
var _is_music_muted: bool = false

static var _instance: Node = null

func _init() -> void:
	_instance = self

func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_music_player()
	_players.resize(POOL_SIZE)
	_generators.resize(POOL_SIZE)
	_playbacks.resize(POOL_SIZE)
	_pending_buffers.resize(POOL_SIZE)
	_pending_indices.resize(POOL_SIZE)
	
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "AudioPlayer_%d" % i
		p.bus = "Master"
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = float(MIX_RATE)
		gen.buffer_length = BUFFER_LENGTH
		p.stream = gen
		add_child(p)
		p.play()
		_players[i] = p
		_generators[i] = gen
		_playbacks[i] = p.get_stream_playback() as AudioStreamGeneratorPlayback
		_pending_buffers[i] = PackedVector2Array()
		_pending_indices[i] = 0
	
	_bake_waveforms()

func _process(_delta: float) -> void:
	for i in range(POOL_SIZE):
		var buf: PackedVector2Array = _pending_buffers[i]
		var cur_pos: int = _pending_indices[i]
		if buf.is_empty() or cur_pos >= buf.size():
			continue
		
		var playback: AudioStreamGeneratorPlayback = _playbacks[i]
		if not playback:
			continue
		
		var avail: int = playback.get_frames_available()
		if avail <= 0:
			continue
		
		var count: int = mini(avail, buf.size() - cur_pos)
		for j in range(count):
			playback.push_frame(buf[cur_pos + j])
		
		cur_pos += count
		_pending_indices[i] = cur_pos
		if cur_pos >= buf.size():
			_pending_buffers[i] = PackedVector2Array()
			_pending_indices[i] = 0

func _play_burst(frames: PackedVector2Array) -> void:
	if frames.is_empty():
		return
	
	var idx: int = _current_player_idx
	_current_player_idx = (_current_player_idx + 1) % POOL_SIZE
	
	var p: AudioStreamPlayer = _players[idx]
	if not p.playing:
		p.play()
	
	var playback: AudioStreamGeneratorPlayback = _playbacks[idx]
	if not playback:
		playback = p.get_stream_playback() as AudioStreamGeneratorPlayback
		_playbacks[idx] = playback
	
	if not playback:
		return
	
	var avail: int = playback.get_frames_available()
	var to_push: int = mini(avail, frames.size())
	for i in range(to_push):
		playback.push_frame(frames[i])
	
	if to_push < frames.size():
		_pending_buffers[idx] = frames
		_pending_indices[idx] = to_push
	else:
		_pending_buffers[idx] = PackedVector2Array()
		_pending_indices[idx] = 0

## 60ms rising sine/triangle chirp (420 Hz -> 680 Hz)
static func play_ui_click() -> void:
	if _instance and _instance.has_method("_play_burst"):
		_instance._play_burst(_instance.get("_ui_click_frames"))

## 110ms punchy low-pass noise + 140 Hz -> 55 Hz pitch-drop thud
static func play_smash_hit() -> void:
	if _instance and _instance.has_method("_play_burst"):
		_instance._play_burst(_instance.get("_smash_hit_frames"))

## 380ms layered white-noise rumble with exponential decay
static func play_explosion() -> void:
	if _instance and _instance.has_method("_play_burst"):
		_instance._play_burst(_instance.get("_explosion_frames"))

## 220ms rising sawtooth whoosh (220 Hz -> 880 Hz)
static func play_drift_boost() -> void:
	if _instance and _instance.has_method("_play_burst"):
		_instance._play_burst(_instance.get("_drift_boost_frames"))

## 3-note ascending major arpeggio chime (C5 -> E5 -> G5)
static func play_star_up() -> void:
	if _instance and _instance.has_method("_play_burst"):
		_instance._play_burst(_instance.get("_star_up_frames"))

## 420ms deep sub-bass impact slam (80 Hz -> 26 Hz pitch drop + punch transient)
static func play_bass_impact() -> void:
	if _instance and _instance.has_method("_play_burst"):
		_instance._play_burst(_instance.get("_bass_impact_frames"))

## Alias for busted stamp slam
static func play_busted_slam() -> void:
	play_bass_impact()

## 110ms sharp handgun/carbine gunfire crack with punchy noise transient
static func play_gunshot() -> void:
	if _instance and _instance.has_method("_play_burst"):
		_instance._play_burst(_instance.get("_gunshot_frames"))

## 150ms tire blowout spike hiss and metallic slash
static func play_spike_puncture() -> void:
	if _instance and _instance.has_method("_play_burst"):
		_instance._play_burst(_instance.get("_spike_frames"))

## 140ms urgent double-chirp alarm tone for low HP warning
static func play_low_hp_alert() -> void:
	if _instance and _instance.has_method("_play_burst"):
		_instance._play_burst(_instance.get("_low_hp_frames"))

## Audio aliases for robust cross-system compatibility
static func play_crash_hard() -> void:
	play_smash_hit()

static func play_coin_pickup() -> void:
	play_ui_click()

static func play_collision() -> void:
	play_smash_hit()

static func play_nitro_boost() -> void:
	play_drift_boost()

static func play_tire_screech() -> void:
	play_drift_boost()

static func play_emp_blast() -> void:
	play_bass_impact()

static func play_level_complete() -> void:
	play_star_up()

# ==============================================================================
# BACKGROUND MUSIC (BGM) SYSTEM
# ==============================================================================

func _init_music_player() -> void:
	if not _music_player:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "BGM_MusicPlayer"
		_music_player.bus = "Master"
		_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_music_player.volume_db = _music_volume_db
		add_child(_music_player)
		_music_player.finished.connect(func():
			if _music_player and not _is_music_muted and not _current_music_key.is_empty():
				_music_player.play()
		)

func play_lobby_music(fade_duration: float = 0.6) -> void:
	play_music(LOBBY_MUSIC_PATH, "lobby", fade_duration)

func play_gameplay_music(fade_duration: float = 0.6) -> void:
	play_music(GAMEPLAY_MUSIC_PATH, "gameplay", fade_duration)

func play_music(path: String, track_key: String, fade_duration: float = 0.6) -> void:
	if _current_music_key == track_key and _music_player and _music_player.playing:
		return
	
	if not _music_player:
		_init_music_player()
	
	if not ResourceLoader.exists(path):
		return
	
	var stream = load(path)
	if not stream:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	
	_current_music_key = track_key
	
	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	
	if _music_player.playing and fade_duration > 0.05:
		_music_fade_tween = create_tween()
		_music_fade_tween.tween_property(_music_player, "volume_db", -45.0, fade_duration * 0.4)
		_music_fade_tween.tween_callback(func():
			if _music_player:
				_music_player.stream = stream
				_music_player.volume_db = -45.0
				_music_player.play()
		)
		_music_fade_tween.tween_property(_music_player, "volume_db", _music_volume_db, fade_duration * 0.6)
	else:
		_music_player.stream = stream
		_music_player.volume_db = _music_volume_db
		_music_player.play()

func stop_music(fade_duration: float = 0.4) -> void:
	_current_music_key = ""
	if not _music_player or not _music_player.playing:
		return
	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	if fade_duration > 0.05:
		_music_fade_tween = create_tween()
		_music_fade_tween.tween_property(_music_player, "volume_db", -45.0, fade_duration)
		_music_fade_tween.tween_callback(func():
			if _music_player:
				_music_player.stop()
		)
	else:
		_music_player.stop()

func set_music_volume(volume_db: float) -> void:
	_music_volume_db = volume_db
	if _music_player and _music_player.playing:
		_music_player.volume_db = volume_db

func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing

func get_current_music_key() -> String:
	return _current_music_key

static func play_music_lobby(fade_duration: float = 0.6) -> void:
	if _instance and _instance.has_method("play_lobby_music"):
		_instance.play_lobby_music(fade_duration)

static func play_music_gameplay(fade_duration: float = 0.6) -> void:
	if _instance and _instance.has_method("play_gameplay_music"):
		_instance.play_gameplay_music(fade_duration)

static func stop_bgm(fade_duration: float = 0.4) -> void:
	if _instance and _instance.has_method("stop_music"):
		_instance.stop_music(fade_duration)

# ==============================================================================
# PROCEDURAL WAVEFORM GENERATION
# ==============================================================================

func _bake_waveforms() -> void:
	_ui_click_frames = _generate_ui_click()
	_smash_hit_frames = _generate_smash_hit()
	_explosion_frames = _generate_explosion()
	_drift_boost_frames = _generate_drift_boost()
	_star_up_frames = _generate_star_up()
	_bass_impact_frames = _generate_bass_impact()
	_gunshot_frames = _generate_gunshot()
	_spike_frames = _generate_spike_puncture()
	_low_hp_frames = _generate_low_hp_alert()

func _generate_ui_click() -> PackedVector2Array:
	var total_samples: int = int(0.06 * float(MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(total_samples)
	var phase: float = 0.0
	
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		var freq: float = lerpf(420.0, 680.0, progress)
		phase += freq * (1.0 / float(MIX_RATE)) * TAU
		var sine_val: float = sin(phase)
		var tri_val: float = 2.0 * absf(fmod(phase / PI, 2.0) - 1.0) - 1.0
		var raw: float = 0.65 * sine_val + 0.35 * tri_val
		var attack: float = clampf(progress * 15.0, 0.0, 1.0)
		var decay: float = 1.0 - progress
		var sample: float = raw * attack * decay * 0.4
		frames[i] = Vector2(sample, sample)
	
	return frames

func _generate_smash_hit() -> PackedVector2Array:
	var total_samples: int = int(0.11 * float(MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(total_samples)
	var phase: float = 0.0
	var lpf: float = 0.0
	
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		var freq: float = lerpf(140.0, 55.0, progress)
		phase += freq * (1.0 / float(MIX_RATE)) * TAU
		var thud: float = sin(phase)
		var noise: float = randf_range(-1.0, 1.0)
		lpf = lerpf(lpf, noise, 0.22)
		var decay: float = pow(1.0 - progress, 1.6)
		var sample: float = (thud * 0.72 + lpf * 0.38) * decay * 0.65
		frames[i] = Vector2(sample, sample)
	
	return frames

func _generate_explosion() -> PackedVector2Array:
	var total_samples: int = int(0.38 * float(MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(total_samples)
	var phase: float = 0.0
	var lpf: float = 0.0
	
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		var sub_freq: float = lerpf(60.0, 24.0, progress)
		phase += sub_freq * (1.0 / float(MIX_RATE)) * TAU
		var rumble: float = sin(phase) + 0.45 * sin(phase * 0.5)
		var noise: float = randf_range(-1.0, 1.0)
		lpf = lerpf(lpf, noise, 0.32)
		var decay: float = exp(-4.6 * progress)
		var sample: float = (rumble * 0.45 + lpf * 0.65) * decay * 0.7
		frames[i] = Vector2(sample, sample)
	
	return frames

func _generate_drift_boost() -> PackedVector2Array:
	var total_samples: int = int(0.22 * float(MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(total_samples)
	var phase: float = 0.0
	
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		var freq: float = lerpf(220.0, 880.0, progress)
		phase = fmod(phase + freq * (1.0 / float(MIX_RATE)), 1.0)
		var saw: float = (phase * 2.0 - 1.0)
		var bell_env: float = sin(progress * PI)
		var sample: float = saw * bell_env * 0.42
		frames[i] = Vector2(sample, sample)
	
	return frames

func _generate_star_up() -> PackedVector2Array:
	var total_samples: int = int(0.36 * float(MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(total_samples)
	var phase: float = 0.0
	
	for i in range(total_samples):
		var t: float = float(i) / float(MIX_RATE)
		var note_idx: int = mini(2, int(t / 0.12))
		var note_t: float = (t - float(note_idx) * 0.12) / 0.12
		var freq: float = 523.25 if note_idx == 0 else (659.25 if note_idx == 1 else 783.99)
		phase += freq * (1.0 / float(MIX_RATE)) * TAU
		var wave: float = sin(phase) + 0.28 * sin(phase * 2.0)
		var attack: float = clampf(note_t * 20.0, 0.0, 1.0)
		var decay: float = pow(1.0 - note_t, 1.8)
		var sample: float = wave * attack * decay * 0.48
		frames[i] = Vector2(sample, sample)
	
	return frames

func _generate_bass_impact() -> PackedVector2Array:
	var total_samples: int = int(0.42 * float(MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(total_samples)
	var phase: float = 0.0
	var lpf: float = 0.0
	
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		# Deep sub-bass frequency drop from 82 Hz down to 26 Hz
		var freq: float = lerpf(82.0, 26.0, pow(progress, 0.65))
		phase += freq * (1.0 / float(MIX_RATE)) * TAU
		
		# Fundamental sub-bass with punchy harmonics
		var sub_bass: float = sin(phase) + 0.38 * sin(phase * 2.0) + 0.16 * sin(phase * 3.0)
		
		# Initial kick click / transient thump in the first 25ms
		var click_phase: float = float(i) * 0.12
		var click: float = sin(click_phase) * exp(-float(i) / (0.015 * float(MIX_RATE))) if i < int(0.04 * float(MIX_RATE)) else 0.0
		
		# Low-frequency rumble noise
		var noise: float = randf_range(-1.0, 1.0)
		lpf = lerpf(lpf, noise, 0.18)
		
		# Envelope: fast 8ms attack, powerful exponential sustain/decay
		var attack: float = clampf(progress * 50.0, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.5) * exp(-2.4 * progress)
		
		var sample: float = (sub_bass * 0.72 + click * 0.55 + lpf * 0.28) * attack * decay * 0.95
		frames[i] = Vector2(sample, sample)
	
	return frames

func _generate_gunshot() -> PackedVector2Array:
	var total_samples: int = int(0.12 * float(MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(total_samples)
	var phase: float = 0.0
	
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		var freq: float = lerpf(980.0, 140.0, pow(progress, 0.4))
		phase += freq * (1.0 / float(MIX_RATE)) * TAU
		
		# Snappy square + white noise transient
		var sqr: float = 1.0 if sin(phase) > 0.0 else -1.0
		var noise: float = randf_range(-1.0, 1.0)
		var raw: float = sqr * 0.4 + noise * 0.6
		
		var attack: float = clampf(progress * 80.0, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 2.8)
		var sample: float = raw * attack * decay * 0.75
		frames[i] = Vector2(sample, sample)
	
	return frames

func _generate_spike_puncture() -> PackedVector2Array:
	var total_samples: int = int(0.16 * float(MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(total_samples)
	var phase: float = 0.0
	
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		var freq: float = lerpf(2400.0, 480.0, progress)
		phase += freq * (1.0 / float(MIX_RATE)) * TAU
		
		# High frequency hiss and tire rupture
		var hiss: float = randf_range(-1.0, 1.0) * 0.7 + sin(phase) * 0.3
		var attack: float = clampf(progress * 60.0, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.6)
		var sample: float = hiss * attack * decay * 0.65
		frames[i] = Vector2(sample, sample)
	
	return frames

func _generate_low_hp_alert() -> PackedVector2Array:
	var total_samples: int = int(0.14 * float(MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(total_samples)
	var phase: float = 0.0
	
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		var freq: float = 750.0 if progress < 0.5 else 920.0
		phase += freq * (1.0 / float(MIX_RATE)) * TAU
		
		var raw: float = sin(phase) * 0.7 + (1.0 if sin(phase) > 0.0 else -1.0) * 0.3
		var env: float = sin(progress * PI)
		var sample: float = raw * env * 0.45
		frames[i] = Vector2(sample, sample)
	
	return frames
