extends Node2D
# SIGNAL AT BIRCHWOOD - Act I. Native Godot 4, everything drawn in code (curves + lighting shader).
const WORLD := 4200.0
const SW := 960.0
const SH := 540.0
const LEDGES := [[1000.0, 1200.0, 80.0], [2050.0, 2300.0, 100.0], [3100.0, 3350.0, 70.0]]  # back-lane barriers: x0, x1, height
const LAMPS := [520.0, 1300.0, 2100.0, 2900.0, 3700.0]
const SHADER := "shader_type canvas_item;
uniform vec2 holes[12]; uniform float hr[12]; uniform vec2 co; uniform float ca; uniform float on; uniform float dark; uniform vec3 tint;
void fragment(){ vec2 p=UV*vec2(960.,540.); float l=0.;
 for(int i=0;i<12;i++){ l=max(l,1.-smoothstep(0.,hr[i],distance(p,holes[i]))); }
 vec2 d=p-co; float r=length(d)+0.001; float c=dot(d/r,vec2(cos(ca),sin(ca)));
 l=max(l,on*smoothstep(0.86,0.97,c)*(1.-smoothstep(40.,400.,r)));
 COLOR=vec4(tint,dark*(1.-clamp(l,0.,1.))); }"

class Foe:
	var x := 0.0
	var y := 400.0
	var face := -1
	var hp := 70.0
	var kind := 0   # 0 Echo Stalker, 1 Hollow Nurse, 2 The Distortion
	var st := 0     # 0 patrol 1 investigate 2 chase 3 windup 4 strike 5 recover 6 stagger 7 search
	var tm := 0.0
	var home := 0.0
	var alert := 0.0
	var last := Vector2.ZERO
	var atk := 0
	var slot := 0.0
	var done := false
	var dir := 1.0
	var van := 0.0

var t := 0.0
var rt := 0.0
var rdt := 0.016
var last_us := 0
var acc := 0.0
var cam := 0.0
var zoom := 1.0
var focus := Vector2(480, 270)
var band := 0
var light := true
var energy := 100.0
var hp := 100.0
var started := false
var ended := false
var P := Vector2(220, 400)
var alt := 0.0
var face := 1
var still := 0.0
var noise := 0.0
var phase := 0.0
var lean := Vector2.ZERO
var tip := {}
var tgt := {}
var spd := {}
var cd := {}
var trails := {}
var guarding := false
var guard_t := -9.0
var hab := {"guard": 0.0, "dodge": 0.0, "strike": 0.0}
var foes: Array = []
var trail: Array = []
var parts: Array = []
var pops: Array = []
var msgs: Array = []
var tch := {}
var stick := Vector2.ZERO
var shake := 0.0
var check := 220.0
var fade := 0.0
var jab := 0.0
var climb := -1.0
var climb_alt := 0.0
var climb_x := 0.0
var got := false
var spawned := false
var seen_stalker := false
var ui: Node2D
var rect: ColorRect
var pb: AudioStreamGeneratorPlayback
var lp := 0.0
var sph := 0.0
var holes: Array = []
var menu := 1
var diff := 1
var gfx := 1
var vol := 8
var mag := 7
var res := 7
var reload := 0.0
var fcd := 0.0
var rc := 0.0
var bloom := 0.0
var flash := 0.0
var muz := Vector2.ZERO
var shot := 0.0
var aim := false
var aim_t := 0.0
var aim_el := 0.0
var shots: Array = []
var boxes: Array = []
var cine := false
var bars := 26.0
var card_t := 0.0
var end_t := 0.0
var radio_fx := false
const INTRO := [["Evelyn Mercer", "The bridge is completely out... How is there a signal out here?", "«پل کاملاً خراب شده... چطور اینجا سیگنال رادیویی هست؟»"], ["Radio Voice (Static)", "Evelyn... leave the car. The rain won't stop until you hear the tape.", "«ایولین... ماشین رو رها کن. بارون بند نمیاد تا زمانی که نوار رو بشنوی.»"], ["Radio Voice (Static)", "There is a Colt in your coat. Seven rounds. Every one of them is loud. When the dial hits 99.9, time itself slows. Use it.", "«توی کتت یه کلت هست. هفت گلوله. صدای هر کدوم خیلی بلنده. وقتی روی ۹۹.۹ بری زمان کند می‌شه؛ ازش استفاده کن.»"]]

func _ready() -> void:
	var cl := CanvasLayer.new(); cl.layer = 1; add_child(cl)
	rect = ColorRect.new(); rect.size = Vector2(SW, SH); rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new(); sh.code = SHADER
	var m := ShaderMaterial.new(); m.shader = sh; rect.material = m; cl.add_child(rect)
	var cu := CanvasLayer.new(); cu.layer = 2; add_child(cu)
	ui = Node2D.new(); cu.add_child(ui); ui.draw.connect(draw_ui)
	var ap := AudioStreamPlayer.new(); var gen := AudioStreamGenerator.new(); gen.mix_rate = 22050.0; gen.buffer_length = 0.25
	ap.stream = gen; add_child(ap); ap.play(); pb = ap.get_stream_playback()
	for k in ["lh", "rh", "lf", "rf"]:
		tip[k] = stance(k); tgt[k] = stance(k); spd[k] = 0.0; cd[k] = 0.0; trails[k] = []
	for i in range(240): trail.append(P)
	for d in [[1350.0, 0], [1550.0, 0], [2450.0, 1], [2750.0, 0], [3000.0, 1], [3500.0, 0], [3650.0, 1]]:
		var f := Foe.new(); f.x = d[0]; f.home = d[0]; f.kind = d[1]; f.y = 360.0 + randf() * 100.0; f.hp = 60.0 if d[1] == 0 else 90.0; foes.append(f)
	load_cfg()
	Engine.time_scale = 1.0
	last_us = Time.get_ticks_usec()

func stance(k: String) -> Vector2:
	match k:
		"lh": return Vector2(8, -108)
		"rh": return Vector2(22, -100)
		"lf": return Vector2(-12, 0)
	return Vector2(12, 0)

func sc(y: float) -> float: return 0.8 + (y - 330.0) / 140.0 * 0.4
func w2s(w: Vector2) -> Vector2: return (w - focus) * zoom + Vector2(480, 270)
func s2w(s: Vector2) -> Vector2: return (s - Vector2(480, 270)) / zoom + focus
func W(o: Vector2, s: float, fc: int, l: Vector2) -> Vector2: return o + Vector2(l.x * fc, l.y) * s
func slow() -> bool: return band == 2 and energy > 1.0 and started and not ended
func floor_at(x: float, y: float) -> float:
	var h := 0.0
	if y < 392.0:
		for l in LEDGES:
			if x > l[0] and x < l[1]: h = max(h, l[2])
	return h

