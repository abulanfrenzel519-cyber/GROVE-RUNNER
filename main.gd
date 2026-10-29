extends Node2D
## Grove Runner — Godot 4.x port.
## Attach to a Node2D root called "Main", set it as the main scene.
## Everything is drawn procedurally, so no sprite assets are required.

const TS := 48
const VW := 960
const VH := 540
const ROWS := 11
const GROUND_ROW := 8

const GRAV := 0.62
const JUMP_V := -12.4
const RUN := 4.2
const MAXFALL := 15.0

# tile ids
const EMPTY := 0
const DIRT := 1
const PLAT := 2
const WATER := 3

const LEVELS := [
	{
		"name":"Sunny Clearing", "w":48, "tint":Color("9fe8df"), "orb":Color("ff8a3d"),
		"ground":[[0,6],[9,8],[20,11],[34,14]], "water":[[17,3]],
		"platforms":[[10,4,5],[22,4,5],[29,3,4],[38,3,4]],
		"gems":[[11,4],[12,4],[23,4],[30,3],[39,3],[25,7],[44,7]],
		"slimes":[[13,7],[24,7],[40,7],[23,4]],
		"trees":[[3,7],[27,7],[35,7]], "bushes":[[15,7],[36,7],[21,7]],
		"crates":[[42,7]], "player":[1,7], "goal":[46,7],
	},
	{
		"name":"Mossy Steps", "w":56, "tint":Color("a8e6b8"), "orb":Color("49d0ff"),
		"ground":[[0,7],[11,6],[21,4],[28,9],[41,15]], "water":[[8,3],[18,3],[37,4]],
		"platforms":[[8,3,6],[18,3,5],[25,3,4],[33,4,5],[37,3,3],[47,4,4]],
		"gems":[[9,5],[19,4],[26,3],[34,4],[35,4],[38,2],[48,3],[49,3],[15,7],[31,7]],
		"slimes":[[13,7],[22,7],[31,7],[45,7],[50,7],[34,4]],
		"trees":[[4,7],[29,7],[49,7]], "bushes":[[12,7],[24,7],[44,7]],
		"crates":[[6,7],[51,7]], "player":[1,7], "goal":[54,7],
	},
	{
		"name":"Deep Timber", "w":64, "tint":Color("8fd9e8"), "orb":Color("c46bff"),
		"ground":[[0,6],[10,5],[19,3],[26,4],[34,5],[43,6],[53,11]],
		"water":[[7,3],[16,3],[23,3],[31,3],[40,3],[50,3]],
		"platforms":[[7,3,6],[15,3,5],[23,3,6],[30,3,4],[39,3,5],[48,3,4],[57,4,4],[35,3,3]],
		"gems":[[8,5],[16,4],[24,5],[31,3],[36,2],[40,4],[49,3],[58,3],[59,3],[12,7],[45,7]],
		"slimes":[[12,7],[21,7],[28,7],[36,7],[45,7],[56,7],[59,7],[31,3]],
		"trees":[[3,7],[27,7],[47,7]], "bushes":[[11,7],[35,7],[55,7]],
		"crates":[[5,7],[44,7],[60,7]], "player":[1,7], "goal":[62,7],
	},
]

# ---------------- runtime state ----------------
enum Mode {TITLE, PLAY, PAUSED, CLEAR, OVER, WIN}
var mode: int = Mode.TITLE
var level_index := 0

var tiles: Array = []
var lvl_w := 0
var gems: Array = []
var slimes: Array = []
var crates: Array = []
var shots: Array = []
var particles: Array = []
var trees: Array = []
var bushes: Array = []
var goal := Vector2.ZERO
var start_pos := Vector2.ZERO

var hearts := 3
var gem_count := 0
var gems_total := 0
var score := 0
var level_time := 0.0
var shake := 0.0
var tglobal := 0.0
var look := 0.0
var cam_x := 0.0

# player
var p_pos := Vector2.ZERO
var p_vel := Vector2.ZERO
const P_W := 30.0
const P_H := 42.0
var p_on_ground := false
var p_face := 1
var p_anim := 0.0
var p_inv := 0
var p_cool := 0
var p_dead := false
var p_dead_t := 0
var p_jumps := 0
var p_max_jumps := 2          # <-- DOUBLE JUMP
var p_flip := 0.0

# input edges
var held := {"left":false, "right":false, "jump":false, "shoot":false}
var jump_edge := false
var shoot_edge := false
var mouse_norm := 0.0
var pad_x := 0.0              # controller left stick

var hud: Control
var menu: Node

func _ready() -> void:
	make_cursor()
	make_touch_controls()
	make_title_buttons()
	set_process_unhandled_input(true)
	# HUD layer
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)
	# settings menu (see settings_menu.gd)
	var menu_script := load("res://settings_menu.gd")
	if menu_script:
		menu = menu_script.new()
		menu.main = self
		add_child(menu)
	load_level(0)
	mode = Mode.TITLE

# ============================================================ level building
func surface_y(col: int, from_row: int) -> float:
	for r in range(from_row, ROWS):
		var t: int = tiles[r][col]
		if t == DIRT or t == PLAT or t == WATER:
			return float(r * TS)
	return float(ROWS * TS)

