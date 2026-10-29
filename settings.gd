extends Node
## Autoload singleton. Project > Project Settings > Autoload > add as "Settings".
## Holds every option from the settings menu and does the procedural audio.

const SAVE_PATH := "user://settings.cfg"
const PROGRESS_PATH := "user://progress.cfg"

# ---------- sound ----------
var master := 80
var music := 45
var sfx := 70

# ---------- graphics ----------
var quality := "high"          # low / med / high
var fullscreen := false
var brightness := 100
var theme := "day"             # day / sunset / night

const THEME_TINT := {
	"day":    Color("ffffff"),
	"sunset": Color("ffb98a"),
	"night":  Color("6f7fb8"),
}

# ---------- controls ----------
var layout := "wasd"           # wasd / arrows / custom
var mouse_sens := 100
var binds := {
	"left":  [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"jump":  [KEY_W, KEY_SPACE, KEY_UP],
	"shoot": [KEY_J, KEY_Z],
	"pause": [KEY_ESCAPE, KEY_P],
}

# ---------- game ----------
var difficulty := "normal"     # easy / normal / hard
var lang := "en"               # en / tl / es
var autosave := true

# ---------- gameplay ----------
var show_score := true
var show_timer := true
var vibration := true

const PRESETS := {
	"wasd":   {"left":[KEY_A], "right":[KEY_D], "jump":[KEY_W, KEY_SPACE], "shoot":[KEY_J], "pause":[KEY_ESCAPE]},
	"arrows": {"left":[KEY_LEFT], "right":[KEY_RIGHT], "jump":[KEY_UP, KEY_SPACE], "shoot":[KEY_Z], "pause":[KEY_ESCAPE]},
}

const DIFF := {
	"easy":   {"hearts":5, "slime":0.75, "inv":110, "cool":11},
	"normal": {"hearts":3, "slime":1.0,  "inv":90,  "cool":14},
	"hard":   {"hearts":2, "slime":1.35, "inv":60,  "cool":18},
}

const TEXT := {
	"en": {"title":"Grove Runner","intro":"Double jump, stomp or shoot the slimes, grab crystals, reach the flag.",
		"start":"Start","cont":"Continue","paused":"Paused","resume":"Resume","clear":"Level clear","next":"Next level",
		"over":"Out of hearts","retry":"Try again","won":"You made it through!","again":"Play again",
		"crystals":"crystals","score":"Score","settings":"Settings","close":"Close"},
	"tl": {"title":"Grove Runner", "intro":"Double jump, tapakan o barilin ang slime, kunin ang kristal, abutin ang bandila.",
		"start":"Simulan","cont":"Ituloy","paused":"Naka-pause","resume":"Ituloy","clear":"Tapos ang level","next":"Susunod",
		"over":"Ubos na ang puso","retry":"Ulitin","won":"Natapos mo!","again":"Ulit",
		"crystals":"kristal","score":"Iskor","settings":"Mga Setting","close":"Isara"},
	"es": {"title":"Grove Runner", "intro":"Doble salto, pisa o dispara a los limos, recoge cristales y llega a la bandera.",
		"start":"Empezar","cont":"Continuar","paused":"En pausa","resume":"Reanudar","clear":"Nivel superado","next":"Siguiente",
		"over":"Sin corazones","retry":"Reintentar","won":"¡Lo lograste!","again":"Jugar otra vez",
		"crystals":"cristales","score":"Puntos","settings":"Ajustes","close":"Cerrar"},
}

func t(key: String) -> String:
	var d: Dictionary = TEXT.get(lang, TEXT["en"])
	return d.get(key, TEXT["en"].get(key, key))

func diff() -> Dictionary:
	return DIFF.get(difficulty, DIFF["normal"])

func q_low() -> bool:  return quality == "low"
func q_high() -> bool: return quality == "high"

# ============================================================ persistence
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	master     = cfg.get_value("sound", "master", master)
	music      = cfg.get_value("sound", "music", music)
	sfx        = cfg.get_value("sound", "sfx", sfx)
	quality    = cfg.get_value("gfx", "quality", quality)
	fullscreen = cfg.get_value("gfx", "fullscreen", fullscreen)
	brightness = cfg.get_value("gfx", "brightness", brightness)
	theme      = cfg.get_value("gfx", "theme", theme)
	layout     = cfg.get_value("ctrl", "layout", layout)
	mouse_sens = cfg.get_value("ctrl", "mouse_sens", mouse_sens)
	binds      = cfg.get_value("ctrl", "binds", binds)
	difficulty = cfg.get_value("game", "difficulty", difficulty)
	lang       = cfg.get_value("game", "lang", lang)
	autosave   = cfg.get_value("game", "autosave", autosave)
	show_score = cfg.get_value("play", "show_score", show_score)
	show_timer = cfg.get_value("play", "show_timer", show_timer)
	vibration  = cfg.get_value("play", "vibration", vibration)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sound", "master", master)
	cfg.set_value("sound", "music", music)
	cfg.set_value("sound", "sfx", sfx)
	cfg.set_value("gfx", "quality", quality)
	cfg.set_value("gfx", "fullscreen", fullscreen)
	cfg.set_value("gfx", "brightness", brightness)
	cfg.set_value("gfx", "theme", theme)
	cfg.set_value("ctrl", "layout", layout)
	cfg.set_value("ctrl", "mouse_sens", mouse_sens)
	cfg.set_value("ctrl", "binds", binds)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "lang", lang)
	cfg.set_value("game", "autosave", autosave)
	cfg.set_value("play", "show_score", show_score)
	cfg.set_value("play", "show_timer", show_timer)
	cfg.set_value("play", "vibration", vibration)
	cfg.save(SAVE_PATH)