func ik(a: Vector2, b: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d := clampf(a.distance_to(b), 1.0, l1 + l2 - 1.0)
	var c := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	return a + Vector2.from_angle((b - a).angle() + bend * acos(c)) * l1

# ---------------- input ----------------
func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var te: InputEventScreenTouch = e
		if te.pressed: tdown(te.index, te.position)
		else:
			tch.erase(te.index)
			if tch.is_empty(): stick = Vector2.ZERO
	elif e is InputEventScreenDrag:
		var de: InputEventScreenDrag = e
		tmove(de.index, de.position)

func btn(p: Vector2, c: Vector2, r: float) -> bool: return p.distance_to(c) < r
func tdown(i: int, p: Vector2) -> void:
	if menu != 0: menu_tap(p); return
	if card_t > 0.0: return
	if not msgs.is_empty():
		msgs.pop_front()
		if msgs.is_empty() and got: ended = true
		return
	if ended:
		if end_t > 2.0: get_tree().reload_current_scene()
		return
	if p.distance_to(Vector2(924, 56)) < 30: menu = 2; return
	if btn(p, Vector2(880, 470), 44): band = (band + 1) % 3; noise = 200.0; return
	if btn(p, Vector2(770, 485), 34): light = not light; noise = 200.0; return
	if btn(p, Vector2(880, 370), 40): fire(); return
	if btn(p, Vector2(770, 395), 34): act(); return
	if btn(p, Vector2(680, 480), 34): aim = not aim; aim_t = 0.0; return
	if btn(p, Vector2(680, 400), 30): do_reload(); return
	if slow():
		var o := w2s(Vector2(P.x, P.y - alt)); var s := sc(P.y) * zoom
		var best := ""; var bd := 70.0
		for k in tip:
			var d := p.distance_to(o + Vector2(tip[k].x * face, tip[k].y) * s)
			if d < bd: bd = d; best = k
		if p.distance_to(o + Vector2(lean.x * face, -85 + lean.y) * s) < 60 and best == "": best = "body"
		if best != "": tch[i] = {"k": best}; return
	if aim and p.x > 480: tch[i] = {"k": "aim", "l": p}; return
	if p.x < 480: tch[i] = {"k": "stick", "o": p}

func tmove(i: int, p: Vector2) -> void:
	if not tch.has(i): return
	var k: String = tch[i]["k"]
	if k == "aim":
		aim_el = clampf(aim_el - (p.y - tch[i]["l"].y) * 0.006, -0.9, 0.9); tch[i]["l"] = p; return
	if k == "stick": stick = ((p - tch[i]["o"]) / 55.0).limit_length(1.0); return
	var o := w2s(Vector2(P.x, P.y - alt)); var s := sc(P.y) * zoom
	var l := (p - o) / s; l.x *= face
	if k == "body": lean = (l - Vector2(0, -85)).limit_length(40.0); return
	var j := Vector2(0, -100) + lean if k.ends_with("h") else Vector2(0, -62)
	tgt[k] = j + (l - j).limit_length(52.0 if k.ends_with("h") else 62.0)

func say(q: Array) -> void: msgs.append_array(q)

func act() -> void:
	if not msgs.is_empty() or climb >= 0.0: return
	if not got and absf(P.x - 3990.0) < 70.0:
		got = true
		say([["Eleanor Mercer (Tape)", "Evelyn... if this signal reaches you, turn back. Don't look for the Broadcast Spire. The Echo hasn't forgotten your voice.", "«ایولین... اگه این سیگنال به دستت می‌رسه، برگرد. دنبال برج فرستنده نگرد. پژواک هنوز صداتو فراموش نکرده.»"], ["Evelyn Mercer", "...That's Mom. And the footsteps in the background... they're mine.", "«...این مامانه. و اون قدم‌های پس‌زمینه... مال منه.»"]])
		return
	try_climb()

func try_climb() -> void:
	if alt > 5.0 or P.y > 392.0: return
	for l in LEDGES:
		if (absf(P.x - l[0]) < 60.0 and face == 1) or (absf(P.x - l[1]) < 60.0 and face == -1):
			climb = 0.0; climb_alt = l[2]; climb_x = (l[0] + 40.0) if face == 1 else (l[1] - 40.0); return

# ---------------- simulation ----------------
func _process(delta: float) -> void:
	var now := Time.get_ticks_usec(); rdt = minf((now - last_us) / 1000000.0, 0.05); last_us = now; rt += rdt; t += delta
	if menu != 0:
		Engine.time_scale = 1.0; snd(delta); queue_redraw(); ui.queue_redraw(); draw_dark(); return
	cine = not msgs.is_empty() or ended or card_t > 0.0
	bars = lerpf(bars, 100.0 if cine else 26.0, minf(1.0, 4.0 * rdt))
	var sl := slow()
	if band == 2 and energy <= 1.0: band = 0
	Engine.time_scale = lerpf(Engine.time_scale, 0.2 if sl else 1.0, minf(1.0, 8.0 * rdt))
	if sl: energy -= 15.0 * rdt
	else: energy = minf(100.0, energy + 7.0 * rdt)
	zoom = lerpf(zoom, 1.75 if sl else (1.3 if cine else 1.0), minf(1.0, 5.0 * rdt))
	shake = maxf(0.0, shake - 30.0 * rdt)
	var locked := not msgs.is_empty() or fade > 0.0 or ended or not started or climb >= 0.0 or card_t > 0.0
	var mv := Vector2.ZERO
	if not locked: mv = stick + Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	mv = mv.limit_length(1.0)
	var sp := 190.0 if mv.length() > 0.85 else 140.0
	if aim: sp *= 0.45
	var nx := clampf(P.x + mv.x * sp * delta, 150.0, WORLD - 40.0)
	if floor_at(nx, P.y) > alt + 6.0: nx = P.x
	P.x = nx; P.y = clampf(P.y + mv.y * 90.0 * delta, 330.0, 470.0)
	if absf(mv.x) > 0.2 and not aim: face = 1 if mv.x > 0 else -1
	if mv.length() > 0.1: still = 0.0; phase += mv.length() * 9.0 * delta
	else: still += delta
	var fl := floor_at(P.x, P.y)
	if climb >= 0.0:
		climb += delta / 0.7; alt = lerpf(alt, climb_alt, minf(1.0, 6.0 * delta)); P.x = lerpf(P.x, climb_x, minf(1.0, 4.0 * delta))
		if climb >= 1.0: climb = -1.0
	elif alt > fl: alt = maxf(fl, alt - 400.0 * delta)
	var nt := 40.0 if mv.length() < 0.1 else (320.0 if sp > 150.0 else 150.0)
	noise = lerpf(noise, nt, minf(1.0, 3.0 * delta)) if noise <= nt + 1.0 else maxf(nt, noise - 150.0 * delta)
	acc += delta
	while acc >= 1.0 / 60.0: acc -= 1.0 / 60.0; trail.append(P); trail.pop_front()
	var tcam := clampf(P.x - 480.0 + face * 80.0, 0.0, WORLD - SW)
	cam += (tcam - cam) * minf(1.0, 5.0 * rdt)
	var foc := Vector2(cam + 480.0, 270.0)
	focus = foc.lerp(Vector2(P.x, P.y - alt - 50.0), clampf((zoom - 1.0) / 0.75, 0.0, 1.0))
	update_limbs(sl, mv)
	fcd = maxf(0.0, fcd - rdt); rc = maxf(0.0, rc - 5.0 * rdt); bloom = maxf(0.0, bloom - 0.08 * rdt); flash = maxf(0.0, flash - rdt)
	if aim_t > 0.0 and not aim: aim_t -= rdt
	if reload > 0.0:
		reload -= rdt
		if reload <= 0.0:
			var tk := mini(7 - mag, res); mag += tk; res -= tk; shot = 0.3
	for sh in shots: sh["l"] -= delta
	shots = shots.filter(func(q): return q["l"] > 0.0)
	for b in boxes:
		if not b[3] and absf(P.x - b[0]) < 40.0 and absf(P.y - b[1]) < 40.0:
			b[3] = true; res += b[2]; shot = 0.2
			pops.append({"t": "+" + str(b[2]) + " 45ACP", "p": Vector2(P.x, P.y - alt - 120.0), "l": 1.2, "c": Color(0.9, 0.8, 0.4)})
	if card_t > 0.0:
		card_t -= rdt
		if card_t <= 0.0: say(INTRO)
	if ended: end_t += rdt
	radio_fx = not msgs.is_empty() and (msgs[0][0].begins_with("Radio") or msgs[0][0].begins_with("Eleanor"))
	if jab > 0.0:
		jab -= rdt
		if jab > 0.12: tgt["rh"] = Vector2(54, -100)
		if jab <= 0.12 and jab > 0.115:
			for f in foes:
				if absf(f.y - P.y) < 34.0 and (f.x - P.x) * face > 0.0 and (f.x - P.x) * face < 85.0: hit_foe(f, 9.0, "rh")
	if not spawned and P.x > 900.0 and not locked:
		spawned = true; check = 800.0
		say([["Evelyn Mercer", "Those footsteps... they're mine. Something is walking exactly where I walked.", "«اون قدم‌ها... مال منه. چیزی دقیقاً همون جاهایی راه میره که من رفتم.»"]])
		var f := Foe.new(); f.kind = 2; f.x = P.x - 600.0; f.y = P.y; f.hp = 160.0; f.st = 2; f.alert = 1.0; foes.append(f)
	if not seen_stalker and P.x > 1150.0 and not locked:
		seen_stalker = true; check = 1100.0
		say([["Radio Voice (Static)", "Echo Stalkers. They hear every step. Kill the light... or make them listen to you.", "«پژواک‌گردها. هر قدمی رو می‌شنوند. چراغ رو خاموش کن... یا مجبورشون کن به تو گوش بدن.»"]])
	for f in foes: ai(f, delta, sl)
	foes = foes.filter(func(f): return f.hp > 0.0)
	for p in parts:
		p["p"] += p["v"] * delta; p["l"] -= delta
		if p.has("g"):
			var vv: Vector2 = p["v"]; vv.y += p["g"] * delta; p["v"] = vv
		elif p.get("k", "p") == "s": p["v"] = p["v"] * (1.0 - 1.5 * delta)
	parts = parts.filter(func(p): return p["l"] > 0.0)
	for q in pops: q["l"] -= rdt
	pops = pops.filter(func(q): return q["l"] > 0.0)
	if hp <= 0.0 and fade <= 0.0: fade = 0.01
	if fade > 0.0:
		fade += rdt
		if fade > 2.4:
			fade = 0.0; hp = 100.0; P = Vector2(check, 400.0); alt = 0.0; lean = Vector2.ZERO
			for f in foes: f.st = 7; f.tm = 3.0; f.alert = 0.0; f.x = f.home if f.kind != 2 else check - 600.0
	snd(delta)
	queue_redraw(); ui.queue_redraw()
	if rect: draw_dark()

func update_limbs(sl: bool, mv: Vector2) -> void:
	var held := []
	for i in tch: held.append(tch[i]["k"])
	var hh: Vector2 = Vector2(0, -114) + lean * 1.2
	var gd: bool = tip["lh"].distance_to(hh) < 34.0 and tip["rh"].distance_to(hh) < 34.0 and sl
	if gd and not guarding: guard_t = rt
	guarding = gd
	if not sl:
		lean = lean.lerp(Vector2.ZERO, minf(1.0, 6.0 * rdt))
		var sw := sin(phase) * 15.0 * minf(1.0, mv.length() * 2.0)
		tgt["lf"] = Vector2(-10 + sw, -maxf(0.0, cos(phase)) * 9.0 * mv.length())
		tgt["rf"] = Vector2(10 - sw, -maxf(0.0, -cos(phase)) * 9.0 * mv.length())
		tgt["lh"] = Vector2(-6 - sw * 0.5, -78.0)
		var gun := aim or aim_t > 0.0
		if reload > 0.0:
			tgt["rh"] = Vector2(14, -74); tgt["lh"] = Vector2(12, -70)
		elif gun:
			var el := aim_el + sin(t * 1.7) * 0.012 * (1.0 + 3.0 * mv.length()) - rc * 0.12
			var dv := Vector2(cos(el), -sin(el)); var shv := Vector2(0, -100) + lean
			tgt["rh"] = shv + dv * (50.0 - rc * 8.0); tgt["lh"] = shv + dv * 36.0 + Vector2(0, 6)
		elif jab <= 0.0: tgt["rh"] = Vector2(26, -92 + (10.0 if light else 0.0)) if light else Vector2(10, -78)
	else:
		for k in tgt:
			if not held.has(k): tgt[k] = tgt[k].lerp(stance(k), minf(1.0, 1.5 * rdt))
		if not held.has("body"): lean = lean.lerp(Vector2.ZERO, minf(1.0, 1.2 * rdt))
	var s := sc(P.y)
	for k in tip:
		var old: Vector2 = tip[k]
		tip[k] = old.lerp(tgt[k], minf(1.0, 28.0 * rdt))
		spd[k] = (tip[k] - old).length() * s / maxf(rdt, 0.001); cd[k] -= rdt
		var tr: Array = trails[k]; tr.append(W(Vector2(P.x, P.y - alt), s, face, tip[k])); if tr.size() > 9: tr.pop_front()
		if spd[k] > 420.0 and cd[k] <= 0.0 and (sl or jab > 0.0):
			var wp := W(Vector2(P.x, P.y - alt), s, face, tip[k])
			for f in foes:
				if f.van > 0.0: continue
				var fs := 1.12 if f.kind == 0 else 1.28 if f.kind == 1 else 1.2
				if absf(f.y - P.y) < 36.0 and absf(wp.x - f.x) < 30.0 * fs and wp.y < f.y and wp.y > f.y - 125.0 * fs:
					var d := clampf(spd[k] * 0.03, 5.0, 38.0) * (1.6 if k.ends_with("f") else 1.0)
					if tip[k].y < -105.0 and f.kind == 1: d *= 2.0
					hit_foe(f, d, k); break
	if climb < 0.0 and sl and alt < 5.0:
		for k in ["lh", "rh"]:
			for l in LEDGES:
				var wp := W(Vector2(P.x, P.y - alt), s, face, tip[k])
				if tip[k].y < -125.0 and P.y < 392.0 and wp.y < 345.0 - l[2] + 8.0 and wp.x > l[0] - 24.0 and wp.x < l[1] + 24.0 and (absf(P.x - l[0]) < 70.0 or absf(P.x - l[1]) < 70.0):
					face = 1 if P.x < (l[0] + l[1]) * 0.5 else -1; try_climb()

func hit_foe(f: Foe, d: float, k: String) -> void:
	if alt > 30.0: d *= 1.5
	if f.st == 6: d *= 1.3
	f.hp -= d; f.alert = 1.0; f.last = P
	if d > 14.0 or f.st == 3: f.st = 6; f.tm = 0.5 + d * 0.025
	f.x += signf(f.x - P.x) * d * 0.9; cd[k] = 0.45; shake = minf(10.0, d * 0.4); hab["strike"] += 0.2
	var wp := Vector2(f.x, f.y - 70.0)
	for i in range(6): parts.append({"p": wp, "v": Vector2.from_angle(randf() * TAU) * (60.0 + randf() * 120.0), "l": 0.5})
	pops.append({"t": str(int(d)), "p": wp, "l": 0.8, "c": Color(1, 0.8, 0.5)})

func ai(f: Foe, dt: float, sl: bool) -> void:
	f.tm -= dt
	if f.van > 0.0:
		f.van -= dt
		if f.van <= 0.0: f.x = P.x - face * 450.0; f.y = P.y; f.st = 2; f.alert = 1.0
		return
	var d := Vector2(P.x - f.x, P.y - f.y)
	var dist := absf(d.x)
	var hidden := not light and still > 1.5 and dist > 70.0
	var vis := 300.0 if light else 120.0
	if band == 1: vis *= 0.4
	var see := not hidden and absf(d.y) < 80.0 and ((d.x * f.face > 0.0 and dist < vis) or dist < 80.0)
	var hear := noise * (1.3 if band == 2 else 1.0) > dist and absf(d.y) < 160.0
	if f.kind == 2: see = not hidden and dist < 600.0; hear = false
	if see: f.alert = 1.0; f.last = P
	elif hear: f.alert = maxf(f.alert, 0.6); f.last = P + Vector2(randf_range(-40, 40), 0)
	else: f.alert = maxf(0.0, f.alert - dt * 0.12)
	var spdm: float = [170.0, 95.0, 125.0][f.kind]
	var reach := [70.0, 120.0, 52.0, 260.0]
	match f.st:
		0:
			if f.x > f.home + 160.0: f.dir = -1.0
			elif f.x < f.home - 160.0: f.dir = 1.0
			f.x += f.dir * 38.0 * dt; f.face = int(f.dir)
			if f.alert > 0.55: f.st = 2 if see else 1; f.tm = 4.0
		1:
			f.x += signf(f.last.x - f.x) * spdm * 0.45 * dt; f.face = 1 if f.last.x > f.x else -1
			if see: f.st = 2
			elif absf(f.last.x - f.x) < 20.0 or f.tm <= 0.0: f.st = 7; f.tm = 4.0
		2:
			var tg := P
			if f.kind == 2 and f.hp > 0.0: tg = trail[0]
			if hidden and f.kind != 2: f.st = 7; f.tm = 3.0
			var ty := tg.y + f.slot
			f.y += clampf(ty - f.y, -60.0 * dt, 60.0 * dt)
			var dx := tg.x - f.x
			f.face = 1 if dx > 0 else -1
			if absf(dx) > reach[0] * 0.8: f.x += signf(dx) * spdm * dt
			if f.alert < 0.2 and f.kind != 2: f.st = 7; f.tm = 3.0
			if dist < 190.0 and absf(P.y - f.y) < 34.0 and f.tm < 0.0 and (f.kind != 2 or dist < 70.0):
				f.face = 1 if d.x > 0 else -1
				var w1: float = 2.0 + hab["dodge"]; var w2: float = 1.0 + hab["strike"] * 0.5; var w3: float = 1.0 + hab["guard"] * 1.5
				var r := randf() * (w1 + w2 + w3)
				f.atk = 0 if r < w1 else 1 if r < w1 + w2 else 2
				if f.kind == 1 and dist > 120.0: f.atk = 3
				if (f.atk == 0 and dist > 90.0) or (f.atk == 2 and dist > 70.0): f.atk = 1
				f.st = 3; f.tm = [0.55, 0.9, 0.35, 1.0][f.atk]; f.done = false
		3:
			f.face = 1 if d.x > 0 else -1
			if f.tm <= 0.0: f.st = 4; f.tm = 0.18
		4:
			if not f.done:
				f.done = true
				if absf(d.x) < reach[f.atk] * (1.0 if f.kind != 1 else 1.1) and absf(d.y) < 34.0 and (alt < 20.0 or f.atk != 2): resolve(f)
			if f.atk == 1: f.x += f.face * 420.0 * dt
			if f.tm <= 0.0: f.st = 5; f.tm = 0.7
		5:
			if f.tm <= 0.0: f.st = 2; f.tm = 0.4
		6:
			if f.tm <= 0.0: f.st = 2; f.tm = 0.3
		7:
			f.x += sin(t * 0.7 + f.home) * 20.0 * dt
			if f.alert > 0.55: f.st = 2 if see else 1; f.tm = 4.0
			elif f.tm <= 0.0: f.st = 0
	for o in foes:
		if o != f and absf(o.x - f.x) < 46.0 and absf(o.y - f.y) < 24.0:
			f.x += signf(f.x - o.x + 0.01) * 50.0 * dt; f.slot = 34.0 if f.x < o.x else -34.0
	f.x = clampf(f.x, 150.0, WORLD - 40.0); f.y = clampf(f.y, 330.0, 470.0)

func resolve(f: Foe) -> void:
	var sg := signf(f.x - P.x)
	var dm: float = [12.0, 18.0, 24.0, 12.0][f.atk] * [0.6, 1.0, 1.4][diff]
	var need := 36.0 if f.atk == 2 else 22.0
	var lw := absf(lean.x) if lean.x * face * sg < 0.0 else 0.0
	if f.atk != 3 and lw > need:
		hab["dodge"] += 1.0; energy = minf(100.0, energy + 8.0)
		pops.append({"t": "SLIP", "p": Vector2(P.x, P.y - alt - 120.0), "l": 0.9, "c": Color(0.5, 1, 0.9)}); return
	if guarding and rt - guard_t < 0.4:
		f.st = 6; f.tm = 1.8; energy = minf(100.0, energy + 25.0); hab["guard"] += 1.0; shake = 10.0
		pops.append({"t": "PARRY", "p": Vector2(P.x, P.y - alt - 120.0), "l": 1.0, "c": Color(1, 0.3, 0.25)})
		for i in range(10): parts.append({"p": Vector2(P.x + face * 30.0, P.y - alt - 90.0), "v": Vector2.from_angle(randf() * TAU) * 160.0, "l": 0.6})
		return
	if guarding and f.atk != 2:
		hp -= dm * 0.2; energy -= 8.0; hab["guard"] += 1.0
		pops.append({"t": "BLOCK", "p": Vector2(P.x, P.y - alt - 120.0), "l": 0.8, "c": Color(0.8, 0.8, 1)}); return
	hp -= dm; shake = 12.0; hab["guard"] = maxf(0.0, hab["guard"] - 0.5)
	pops.append({"t": "-" + str(int(dm)), "p": Vector2(P.x, P.y - alt - 120.0), "l": 0.8, "c": Color(1, 0.2, 0.2)})

func snd(dt: float) -> void:
	var n := pb.get_frames_available()
	var a: float = [0.5, 0.08, 0.3][band]; var v: float = [0.07, 0.12, 0.1][band]
	if radio_fx: a = 0.6; v = 0.17
	for i in range(n):
		lp = lerpf(lp, randf() * 2.0 - 1.0, a); sph += 48.0 / 22050.0 * TAU
		var beat := 0.0
		if band == 2: beat = 0.3 * sin(sph) * exp(-fmod(t, 0.9) * 9.0)
		shot *= 0.9992
		var gs := (randf() * 2.0 - 1.0) * shot * 0.5 + sin(sph * 0.6) * shot * 0.35
		pb.push_frame(Vector2.ONE * clampf(lp * v + beat + gs, -1.0, 1.0))

# ---------------- drawing: world ----------------
func tri(x: float, b: float, h: float, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(x - h * 0.22, b), Vector2(x, b - h), Vector2(x + h * 0.22, b)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(x - h * 0.17, b - h * 0.35), Vector2(x, b - h * 1.12), Vector2(x + h * 0.17, b - h * 0.35)]), c)

