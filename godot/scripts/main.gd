extends Node3D
## Dino Jungle: fly a little explorer helicopter anywhere over the island and meet the dinosaurs.
## Left stick: faster / slower (stays where you leave it, never reverses).
## Right stick: turn left/right, climb/dive. It never crashes: it floats over the ground and water.
## Fly anywhere: nothing interrupts the flight. Tap a dinosaur when you're near it to meet it:
## chime, its name and a fun fact read aloud, a star in the Dino Book, and the camera circles it.
## Tap it again for another fact. "Find a dino!" flies you next to one you haven't met, then stops.

const VOLCANO := Vector3(150, 0, -140)
const LAKE := Vector3(-70, 0, 60)
const MEET_DIST := 38.0      # FIND A DINO! stops about this far away
const TAP_RANGE := 80.0      # a dinosaur can be tapped when the helicopter is this close
const LABEL_DIST := 90.0
const WORLD_R := 380.0

var heights: Heights
var dinos: Array[Dino] = []
var species: Array[String] = []         # ids that have a model
var found := {}                         # id -> true
var models := {}                        # id -> PackedScene

# Player
var heli: Node3D
var rotor: Node3D
var heli_model: Node3D
var tail_rotor: Node3D
var cam: Camera3D
var throttle := 0.0
var throttle_in := 0.0
var steer := Vector2.ZERO
var yaw := 0.0
var alt := 30.0
var vspeed := 0.0
var bank := 0.0
var auto_target: Dino
var auto_on := false
var show_dino: Dino          # the camera swings round to look at a dinosaur you just met
var show_t := 0.0
var show_ang := 0.0

# HUD
var hud: CanvasLayer
var speed_stick: Stick
var steer_stick: Stick
var card: Panel
var card_name: Label
var card_fact: Label
var card_t := 0.0
var card_dino_id := ""
var book_btn: Tap
var book: Control
var arrow: Tap
var arrow_ang := 0.0
var arrow_show := false
var find_btn: Tap
var roar_btn: Tap
var near_dino: Dino
var hint_dino: Dino          # FIND A DINO! arrived here: its label says "Tap me!" until tapped
var fact_i := {}             # species -> which fact to read next
var _closer_t := 0.0
var _auto_wait := 0.0
var _last_tap_ms := 0
var _last_focus: Dino
var _last_focus_ms := 0
var _last_roar_ms := -10000
var autoplay_dir := ""
var _shot_t := 0.0
var _shots := 0
var _t := 0.0


func _ready() -> void:
	randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autoplay="):
			autoplay_dir = a.substr(11)
	heights = Heights.new("res://assets/models/jungle_heights.bin")
	_build_world()
	_load_species()
	_spawn_dinos()
	_build_heli()
	_build_hud()
	Sfx.start_music()
	if autoplay_dir != "":
		DirAccess.make_dir_recursive_absolute(autoplay_dir)
		auto_on = true
	await get_tree().create_timer(1.0).timeout
	Sfx.say("Let's find the dinosaurs!")


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.5, 0.9)
	sm.sky_horizon_color = Color(0.75, 0.85, 0.95)
	sm.ground_horizon_color = Color(0.75, 0.85, 0.95)
	sm.ground_bottom_color = Color(0.2, 0.35, 0.45)
	sky.sky_material = sm
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color(0.72, 0.84, 0.92)
	# Depth fog: crisp up close, only far hills fade into the haze.
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_density = 0.85
	e.fog_depth_begin = 200.0
	e.fog_depth_end = 650.0
	e.fog_sky_affect = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1, 0.96, 0.88)
	add_child(sun)

	var terrain: Node3D = load("res://assets/models/jungle_terrain.glb").instantiate()
	add_child(terrain)
	var gm := ShaderMaterial.new()
	gm.shader = load("res://assets/terrain.gdshader")
	gm.set_shader_parameter("mode", 0)
	gm.set_shader_parameter("tex_a", load("res://assets/tex/sand.jpg"))
	gm.set_shader_parameter("tex_b", load("res://assets/tex/grass.jpg"))
	gm.set_shader_parameter("tex_c", load("res://assets/tex/rock.jpg"))
	gm.set_shader_parameter("tex_d", load("res://assets/tex/dirt.jpg"))
	for mi in terrain.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = gm

	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.12, 0.55, 0.7, 0.62)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.15
	wm.metallic_specular = 0.8
	water.material_override = wm
	water.position.y = -0.2
	add_child(water)

	_plant_jungle()
	_volcano_smoke()


func walkable(x: float, z: float, home: String) -> bool:
	if Vector2(x, z).length() > WORLD_R - 20:
		return false
	var h := heights.at(x, z)
	if home == "sea":
		return h < -3.0
	return h > 0.5 and h < 40.0


func random_spot(center: Vector3, radius: float, home: String) -> Vector3:
	for i in 40:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		if walkable(p.x, p.z, home):
			p.y = heights.at(p.x, p.z)
			return p
	return center