func reset_settings() -> void:
	master = 80; music = 45; sfx = 70
	quality = "high"; brightness = 100; theme = "day"
	layout = "wasd"; mouse_sens = 100
	binds = PRESETS["wasd"].duplicate(true)
	difficulty = "normal"; lang = "en"; autosave = true
	show_score = true; show_timer = true; vibration = true
	save_settings()

func save_progress(level: int, score: int, gems: int) -> void:
	if not autosave: return
	var cfg := ConfigFile.new()
	cfg.set_value("run", "level", level)
	cfg.set_value("run", "score", score)
	cfg.set_value("run", "gems", gems)
	cfg.save(PROGRESS_PATH)

func load_progress() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return {}
	return {"level": cfg.get_value("run","level",0), "score": cfg.get_value("run","score",0), "gems": cfg.get_value("run","gems",0)}

func clear_progress() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))

func save_best(v: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	if v > int(cfg.get_value("run", "best", 0)):
		cfg.set_value("run", "best", v)
		cfg.save(PROGRESS_PATH)

func get_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK: return 0
	return int(cfg.get_value("run", "best", 0))

func apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func vibrate(ms: int) -> void:
	if vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

# ============================================================ procedural audio
# Tiny software synth: no .wav assets needed. Voices are mixed each frame.
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array = []          # {freq, phase, left, dur, amp, wave, bus}
var _mix_rate := 44100.0
var _music_t := 0.0
var _music_step := 0
var music_on := false

const SCALE := [0, 3, 5, 7, 10, 12, 15]
const ROOTS := [196.0, 220.0, 174.6, 164.8]

func _ready() -> void:
	load_settings()
	apply_fullscreen()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _mix_rate
	gen.buffer_length = 0.1
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

func beep(freq: float, dur: float, wave := "square", amp := 0.25) -> void:
	if master == 0 or sfx == 0: return
	_voices.append({"freq":freq, "phase":0.0, "left":dur, "dur":dur, "amp":amp, "wave":wave, "bus":"sfx"})

func sweep(f1: float, f2: float, dur: float) -> void:
	if master == 0 or sfx == 0: return
	_voices.append({"freq":f1, "f2":f2, "phase":0.0, "left":dur, "dur":dur, "amp":0.3, "wave":"tri", "bus":"sfx"})

func _note(freq: float, dur: float, amp: float) -> void:
	_voices.append({"freq":freq, "phase":0.0, "left":dur, "dur":dur, "amp":amp, "wave":"tri", "bus":"music"})

func _process(delta: float) -> void:
	# ---- music sequencer
	if music_on and master > 0 and music > 0:
		_music_t += delta
		if _music_t >= 0.23:
			_music_t = 0.0
			var root: float = ROOTS[int(_music_step / 8.0) % ROOTS.size()]
			var n: int = SCALE[(_music_step * 3) % SCALE.size()]
			_note(root * pow(2.0, n / 12.0), 0.34, 0.22)
			if _music_step % 4 == 0:
				_note(root * 0.5, 0.42, 0.28)
			_music_step += 1
	_fill_audio(delta)

func _fill_audio(delta: float) -> void:
	if _playback == null: return
	var frames := _playback.get_frames_available()
	if frames <= 0: return
	var mvol := master / 100.0
	var svol := (sfx / 100.0) * 0.9 * mvol
	var mus := (music / 100.0) * 0.5 * mvol
	for i in frames:
		var s := 0.0
		for v in _voices:
			if v["left"] <= 0.0: continue
			var env: float = clamp(v["left"] / max(v["dur"], 0.0001), 0.0, 1.0)
			var f: float = v["freq"]
			if v.has("f2"):
				f = lerp(float(v["f2"]), float(v["freq"]), env)
			v["phase"] = fposmod(v["phase"] + f / _mix_rate, 1.0)
			var w := 0.0
			match v["wave"]:
				"square": w = 1.0 if v["phase"] < 0.5 else -1.0
				"saw":    w = v["phase"] * 2.0 - 1.0
				_:        w = 1.0 - abs(v["phase"] * 4.0 - 2.0)   # triangle
			var gain: float = svol if v["bus"] == "sfx" else mus
			s += w * v["amp"] * env * env * gain
			v["left"] -= 1.0 / _mix_rate
		s = clamp(s, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))
	var keep := []
	for v in _voices:
		if v["left"] > 0.0: keep.append(v)
	_voices = keep