func txt(c: CanvasItem, p: Vector2, s: String, sz: int = 20, col: Color = Color.WHITE, w: float = -1.0, al: int = 0) -> void:
	c.draw_string(ThemeDB.fallback_font, p, s, al, w, sz, col)

func _draw() -> void:
	var xf := Transform2D(0.0, Vector2(zoom, zoom), 0.0, Vector2(480, 270) - focus * zoom + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake)
	draw_set_transform_matrix(xf)
	holes = []
	var x0 := focus.x - 480.0 / zoom - 60.0
	var x1 := focus.x + 480.0 / zoom + 60.0
	var y0 := focus.y - 270.0 / zoom - 40.0
	var y1 := focus.y + 270.0 / zoom + 40.0
	draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, 340), Vector2(x0, 340)]), PackedColorArray([Color("05080b"), Color("05080b"), Color("22343a"), Color("22343a")]))
	draw_circle(Vector2(cam + 700.0 - cam * 0.02, 90), 34, Color(0.55, 0.65, 0.7, 0.10))
	var layers := [[0.1, Color("0e171b"), 250.0], [0.3, Color("0a1215"), 300.0], [0.6, Color("060b0d"), 330.0]]
	for li in range(3):
		var p: float = layers[li][0]; var col: Color = layers[li][1]; var base: float = layers[li][2]
		var pts := PackedVector2Array([Vector2(x0, 345)])
		var xx := x0
		while xx <= x1:
			var u := xx - cam * (1.0 - p)
			pts.append(Vector2(xx, base - 40.0 - (55.0 + 30.0 * sin(u * 0.009 + li) + 18.0 * sin(u * 0.031 + 2.0)) * (1.0 if li == 0 else 0.5)))
			xx += 24.0
		pts.append(Vector2(x1, 345)); draw_colored_polygon(pts, col)
		if li > 0:
			var step := 38.0 if li == 1 else 52.0
			var u := floorf((x0 - cam * (1.0 - p)) / step) * step
			while u + cam * (1.0 - p) < x1:
				tri(u + cam * (1.0 - p), base + 20.0, 80.0 + 40.0 * absf(sin(u * 12.9)), col)
				u += step
		draw_rect(Rect2(x0, 200 + li * 25, x1 - x0, 90), Color(0.45, 0.55, 0.6, 0.07))
	draw_rect(Rect2(x0, 340, x1 - x0, y1 - 340), Color("0b1113"))
	draw_colored_polygon(PackedVector2Array([Vector2(x0, 352), Vector2(x1, 352), Vector2(x1, 500), Vector2(x0, 500)]), Color("151b1e"))
	draw_line(Vector2(x0, 350), Vector2(x1, 350), Color("2a3338"), 4.0); draw_line(Vector2(x0, 498), Vector2(x1, 498), Color("2a3338"), 4.0)
	var dx := floorf(x0 / 90.0) * 90.0
	while dx < x1: draw_rect(Rect2(dx, 418, 44, 4), Color("6f6330")); dx += 90.0
	# collapsed bridge
	var v := PackedVector2Array([Vector2(x0 - 300, 340), Vector2(140, 340)])
	for i in range(9): v.append(Vector2(140.0 - 14.0 * absf(sin(i * 2.3)), 340.0 + i * 24.0))
	v.append(Vector2(x0 - 300, 560)); draw_colored_polygon(v, Color.BLACK)
	draw_polyline(PackedVector2Array([Vector2(138, 400), Vector2(120, 380), Vector2(100, 395)]), Color("4a3326"), 3.0, true)
	# outpost 04
	var ox := 3750.0
	draw_colored_polygon(PackedVector2Array([Vector2(ox, 350), Vector2(ox, 250), Vector2(ox + 120, 236), Vector2(ox + 260, 250), Vector2(ox + 260, 350)]), Color("1c2528"))
	draw_rect(Rect2(ox - 14, 232, 288, 14), Color("10181b")); draw_rect(Rect2(ox + 108, 292, 38, 58), Color("050809"))
	var fl := sin(t * 3.0) > -0.6 or fmod(t, 1.7) < 0.15
	draw_rect(Rect2(ox + 50, 258, 160, 24), Color("c0392b") if fl else Color("4a1a15")); txt(self, Vector2(ox + 70, 278), "OUTPOST 04", 20, Color.BLACK)
	holes.append([Vector2(ox + 130, 270), 120.0])
	for lx in LAMPS:
		var on := sin(t * 2.0 + lx) > -0.85
		draw_line(Vector2(lx, 346), Vector2(lx, 246), Color("1a2124"), 5.0); draw_line(Vector2(lx, 246), Vector2(lx + 20, 242), Color("1a2124"), 5.0)
		if on: draw_circle(Vector2(lx + 22, 244), 5, Color("e6d79a")); holes.append([Vector2(lx + 22, 250), 170.0])
	for l in LEDGES:
		draw_rect(Rect2(l[0], 345 - l[2], l[1] - l[0], l[2]), Color("222b2f")); draw_rect(Rect2(l[0] - 4, 341 - l[2], l[1] - l[0] + 8, 8), Color("2d383c"))
		for i in range(int((l[1] - l[0]) / 40.0)): draw_line(Vector2(l[0] + 20 + i * 40, 350 - l[2]), Vector2(l[0] + 20 + i * 40, 345), Color("181f22"), 2.0)
	if band == 1:
		for gx in [700.0, 1700.0, 2600.0, 3300.0]:
			var a := 0.3 + 0.2 * sin(t * 2.0 + gx); var gc := Color(0.75, 0.22, 0.17, a)
			draw_colored_polygon(PackedVector2Array([Vector2(gx - 14, 420), Vector2(gx - 10, 330), Vector2(gx + 10, 330), Vector2(gx + 14, 420)]), gc); draw_circle(Vector2(gx, 318), 13, gc)
		txt(self, Vector2(1620, 296), "WE WERE ONLY FOLLOWING", 18, Color(0.75, 0.22, 0.17, 0.9)); txt(self, Vector2(1620, 318), "THE SOUND OF OUR OWN FOOTSTEPS", 18, Color(0.75, 0.22, 0.17, 0.9))
	var items: Array = []
	for cdat in [[500.0, 380.0, Color("2a3a44")], [820.0, 355.0, Color("3a2a2a")], [1650.0, 470.0, Color("26333a")], [2500.0, 372.0, Color("2f3a2c")], [3250.0, 440.0, Color("3a3a2a")]]:
		items.append([cdat[1], func(): draw_car(cdat[0], cdat[1], cdat[2])])
	items.append([P.y, func(): draw_evelyn()])
	for f in foes: items.append([f.y, func(): draw_foe(f)])
	for b in boxes:
		if not b[3]: items.append([b[1], func(): draw_box(b)])
	if not got: items.append([420.0, func(): draw_tape()])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items: it[1].call()
	holes.append([Vector2(3990, 392), 90.0])
	for p in parts:
		var k: String = p.get("k", "p"); var lf: float = clampf(p["l"] / p.get("m", 0.5), 0.0, 1.0)
		if k == "s":
			var sc_: Color = p["c"]; draw_circle(p["p"], p["r"] * (2.4 - lf * 1.4), Color(sc_.r, sc_.g, sc_.b, lf * 0.28))
		elif k == "f": draw_circle(p["p"], 3.0, Color(1.0, 0.6, 0.2, lf))
		elif k == "c": draw_rect(Rect2(p["p"], Vector2(4, 2)), Color("c9a24a"))
		else: draw_circle(p["p"], 2.5, Color(1, 0.85, 0.6, clampf(p["l"] * 2.0, 0.0, 1.0)))
	for sh in shots: draw_line(sh["a"], sh["b"], Color(1, 0.9, 0.6, clampf(sh["l"] * 8.0, 0.0, 0.9)), 1.5)
	if flash > 0.0:
		var el := gun_el(); var dv := Vector2(face * cos(el), -sin(el)); var pv := Vector2(-dv.y, dv.x)
		draw_colored_polygon(PackedVector2Array([muz, muz + dv * 22.0 + pv * 8.0, muz + dv * 48.0, muz + dv * 22.0 - pv * 8.0]), Color(1, 0.75, 0.3, 0.95))
		draw_colored_polygon(PackedVector2Array([muz, muz + dv * 14.0 + pv * 3.0, muz + dv * 26.0, muz + dv * 14.0 - pv * 3.0]), Color(1, 1, 0.9, 1))
		holes.insert(0, [muz, 260.0])
	for q in pops: txt(self, q["p"] + Vector2(-20, -40.0 * (0.9 - q["l"])), q["t"], 26, q["c"])
	draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_box(b: Array) -> void:
	draw_rect(Rect2(b[0] - 11, b[1] - 12, 22, 12), Color("4a5a2a")); draw_rect(Rect2(b[0] - 11, b[1] - 12, 22, 3), Color("8a7a3a"))
	if int(t * 2.0) % 2 == 0: draw_circle(Vector2(b[0] + 5, b[1] - 15), 2.0, Color(1, 0.9, 0.5, 0.9))