func _habitat_center(home: String) -> Vector3:
	var spots := {
		"plains": [Vector3(-20, 0, -90), Vector3(60, 0, 80), Vector3(-150, 0, -120), Vector3(10, 0, 30)],
		"lake": [LAKE + Vector3(45, 0, 0), LAKE + Vector3(0, 0, -45), LAKE + Vector3(-40, 0, 20)],
		"forest": [Vector3(-160, 0, 20), Vector3(40, 0, 150), Vector3(90, 0, -10), Vector3(-90, 0, -40)],
		"river": [Vector3(30, 0, -45), Vector3(-120, 0, 105), Vector3(-15, 0, 10)],
		"volcano": [VOLCANO],
		"coast": [Vector3(200, 0, 80), Vector3(-200, 0, -60), Vector3(0, 0, 210), Vector3(60, 0, -230)],
		"sea": [Vector3(260, 0, 150), Vector3(-250, 0, 150), Vector3(230, 0, -220), Vector3(-200, 0, -250), Vector3(0, 0, 300)],
	}
	var list: Array = spots.get(home, spots["plains"])
	var c: Vector3 = list[randi() % list.size()]
	var kind := "sea" if home == "sea" else "plains"
	if walkable(c.x, c.z, kind):
		return random_spot(c, 30.0, kind)
	# Spot fell in the water (or on land for sea animals): find the closest good place.
	for r in [40.0, 80.0, 140.0, 220.0]:
		var p := random_spot(c, r, kind)
		if p != c:
			return p
	return c


func _load_species() -> void:
	var dir := "res://assets/models/dinos/"
	for f in ResourceLoader.list_directory(dir):
		if not (f.ends_with(".glb") or f.ends_with(".gltf") or f.ends_with(".fbx")):
			continue
		var id := DinoData.id_for_file(f.get_basename())
		if id == "" or models.has(id):
			continue
		models[id] = load(dir + f)
		species.append(id)
	species.sort()


func _spawn_dinos() -> void:
	var cfg: Dictionary = {}
	if ResourceLoader.exists("res://assets/models/dinos/tuning.json") or FileAccess.file_exists("res://assets/models/dinos/tuning.json"):
		cfg = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/dinos/tuning.json"))
	for id in species:
		var info: Dictionary = DinoData.ALL[id]
		var tune: Dictionary = cfg.get(id, {})
		var groups: int = info.get("count", 2)
		for g in groups:
			var center := _habitat_center(info["home"])
			if info["kind"] == "fly":
				center = VOLCANO if info["home"] == "volcano" else _habitat_center("coast")
			var lead: Dino = null
			for k in int(info["herd"]):
				var dn := Dino.new()
				add_child(dn)
				var sc := randf_range(0.85, 1.1) * float(tune.get("scale", 1.0))
				if k > 0:
					sc *= 0.8 if randf() < 0.4 else 1.0
				dn.setup(id, models[id], self, center, sc, deg_to_rad(float(tune.get("yaw", 0.0))))
				var p := random_spot(center, 15.0, info["home"]) if info["kind"] != "fly" else center + Vector3(randf_range(-20, 20), 30, randf_range(-20, 20))
				dn.global_position = p
				if k == 0:
					lead = dn
				else:
					dn.leader = lead
					dn.offset = Vector3(randf_range(-1, 1), 0, -randf_range(0.6, 1.5)).normalized() * info["length"] * randf_range(1.0, 1.8)
					if info["kind"] == "fly":
						dn.leader = null
				dinos.append(dn)