func load_level(i: int) -> void:
	level_index = i
	var spec: Dictionary = LEVELS[i]
	lvl_w = spec["w"]
	tiles = []
	for r in ROWS:
		var row := []
		for c in lvl_w: row.append(EMPTY)
		tiles.append(row)
	for s in spec["ground"]:
		for c in range(s[0], min(s[0] + s[1], lvl_w)):
			for r in range(GROUND_ROW, ROWS): tiles[r][c] = DIRT
	for s in spec.get("water", []):
		for c in range(s[0], min(s[0] + s[1], lvl_w)):
			for r in range(GROUND_ROW, ROWS): tiles[r][c] = WATER
	for p in spec.get("platforms", []):
		for c in range(p[0], min(p[0] + p[1], lvl_w)):
			tiles[p[2]][c] = PLAT

	gems = []; slimes = []; crates = []; shots = []; particles = []; trees = []; bushes = []
	for g in spec["gems"]:
		gems.append({"pos":Vector2(g[0] * TS + TS / 2.0, g[1] * TS + TS / 2.0), "got":false, "t":randf() * 6.0})
	for g in spec["slimes"]:
		var y := surface_y(g[0], g[1])
		slimes.append({"pos":Vector2(g[0] * TS + 8, y - 30), "w":34.0, "h":30.0,
			"vx":1.1 * (-1.0 if randf() < 0.5 else 1.0), "vy":0.0, "dead":false, "t":randf() * 6.0})
	for g in spec.get("crates", []):
		var yc := surface_y(g[0], g[1])
		crates.append({"pos":Vector2(g[0] * TS + 8, yc - 34), "w":32.0, "h":34.0, "broken":false})
	# DECOR IS ANCHORED TO THE FIRST SOLID SURFACE BELOW — it can never float
	var i2 := 0
	for g in spec.get("trees", []):
		trees.append({"x":g[0] * TS + TS / 2.0, "base_y":surface_y(g[0], g[1]) + 6.0, "s":i2 * 1.7}); i2 += 1
	i2 = 0
	for g in spec.get("bushes", []):
		bushes.append({"x":g[0] * TS + TS / 2.0, "base_y":surface_y(g[0], g[1]) + 10.0, "s":i2 * 2.3}); i2 += 1

	goal = Vector2(spec["goal"][0] * TS + TS / 2.0, surface_y(spec["goal"][0], spec["goal"][1]))
	start_pos = Vector2(spec["player"][0] * TS, spec["player"][1] * TS)

	p_pos = start_pos
	p_vel = Vector2.ZERO
	p_dead = false; p_dead_t = 0
	p_inv = 60; p_cool = 0; p_face = 1
	p_jumps = p_max_jumps; p_flip = 0.0
	hearts = Settings.diff()["hearts"]
	gem_count = 0
	level_time = 0.0

func tile_at(c: int, r: int) -> int:
	if r < 0: return EMPTY
	if c < 0 or c >= lvl_w: return DIRT
	if r >= ROWS: return EMPTY
	return tiles[r][c]

func solid_at(c: int, r: int) -> bool:
	var t := tile_at(c, r)
	return t == DIRT or t == PLAT

# ============================================================ input
func _action_for(code: int) -> String:
	for a in Settings.binds.keys():
		if code in Settings.binds[a]: return a
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var a := _action_for(event.keycode)
		if a == "":
			if event.pressed and event.keycode == KEY_R and mode == Mode.PLAY:
				load_level(level_index)
			return
		if a == "pause":
			if event.pressed and not event.echo:
				if mode == Mode.TITLE: toggle_settings()
				else: toggle_pause()
			return
		if event.pressed and not event.echo:
			if not held[a]:
				if a == "jump": jump_edge = true
				if a == "shoot": shoot_edge = true
			held[a] = true
		elif not event.pressed:
			held[a] = false
	elif event is InputEventMouseMotion:
		mouse_norm = clamp((event.position.x / float(VW) - 0.5) * 2.0, -1.0, 1.0)
	elif event is InputEventJoypadButton:
		_on_pad_button(event)
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X:
		pad_x = event.axis_value

func _pad_press(a: String, on: bool) -> void:
	if on and not held[a]:
		if a == "jump": jump_edge = true
		if a == "shoot": shoot_edge = true
	held[a] = on

func _on_pad_button(event: InputEvent) -> void:
	if event.button_index == JOY_BUTTON_BACK:
		if event.pressed: toggle_settings()
		return
	if event.pressed and menu and menu.visible: return
	match event.button_index:
		JOY_BUTTON_A:
			if event.pressed and mode != Mode.PLAY: confirm()
			else: _pad_press("jump", event.pressed)
		JOY_BUTTON_X: _pad_press("shoot", event.pressed)
		JOY_BUTTON_DPAD_LEFT: _pad_press("left", event.pressed)
		JOY_BUTTON_DPAD_RIGHT: _pad_press("right", event.pressed)
		JOY_BUTTON_START:
			if event.pressed:
				if mode == Mode.PLAY: toggle_pause()
				else: confirm()

func toggle_pause() -> void:
	if mode == Mode.PLAY:
		mode = Mode.PAUSED
		Settings.music_on = false
	elif mode == Mode.PAUSED:
		mode = Mode.PLAY
		Settings.music_on = true

func start_run() -> void:
	score = 0; gems_total = 0
	Settings.clear_progress()
	load_level(0)
	mode = Mode.PLAY
	Settings.music_on = true
	Settings.sweep(300, 700, 0.18)

func continue_run() -> void:
	var sv := Settings.load_progress()
	score = sv.get("score", 0)
	gems_total = sv.get("gems", 0)
	load_level(min(int(sv.get("level", 0)), LEVELS.size() - 1))
	mode = Mode.PLAY
	Settings.music_on = true

# ============================================================ physics helpers
func collide_x(pos: Vector2, size: Vector2, vx: float) -> Dictionary:
	var top := int(pos.y / TS)
	var bot := int((pos.y + size.y - 1) / TS)
	if vx > 0:
		var col := int((pos.x + size.x) / TS)
		for r in range(top, bot + 1):
			if solid_at(col, r):
				return {"x":col * TS - size.x - 0.01, "hit":true}
	elif vx < 0:
		var c2 := int(pos.x / TS)
		for r in range(top, bot + 1):
			if solid_at(c2, r):
				return {"x":(c2 + 1) * TS + 0.01, "hit":true}
	return {"x":pos.x, "hit":false}

func collide_y(pos: Vector2, size: Vector2, vy: float, inset := 0.0) -> Dictionary:
	var lft := int(pos.x / TS)
	var rgt := int((pos.x + size.x - 1) / TS)
	if vy > 0:
		var row := int((pos.y + size.y) / TS)
		var gl := int((pos.x + inset) / TS)
		var gr := int((pos.x + size.x - 1 - inset) / TS)
		for c in range(gl, gr + 1):
			if solid_at(c, row):
				return {"y":row * TS - size.y - 0.01, "hit":"ground"}
	elif vy < 0:
		var r := int(pos.y / TS)
		for c in range(lft, rgt + 1):
			if solid_at(c, r):
				return {"y":(r + 1) * TS + 0.01, "hit":"head"}
	return {"y":pos.y, "hit":""}

func aabb(ax, ay, aw, ah, bx, by, bw, bh) -> bool:
	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by