func draw_tape() -> void:
	draw_rect(Rect2(3960, 392, 60, 26), Color("222222"))
	draw_rect(Rect2(3978, 380, 24, 12), Color("c0392b") if int(t * 3.0) % 2 == 0 else Color("7a2a20"))

func draw_car(x: float, y: float, c: Color) -> void:
	var s := sc(y); var o := Vector2(x, y)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-70, 4) * s, o + Vector2(70, 4) * s, o + Vector2(70, 12) * s, o + Vector2(-70, 12) * s]), Color(0, 0, 0, 0.35))
	var body := PackedVector2Array(); for p in [[-68, 0], [-68, -26], [-50, -34], [-30, -56], [-12, -62], [24, -62], [46, -44], [66, -32], [70, 0]]: body.append(o + Vector2(p[0], p[1]) * s)
	draw_colored_polygon(body, c)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-26, -54) * s, o + Vector2(-10, -58) * s, o + Vector2(-8, -36) * s, o + Vector2(-34, -36) * s]), Color("0b1418"))
	draw_colored_polygon(PackedVector2Array([o + Vector2(2, -58) * s, o + Vector2(22, -58) * s, o + Vector2(40, -38) * s, o + Vector2(2, -36) * s]), Color("0b1418"))
	draw_circle(o + Vector2(-42, 0) * s, 12 * s, Color.BLACK); draw_circle(o + Vector2(44, 0) * s, 12 * s, Color.BLACK)
	draw_rect(Rect2(o + Vector2(-70, -26) * s, Vector2(6, 8) * s), Color("c0392b"))
	holes.append([Vector2(x - 66 * s, y - 22 * s), 70.0 * s])

