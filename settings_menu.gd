extends CanvasLayer
## Settings menu, built entirely in code — no scene file to wire up.
## Main instantiates this and sets main. Toggle with O, or main.menu.open().

var main: Node2D
var panel: PanelContainer
var listening_for := ""
var bind_buttons := {}

func _ready() -> void:
	layer = 10
	visible = false
	_build()

func open() -> void:
	visible = true
	_refresh()

func close() -> void:
	visible = false
	listening_for = ""
	Settings.save_settings()

func _section(box: VBoxContainer, title: String) -> VBoxContainer:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color("9fd18f"))
	box.add_child(lbl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	box.add_child(sp)
	return v

func _row(parent: VBoxContainer, label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	parent.add_child(h)
	return h

func _slider(parent: VBoxContainer, label: String, lo: int, hi: int, get_v: Callable, set_v: Callable) -> void:
	var h := _row(parent, label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.value = get_v.call()
	s.custom_minimum_size = Vector2(200, 0)
	var val := Label.new()
	val.text = str(int(s.value))
	val.custom_minimum_size = Vector2(50, 0)
	s.value_changed.connect(func(v):
		set_v.call(int(v))
		val.text = str(int(v))
		Settings.save_settings())
	h.add_child(s)
	h.add_child(val)

func _seg(parent: VBoxContainer, label: String, options: Array, get_v: Callable, set_v: Callable) -> void:
	var h := _row(parent, label)
	var group := ButtonGroup.new()
	for o in options:
		var b := Button.new()
		b.text = o[1]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = get_v.call() == o[0]
		var val = o[0]
		b.pressed.connect(func():
			set_v.call(val)
			Settings.save_settings()
			_refresh())
		h.add_child(b)

func _toggle(parent: VBoxContainer, label: String, get_v: Callable, set_v: Callable) -> void:
	var h := _row(parent, label)
	var c := CheckButton.new()
	c.button_pressed = get_v.call()
	c.toggled.connect(func(on):
		set_v.call(on)
		Settings.save_settings())
	h.add_child(c)

func _build() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	margin.add_child(outer)

	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "⚙  " + Settings.t("settings")
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var closeb := Button.new()
	closeb.text = Settings.t("close")
	closeb.pressed.connect(close)
	head.add_child(closeb)
	outer.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	# ---------- 🔊 Sound ----------
	var s1 := _section(box, "🔊  Sound")
	_slider(s1, "Master Volume", 0, 100, func(): return Settings.master, func(v): Settings.master = v)
	_slider(s1, "Music Volume", 0, 100, func(): return Settings.music, func(v): Settings.music = v)
	_slider(s1, "SFX Volume", 0, 100, func(): return Settings.sfx, func(v):
		Settings.sfx = v
		Settings.beep(700, 0.05, "square", 0.2))

	# ---------- 🎨 Graphics ----------
	var s2 := _section(box, "🎨  Graphics")
	_seg(s2, "Quality", [["low","Low"],["med","Medium"],["high","High"]],
		func(): return Settings.quality, func(v): Settings.quality = v)
	_toggle(s2, "Fullscreen", func(): return Settings.fullscreen, func(v):
		Settings.fullscreen = v
		Settings.apply_fullscreen())
	_slider(s2, "Brightness", 60, 150, func(): return Settings.brightness, func(v): Settings.brightness = v)
	_seg(s2, "Theme", [["day","Day"],["sunset","Sunset"],["night","Night"]],
		func(): return Settings.theme, func(v): Settings.theme = v)

	# ---------- 🎮 Controls ----------
	var s3 := _section(box, "🎮  Controls")
	_seg(s3, "Keyboard Controls", [["wasd","WASD"],["arrows","Arrows"],["custom","Custom"]],
		func(): return Settings.layout, func(v):
			Settings.layout = v
			if Settings.PRESETS.has(v):
				Settings.binds = Settings.PRESETS[v].duplicate(true))
	_slider(s3, "Mouse Sensitivity", 0, 200, func(): return Settings.mouse_sens, func(v): Settings.mouse_sens = v)
	var note := Label.new()
	note.text = "Key Bindings — click a key, then press the new one."
	note.add_theme_color_override("font_color", Color("94ab90"))
	s3.add_child(note)
	for pair in [["left","Move Left"],["right","Move Right"],["jump","Jump / Double Jump"],["shoot","Shoot"],["pause","Pause"]]:
		var h := _row(s3, pair[1])
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 0)
		var act: String = pair[0]
		b.pressed.connect(func():
			listening_for = act
			_refresh())
		bind_buttons[act] = b
		h.add_child(b)
	var padnote := Label.new()
	padnote.text = "Controller — Stick/D-pad: move · A: jump · X: shoot · Start: pause · Back: settings"
	padnote.add_theme_color_override("font_color", Color("94ab90"))
	s3.add_child(padnote)

	# ---------- 🌐 Game ----------
	var s4 := _section(box, "🌐  Game")
	_seg(s4, "Difficulty", [["easy","Easy"],["normal","Normal"],["hard","Hard"]],
		func(): return Settings.difficulty, func(v): Settings.difficulty = v)
	var hl := _row(s4, "Language")
	var opt := OptionButton.new()
	opt.add_item("English"); opt.add_item("Filipino"); opt.add_item("Español")
	opt.selected = ["en","tl","es"].find(Settings.lang)
	opt.item_selected.connect(func(i):
		Settings.lang = ["en","tl","es"][i]
		Settings.save_settings())
	hl.add_child(opt)
	_toggle(s4, "Auto Save", func(): return Settings.autosave, func(v):
		Settings.autosave = v
		if not v: Settings.clear_progress())

	# ---------- 📊 Gameplay ----------
	var s5 := _section(box, "📊  Gameplay")
	_toggle(s5, "Show Score", func(): return Settings.show_score, func(v): Settings.show_score = v)
	_toggle(s5, "Show Timer", func(): return Settings.show_timer, func(v): Settings.show_timer = v)
	_toggle(s5, "Vibration", func(): return Settings.vibration, func(v):
		Settings.vibration = v
		if v: Settings.vibrate(30))

	# ---------- ⚙️ System ----------
	var s6 := _section(box, "⚙️  System")

	var hrs := _row(s6, "Restart Level")
	var brs := Button.new(); brs.text = "Restart"
	brs.pressed.connect(func():
		close()
		main.load_level(main.level_index)
		main.mode = main.Mode.PLAY
		Settings.music_on = true)
	hrs.add_child(brs)

	var hr := _row(s6, "Reset Settings")
	var br := Button.new(); br.text = "Reset"
	br.pressed.connect(func():
		Settings.reset_settings()
		Settings.apply_fullscreen()
		_refresh())
	hr.add_child(br)

	var hs := _row(s6, "Save & Exit")
	var bs := Button.new(); bs.text = "Save"
	bs.pressed.connect(func():
		Settings.save_settings()
		if main.mode == main.Mode.PLAY or main.mode == main.Mode.PAUSED:
			Settings.save_progress(main.level_index, main.score, main.gems_total)
		close()
		main.mode = main.Mode.TITLE
		Settings.music_on = false)
	hs.add_child(bs)

	var hm := _row(s6, "Back to Main Menu")
	var bm := Button.new(); bm.text = "Menu"
	bm.pressed.connect(func():
		Settings.save_settings()
		close()
		main.mode = main.Mode.TITLE
		Settings.music_on = false)
	hm.add_child(bm)

func _refresh() -> void:
	for act in bind_buttons.keys():
		var names := []
		for code in Settings.binds.get(act, []):
			names.append(OS.get_keycode_string(code))
		bind_buttons[act].text = "…" if listening_for == act else " / ".join(names)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if listening_for != "":
			Settings.binds[listening_for] = [event.keycode]
			Settings.layout = "custom"
			listening_for = ""
			Settings.save_settings()
			_refresh()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