func burst(at: Vector2, color: Color, n: int, spd := 3.0) -> void:
	if Settings.q_low(): n = int(ceil(n / 3.0))
	for i in n:
		var a := randf() * TAU
		var s := spd * (0.4 + randf() * 0.9)
		particles.append({"pos":at, "vel":Vector2(cos(a) * s, sin(a) * s - 1.0),
			"life":1.0, "color":color, "r":2.0 + randf() * 3.0})

# ============================================================ update
func _physics_process(delta: float) -> void:
	tglobal += delta * 60.0
	if shake > 0: shake *= 0.88
	queue_redraw()
	hud.queue_redraw()
	modulate = Settings.THEME_TINT.get(Settings.theme, Color.WHITE)
	touch.visible = (mode == Mode.PLAY)
	title_ui.visible = (mode == Mode.TITLE) and not (menu and menu.visible)
	if mode != Mode.PLAY: return
	level_time += delta

	var dcfg := Settings.diff()

	# ---- death sequence
	if p_dead:
		p_dead_t += 1
		p_vel.y = min(p_vel.y + GRAV, MAXFALL)
		p_pos.y += p_vel.y
		if p_dead_t > 70:
			hearts -= 1
			if hearts <= 0:
				game_over()
			else:
				p_dead = false; p_dead_t = 0
				p_pos = start_pos; p_vel = Vector2.ZERO
				p_inv = dcfg["inv"]; p_jumps = p_max_jumps
		return

	# ---- horizontal
	var want := (1 if held["right"] else 0) - (1 if held["left"] else 0)
	if want == 0 and abs(pad_x) > 0.4:
		want = 1 if pad_x > 0 else -1
	if want != 0:
		p_vel.x = want * RUN
		p_face = want
		p_anim += 0.22
	else:
		p_vel.x *= 0.68
		if abs(p_vel.x) < 0.1: p_vel.x = 0.0
		p_anim *= 0.9
	p_pos.x += p_vel.x
	var rx := collide_x(p_pos, Vector2(P_W, P_H), p_vel.x)
	p_pos.x = rx["x"]
	if rx["hit"]: p_vel.x = 0.0
	p_pos.x = clamp(p_pos.x, 0.0, lvl_w * TS - P_W)

	# ---- JUMP / DOUBLE JUMP
	if jump_edge and p_jumps > 0:
		var second := not p_on_ground
		p_vel.y = JUMP_V * (0.92 if second else 1.0)
		p_on_ground = false
		p_jumps -= 1
		if second:
			p_flip = 0.01
			burst(p_pos + Vector2(P_W / 2.0, P_H), Color("eaffe0"), 10, 2.6)
			Settings.beep(760, 0.10, "tri", 0.3)
			Settings.beep(1040, 0.08, "square", 0.18)
		else:
			Settings.beep(520, 0.09, "square", 0.25)
	jump_edge = false
	if not held["jump"] and p_vel.y < -4.0: p_vel.y = -4.0

	p_vel.y = min(p_vel.y + GRAV, MAXFALL)
	p_pos.y += p_vel.y
	var ry := collide_y(p_pos, Vector2(P_W, P_H), p_vel.y, 9.0)
	p_pos.y = ry["y"]
	if ry["hit"] != "": p_vel.y = 0.0
	p_on_ground = ry["hit"] == "ground"
	if p_on_ground:
		p_jumps = p_max_jumps
		p_flip = 0.0
	elif p_flip > 0.0:
		p_flip += 0.34
		if p_flip > TAU: p_flip = 0.0

	if p_inv > 0: p_inv -= 1
	if p_cool > 0: p_cool -= 1

	# ---- shooting
	if shoot_edge and p_cool <= 0:
		shots.append({"pos":Vector2(p_pos.x + (P_W if p_face > 0 else -10.0), p_pos.y + 16.0),
			"vx":p_face * 9.0, "life":70, "t":0.0})
		p_cool = dcfg["cool"]
		Settings.beep(880, 0.07, "saw", 0.22)
	shoot_edge = false

	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		s["pos"].x += s["vx"]
		s["life"] -= 1
		s["t"] += 1.0
		var c := int((s["pos"].x + 6) / TS)
		var r := int((s["pos"].y + 6) / TS)
		var gone: bool = s["life"] <= 0 or solid_at(c, r)
		if not gone:
			for sl in slimes:
				if not sl["dead"] and aabb(s["pos"].x, s["pos"].y, 12, 12, sl["pos"].x, sl["pos"].y, sl["w"], sl["h"]):
					kill_slime(sl); gone = true; break
		if not gone:
			for cr in crates:
				if not cr["broken"] and aabb(s["pos"].x, s["pos"].y, 12, 12, cr["pos"].x, cr["pos"].y, cr["w"], cr["h"]):
					break_crate(cr); gone = true; break
		if gone:
			burst(s["pos"] + Vector2(6, 6), LEVELS[level_index]["orb"], 6, 2.0)
			shots.remove_at(i)

	# ---- slimes
	var sp: float = dcfg["slime"]
	for sm in slimes:
		if sm["dead"]: continue
		sm["t"] += 0.12
		var step: float = sm["vx"] * sp
		sm["pos"].x += step
		var r2 := collide_x(sm["pos"], Vector2(sm["w"], sm["h"]), step)
		sm["pos"].x = r2["x"]
		if r2["hit"]: sm["vx"] = -sm["vx"]
		var ahead := int((sm["pos"].x + sm["w"] + 2 if sm["vx"] > 0 else sm["pos"].x - 2) / TS)
		var below := int((sm["pos"].y + sm["h"] + 4) / TS)
		if not solid_at(ahead, below): sm["vx"] = -sm["vx"]
		sm["vy"] = min(sm["vy"] + GRAV, MAXFALL)
		sm["pos"].y += sm["vy"]
		var r3 := collide_y(sm["pos"], Vector2(sm["w"], sm["h"]), sm["vy"])
		sm["pos"].y = r3["y"]
		if r3["hit"] != "": sm["vy"] = 0.0
		if sm["pos"].y > (ROWS + 2) * TS:
			sm["dead"] = true
			continue
		if aabb(p_pos.x, p_pos.y, P_W, P_H, sm["pos"].x, sm["pos"].y, sm["w"], sm["h"]):
			var stomp: bool = p_vel.y > 1.2 and (p_pos.y + P_H) < sm["pos"].y + sm["h"] * 0.7
			if stomp:
				kill_slime(sm)
				p_vel.y = JUMP_V * 0.72
				p_jumps = max(p_jumps, 1)
			elif p_inv <= 0:
				hurt(1 if sm["pos"].x < p_pos.x else -1)

	# ---- crates
	for cq in crates:
		if cq["broken"]: continue
		if aabb(p_pos.x, p_pos.y, P_W, P_H, cq["pos"].x, cq["pos"].y, cq["w"], cq["h"]) \
			and p_vel.y > 1.2 and (p_pos.y + P_H) < cq["pos"].y + cq["h"] * 0.7:
			break_crate(cq)
			p_vel.y = JUMP_V * 0.62

	# ---- gems
	for gm in gems:
		gm["t"] += 0.08
		if gm["got"]: continue
		if aabb(p_pos.x - 4, p_pos.y - 4, P_W + 8, P_H + 8, gm["pos"].x - 14, gm["pos"].y - 14, 28, 28):
			gm["got"] = true
			gem_count += 1; gems_total += 1; score += 10
			burst(gm["pos"], Color("ffd34d"), 10, 3.0)
			Settings.beep(1200 + (gem_count % 5) * 110, 0.08, "tri", 0.22)
			Settings.vibrate(12)

	# ---- hazards
	var pc := int((p_pos.x + P_W / 2.0) / TS)
	var pr := int((p_pos.y + P_H - 6) / TS)
	if tile_at(pc, pr) == WATER or p_pos.y > (ROWS + 1) * TS:
		p_dead = true
		p_vel.y = 0.0
		shake = 10.0
		burst(p_pos + Vector2(15, 30), Color("7fe6ff"), 14, 3.5)
		Settings.sweep(420, 110, 0.35)
		Settings.vibrate(60)

	# ---- particles
	for i in range(particles.size() - 1, -1, -1):
		var pt: Dictionary = particles[i]
		pt["pos"] += pt["vel"]
		pt["vel"].y += 0.18
		pt["life"] -= 0.026
		if pt["life"] <= 0: particles.remove_at(i)

	# ---- goal
	if abs((p_pos.x + P_W / 2.0) - goal.x) < 30 and abs((p_pos.y + P_H) - goal.y) < 70:
		score += 100 + hearts * 25 + int(max(0, 120 - level_time))
		Settings.sweep(500, 1200, 0.4)
		Settings.vibrate(40)
		if level_index >= LEVELS.size() - 1:
			mode = Mode.WIN
			Settings.music_on = false
			Settings.save_best(score)
			Settings.clear_progress()
		else:
			mode = Mode.CLEAR
			Settings.music_on = false
			Settings.save_progress(level_index + 1, score, gems_total)