func _plant_jungle() -> void:
	var dir := "res://assets/models/jungle/"
	var kinds := {"palm": [], "tree": [], "bush": [], "rock": [], "flower": []}
	for f in ResourceLoader.list_directory(dir):
		if not f.ends_with(".glb"):
			continue
		var n := f.to_lower()
		var k := "tree"
		if "palm" in n:
			k = "palm"
		elif "rock" in n or "stone" in n or "boulder" in n:
			k = "rock"
		elif "flower" in n or "mushroom" in n:
			k = "flower"
		elif "bush" in n or "fern" in n or "plant" in n or "grass" in n or "shrub" in n or "leaf" in n:
			k = "bush"
		var meshes := _meshes_of(load(dir + f))
		if meshes.size() > 0:
			kinds[k].append(meshes)
	# Scatter on a grid of 60 m cells so far cells can be culled.
	var cell := 60.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.012
	var cells := int(WORLD_R * 2 / cell)
	for cj in cells:
		for ci in cells:
			var x0 := -WORLD_R + ci * cell
			var z0 := -WORLD_R + cj * cell
			var placed := {}   # mesh key -> Array[Transform3D]
			for t in (45 if OS.has_feature("android") else 70):
				var x := x0 + rng.randf() * cell
				var z := z0 + rng.randf() * cell
				var h := heights.at(x, z)
				if h < 0.3 or h > 38.0:
					continue
				if Vector2(x - VOLCANO.x, z - VOLCANO.z).length() < 40:
					continue
				var dense := noise.get_noise_2d(x, z) * 0.5 + 0.5
				var slope := heights.normal(x, z).y
				var k := ""
				if h < 2.5:
					k = "palm" if rng.randf() < 0.35 else ""
				elif rng.randf() < dense * 0.75:
					k = "tree" if rng.randf() < 0.55 else ("palm" if rng.randf() < 0.3 else "bush")
				elif rng.randf() < 0.12:
					k = ["bush", "flower", "rock"][rng.randi() % 3]
				if slope < 0.75 and k != "rock":
					k = "rock" if rng.randf() < 0.1 else ""
				if k == "" or kinds[k].is_empty():
					if k == "flower" and not kinds["bush"].is_empty():
						k = "bush"
					else:
						continue
				var pick: Array = kinds[k][rng.randi() % kinds[k].size()]
				var s := rng.randf_range(0.8, 1.4)
				if k == "tree" or k == "palm":
					s *= rng.randf_range(1.6, 2.6)
				var tf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h - 0.2, z))
				var key: int = kinds[k].find(pick) + 1000 * ["palm", "tree", "bush", "rock", "flower"].find(k)
				if not placed.has(key):
					placed[key] = [pick, []]
				placed[key][1].append(tf)
			for key in placed:
				var pick: Array = placed[key][0]
				var tfs: Array = placed[key][1]
				for m in pick:
					var mm := MultiMesh.new()
					mm.transform_format = MultiMesh.TRANSFORM_3D
					mm.mesh = m[0]
					mm.instance_count = tfs.size()
					for i in tfs.size():
						mm.set_instance_transform(i, tfs[i] * m[1])
					var mmi := MultiMeshInstance3D.new()
					mmi.multimesh = mm
					mmi.visibility_range_end = 200.0 if OS.has_feature("android") else 260.0
					mmi.visibility_range_end_margin = 20.0
					mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					add_child(mmi)


## Every mesh in a scene with its transform relative to the root: [[Mesh, Transform3D], ...]
func _meshes_of(ps: PackedScene) -> Array:
	var out := []
	if ps == null:
		return out
	var root := ps.instantiate()
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var t := Transform3D.IDENTITY
		var cur: Node = mi
		while cur and cur != root:
			if cur is Node3D:
				t = (cur as Node3D).transform * t
			cur = cur.get_parent()
		if mi.mesh:
			out.append([mi.mesh, t])
	root.free()
	return out


func _volcano_smoke() -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(14, 14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	m.albedo_texture = gt
	q.material = m
	p.mesh = q
	p.amount = 40
	p.lifetime = 9.0
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 12
	p.initial_velocity_min = 4
	p.initial_velocity_max = 7
	p.gravity = Vector3(0.6, 0.3, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.45, 0.42, 0.7))
	ramp.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	p.color_ramp = ramp
	p.position = VOLCANO + Vector3(0, heights.at(VOLCANO.x, VOLCANO.z) + 4, 0)
	add_child(p)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1, 0.45, 0.1)
	glow.light_energy = 3.0
	glow.omni_range = 30
	glow.position = p.position + Vector3(0, -2, 0)
	add_child(glow)


# ---------------------------------------------------------------- helicopter

func _build_heli() -> void:
	heli = Node3D.new()
	add_child(heli)
	# helicopter.glb (the Space Mission heli) is kept out of the public repo because its licence is
	# unknown; a fresh clone flies the CC0 one instead.
	var own: PackedScene = load("res://assets/models/helicopter.glb") if ResourceLoader.exists("res://assets/models/helicopter.glb") else null
	if own:
		_cc0_heli(own)
	elif ResourceLoader.exists("res://assets/models/helicopter_cc0.glb"):
		_kazuma_heli()
	else:
		_shape_heli()
	heli.position = Vector3(0, 30, 120)
	alt = 30.0
	cam = Camera3D.new()
	cam.fov = 62
	cam.far = 1500
	add_child(cam)
	cam.position = heli.position + Vector3(0, 8, 16)


## The helicopter from the Space Mission game (heli.glb: Body + Rotor).
func _cc0_heli(scene: PackedScene) -> void:
	var m: Node3D = scene.instantiate()
	var holder := Node3D.new()
	holder.rotation.y = -PI / 2      # nose is model -X; Godot forward is -Z
	holder.scale = Vector3.ONE * 0.6
	heli.add_child(holder)
	holder.add_child(m)
	m.position = Vector3(-0.55, 0, 0)
	rotor = m.find_child("Rotor", true, false)
	if rotor == null:
		rotor = Node3D.new()
	tail_rotor = Node3D.new()
	heli.add_child(tail_rotor)
	heli_model = m


