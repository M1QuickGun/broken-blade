extends Node
## Background music. Autoloaded as "Music". Tracks live in res://audio/music/<name>.ogg,
## loop, and crossfade when the track changes.

const FADE_TIME := 1.5
const VOLUME_DB := -8.0
const SILENT_DB := -60.0

var _players: Array[AudioStreamPlayer] = []
var _current := 0
var _track := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


## Starts a track, fading out whatever was playing. Asking for the current track does nothing.
func play(track: String) -> void:
	if track == _track:
		return
	_track = track
	var stream := load("res://audio/music/%s.ogg" % track) as AudioStreamOggVorbis
	stream.loop = true
	var old := _players[_current]
	_current = 1 - _current
	var new := _players[_current]
	new.stream = stream
	new.volume_db = SILENT_DB
	new.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(new, "volume_db", VOLUME_DB, FADE_TIME)
	if old.playing:
		tween.tween_property(old, "volume_db", SILENT_DB, FADE_TIME)
		tween.chain().tween_callback(old.stop)