func game_over() -> void:
	mode = Mode.OVER
	Settings.music_on = false
	Settings.save_best(score)

func kill_slime(sl: Dictionary) -> void:
	sl["dead"] = true
	score += 25
	shake = 5.0
	burst(sl["pos"] + Vector2(sl["w"] / 2.0, sl["h"] / 2.0), Color("6fdc5a"), 12, 3.0)
	Settings.beep(200, 0.12, "square", 0.25)
	Settings.vibrate(15)

func break_crate(cr: Dictionary) -> void:
	cr["broken"] = true
	shake = 4.0
	burst(cr["pos"] + Vector2(cr["w"] / 2.0, cr["h"] / 2.0), Color("b07a44"), 14, 3.0)
	for i in 3:
		gems.append({"pos":cr["pos"] + Vector2(cr["w"] / 2.0 + (i - 1) * 22, -10), "got":false, "t":randf() * 6.0})
	Settings.beep(150, 0.14, "square", 0.25)
	Settings.vibrate(25)

func hurt(dir: int) -> void:
	hearts -= 1
	p_inv = Settings.diff()["inv"]
	p_vel = Vector2(dir * 5.0, -6.0)
	shake = 9.0
	burst(p_pos + Vector2(15, 20), Color("ff5d5d"), 10, 3.0)
	Settings.beep(180, 0.18, "saw", 0.28)
	Settings.vibrate(80)
	if hearts <= 0: game_over()

# ============================================================ drawing helpers
func ellipse(center: Vector2, rx: float, ry: float, col: Color, segments := 20) -> void:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func rrect(r: Rect2, col: Color) -> void:
	draw_rect(r, col, true)