## CC0 "Helicopter" by kazuma (poly.pizza/m/EQJ2MECUbx): Body + MainRotor, nose +Z; body painted yellow.
func _kazuma_heli() -> void:
	var m: Node3D = load("res://assets/models/helicopter_cc0.glb").instantiate()
	m.rotation.y = PI
	m.scale = Vector3.ONE * 1.2
	m.position.y = -0.8
	heli.add_child(m)
	rotor = m.find_child("MainRotor", true, false)
	if rotor == null:
		rotor = Node3D.new()
	tail_rotor = Node3D.new()
	heli.add_child(tail_rotor)
	heli_model = m
	var body := m.find_child("Body", true, false) as MeshInstance3D
	if body and body.mesh:
		for i in body.mesh.get_surface_count():
			var mat := body.get_active_material(i) as BaseMaterial3D
			if mat and mat.albedo_color.v < 0.2:
				var y := mat.duplicate() as BaseMaterial3D
				y.albedo_color = Color(1.0, 0.78, 0.1)
				body.set_surface_override_material(i, y)


func _shape_heli() -> void:
	var body_m := _mat(Color(1.0, 0.78, 0.1))
	var glass_m := _mat(Color(0.55, 0.85, 1.0, 0.55))
	glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_m.roughness = 0.05
	var dark := _mat(Color(0.2, 0.22, 0.25))
	var red := _mat(Color(0.9, 0.2, 0.15))
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.3
	sm.height = 2.4
	body.mesh = sm
	body.material_override = body_m
	body.scale = Vector3(1, 0.95, 1.25)
	heli.add_child(body)
	var bubble := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 1.0
	bm.height = 1.7
	bubble.mesh = bm
	bubble.material_override = glass_m
	bubble.position = Vector3(0, 0.45, -0.75)
	heli.add_child(bubble)
	var tail := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.42
	cm.height = 3.4
	tail.mesh = cm
	tail.material_override = body_m
	tail.rotation_degrees.x = 90
	tail.position = Vector3(0, 0.25, 2.6)
	heli.add_child(tail)
	var fin := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.12, 1.0, 0.6)
	fin.mesh = fm
	fin.material_override = red
	fin.position = Vector3(0, 0.75, 4.15)
	heli.add_child(fin)
	tail_rotor = Node3D.new()
	tail_rotor.position = Vector3(0.22, 0.6, 4.2)
	heli.add_child(tail_rotor)
	for i in 2:
		var b := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.05, 1.2, 0.16)
		b.mesh = bx
		b.material_override = dark
		b.rotation.x = i * PI / 2
		tail_rotor.add_child(b)
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.1
	mm.bottom_radius = 0.1
	mm.height = 0.5
	mast.mesh = mm
	mast.material_override = dark
	mast.position.y = 1.35
	heli.add_child(mast)
	rotor = Node3D.new()
	rotor.position.y = 1.6
	heli.add_child(rotor)
	for i in 3:
		var b := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.35, 0.05, 4.6)
		b.mesh = bx
		b.material_override = dark
		b.position = Vector3(0, 0, 2.3).rotated(Vector3.UP, i * TAU / 3)
		b.rotation.y = i * TAU / 3
		rotor.add_child(b)
	for s in [-1, 1]:
		var skid := MeshInstance3D.new()
		var sk := CylinderMesh.new()
		sk.top_radius = 0.08
		sk.bottom_radius = 0.08
		sk.height = 3.0
		skid.mesh = sk
		skid.material_override = dark
		skid.rotation_degrees.x = 90
		skid.position = Vector3(0.85 * s, -1.25, -0.1)
		heli.add_child(skid)
	# Explorer badge: green dot on each side.
	for s in [-1, 1]:
		var dot := MeshInstance3D.new()
		var ds := CylinderMesh.new()
		ds.top_radius = 0.4
		ds.bottom_radius = 0.4
		ds.height = 0.05
		dot.mesh = ds
		dot.material_override = _mat(Color(0.2, 0.75, 0.3))
		dot.rotation_degrees.z = 90
		dot.position = Vector3(1.28 * s, 0, 0.2)
		heli.add_child(dot)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	return m