func person(o: Vector2, s: float, fc: int, tp: Dictionary, ln: Vector2, coat: Color, skin: Color, hair: Color, kind: int, ghost: float = 1.0) -> void:
	var hip := Vector2(0, -62) + ln * 0.4; var sh := Vector2(0, -100) + ln; var hd := Vector2(0, -114) + ln * 1.2
	var dk := coat.darkened(0.55); dk.a = ghost; coat.a = ghost; skin.a = ghost
	draw_colored_polygon(PackedVector2Array([o + Vector2(-26, 3) * s, o + Vector2(26, 3) * s, o + Vector2(20, 8) * s, o + Vector2(-20, 8) * s]), Color(0, 0, 0, 0.35 * ghost))
	var limbs := [["lf", hip + Vector2(-4, 0), -1.0, 30.0, 32.0], ["lh", sh + Vector2(-2, 0), 1.0, 25.0, 26.0]]
	for L in limbs:
		var e := ik(L[1], tp[L[0]], L[3], L[4], L[2])
		draw_polyline(PackedVector2Array([W(o, s, fc, L[1]), W(o, s, fc, e), W(o, s, fc, tp[L[0]])]), dk, 7.0 * s, true)
	var tor := PackedVector2Array([W(o, s, fc, sh + Vector2(-9, 0)), W(o, s, fc, sh + Vector2(9, 0)), W(o, s, fc, hip + Vector2(11, 6)), W(o, s, fc, hip + Vector2(-11, 6)), W(o, s, fc, hip + Vector2(-16, 26))])
	draw_colored_polygon(tor, coat)
	draw_circle(W(o, s, fc, hd), 10.5 * s, skin if kind != 3 else Color(0, 0, 0, ghost))
	match kind:
		0:
			draw_circle(W(o, s, fc, hd + Vector2(-3, -3)), 11 * s, hair)
			draw_polyline(PackedVector2Array([W(o, s, fc, hd + Vector2(-8, -2)), W(o, s, fc, hd + Vector2(-20, 8)), W(o, s, fc, hd + Vector2(-18, 24))]), hair, 5 * s, true)
			draw_circle(W(o, s, fc, hd + Vector2(6, 0)), 1.5 * s, Color.BLACK)
			var hp_ := W(o, s, fc, tip["rh"]); draw_line(hp_, hp_ + Vector2(11 * fc, 0) * s, Color("f2ecc4"), 4 * s)
			draw_rect(Rect2(W(o, s, fc, hip + Vector2(-12, -2)), Vector2(8, 10) * s), Color("c0392b"))
		1:
			for i in range(4): draw_line(W(o, s, fc, hd + Vector2(-8, -6 + i * 4)), W(o, s, fc, hd + Vector2(8 + sin(t * 20 + i) * 5, -6 + i * 4)), Color(0.5, 0.6, 0.65, 0.5), 2 * s)
		2:
			draw_colored_polygon(PackedVector2Array([W(o, s, fc, hd + Vector2(-10, -8)), W(o, s, fc, hd + Vector2(10, -8)), W(o, s, fc, hd + Vector2(0, -22))]), Color("d8d8d0"))
			draw_circle(W(o, s, fc, hd + Vector2(3, -1)), 2 * s, Color("7a3a1a")); draw_circle(W(o, s, fc, hd + Vector2(9, -1)), 2 * s, Color("7a3a1a"))
			draw_rect(Rect2(W(o, s, fc, sh + Vector2(2, 4)), Vector2(7, 9) * s), Color("c0392b"))
		3:
			draw_circle(W(o, s, fc, hd + Vector2(4, 0)), 2 * s, Color("c0392b")); draw_circle(W(o, s, fc, hd + Vector2(8, 0)), 2 * s, Color("c0392b"))
	var e2 := ik(sh + Vector2(2, 0), tp["rh"], 25.0, 26.0, 1.0)
	draw_polyline(PackedVector2Array([W(o, s, fc, sh + Vector2(2, 0)), W(o, s, fc, e2), W(o, s, fc, tp["rh"])]), coat.lightened(0.1), 7.0 * s, true)
	var e3 := ik(hip + Vector2(4, 0), tp["rf"], 30.0, 32.0, -1.0)
	draw_polyline(PackedVector2Array([W(o, s, fc, hip + Vector2(4, 0)), W(o, s, fc, e3), W(o, s, fc, tp["rf"])]), coat.darkened(0.2), 7.0 * s, true)
	draw_circle(W(o, s, fc, tp["rh"]), 4 * s, skin); draw_circle(W(o, s, fc, tp["lh"]), 4 * s, skin)