# ============================================================ world drawing
func _draw() -> void:
	var b := Settings.brightness / 100.0
	var spec: Dictionary = LEVELS[level_index]

	# camera (mouse look-ahead uses the sensitivity setting)
	var target := mouse_norm * 120.0 * (Settings.mouse_sens / 100.0)
	look = lerp(look, target, 0.08)
	cam_x = clamp(p_pos.x + P_W / 2.0 - VW / 2.0 + look, 0.0, lvl_w * TS - VW)
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.5

	draw_backdrop(b, spec)

	draw_set_transform(Vector2(-cam_x, 0) + jitter, 0.0, Vector2.ONE)

	for t in trees: draw_tree(t, b)
	draw_goal(b)

	var c0: int = max(0, int(cam_x / TS) - 1)
	var c1: int = min(lvl_w - 1, int((cam_x + VW) / TS) + 1)
	for col in range(c0, c1 + 1):
		for row in ROWS:
			var t: int = tiles[row][col]
			var px := col * TS
			var py := row * TS
			if t == DIRT: draw_dirt(px, py, col, row, b)
			elif t == PLAT: draw_platform(px, py, b)
			elif t == WATER and row == GROUND_ROW: draw_water(px, py, b)

	for bu in bushes: draw_bush(bu, b)
	for cr in crates:
		if not cr["broken"]: draw_crate(cr, b)
	for gm in gems:
		if not gm["got"]: draw_gem(gm, b)
	for sm in slimes: draw_slime(sm, b)
	for s in shots: draw_shot(s, spec["orb"], b)
	draw_player(b)
	for pt in particles:
		draw_circle(pt["pos"], pt["r"], Color(pt["color"].r, pt["color"].g, pt["color"].b, clamp(pt["life"], 0, 1)) * b)

	draw_water_over(c0, c1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_dirt(x: int, y: int, col: int, row: int, b: float) -> void:
	var grass_top := not solid_at(col, row - 1)
	draw_rect(Rect2(x, y, TS, TS), Color("8c5a37") * b, true)
	if not Settings.q_low():
		var seed := (col * 37 + row * 91) % 7
		draw_circle(Vector2(x + 12 + seed * 3, y + 30), 5, Color(0, 0, 0, 0.10))
		draw_circle(Vector2(x + 34 - seed * 2, y + 16 + seed), 4, Color(0, 0, 0, 0.10))
		draw_circle(Vector2(x + 26, y + 40 - seed), 4, Color(1, 1, 1, 0.07))
	draw_rect(Rect2(x + 1, y + 1, TS - 2, TS - 2), Color(0.23, 0.13, 0.06, 0.35), false, 2.0)
	if grass_top:
		draw_rect(Rect2(x, y, TS, 14), Color("5da832") * b, true)
		draw_rect(Rect2(x, y, TS, 9), Color("7dc63f") * b, true)
		draw_rect(Rect2(x, y, TS, 4), Color("9ade5c") * b, true)
		draw_circle(Vector2(x + 10, y + 13), 6, Color("5da832") * b)
		draw_circle(Vector2(x + 26, y + 15), 7, Color("5da832") * b)
		draw_circle(Vector2(x + 40, y + 12), 5, Color("5da832") * b)

func draw_platform(x: int, y: int, b: float) -> void:
	draw_rect(Rect2(x, y + 6, TS, TS - 10), Color("8c5a37") * b, true)
	draw_rect(Rect2(x - 2, y, TS + 4, 18), Color("5da832") * b, true)
	draw_rect(Rect2(x - 2, y, TS + 4, 12), Color("7dc63f") * b, true)
	draw_rect(Rect2(x, y + 2, TS, 3), Color(1, 1, 1, 0.18), true)

func draw_water(x: int, y: int, b: float) -> void:
	draw_rect(Rect2(x, y, TS, TS * 4), Color("46a7d6") * b, true)
	if not Settings.q_low():
		draw_rect(Rect2(x, y, TS, TS), Color("63c8f2") * b, true)
		var i := 0
		while i < TS:
			var h := 3.0 + sin((x + i) * 0.06 + tglobal * 0.06) * 3.0
			draw_rect(Rect2(x + i, y + 4 + h, 5, 3), Color(1, 1, 1, 0.55), true)
			i += 6
	draw_rect(Rect2(x, y, TS, 6), Color(1, 1, 1, 0.16), true)

func draw_tree(t: Dictionary, b: float) -> void:
	var sway := 0.0 if Settings.q_low() else sin(tglobal * 0.015 + t["s"]) * 3.0
	var x: float = t["x"]
	var base_y: float = t["base_y"]
	ellipse(Vector2(x, base_y - 3), 26, 9, Color("6b3f22") * b)
	var trunk := PackedVector2Array([
		Vector2(x - 16, base_y - 2), Vector2(x - 9 + sway * 0.3, base_y - 96),
		Vector2(x + 9 + sway * 0.3, base_y - 96), Vector2(x + 16, base_y - 2)])
	draw_colored_polygon(trunk, Color("7a4a2a") * b)
	draw_rect(Rect2(x - 4, base_y - 92, 5, 86), Color(0, 0, 0, 0.16), true)
	var c := Vector2(x + sway, base_y - 105 + sway * 0.6)
	for o in [[-44, 6, 34], [44, 6, 34], [0, -18, 50], [-26, -30, 32], [28, -28, 34]]:
		draw_circle(c + Vector2(o[0], o[1]), o[2], Color("4d9c34") * b)
	for o in [[-30, -4, 26], [30, -6, 26], [0, -26, 38], [-6, 4, 30]]:
		draw_circle(c + Vector2(o[0], o[1]), o[2], Color("6cc24a") * b)
	if not Settings.q_low():
		draw_circle(c + Vector2(-12, -30), 20, Color("95d861") * b)
		draw_circle(c + Vector2(18, -18), 14, Color("95d861") * b)

func draw_bush(bu: Dictionary, b: float) -> void:
	var s := 1.0 if Settings.q_low() else 1.0 + sin(tglobal * 0.02 + bu["s"]) * 0.03
	var o := Vector2(bu["x"], bu["base_y"])
	ellipse(o + Vector2(0, -4), 30, 7, Color(0, 0, 0, 0.16))
	for p in [[-22, -14, 19], [22, -14, 19], [0, -24, 25]]:
		draw_circle(o + Vector2(p[0], p[1]) * s, p[2] * s, Color("4d9c34") * b)
	for p in [[-14, -18, 14], [14, -18, 14], [0, -28, 18]]:
		draw_circle(o + Vector2(p[0], p[1]) * s, p[2] * s, Color("6cc24a") * b)
	if not Settings.q_low():
		draw_circle(o + Vector2(-6, -32) * s, 9 * s, Color("95d861") * b)

func draw_gem(g: Dictionary, b: float) -> void:
	var o: Vector2 = g["pos"] + Vector2(0, sin(g["t"]) * 5.0)
	if not Settings.q_low():
		draw_circle(o, 20, Color(1, 0.78, 0.31, 0.20))
	_crystal(o + Vector2(-8, 3), 0.8, Color("ff9a3c") * b, Color("e2701d") * b)
	_crystal(o + Vector2(9, 4), 0.7, Color("ffd166") * b, Color("f0a733") * b)
	_crystal(o + Vector2(0, -4), 1.0, Color("ff7ac2") * b, Color("e0459b") * b)
	draw_circle(o + Vector2(-3, -9), 2.5, Color(1, 1, 1, 0.85))

func _crystal(o: Vector2, s: float, c1: Color, c2: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(0, -12 * s), o + Vector2(8 * s, 0), o + Vector2(0, 11 * s), o + Vector2(-8 * s, 0)]), c1)
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(0, -12 * s), o + Vector2(8 * s, 0), o + Vector2(0, 11 * s)]), c2)