func _physics_process(dt: float) -> void:
	_t += dt
	# Autopilot.
	var steer_x := steer.x
	var climb := steer.y
	if autoplay_dir != "" and not auto_on:
		_auto_wait -= dt
		if _auto_wait <= 0.0 and show_t <= 0.0:
			auto_on = true      # test autopilot: after looking at one, go find the next
	if auto_on:
		if auto_target and is_instance_valid(auto_target) and _dist_to(auto_target) < MEET_DIST + auto_target.length:
			# Arrived: hover here and let the kid tap it. No explaining.
			auto_on = false
			throttle = 0.0
			hint_dino = auto_target if not found.has(auto_target.id) else null
			if autoplay_dir != "":
				_auto_wait = 3.0
				_autoplay_tap(auto_target)
			auto_target = null
		if auto_on and (auto_target == null or not is_instance_valid(auto_target)):
			auto_target = _nearest_unfound()
			if auto_target == null:
				auto_on = false
				if autoplay_dir != "" and not species.is_empty():
					get_tree().quit()
		if auto_on and auto_target:
			var to := auto_target.global_position - heli.position
			var want_yaw := atan2(-to.x, -to.z)
			steer_x = clampf(angle_difference(yaw, want_yaw) * -1.5, -1, 1)
			var want_alt := auto_target.global_position.y + 12.0 + auto_target.length * 0.6
			climb = clampf((want_alt - heli.position.y) * 0.15, -1, 1)
			var dist := Vector2(to.x, to.z).length()
			throttle = clampf(dist / 60.0, 0.15, 1.0) if absf(angle_difference(yaw, want_yaw)) < 1.0 else 0.15
	else:
		throttle = clampf(throttle + throttle_in * dt * 0.6, 0.0, 1.0)
		# After FIND A DINO! arrives, gently turn to face the dinosaur so it's right in front.
		if hint_dino and is_instance_valid(hint_dino) and steer == Vector2.ZERO and throttle < 0.05:
			var tv := hint_dino.global_position - heli.position
			var want_yaw := atan2(-tv.x, -tv.z)
			steer_x = clampf(angle_difference(yaw, want_yaw) * -1.2, -0.6, 0.6)

	var spd := lerpf(0.0, 26.0, throttle)
	yaw -= steer_x * dt * 1.3
	bank = lerpf(bank, -steer_x * 0.35, dt * 3)
	# Keep inside the world: gently turn back toward the island.
	var flat := Vector2(heli.position.x, heli.position.z)
	if flat.length() > WORLD_R:
		var back := atan2(heli.position.x, heli.position.z)
		yaw = lerp_angle(yaw, back, dt * 1.5)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var p := heli.position + fwd * spd * dt
	vspeed = lerpf(vspeed, climb * 14.0, dt * 3)
	p.y += vspeed * dt
	var ground := maxf(heights.at(p.x, p.z), 0.0)
	# Look ahead too so it lifts over hills before reaching them.
	var ahead := maxf(heights.at(p.x + fwd.x * 25, p.z + fwd.z * 25), 0.0)
	var floor_y := maxf(ground, ahead - 4.0) + 4.0
	if p.y < floor_y:
		p.y = lerpf(p.y, floor_y, clampf(dt * 6, 0, 1))
		vspeed = maxf(vspeed, 0.0)
	p.y = minf(p.y, 150.0)
	heli.position = p
	heli.rotation = Vector3(-throttle * 0.18 + vspeed * -0.01, yaw, bank)
	rotor.rotate_y(dt * (14.0 + throttle * 10.0))
	tail_rotor.rotate_x(dt * 30.0)

	if show_t > 0.0 and is_instance_valid(show_dino):
		show_t -= dt
		show_ang += dt * 0.35
		var dp := show_dino.global_position + Vector3(0, show_dino.length * 0.3, 0)
		var r := show_dino.length * 1.4 + 6.0
		# High enough to look over the palm trees.
		var sp := dp + Vector3(sin(show_ang) * r, show_dino.length * 0.5 + 6.0, cos(show_ang) * r)
		sp.y = maxf(sp.y, maxf(heights.at(sp.x, sp.z), 0.0) + 2.0)
		# Keep a clear view: lift the camera until the line to the dinosaur passes over hills and trees.
		for i in range(1, 8):
			var t := i / 8.0
			var q := dp.lerp(sp, t)
			var need := maxf(heights.at(q.x, q.z), 0.0) + 6.0
			if q.y < need:
				sp.y += (need - q.y) / t
		cam.position = cam.position.lerp(sp, clampf(dt * 2.5, 0, 1))
		cam.look_at(dp)
		_check_dinos(dt)
		_update_hud(dt)
		if autoplay_dir != "":
			_autoplay_shots(dt)
		return
	# Chase camera.
	var back_dir := -fwd
	var cpos := heli.position + back_dir * (15.0 + throttle * 4.0) + Vector3(0, 6.0, 0)
	var cg := maxf(heights.at(cpos.x, cpos.z), 0.0) + 2.0
	cpos.y = maxf(cpos.y, cg)
	cam.position = cam.position.lerp(cpos, clampf(dt * 4.0, 0, 1))
	cam.look_at(heli.position + fwd * 8.0 + Vector3(0, 1.0, 0))

	_check_dinos(dt)
	_update_hud(dt)
	if autoplay_dir != "":
		_autoplay_shots(dt)


func _dist_to(d: Dino) -> float:
	return d.global_position.distance_to(heli.position)


func _nearest_unfound() -> Dino:
	var best: Dino = null
	var bd := INF
	for d in dinos:
		if found.has(d.id):
			continue
		var dd := _dist_to(d)
		if dd < bd:
			bd = dd
			best = d
	return best


