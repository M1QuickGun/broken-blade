extends Node
## Sound effects. Autoloaded as "Sfx". Sounds live in res://audio/sfx/<name>.wav (made by
## tools/make_sfx.py) and play on the "SFX" bus, a little varied in pitch each time so
## repeats don't sound mechanical.

const VOICES := 14

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)


## Plays a sound. `volume_db` adjusts it; `vary` is how much the pitch may wander.
func play(sound: String, volume_db := 0.0, vary := 0.08) -> void:
	if not _cache.has(sound):
		var path := "res://audio/sfx/%s.wav" % sound
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _cache[sound]
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-vary, vary)
	player.play()