func draw_crate(c: Dictionary, b: float) -> void:
	var p: Vector2 = c["pos"]
	var w: float = c["w"]
	var h: float = c["h"]
	draw_rect(Rect2(p.x, p.y, w, h), Color("a9703f") * b, true)
	draw_rect(Rect2(p.x + 2, p.y + 2, w - 4, h - 4), Color("7a4a24") * b, false, 4.0)
	draw_line(p + Vector2(4, 4), p + Vector2(w - 4, h - 4), Color("7a4a24") * b, 3.0)
	draw_line(p + Vector2(w - 4, 4), p + Vector2(4, h - 4), Color("7a4a24") * b, 3.0)
	draw_rect(Rect2(p.x + 4, p.y + 4, w - 8, 4), Color(1, 1, 1, 0.14), true)

func draw_slime(s: Dictionary, b: float) -> void:
	if s["dead"]: return
	var squash := sin(s["t"]) * 0.10
	var w: float = s["w"] * (1.0 + squash)
	var h: float = s["h"] * (1.0 - squash)
	var cx: float = s["pos"].x + s["w"] / 2.0
	var by: float = s["pos"].y + s["h"]
	ellipse(Vector2(cx, by + 3), w * 0.5, 5, Color(0, 0, 0, 0.18))
	var body := PackedVector2Array()
	for i in 16:
		var a := PI + PI * i / 15.0
		body.append(Vector2(cx + cos(a) * w * 0.5, by + sin(a) * h))
	body.append(Vector2(cx + w * 0.5, by))
	body.append(Vector2(cx - w * 0.5, by))
	draw_colored_polygon(body, Color("5cbf46") * b if Settings.q_low() else Color("6fd253") * b)
	if not Settings.q_low():
		ellipse(Vector2(cx - w * 0.18, by - h * 0.66), w * 0.14, h * 0.16, Color(1, 1, 1, 0.45))
	var dir := 1.0 if s["vx"] > 0 else -1.0
	draw_circle(Vector2(cx - 6 + dir * 2, by - h * 0.55), 5.5, Color.WHITE)
	draw_circle(Vector2(cx + 7 + dir * 2, by - h * 0.55), 5.5, Color.WHITE)
	draw_circle(Vector2(cx - 6 + dir * 3.2, by - h * 0.55), 2.6, Color("17300f"))
	draw_circle(Vector2(cx + 7 + dir * 3.2, by - h * 0.55), 2.6, Color("17300f"))

func draw_shot(s: Dictionary, col: Color, b: float) -> void:
	var o: Vector2 = s["pos"] + Vector2(6, 6)
	if not Settings.q_low():
		for i in range(1, 4):
			draw_circle(o - Vector2(s["vx"] * i * 0.8, 0), 7 - i * 1.4,
				Color(col.r, col.g, col.b, 0.16 * (4 - i)))
	draw_circle(o, 8 + sin(s["t"] * 0.5) * 1.2, col * b)
	draw_circle(o - Vector2(sign(s["vx"]) * 1.5, 1.5), 3, Color.WHITE)

func draw_goal(b: float) -> void:
	var x := goal.x
	var y := goal.y
	draw_rect(Rect2(x - 24, y - 26, 48, 28), Color("8b5a33") * b, true)
	ellipse(Vector2(x, y - 26), 24, 8, Color("c69257") * b)
	ellipse(Vector2(x, y - 26), 14, 4.5, Color("a8763f") * b)
	draw_rect(Rect2(x - 3, y - 124, 6, 100), Color("7a4a2a") * b, true)
	var w := sin(tglobal * 0.09) * 5.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 3, y - 120), Vector2(x + 34 + w, y - 108), Vector2(x + 3, y - 92)]), Color("ffce3b") * b)
	if not Settings.q_low():
		draw_circle(Vector2(x + 16, y - 130), 4,
			Color(1, 0.97, 0.78, 0.35 + sin(tglobal * 0.08) * 0.25))

func draw_player(b: float) -> void:
	if p_inv > 0 and int(tglobal / 4.0) % 2 == 0 and not p_dead: return
	var origin := p_pos + Vector2(P_W / 2.0, P_H)
	var rot := 0.0
	if p_dead: rot = p_dead_t * 0.06
	elif p_flip > 0.0: rot = -p_flip * p_face
	draw_set_transform(Vector2(-cam_x, 0) + origin, rot, Vector2(p_face, 1))

	if p_on_ground: ellipse(Vector2(0, 2), 16, 4.5, Color(0, 0, 0, 0.18))
	var run := sin(p_anim) * (1.0 if p_on_ground else 0.2)
	var l1 := run * 7.0
	var l2 := -run * 7.0
	if not p_on_ground: l1 = -5.0; l2 = 5.0
	draw_rect(Rect2(-10 + l1 * 0.4, -14, 8, 14), Color("5a3a24") * b, true)
	draw_rect(Rect2(2 + l2 * 0.4, -14, 8, 14), Color("5a3a24") * b, true)
	draw_rect(Rect2(-11 + l1 * 0.4, -4, 10, 5), Color("3b2617") * b, true)
	draw_rect(Rect2(1 + l2 * 0.4, -4, 10, 5), Color("3b2617") * b, true)
	draw_rect(Rect2(-14, -33, 10, 16), Color("2f5f8a") * b, true)
	draw_rect(Rect2(-11, -33, 22, 20), Color("3f86c9") * b, true)
	draw_rect(Rect2(-11, -20, 22, 7), Color("2f6ba4") * b, true)
	draw_line(Vector2(-9, -31), Vector2(7, -18), Color("d9b45a") * b, 3.0)
	draw_rect(Rect2(5, -29, 7, 15), Color("f2c49a") * b, true)
	draw_circle(Vector2(0, -46), 16, Color("f7cfa6") * b)
	draw_circle(Vector2(0, -52), 16, Color("6b3f22") * b)
	draw_circle(Vector2(12, -56), 7, Color("5a3218") * b)
	ellipse(Vector2(4, -45), 5, 6, Color.WHITE)
	ellipse(Vector2(-6, -45), 4, 5.4, Color.WHITE)
	draw_circle(Vector2(5, -45), 3, Color("2b7fbf"))
	draw_circle(Vector2(-5.5, -45), 2.6, Color("2b7fbf"))
	draw_circle(Vector2(5.6, -45), 1.4, Color("12232e"))
	draw_circle(Vector2(-5, -45), 1.2, Color("12232e"))
	draw_set_transform(Vector2(-cam_x, 0), 0.0, Vector2.ONE)