func _check_dinos(dt: float) -> void:
	_closer_t -= dt
	near_dino = null
	var nd := INF
	var label_for := {}   # species -> nearest one, the only one that shows its name
	for d in dinos:
		var dist := _dist_to(d)
		d.label.visible = false
		if found.has(d.id) and dist < LABEL_DIST + d.length * 2:
			if not label_for.has(d.id) or dist < _dist_to(label_for[d.id]):
				label_for[d.id] = d
		if dist < TAP_RANGE + d.length and dist < nd:
			nd = dist
			near_dino = d
	for id in label_for:
		label_for[id].label.visible = true
	if show_t > 0.0 and is_instance_valid(show_dino):
		show_dino.label.visible = false    # the card names it; keep the animal itself in view
	if hint_dino and is_instance_valid(hint_dino):
		if found.has(hint_dino.id) or _dist_to(hint_dino) > TAP_RANGE + hint_dino.length * 2:
			hint_dino.label.text = DinoData.ALL[hint_dino.id]["name"]
			hint_dino = null
		else:
			hint_dino.label.text = "Tap me!"
			hint_dino.label.visible = true


## A tap that no button or stick took: did it land on a dinosaur near the helicopter?
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var e := event as InputEventScreenTouch
	if not e.pressed or e.is_echo() or e.canceled:
		return
	if book.visible:
		return
	# One tap = one action: ignore taps that come too fast after the last one.
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < 400:
		return
	_last_tap_ms = now
	_tap_at(e.position)


func _tap_at(sp: Vector2) -> void:
	var best: Dino = null
	var best_score := INF
	var far_hit := false
	var right := cam.global_basis.x
	for d in dinos:
		var mid := d.global_position + Vector3(0, d.length * 0.25, 0)
		if cam.is_position_behind(mid):
			continue
		var c := cam.unproject_position(mid)
		# Forgiving hit area: the dinosaur's size on screen, never smaller than a fingertip.
		var r_px := c.distance_to(cam.unproject_position(mid + right * d.length * 0.55))
		var hit_r := maxf(r_px, 80.0)
		var dpx := c.distance_to(sp)
		if dpx > hit_r:
			continue
		if _dist_to(d) > TAP_RANGE + d.length:
			far_hit = true
			continue
		var score := dpx / hit_r
		if score < best_score:
			best_score = score
			best = d
	if best:
		_focus(best)
	elif far_hit and _closer_t <= 0.0:
		_closer_t = 3.0
		Sfx.say("Fly closer!")


## Tapped a dinosaur: meet it (first time) or hear another fact, and circle the camera around it.
func _focus(d: Dino) -> void:
	# Still presenting this one: let it finish instead of restarting the sound and card.
	var now := Time.get_ticks_msec()
	if d == _last_focus and now - _last_focus_ms < 2500:
		return
	_last_focus = d
	_last_focus_ms = now
	var info: Dictionary = DinoData.ALL[d.id]
	var facts: Array = info["facts"]
	var first := not found.has(d.id)
	var i: int = fact_i.get(d.id, 0)
	var fact: String = facts[i % facts.size()]
	fact_i[d.id] = i + 1
	found[d.id] = true
	if hint_dino == d or (hint_dino and hint_dino.id == d.id):
		hint_dino.label.text = info["name"]
		hint_dino = null
	_show_card(d.id, fact)
	if show_dino != d or show_t <= 0.0:
		var away := cam.position - d.global_position
		show_ang = atan2(away.x, away.z)
	show_dino = d
	show_t = 6.0
	if first:
		Sfx.chime()
		Sfx.say("You found " + info["say"] + "! " + fact)
		if found.size() == species.size() and species.size() > 0:
			await get_tree().create_timer(9.0).timeout
			Sfx.say("Wow! You found every dinosaur on the island! You are a dino explorer!")
	else:
		Sfx.say(fact)