func draw_evelyn() -> void:
	var o := Vector2(P.x, P.y - alt); var s := sc(P.y)
	if climb >= 0.0 or alt > 1.0: draw_circle(Vector2(P.x, P.y), 14 * s, Color(0, 0, 0, 0.3))
	if slow():
		for k in trails:
			var tr: Array = trails[k]
			if tr.size() > 2: draw_polyline(PackedVector2Array(tr), Color(0.5, 1, 0.9, 0.45), 3.0, true)
	person(o, s, face, tip, lean, Color("2f4a52"), Color("c9a58a"), Color("4a3226"), 0)
	if aim or aim_t > 0.0 or reload > 0.0:
		var hnd := W(o, s, face, tip["rh"]); var el := gun_el(); var dv := Vector2(face * cos(el), -sin(el))
		draw_line(hnd - dv * 4.0 * s, hnd + dv * 22.0 * s, Color("202325"), 6.0 * s)
		draw_line(hnd, hnd + Vector2(-face * 2.0, 13.0) * s, Color("3b2a1c"), 6.0 * s)

func draw_foe(f: Foe) -> void:
	if f.van > 0.0: return
	var s: float = [1.12, 1.28, 1.2][f.kind] * sc(f.y) * 0.9; var o := Vector2(f.x, f.y)
	var vis := 1.0
	if f.kind == 2: vis = 0.0 if band == 1 else (1.0 if band == 2 else (0.85 if (int(t * 6.0) % 5 < 3 and absf(f.x - P.x) < 220.0) else 0.0))
	if vis <= 0.0: return
	var w := sin(f.x * 0.06)
	var tp := {"lh": Vector2(-14, -58), "rh": Vector2(14, -58), "lf": Vector2(-10 + w * 14, 0), "rf": Vector2(10 - w * 14, 0)}
	if f.kind == 1: tp["lh"] = Vector2(-16, -46); tp["rh"] = Vector2(16, -46)
	if f.st == 3:
		match f.atk:
			0: tp["rh"] = Vector2(20, -140); tp["lh"] = Vector2(-4, -132)
			1: tp["rh"] = Vector2(-40, -100); tp["lh"] = Vector2(-30, -80); tp["lf"] = Vector2(-26, 0); tp["rf"] = Vector2(26, 0)
			2: tp["rh"] = Vector2(48, -96); tp["lh"] = Vector2(44, -82)
			3: tp["rh"] = Vector2(10, -150); tp["lh"] = Vector2(-10, -150)
	elif f.st == 4: tp["rh"] = Vector2(80 if f.atk != 3 else 20, -98); tp["lh"] = Vector2(58, -92 if f.atk == 2 else -70)
	elif f.st == 6: tp["rh"] = Vector2(-20, -70); tp["lh"] = Vector2(-18, -60)
	var ln := Vector2(5 * sin(t * 5.0 + f.x), 0)
	var coat: Color = [Color("11181b"), Color("c4c9c4"), Color("050505")][f.kind]; var skin: Color = [Color("1a2226"), Color("a9a496"), Color("0a0a0a")][f.kind]
	person(o, s, f.face, tp, ln, coat, skin, Color.BLACK, [1, 2, 3][f.kind], vis)
	if f.st == 3: draw_circle(o + Vector2(0, -80) * s, 6.0 + (0.9 - f.tm) * 14.0, Color(1, 0.2, 0.15, 0.35))
	if f.st == 4 and f.atk == 3:
		for i in range(3): draw_arc(o + Vector2(0, -70) * s, 40.0 + i * 55.0 + (0.18 - f.tm) * 700.0, 0.0, TAU, 40, Color(0.6, 0.9, 1, 0.5), 3.0)
	if band == 2: draw_arc(o + Vector2(0, -60) * s, fmod(t * 60.0, 40.0), 0.0, TAU, 24, Color(0.75, 0.22, 0.17, 0.6), 2.0)

func draw_dark() -> void:
	var hs := PackedVector2Array(); var hr := PackedFloat32Array()
	var o := Vector2(P.x, P.y - alt); var s := sc(P.y)
	hs.append(w2s(o + Vector2(0, -60) * s)); hr.append((70.0 if light else 40.0) * zoom * s)
	for h in holes:
		if hs.size() < 12: hs.append(w2s(h[0])); hr.append(maxf(1.0, h[1] * zoom))
	while hs.size() < 12: hs.append(Vector2(-999, -999)); hr.append(1.0)
	var m: ShaderMaterial = rect.material
	m.set_shader_parameter("holes", hs); m.set_shader_parameter("hr", hr)
	var hand := w2s(W(o, s, face, tip["rh"])); var sh := w2s(W(o, s, face, Vector2(0, -100) + lean))
	m.set_shader_parameter("co", hand); m.set_shader_parameter("ca", (hand - sh).angle()); m.set_shader_parameter("on", 1.0 if light else 0.0)
	m.set_shader_parameter("dark", [0.72, 0.88, 0.8][band] + (0.08 if not light else 0.0)); m.set_shader_parameter("tint", Vector3(0.0, 0.02, 0.03))

# ---------------- gun ----------------
func gun_el() -> float:
	var v: Vector2 = tip["rh"] - (Vector2(0, -100) + lean)
	return atan2(-v.y, v.x)

func spread_now() -> float:
	return 0.012 + bloom + (0.035 if still < 0.3 else 0.0) + (0.0 if aim or aim_t > 0.0 else 0.03)