# ============================================================ HUD + overlays
func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var maxh: int = Settings.diff()["hearts"]
	for i in maxh:
		var on := i < hearts
		var c := Color("ff5470") if on else Color(0, 0, 0, 0.22)
		var o := Vector2(18 + i * 30, 18)
		hud.draw_circle(o + Vector2(-4, -2), 6, c)
		hud.draw_circle(o + Vector2(4, -2), 6, c)
		hud.draw_colored_polygon(PackedVector2Array([
			o + Vector2(-10, 0), o + Vector2(10, 0), o + Vector2(0, 11)]), c)
	for i in p_max_jumps:
		var c2 := Color("9ade5c") if i < p_jumps else Color(0, 0, 0, 0.22)
		var ox := 20 + i * 18
		hud.draw_colored_polygon(PackedVector2Array([
			Vector2(ox, 58), Vector2(ox + 6, 47), Vector2(ox + 12, 58)]), c2)

	if Settings.show_score:
		hud.draw_rect(Rect2(VW - 160, 8, 150, 34), Color(0.04, 0.10, 0.06, 0.30), true)
		hud.draw_string(font, Vector2(VW - 130, 32), "%d  %d" % [gem_count, score],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if Settings.show_timer:
		var ty := 60 if Settings.show_score else 8
		hud.draw_rect(Rect2(VW - 160, ty, 90, 30), Color(0.04, 0.10, 0.06, 0.30), true)
		hud.draw_string(font, Vector2(VW - 150, ty + 21),
			"%d:%02d" % [int(level_time / 60), int(level_time) % 60],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("eefbe8"))

	hud.draw_rect(Rect2(VW / 2 - 95, 8, 190, 30), Color(0.04, 0.10, 0.06, 0.30), true)
	hud.draw_string(font, Vector2(VW / 2 - 85, 29),
		"%d · %s" % [level_index + 1, LEVELS[level_index]["name"]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("eefbe8"))

	if mode != Mode.PLAY:
		hud.draw_rect(Rect2(0, 0, VW, VH), Color(0.03, 0.07, 0.05, 0.74), true)
		var title := ""
		var sub := ""
		match mode:
			Mode.TITLE: title = Settings.t("title"); sub = Settings.t("intro")
			Mode.PAUSED: title = Settings.t("paused"); sub = "Esc / P"
			Mode.CLEAR: title = Settings.t("clear"); sub = "%s — %d %s · %s %d" % [LEVELS[level_index]["name"], gem_count, Settings.t("crystals"), Settings.t("score"), score]
			Mode.OVER: title = Settings.t("over"); sub = "%s %d" % [Settings.t("score"), score]
			Mode.WIN: title = Settings.t("won"); sub = "%d %s · %s %d" % [gems_total, Settings.t("crystals"), Settings.t("score"), score]
		hud.draw_string(font, Vector2(VW / 2 - 200, VH / 2 - 30), title,
			HORIZONTAL_ALIGNMENT_CENTER, 400, 34, Color("f4fbf2"))
		hud.draw_string(font, Vector2(VW / 2 - 450, VH / 2 + 10), sub,
			HORIZONTAL_ALIGNMENT_CENTER, 900, 16, Color("cfe6cd"))
		hud.draw_string(font, Vector2(VW / 2 - 260, VH / 2 + 34),
			"Best: %d" % max(Settings.get_best(), score),
			HORIZONTAL_ALIGNMENT_CENTER, 520, 16, Color("ffd34d"))
		hud.draw_string(font, Vector2(VW / 2 - 260, VH / 2 + 60),
			"[Enter] " + (Settings.t("resume") if mode == Mode.PAUSED else Settings.t("start")) + "    [O] " + Settings.t("settings"),
			HORIZONTAL_ALIGNMENT_CENTER, 520, 16, Color("a9c7a8"))

# ============================================================ menus / confirm
func confirm() -> void:
	match mode:
		Mode.TITLE, Mode.OVER, Mode.WIN: start_run()
		Mode.CLEAR:
			load_level(level_index + 1)
			mode = Mode.PLAY
			Settings.music_on = true
		Mode.PAUSED: toggle_pause()

func toggle_settings() -> void:
	if menu == null: return
	if menu.visible:
		if menu.listening_for == "": menu.close()
	else:
		if mode == Mode.PLAY: toggle_pause()
		menu.open()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_O:
			toggle_settings()
		elif event.keycode == KEY_ENTER and not (menu and menu.visible):
			confirm()

# ============================================================ backgrounds (one per level)
func _gradient(top: Color, bottom: Color, b: float) -> void:
	var steps := 18
	for i in steps:
		var t := float(i) / float(steps - 1)
		draw_rect(Rect2(0, i * VH / float(steps), VW, VH / float(steps) + 1), top.lerp(bottom, t) * b, true)

func _clouds(b: float, col: Color, n: int, speed: float) -> void:
	for c in n:
		var cx := fposmod(c * 340.0 - cam_x * speed, VW + 420.0) - 210.0
		var cy := 50.0 + (c % 3) * 46.0
		draw_circle(Vector2(cx, cy), 26, col * b)
		draw_circle(Vector2(cx + 28, cy + 6), 20, col * b)
		draw_circle(Vector2(cx - 26, cy + 18), 20, col * b)
		draw_circle(Vector2(cx + 6, cy - 14), 20, col * b)

func _hills(b: float, col: Color, speed: float, r: float, y: float) -> void:
	for h in 12:
		var hx := h * 260.0 - fposmod(cam_x * speed, 260.0) - 130.0
		ellipse(Vector2(hx, y), r, r, col * b, 24)

func draw_backdrop(b: float, spec: Dictionary) -> void:
	var low := Settings.q_low()
	var n := 8 if Settings.q_high() else 5
	match level_index:
		0:
			draw_rect(Rect2(0, 0, VW, VH), (spec["tint"] as Color) * b, true)
			if not low:
				draw_rect(Rect2(0, VH * 0.6, VW, VH * 0.4), Color("d9f5e2") * b * 0.98, true)
				_clouds(b, Color(1, 1, 1, 0.75), n, 0.25)
				_hills(b, Color(0.47, 0.77, 0.47, 0.45), 0.4, 150, VH - 120)
		1:
			_gradient(Color("ffd9a0"), Color("ff8a65"), b)
			if not low:
				draw_circle(Vector2(740, 330), 70, Color("fff3c4") * b)
				_clouds(b, Color(1, 0.8, 0.7, 0.7), n, 0.2)
				_hills(b, Color(0.55, 0.35, 0.5, 0.55), 0.3, 190, VH - 80)
				_hills(b, Color(0.35, 0.25, 0.4, 0.6), 0.5, 130, VH - 110)
		2:
			_gradient(Color("0b1030"), Color("2b3a7a"), b)
			if not low:
				for s in 40:
					var sx := fposmod(s * 97.0 - cam_x * 0.05, VW)
					var sy := fposmod(s * 53.0, VH * 0.6)
					draw_circle(Vector2(sx, sy), 1.5 + (s % 3) * 0.5, Color(1, 1, 0.9, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0 + s)) * b)
				draw_circle(Vector2(180, 90), 36, Color("f5f0d0") * b)
				draw_circle(Vector2(194, 82), 32, Color("0e1538") * b)
				_hills(b, Color(0.08, 0.18, 0.22, 0.8), 0.3, 170, VH - 90)
				_hills(b, Color(0.05, 0.12, 0.16, 0.9), 0.5, 120, VH - 110)
		_:
			draw_rect(Rect2(0, 0, VW, VH), (spec["tint"] as Color) * b, true)

# ============================================================ water overlay, cursor, on-screen buttons
func draw_water_over(c0: int, c1: int) -> void:
	for col in range(c0, c1 + 1):
		if tiles[GROUND_ROW][col] == WATER:
			draw_rect(Rect2(col * TS, GROUND_ROW * TS + 4, TS, TS * 4), Color(0.27, 0.65, 0.84, 0.6), true)

func make_cursor() -> void:
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	var c := Vector2(16, 16)
	for x in 32:
		for y in 32:
			var d := Vector2(x, y).distance_to(c)
			if d <= 3.5 or (d >= 8.0 and d <= 12.5):
				img.set_pixel(x, y, Color(0, 0, 0, 0.8))
			if d <= 2.0 or (d >= 9.0 and d <= 11.5):
				img.set_pixel(x, y, Color.WHITE)
	Input.set_custom_mouse_cursor(img, Input.CURSOR_ARROW, c)
	Input.set_custom_mouse_cursor(img, Input.CURSOR_POINTING_HAND, c)

var touch: CanvasLayer
var touch_down := {}

func make_touch_controls() -> void:
	touch = CanvasLayer.new()
	touch.layer = 5
	add_child(touch)
	_touch_btn("left", Vector2(52, VH - 52), 30.0)
	_touch_btn("right", Vector2(122, VH - 52), 30.0)
	_touch_btn("jump", Vector2(VW - 138, VH - 52), 34.0)
	_touch_btn("shoot", Vector2(VW - 58, VH - 52), 32.0)

func _touch_btn(act: String, center: Vector2, r: float) -> void:
	var c := Control.new()
	c.position = center - Vector2(r, r)
	c.size = Vector2(r, r) * 2.0
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_down[act] = false
	c.draw.connect(func(): _draw_touch_btn(c, act, r))
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			touch_down[act] = e.pressed
			_pad_press(act, e.pressed)
			c.queue_redraw())
	c.mouse_exited.connect(func():
		if touch_down[act]:
			touch_down[act] = false
			_pad_press(act, false)
			c.queue_redraw())
	touch.add_child(c)

