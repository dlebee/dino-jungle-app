class_name Dino
extends Node3D
## One animal living its life: wander, eat, rest, drink, follow its herd, flee from big meat-eaters.
## Flyers circle and glide; swimmers cruise in the sea. Animations are picked by name keywords so
## any CC0 model works (Idle / Walk / Run / Eat / Attack / Fly ...).

var id := ""
var info: Dictionary
var world: Node            # main.gd: heights, place_ok(), random_spot()
var leader: Dino           # herd leader (null = this one leads)
var offset := Vector3.ZERO # place in the herd
var home := Vector3.ZERO

var model: Node3D
var anim: AnimationPlayer
var anims := {}            # role -> animation name
var length := 5.0
var speed := 3.0
var state := "idle"
var timer := 0.0
var target := Vector3.ZERO
var vel := 0.0
var yaw := 0.0
var label: Label3D
var roar_t := 0.0
var _cur_anim := ""
var _fly_ang := 0.0
var _fly_r := 40.0
var _fly_h := 25.0
var body_h := 2.0


func setup(sp_id: String, model_scene: PackedScene, w: Node, home_pos: Vector3, scale_mul: float, yaw_fix: float) -> void:
	id = sp_id
	info = DinoData.ALL[id]
	world = w
	home = home_pos
	speed = info["speed"] * randf_range(0.85, 1.15)
	# Bigger than life so a 4-year-old can spot them from the air; tiny ones get the biggest boost.
	length = maxf(info["length"] * 1.3, 3.5) * scale_mul
	model = model_scene.instantiate()
	var skin := "res://assets/models/dinos/%s_skin.png" % id
	if ResourceLoader.exists(skin):
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = load(skin)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = sm
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	pivot.add_child(model)
	# Normalise size: longest horizontal extent = species length.
	var box := _aabb(model)
	var ext := maxf(box.size.x, box.size.z)
	var s := length / maxf(ext, 0.001)
	model.scale = Vector3.ONE * s
	model.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)
	body_h = box.size.y * s
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = 220.0 + length * 6.0
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.rotation.y = yaw_fix
	anim = _find_anim(model)
	if anim:
		if box.size.x > box.size.z * 1.3 and yaw_fix == 0.0:
			pivot.rotation.y = -PI / 2  # model was authored along X
		_map_anims()
	else:
		# A static sculpture: the walking shader animates it, and it is turned so its head leads.
		var head := _setup_shader()
		if yaw_fix == 0.0:
			pivot.rotation.y = head
	label = Label3D.new()
	label.text = info["name"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 72
	label.outline_size = 24
	label.fixed_size = true          # same size on screen near or far
	label.pixel_size = 0.0011
	label.modulate = Color(1, 1, 0.85)
	label.outline_modulate = Color(0.1, 0.25, 0.05)
	label.position.y = box.size.y * s + 1.2 * clampf(length / 6.0, 0.6, 2.0)
	label.no_depth_test = true
	label.visible = false
	add_child(label)
	yaw = randf() * TAU
	_fly_ang = randf() * TAU
	_fly_r = randf_range(30, 70)
	_fly_h = randf_range(18, 40)
	timer = randf_range(0.2, 1.5)
	_play("idle")


func _aabb(n: Node) -> AABB:
	# Skinned models: measure the skeleton (mesh bounds can be in a different scale than what renders).
	var pts := PackedVector3Array()
	for sk in n.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		var t := _rel_xform(skel, n)
		for i in skel.get_bone_count():
			pts.append(t * skel.get_bone_global_rest(i).origin)
	if pts.size() >= 4:
		var b := AABB(pts[0], Vector3.ZERO)
		for p in pts:
			b = b.expand(p)
		# Bones stop short of the snout, tail tip and toes.
		var g := b.size * 0.08
		b.position -= Vector3(g.x, 0, g.z)
		b.size += Vector3(g.x * 2, g.y * 1.2, g.z * 2)
		return b
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var bb := _rel_xform(mi, n) * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out


func _rel_xform(node: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


var shader_mats: Array[ShaderMaterial] = []
var walk_phase := 0.0
var stride_amt := 0.0
var life := randf() * 10.0


## Swap every material for the walking shader, measuring the mesh so the shader knows where legs,
## tail and head are. Returns the yaw that turns the head toward +Z (the way Dino walks).
func _setup_shader() -> float:
	var shader: Shader = load("res://assets/dino_walk.gdshader")
	var head_yaw := 0.0
	for c in model.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var b := mi.mesh.get_aabb()
		var along_x := b.size.x > b.size.z
		var lo := b.position.x if along_x else b.position.z
		var ln := b.size.x if along_x else b.size.z
		var cl := lo + ln / 2.0
		# Head end: the end whose last 18% reaches higher (neck/head) than the tail end.
		var hi_pos := -INF
		var hi_neg := -INF
		for si in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var t := ((v.x if along_x else v.z) - cl) / (ln / 2.0)
				if t > 0.64:
					hi_pos = maxf(hi_pos, v.y)
				elif t < -0.64:
					hi_neg = maxf(hi_neg, v.y)
		var hs := 1.0 if hi_pos >= hi_neg else -1.0
		if info.has("head_z") and not along_x:
			hs = float(info["head_z"])   # known heading (e.g. a shark's tail fin is taller than its snout)
		if along_x:
			head_yaw = -PI / 2 if hs > 0 else PI / 2
		else:
			head_yaw = 0.0 if hs > 0 else PI
		for si in mi.mesh.get_surface_count():
			var old := mi.get_active_material(si) as BaseMaterial3D
			var sm := ShaderMaterial.new()
			sm.shader = shader
			if old:
				sm.set_shader_parameter("albedo_tex", old.albedo_texture)
				sm.set_shader_parameter("albedo_color", old.albedo_color)
				if old.normal_enabled and old.normal_texture:
					sm.set_shader_parameter("normal_tex", old.normal_texture)
					sm.set_shader_parameter("has_normal", true)
			sm.set_shader_parameter("long_axis", 0 if along_x else 1)
			sm.set_shader_parameter("center_l", cl)
			sm.set_shader_parameter("half_len", ln / 2.0)
			sm.set_shader_parameter("center_w", b.get_center().z if along_x else b.get_center().x)
			sm.set_shader_parameter("y_min", b.position.y)
			sm.set_shader_parameter("height", b.size.y)
			sm.set_shader_parameter("head_sign", hs)
			sm.set_shader_parameter("biped", info.get("biped", false))
			sm.set_shader_parameter("hip", info.get("hip", 0.4))
			sm.set_shader_parameter("tail_amp", info.get("tail_amp", 1.0))
			mi.set_surface_override_material(si, sm)
			shader_mats.append(sm)
	return head_yaw


func _drive_shader(dt: float) -> void:
	if shader_mats.is_empty():
		return
	var swim: bool = info["kind"] == "swim"
	var v := speed if swim else vel
	var want := clampf(v / maxf(speed, 0.1), 0.0, 1.6) if info["kind"] != "fly" else 0.0
	stride_amt = lerpf(stride_amt, minf(want, 1.0), dt * 4.0)
	# One step cycle per ~1.1 body lengths walked (swimmers: a steady tail beat).
	walk_phase += (v / maxf(length * 0.55, 0.6)) * TAU * 0.5 * dt
	life += dt
	for m in shader_mats:
		m.set_shader_parameter("walk_t", walk_phase)
		m.set_shader_parameter("stride", stride_amt)
		m.set_shader_parameter("life_t", life + (2.0 if state == "eat" else 0.0) * sin(life))


func _find_anim(n: Node) -> AnimationPlayer:
	var list := n.find_children("*", "AnimationPlayer", true, false)
	return list[0] if list.size() > 0 else null


func _map_anims() -> void:
	var roles := {
		"idle": ["idle", "stand", "breath"],
		"walk": ["walk"],
		"run": ["run", "gallop", "sprint"],
		"eat": ["eat", "graze", "bite", "drink"],
		"roar": ["roar", "attack", "jump", "headbutt", "bite"],
		"fly": ["fly_flap", "flap", "glide", "fly"],
		"swim": ["swim"],
		"rest": ["sit", "lay", "sleep", "rest"],
	}
	var names := anim.get_animation_list()
	for role in roles:
		for kw in roles[role]:
			if anims.has(role):
				break
			for nm in names:
				if kw in String(nm).to_lower() and not ("death" in String(nm).to_lower() and role != "rest"):
					anims[role] = nm
					break
	if not anims.has("idle") and names.size() > 0:
		anims["idle"] = names[0]
	for role in ["idle", "walk", "run", "fly", "swim"]:
		if anims.has(role):
			var a := anim.get_animation(anims[role])
			if a:
				a.loop_mode = Animation.LOOP_LINEAR


func _play(role: String, spd := 1.0) -> void:
	if anim == null:
		return
	var nm: String = anims.get(role, anims.get("walk" if role == "run" else "idle", ""))
	if role == "fly" and not anims.has("fly"):
		nm = anims.get("idle", "")
	if nm == "":
		return
	anim.speed_scale = spd
	if nm != _cur_anim:
		_cur_anim = nm
		anim.play(nm, 0.3)


func roar() -> void:
	if roar_t > 0.0:
		return          # already roaring: don't restart the animation
	roar_t = 2.2
	state = "idle"
	timer = 2.5
	vel = 0.0
	if anims.has("roar"):
		_cur_anim = ""
		_play("roar")


func _physics_process(dt: float) -> void:
	_drive_shader(dt)
	if roar_t > 0.0:
		roar_t -= dt
		if roar_t <= 0.0:
			_cur_anim = ""
		return
	match info["kind"]:
		"fly":
			_fly(dt)
		"swim":
			_swim(dt)
		_:
			_walk(dt)


func _walk(dt: float) -> void:
	timer -= dt
	var p := global_position
	if leader and is_instance_valid(leader) and leader.state != "roar":
		# Follow the leader, keeping our spot in the herd.
		var goal := leader.global_position + offset.rotated(Vector3.UP, leader.yaw)
		var d := Vector2(goal.x - p.x, goal.z - p.z)
		if d.length() > maxf(3.0, length * 0.4):
			state = "run" if d.length() > 25.0 and length < 12.0 else "walk"
			target = goal
		elif state != "eat" and state != "idle":
			state = leader.state if leader.state in ["eat", "idle", "rest"] else "idle"
	elif timer <= 0.0:
		_decide()
	var want := 0.0
	if state == "walk" or state == "run":
		var to := Vector2(target.x - p.x, target.z - p.z)
		if to.length() < maxf(1.5, length * 0.3) and not leader:
			state = "idle"
			timer = randf_range(1.0, 3.0)
		else:
			var ty := atan2(to.x, to.y)
			var diff := angle_difference(yaw, ty)
			# Big animals turn slowly and keep walking through the turn (an arc, never a spin).
			var max_turn := clampf(4.0 / length, 0.18, 1.4) * (1.3 if state == "run" else 1.0)
			yaw += clampf(diff, -max_turn * dt, max_turn * dt)
			want = speed * (_run_mul() if state == "run" else 1.0)
			want *= lerpf(1.0, 0.55, clampf(absf(diff) / PI, 0.0, 1.0))
	vel = move_toward(vel, want, dt * speed * 1.5)
	var np := p + Vector3(sin(yaw), 0, cos(yaw)) * vel * dt
	if vel > 0.05 and not world.walkable(np.x, np.z, info["home"]):
		target = world.random_spot(home, 60.0, info["home"])
		np = p
		vel *= 0.5
	np.y = world.heights.at(np.x, np.z)
	global_position = np
	rotation.y = yaw
	# Lean a little with the slope.
	var n: Vector3 = world.heights.normal(np.x, np.z)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	rotation.x = lerpf(rotation.x, -asin(clampf(fwd.dot(n), -0.4, 0.4)) * 0.6, dt * 3)
	if vel > 0.1:
		var stride := clampf(vel / (speed * (_run_mul() if state == "run" else 1.0)), 0.4, 1.4)
		_play(state if state == "run" else "walk", stride * clampf(6.0 / length, 0.5, 1.6) * 1.2)
	elif state == "eat":
		_play("eat")
	elif state == "rest":
		_play("rest" if anims.has("rest") and not "death" in String(anims["rest"]).to_lower() else "idle", 0.6)
	else:
		_play("idle")


## Running speed multiplier: small dinosaurs sprint, big ones only hurry a little.
func _run_mul() -> float:
	return clampf(2.4 - length / 10.0, 1.3, 2.0)


func _decide() -> void:
	# Mostly on the move, so from the helicopter the island always looks alive.
	var r := randf()
	var plant: bool = info["diet"] == "plants"
	if r < 0.72:
		state = "walk"
		target = world.random_spot(home, 80.0, info["home"])
		timer = randf_range(12.0, 25.0)
	elif r < 0.82 and length < 10.0:
		state = "run"
		target = world.random_spot(home, 90.0, info["home"])
		timer = randf_range(4.0, 8.0)
	elif r < 0.92 and plant:
		state = "eat"
		timer = randf_range(3.0, 6.0)
	elif r < 0.96:
		state = "rest"
		timer = randf_range(3.0, 6.0)
	else:
		state = "idle"
		timer = randf_range(1.5, 3.5)


func _fly(dt: float) -> void:
	_fly_ang += dt * speed / _fly_r
	var c := home
	var goal := c + Vector3(cos(_fly_ang) * _fly_r, 0, sin(_fly_ang) * _fly_r)
	var gh: float = world.heights.at(goal.x, goal.z)
	goal.y = maxf(gh, 0.0) + _fly_h + sin(_fly_ang * 2.3) * 5.0
	var p := global_position
	var np := p.lerp(goal, clampf(dt * 1.5, 0, 1))
	var d := np - p
	if d.length() > 0.001:
		var ty := atan2(d.x, d.z)
		var turn := angle_difference(yaw, ty)
		yaw = ty
		rotation = Vector3(0, yaw, clampf(-turn * 8.0, -0.5, 0.5))
	global_position = np
	if randf() < dt * 0.05:
		_fly_r = randf_range(30, 80)
		_fly_h = randf_range(15, 45)
	_play("fly")


func _swim(dt: float) -> void:
	timer -= dt
	var p := global_position
	if timer <= 0.0 or Vector2(target.x - p.x, target.z - p.z).length() < 5.0:
		target = world.random_spot(home, 80.0, "sea")
		timer = randf_range(10.0, 20.0)
	var to := Vector2(target.x - p.x, target.z - p.z)
	yaw = lerp_angle(yaw, atan2(to.x, to.y), dt * 0.8)
	var np := p + Vector3(sin(yaw), 0, cos(yaw)) * speed * dt
	# Back and fin above the water so it can be seen from the air.
	np.y = -body_h * 0.45 + sin(Time.get_ticks_msec() * 0.001 + _fly_ang) * 0.12
	global_position = np
	rotation.y = yaw
	_play("swim" if anims.has("swim") else "walk", 0.8)