func muzzle() -> Vector2:
	var el := gun_el()
	return W(Vector2(P.x, P.y - alt), sc(P.y), face, tip["rh"] + Vector2(cos(el), -sin(el)) * 26.0)

func do_reload() -> void:
	if reload > 0.0 or mag >= 7 or res <= 0 or not msgs.is_empty() or ended: return
	reload = 1.9; shot = 0.25

func fire() -> void:
	if not msgs.is_empty() or fade > 0.0 or ended or climb >= 0.0 or reload > 0.0 or fcd > 0.0: return
	if mag <= 0:
		pops.append({"t": "CLICK", "p": Vector2(P.x, P.y - alt - 120.0), "l": 0.7, "c": Color(0.7, 0.7, 0.7)}); shot = 0.2; fcd = 0.35
		if res > 0: do_reload()
		return
	var sl := slow(); var hip := not (aim or aim_t > 0.0)
	var el := aim_el if (hip and not sl) else gun_el()
	var ang := el + randf_range(-1.0, 1.0) * spread_now()
	aim = true; aim_t = 3.0; mag -= 1; fcd = 0.28
	var o := Vector2(P.x, P.y - alt); var s := sc(P.y)
	var m := W(o, s, face, Vector2(0, -100) + lean + Vector2(cos(el), -sin(el)) * 70.0)
	var best: Foe = null; var bdx := 9999.0; var by := 0.0
	for f in foes:
		if f.van > 0.0 or absf(f.y - P.y) > 26.0: continue
		var dx := (f.x - m.x) * face
		if dx < 10.0 or dx > 900.0 or dx >= bdx: continue
		var hh: float = 125.0 * [1.12, 1.28, 1.2][f.kind] * sc(f.y) * 0.9
		var ya := m.y - tan(ang) * dx
		if ya > f.y or ya < f.y - hh - 6.0: continue
		best = f; bdx = dx; by = ya
	var en := m + Vector2(face * cos(ang), -sin(ang)) * 900.0
	if best != null:
		var hh2: float = 125.0 * [1.12, 1.28, 1.2][best.kind] * sc(best.y) * 0.9
		en = Vector2(best.x, by); hit_shot(best, (by - (best.y - hh2)) / hh2, en)
	shots.append({"a": m, "b": en, "l": 0.07 if not sl else 0.5})
	rc = 1.0; bloom = minf(0.12, bloom + 0.03); shake = maxf(shake, 6.0); flash = 0.07; muz = m; shot = 1.0; noise = 700.0
	if not sl: aim_el = clampf(aim_el + 0.06 + randf() * 0.03, -0.9, 0.9)
	for i in range([3, 6, 12][gfx]): parts.append({"p": m, "v": Vector2(face * randf_range(15.0, 90.0), randf_range(-45.0, -8.0)), "l": randf_range(0.9, 1.8), "m": 1.8, "k": "s", "r": randf_range(5.0, 10.0), "c": Color(0.62, 0.62, 0.6)})
	for i in range(4): parts.append({"p": m, "v": Vector2(face * randf_range(80.0, 260.0), randf_range(-70.0, 40.0)), "l": 0.22, "m": 0.22, "k": "f"})
	parts.append({"p": W(o, s, face, tip["rh"]), "v": Vector2(-face * randf_range(40.0, 90.0), -randf_range(90.0, 160.0)), "l": 1.2, "m": 1.2, "k": "c", "g": 700.0})
	for f in foes:
		if absf(f.x - P.x) < 700.0: f.alert = maxf(f.alert, 0.7); f.last = P

func hit_shot(f: Foe, r: float, pt: Vector2) -> void:
	f.alert = 1.0; f.last = P
	for i in range(8): parts.append({"p": pt, "v": Vector2.from_angle(randf() * TAU) * (40.0 + randf() * 120.0), "l": 0.6, "m": 0.6, "k": "s", "r": 4.0, "c": Color(0.04, 0.04, 0.05)})
	if f.kind == 2:
		f.van = 6.0; f.st = 7
		pops.append({"t": "IT VANISHES", "p": Vector2(pt.x, pt.y - 40.0), "l": 1.4, "c": Color(0.75, 0.22, 0.17)}); return
	f.hp -= 999.0 if r < 0.22 else (65.0 if r < 0.62 else 35.0)
	pops.append({"t": "HEADSHOT" if r < 0.22 else "HIT", "p": Vector2(pt.x, pt.y - 40.0), "l": 1.0, "c": Color(1, 0.4, 0.3)})
	if f.hp > 0.0: f.st = 6; f.tm = 1.0; f.x += signf(f.x - P.x) * 25.0
	else:
		for i in range(14): parts.append({"p": Vector2(f.x, f.y - 60.0), "v": Vector2.from_angle(randf() * TAU) * (20.0 + randf() * 70.0), "l": 1.6, "m": 1.6, "k": "s", "r": 9.0, "c": Color(0.02, 0.02, 0.03)})

# ---------------- menu / settings ----------------
func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load("user://settings.cfg") == OK:
		diff = int(c.get_value("g", "diff", 1)); gfx = int(c.get_value("g", "gfx", 1)); vol = int(c.get_value("g", "vol", 8))
	apply_cfg(false)

func apply_cfg(save: bool = true) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol / 10.0, 0.0001))); Engine.max_fps = 30 if gfx == 0 else 60
	if save:
		var c := ConfigFile.new(); c.set_value("g", "diff", diff); c.set_value("g", "gfx", gfx); c.set_value("g", "vol", vol); c.save("user://settings.cfg")

func menu_btns() -> Array:
	if menu == 1: return [["START" if not started else "RESUME", Rect2(340, 270, 280, 48)], ["SETTINGS", Rect2(340, 330, 280, 48)]]
	return [["DIFFICULTY:  " + ["EASY", "NORMAL", "HARD"][diff], Rect2(300, 180, 360, 48)], ["GRAPHICS:  " + ["LOW", "MEDIUM", "HIGH"][gfx], Rect2(300, 240, 360, 48)], ["SOUND:  " + str(vol * 10) + "%", Rect2(300, 300, 360, 48)], ["BACK" if not started else "RESUME", Rect2(300, 370, 360, 48)]]

func menu_tap(p: Vector2) -> void:
	var b := menu_btns()
	for i in range(b.size()):
		if not b[i][1].has_point(p): continue
		if menu == 1:
			if i == 0:
				if not started: init_game()
				menu = 0
			else: menu = 2
		else:
			if i == 0: diff = (diff + 1) % 3
			elif i == 1: gfx = (gfx + 1) % 3
			elif i == 2: vol = (vol + 1) % 11
			else: menu = 0 if started else 1
			apply_cfg()
		return

func init_game() -> void:
	started = true; mag = 7; res = [40, 5, 0][diff]; boxes = []; hp = 100.0; card_t = 5.5; msgs = []
	var n: int = [14, 3, 2][diff]; var amt: int = [14, 5, 4][diff]
	for i in range(n): boxes.append([450.0 + (3300.0 / n) * (i + 0.4), 380.0 + (i % 3) * 38.0, amt, false])