func _draw_touch_btn(c: Control, act: String, r: float) -> void:
	var o := Vector2(r, r)
	var down: bool = touch_down[act]
	var rr := r * (0.92 if down else 1.0)
	c.draw_circle(o + Vector2(0, 4), rr, Color(0, 0, 0, 0.22))
	c.draw_circle(o, rr, Color(0.35, 0.65, 0.25, 0.80) if down else Color(0.04, 0.10, 0.06, 0.55))
	c.draw_arc(o, rr - 2.0, 0.0, TAU, 40, Color.WHITE if down else Color("9ade5c"), 3.0, true)
	var ic := Color("f4fbf2")
	match act:
		"left":
			c.draw_colored_polygon(PackedVector2Array([
				o + Vector2(-14, 0), o + Vector2(8, -17), o + Vector2(8, 17)]), ic)
		"right":
			c.draw_colored_polygon(PackedVector2Array([
				o + Vector2(14, 0), o + Vector2(-8, -17), o + Vector2(-8, 17)]), ic)
		"jump":
			for k in 2:
				var y := 10.0 - k * 16.0
				c.draw_polyline(PackedVector2Array([
					o + Vector2(-17, y), o + Vector2(0, y - 15), o + Vector2(17, y)]), ic, 6.0, true)
		"shoot":
			for i in range(1, 4):
				c.draw_circle(o + Vector2(-i * 9.0, 0), 11.0 - i * 2.2, Color(1, 0.54, 0.24, 0.20 * (4 - i)))
			c.draw_circle(o + Vector2(6, 0), 19.0, Color(1, 0.54, 0.24, 0.25))
			c.draw_circle(o + Vector2(6, 0), 13.0, Color("ff8a3d"))
			c.draw_circle(o + Vector2(3, -4), 4.5, Color.WHITE)

# ============================================================ title screen buttons
var title_ui: CanvasLayer

func make_title_buttons() -> void:
	title_ui = CanvasLayer.new()
	title_ui.layer = 4
	add_child(title_ui)
	_title_btn("Start Game", Vector2(VW / 2 - 110, VH / 2 + 90), func(): confirm())
	_title_btn("Settings", Vector2(VW / 2 - 110, VH / 2 + 146), func(): toggle_settings())

func _title_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(22)
	return s

func _title_btn(text: String, pos: Vector2, action: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(220, 44)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color("f4fbf2"))
	btn.add_theme_stylebox_override("normal", _title_style(Color(0.04, 0.10, 0.06, 0.75), Color("9ade5c")))
	btn.add_theme_stylebox_override("hover", _title_style(Color(0.35, 0.65, 0.25, 0.85), Color.WHITE))
	btn.add_theme_stylebox_override("pressed", _title_style(Color(0.25, 0.50, 0.18, 0.95), Color.WHITE))
	btn.pressed.connect(action)
	title_ui.add_child(btn)