func _show_card(id: String, fact: String) -> void:
	card_dino_id = id
	card_name.text = DinoData.ALL[id]["name"]
	card_fact.text = fact
	card.visible = true
	card_t = 9.0
	book_btn.queue_redraw()


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	speed_stick = Stick.new(true, func(_x: float, y: float) -> void:
		throttle_in = y
		if y != 0.0:
			auto_on = false
			show_t = minf(show_t, 0.5))
	root.add_child(speed_stick)
	steer_stick = Stick.new(false, func(x: float, y: float) -> void:
		steer = Vector2(x, y)
		if x != 0.0 or y != 0.0:
			auto_on = false
			show_t = minf(show_t, 0.5))
	root.add_child(steer_stick)

	arrow = Tap.new(Vector2(140, 140), _paint_arrow, Callable(), true)
	root.add_child(arrow)

	book_btn = Tap.new(Vector2(190, 110), _paint_book_btn, _open_book)
	root.add_child(book_btn)

	find_btn = Tap.new(Vector2(250, 110), _paint_find, func() -> void:
		auto_on = true
		show_t = 0.0
		auto_target = _nearest_unfound()
		if auto_target == null:
			Sfx.say("You found them all! Fly around and say hi.")
			auto_on = false)
	root.add_child(find_btn)

	roar_btn = Tap.new(Vector2(190, 110), _paint_roar, _do_roar)
	root.add_child(roar_btn)

	card = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.98, 0.88, 0.95)
	sb.set_corner_radius_all(28)
	sb.border_color = Color(0.25, 0.6, 0.2)
	sb.set_border_width_all(8)
	card.add_theme_stylebox_override("panel", sb)
	card.size = Vector2(520, 200)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	card_name = Label.new()
	card_name.add_theme_font_size_override("font_size", 54)
	card_name.add_theme_color_override("font_color", Color(0.15, 0.4, 0.1))
	card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_name.position = Vector2(20, 14)
	card_name.size = Vector2(480, 80)
	card.add_child(card_name)
	card_fact = Label.new()
	card_fact.add_theme_font_size_override("font_size", 30)
	card_fact.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	card_fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_fact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_fact.position = Vector2(24, 88)
	card_fact.size = Vector2(472, 105)
	card.add_child(card_fact)
	var card_tap := Tap.new(card.size, Callable(), func() -> void:
		if card_dino_id != "" and Time.get_ticks_msec() - _last_focus_ms > 2500:
			_last_focus_ms = Time.get_ticks_msec()
			var facts: Array = DinoData.ALL[card_dino_id]["facts"]
			var f: String = facts[randi() % facts.size()]
			card_fact.text = f
			card_t = 9.0
			Sfx.say(f))
	card.add_child(card_tap)
	card.visible = false

	book = _make_book()
	root.add_child(book)
	book.visible = false
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var pad := 40.0
	speed_stick.position = Vector2(pad, vs.y - speed_stick.size.y - pad)
	steer_stick.position = Vector2(vs.x - steer_stick.size.x - pad, vs.y - steer_stick.size.y - pad)
	arrow.position = Vector2(vs.x / 2 - 70, 20)
	book_btn.position = Vector2(vs.x - book_btn.size.x - 24, 24)
	find_btn.position = Vector2(vs.x / 2 - find_btn.size.x - 20, vs.y - find_btn.size.y - 30)
	roar_btn.position = Vector2(vs.x / 2 + 20, vs.y - roar_btn.size.y - 30)
	card.position = Vector2(24, 24)
	book.size = vs
	_layout_book()


func _update_hud(dt: float) -> void:
	if card.visible:
		card_t -= dt
		if card_t <= 0:
			card.visible = false
	var t := _nearest_unfound()
	arrow_show = t != null
	if t:
		var to := t.global_position - heli.position
		var want := atan2(-to.x, -to.z)
		arrow_ang = -angle_difference(yaw, want)
	roar_btn.modulate.a = 1.0 if _roar_target() else 0.45


func _paint_arrow(c: Control) -> void:
	if not arrow_show:
		return
	var ctr := c.size / 2
	var pulse := 1.0 + 0.08 * sin(_t * 5)
	var pts := PackedVector2Array([Vector2(0, -55), Vector2(38, 25), Vector2(0, 10), Vector2(-38, 25)])
	for i in pts.size():
		pts[i] = ctr + (pts[i] * pulse).rotated(arrow_ang)
	var sh := PackedVector2Array()
	for q in pts:
		sh.append(q + Vector2(3, 4))
	c.draw_colored_polygon(sh, Color(0, 0, 0, 0.3))
	c.draw_colored_polygon(pts, Color(0.25, 0.95, 0.35))
	pts.append(pts[0])
	c.draw_polyline(pts, Color(1, 1, 1), 4)