# ---------------- drawing: UI ----------------
func draw_hud(sl: bool) -> void:
	var bn: Array = [["104.2 MHz  REAL BAND", Color("9ec5d0")], ["88.5 MHz  MEMORY BAND", Color("c0392b")], ["99.9 MHz  THREAT BAND", Color("6fb59a")]][band]
	txt(ui, Vector2(24, 52), bn[0], 20, bn[1])
	ui.draw_rect(Rect2(24, 62, 200, 8), Color(0, 0, 0, 0.6)); ui.draw_rect(Rect2(24, 62, 2.0 * hp, 8), Color("b03a2e"))
	ui.draw_rect(Rect2(24, 74, 200, 6), Color(0, 0, 0, 0.6)); ui.draw_rect(Rect2(24, 74, 2.0 * energy, 6), Color("48b5a0"))
	txt(ui, Vector2(24, 104), "COLT M1911   " + str(mag) + " | " + str(res), 18, Color("e6d79a") if mag > 1 else Color("c0392b"))
	if reload > 0.0: ui.draw_rect(Rect2(24, 112, 200.0 * (1.0 - reload / 1.9), 4), Color("e6d79a"))
	txt(ui, Vector2(0, 52), "DEMO", 14, Color(1, 1, 1, 0.35), 890.0, 2)
	ui.draw_arc(Vector2(924, 56), 22.0, 0.0, TAU, 20, Color(1, 1, 1, 0.3), 2.0); txt(ui, Vector2(900, 63), "II", 16, Color(1, 1, 1, 0.6), 48.0, 1)
	for c in [[Vector2(880, 470), 44.0, "DIAL"], [Vector2(770, 485), 34.0, "LIGHT"], [Vector2(880, 370), 40.0, "FIRE"], [Vector2(770, 395), 34.0, "ACT"], [Vector2(680, 480), 34.0, "AIM"], [Vector2(680, 400), 30.0, "RELOAD"]]:
		var on: bool = (c[2] == "AIM" and aim) or (c[2] == "LIGHT" and light)
		ui.draw_circle(c[0], c[1], Color(1, 1, 1, 0.18 if on else 0.08)); ui.draw_arc(c[0], c[1], 0.0, TAU, 32, Color(1, 1, 1, 0.3), 2.0)
		txt(ui, c[0] + Vector2(-c[1], 6), c[2], 14, Color(1, 1, 1, 0.7), c[1] * 2.0, 1)
	for i in tch:
		if tch[i]["k"] == "stick":
			ui.draw_arc(tch[i]["o"], 55.0, 0.0, TAU, 32, Color(1, 1, 1, 0.3), 2.0); ui.draw_circle(tch[i]["o"] + stick * 55.0, 22.0, Color(1, 1, 1, 0.25))
	if (aim or aim_t > 0.0) and not sl:
		var el := gun_el(); var tp := w2s(muzzle() + Vector2(face * cos(el), -sin(el)) * 260.0); var r := 5.0 + spread_now() * 500.0
		ui.draw_arc(tp, r, 0.0, TAU, 20, Color(1, 1, 1, 0.65), 1.5); ui.draw_circle(tp, 1.5, Color(0.9, 0.2, 0.15))
	if sl:
		var o := w2s(Vector2(P.x, P.y - alt)); var s := sc(P.y) * zoom
		for k in tip: ui.draw_arc(o + Vector2(tip[k].x * face, tip[k].y) * s, 24.0, 0.0, TAU, 20, Color(0.5, 1, 0.9, 0.8) if k.ends_with("h") else Color(1, 0.8, 0.4, 0.8), 3.0)
		ui.draw_arc(o + Vector2(lean.x * face, -85 + lean.y) * s, 30.0, 0.0, TAU, 20, Color(1, 1, 1, 0.5), 2.0)
		if guarding: txt(ui, Vector2(0, 90), "GUARD", 24, Color(0.7, 0.8, 1), SW, 1)
		txt(ui, Vector2(0, 505), "Drag hands/feet fast = strike  |  both hands at head = GUARD (just before a hit = PARRY)  |  torso sideways = SLIP  |  hand over ledge = CLIMB", 13, Color(1, 1, 1, 0.55), SW, 1)

func draw_ui() -> void:
	var sl := slow()
	for i in range([25, 60, 110][gfx]):
		var rx := fposmod(i * 97.3 - rt * 60.0, 960.0); var ry := fposmod(i * 53.7 + rt * (420.0 + (i % 5) * 40.0), 540.0)
		ui.draw_line(Vector2(rx, ry), Vector2(rx - 3, ry + 10), Color(0.7, 0.8, 0.9, 0.22), 1.0)
	ui.draw_rect(Rect2(0, 0, SW, SH), Color(0.0, 0.2, 0.2, 0.18) if sl else (Color(0.4, 0.05, 0.05, 0.08) if band == 1 else Color(0, 0, 0, 0)))
	if gfx == 2 or cine:
		for i in range(50): ui.draw_rect(Rect2(randf() * SW, randf() * SH, 2, 2), Color(1, 1, 1, 0.07))
	if radio_fx:
		for i in range(26): ui.draw_rect(Rect2(0, randf() * SH, SW, randf_range(1, 3)), Color(0.8, 0.85, 0.9, randf() * 0.16))
		if randf() < 0.25: ui.draw_rect(Rect2(0, 0, SW, SH), Color(1, 1, 1, 0.04))
	ui.draw_rect(Rect2(0, 0, SW, bars), Color.BLACK); ui.draw_rect(Rect2(0, SH - bars, SW, bars), Color.BLACK)
	if started and menu == 0 and not cine: draw_hud(sl)
	if cine and not msgs.is_empty():
		var m: Array = msgs[0]; var rc_: bool = m[0].begins_with("Radio") or m[0].begins_with("Eleanor") or m[0].begins_with("The D")
		txt(ui, Vector2(0, SH - 88), String(m[0]).to_upper(), 12, Color("c0392b") if rc_ else Color("9ec5d0"), SW, 1)
		ui.draw_multiline_string(ThemeDB.fallback_font, Vector2(30, SH - 68), m[1], 1, 900.0, 14, 2, Color.WHITE)
		ui.draw_multiline_string(ThemeDB.fallback_font, Vector2(30, SH - 34), m[2], 1, 900.0, 14, 2, Color("9aa"))
	if fade > 0.0:
		ui.draw_rect(Rect2(0, 0, SW, SH), Color(0, 0, 0, minf(1.0, fade * 2.0)))
		if fade > 0.6 and fade < 2.2: txt(ui, Vector2(0, 270), "THE ECHO REMEMBERS YOUR VOICE  —  پژواک صدایت را به یاد دارد", 24, Color("c0392b"), SW, 1)
	if card_t > 0.0:
		var a := clampf(card_t / 1.2, 0.0, 1.0); var ta := minf(1.0, (5.5 - card_t) / 1.0) * a
		ui.draw_rect(Rect2(0, 0, SW, SH), Color(0, 0, 0, a))
		txt(ui, Vector2(0, 250), "SIGNAL AT BIRCHWOOD", 46, Color(0.75, 0.22, 0.17, ta), SW, 1)
		txt(ui, Vector2(0, 290), "Oregon  —  03:17 AM", 18, Color(0.8, 0.8, 0.8, ta), SW, 1)
		txt(ui, Vector2(0, 330), "A game by Mohsen Soleimany Far", 16, Color(0.6, 0.65, 0.7, ta), SW, 1)
	if ended:
		var a := minf(1.0, end_t / 2.0); ui.draw_rect(Rect2(0, 0, SW, SH), Color(0, 0, 0, a))
		txt(ui, Vector2(0, 200), "ACT I COMPLETE", 44, Color(0.75, 0.22, 0.17, a), SW, 1)
		txt(ui, Vector2(0, 250), "DEMO VERSION — THANK YOU FOR PLAYING", 22, Color(1, 1, 1, a), SW, 1)
		txt(ui, Vector2(0, 285), "این نسخهٔ دمو است و فقط بخشی از داستان را نشان می‌دهد", 18, Color(0.8, 0.8, 0.8, a), SW, 1)
		txt(ui, Vector2(0, 335), "TO BE CONTINUED...", 20, Color(0.75, 0.22, 0.17, a), SW, 1)
		txt(ui, Vector2(0, 385), "Created by Mohsen Soleimany Far", 18, Color(0.7, 0.75, 0.8, a), SW, 1)
		if end_t > 2.0: txt(ui, Vector2(0, 450), "tap to return to menu", 14, Color(0.5, 0.5, 0.55, a), SW, 1)
	if menu != 0:
		ui.draw_rect(Rect2(0, 0, SW, SH), Color(0, 0, 0, 0.62 if menu == 1 else 0.8))
		if menu == 1:
			txt(ui, Vector2(0, 170), "SIGNAL AT BIRCHWOOD", 52, Color("c0392b"), SW, 1); txt(ui, Vector2(0, 212), "سیگنال در برچ‌وود", 26, Color.WHITE, SW, 1); txt(ui, Vector2(0, 244), "DEMO VERSION", 14, Color("889"), SW, 1)
		else: txt(ui, Vector2(0, 140), "SETTINGS", 30, Color.WHITE, SW, 1)
		for b in menu_btns():
			var r: Rect2 = b[1]; ui.draw_rect(r, Color(1, 1, 1, 0.07)); ui.draw_rect(r, Color(0.75, 0.22, 0.17, 0.7), false, 2.0)
			txt(ui, Vector2(r.position.x, r.position.y + 31), b[0], 20, Color.WHITE, r.size.x, 1)
		txt(ui, Vector2(0, SH - 40), "Created by Mohsen Soleimany Far", 16, Color("889"), SW, 1)