func _paint_book_btn(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_style_box(_box(Color(0.3, 0.6, 0.2, 0.92), 30), r)
	# Little book.
	c.draw_rect(Rect2(22, 26, 56, 58), Color(0.95, 0.85, 0.55))
	c.draw_rect(Rect2(48, 26, 4, 58), Color(0.6, 0.4, 0.2))
	var f := ThemeDB.fallback_font
	c.draw_string(f, Vector2(88, 74), "%d/%d" % [found.size(), species.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)


func _paint_find(c: Control) -> void:
	var on := auto_on
	c.draw_style_box(_box(Color(0.95, 0.55, 0.1, 0.95) if not on else Color(0.2, 0.7, 0.95, 0.95), 36), Rect2(Vector2.ZERO, c.size))
	var f := ThemeDB.fallback_font
	c.draw_string(f, Vector2(0, 50), "FIND A", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 36, Color.WHITE)
	c.draw_string(f, Vector2(0, 92), "DINO!", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 44, Color.WHITE)


func _paint_roar(c: Control) -> void:
	c.draw_style_box(_box(Color(0.85, 0.2, 0.2, 0.95), 36), Rect2(Vector2.ZERO, c.size))
	var f := ThemeDB.fallback_font
	c.draw_string(f, Vector2(0, 72), "ROAR!", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 52, Color.WHITE)


func _box(col: Color, r: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(r)
	sb.border_color = Color(1, 1, 1, 0.8)
	sb.set_border_width_all(5)
	return sb


func _roar_target() -> Dino:
	var best: Dino = null
	var bd := 120.0
	for d in dinos:
		var dd := _dist_to(d) - d.length
		if dd < bd:
			bd = dd
			best = d
	return best


func _do_roar() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_roar_ms < 1500:
		return       # one roar at a time
	_last_roar_ms = now
	var d := _roar_target()
	if d == null:
		Sfx.say("Fly closer to a dinosaur!")
		return
	var herd: Array[Dino] = [d]
	for o in dinos:
		if o != d and o.id == d.id and o.global_position.distance_to(d.global_position) < 40:
			herd.append(o)
	for o in herd:
		o.roar()
	Sfx.roar(clampf(8.0 / d.length, 0.5, 2.2))


# ---------------------------------------------------------------- Dino Book

var _book_cards: Array[Tap] = []

func _make_book() -> Control:
	var b := Control.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Tap.new(Vector2(10, 10), func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.1, 0.2, 0.08, 0.88))
		var f := ThemeDB.fallback_font
		c.draw_string(f, Vector2(0, 80), "My Dino Book", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 60, Color(1, 0.95, 0.7)),
		func() -> void: pass)
	bg.name = "BG"
	b.add_child(bg)
	var close := Tap.new(Vector2(120, 120), func(c: Control) -> void:
		c.draw_circle(c.size / 2, 55, Color(0.85, 0.25, 0.2))
		c.draw_line(Vector2(38, 38), Vector2(82, 82), Color.WHITE, 12)
		c.draw_line(Vector2(82, 38), Vector2(38, 82), Color.WHITE, 12),
		func() -> void: b.visible = false)
	close.name = "Close"
	b.add_child(close)
	for id in species:
		var card_id: String = id
		var t := Tap.new(Vector2(220, 150), func(c: Control) -> void: _paint_book_card(c, card_id), func() -> void:
			if found.has(card_id):
				var facts: Array = DinoData.ALL[card_id]["facts"]
				Sfx.say(DinoData.ALL[card_id]["say"] + ". " + facts[randi() % facts.size()])
			else:
				Sfx.say("You haven't found this one yet! Keep exploring."))
		b.add_child(t)
		_book_cards.append(t)
	return b


func _layout_book() -> void:
	if book == null:
		return
	var vs := book.size
	book.get_node("BG").size = vs
	book.get_node("Close").position = Vector2(vs.x - 150, 30)
	var cols := maxi(1, int((vs.x - 80) / 240))
	for i in _book_cards.size():
		var c := _book_cards[i]
		c.position = Vector2(40 + (i % cols) * 240 + (vs.x - 80 - cols * 240) / 2, 130 + (i / cols) * 170)


func _paint_book_card(c: Control, id: String) -> void:
	var have := found.has(id)
	c.draw_style_box(_box(Color(0.95, 0.88, 0.6) if have else Color(0.35, 0.35, 0.35), 22), Rect2(Vector2.ZERO, c.size))
	var f := ThemeDB.fallback_font
	if have:
		var nm: String = DinoData.ALL[id]["name"]
		c.draw_string(f, Vector2(0, 88), nm, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 30 if nm.length() < 12 else 22, Color(0.2, 0.35, 0.1))
		c.draw_string(f, Vector2(0, 130), "★", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 36, Color(0.95, 0.65, 0.1))
	else:
		c.draw_string(f, Vector2(0, 100), "?", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 72, Color(0.8, 0.8, 0.8))


func _open_book() -> void:
	book.visible = true
	_layout_book()
	for c in _book_cards:
		c.queue_redraw()
	Sfx.say("You found %d dinosaurs!" % found.size() if found.size() != 1 else "You found one dinosaur!")


# ---------------------------------------------------------------- test autopilot

## Test autopilot: tap the dinosaur on screen exactly like a finger would.
func _autoplay_tap(d: Dino) -> void:
	await get_tree().create_timer(1.6).timeout   # let the helicopter turn to face it
	if not is_instance_valid(d):
		return
	var sp := cam.unproject_position(d.global_position + Vector3(0, d.length * 0.25, 0))
	print("AUTOPLAY tap %s at %s" % [d.id, sp.round()])
	_tap_at(sp)


func _autoplay_shots(dt: float) -> void:
	_shot_t += dt
	if _shot_t > 4.0:
		_shot_t = 0.0
		_shots += 1
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%02d.png" % [autoplay_dir, _shots])
		print("AUTOPLAY shot %d found %d/%d heli %s target %s" % [_shots, found.size(), species.size(), heli.position.round(), (auto_target.id + " " + str(auto_target.global_position.round())) if auto_target else "-"])
		if _shots >= 30:
			get_tree().quit()
