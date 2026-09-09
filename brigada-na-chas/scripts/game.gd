extends Node3D
const Art = preload("res://scripts/apartment.gd")
const Worker = preload("res://scripts/worker.gd")
const Voice = preload("res://scripts/voice.gd")
const PORT = 27840
var workers: Dictionary = {}
var props: Dictionary = {}
var holding: Dictionary = {}
var last_input: Dictionary = {}
var voice_times: Dictionary = {}
var next_action: Dictionary = {}
var world: Dictionary
var task = {"valve":false,"pipe":0.0,"paint":0.0,"mount":false,"water":0.0,"time":0.0}
var active = false
var local_id = 1
var yaw = 0.0
var pitch = 0.0
var tick = 0.0
var hint: Label
var status: Label
var menu: PanelContainer
var address: LineEdit
var info: Label
var voice: Node
var mic_enabled: CheckBox
var report_timer = 0.0
var test_mode = false
var test_join = false
var shot_mode = false
var peak_peers = 0
var voice_packets = 0
var test_sent_voice = false
var test_changed = false

func _ready() -> void:
	world = Art.build(self)
	make_prop("cabinet",Vector3(2,1,2),Vector3(1.5,1.1,0.5),Color("658f84"),18)
	make_prop("paint_can",Vector3(-4.5,1.15,3),Vector3(0.45,0.45,0.45),Color("d7b663"),2)
	make_prop("toolbox",Vector3(-5.5,1.1,3),Vector3(0.65,0.35,0.4),Color("c66d50"),4)
	make_prop("plank",Vector3(0,0.5,2),Vector3(2.6,0.15,0.4),Color("b49365"),5)
	make_ui()
	voice = Voice.new()
	add_child(voice)
	voice.packet_ready.connect(send_voice)
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connected_to_server.connect(connected)
	multiplayer.connection_failed.connect(func(): disconnect_game("Не удалось подключиться. Проверь IP и UDP 27840."))
	multiplayer.server_disconnected.connect(func(): disconnect_game("Хост отключился. Комната закрыта."))
	var args = OS.get_cmdline_user_args()
	shot_mode = "--screenshot" in args
	if shot_mode:
		host_game()
		yaw = 0.1
		pitch = -0.12
	if "--test-host" in args or "--test-client" in args:
		test_mode = true
		test_join = "--test-client" in args
		if test_join:
			join_game()
		else:
			host_game()

func make_prop(id: String, pos: Vector3, size: Vector3, color: Color, mass: float) -> void:
	var body = RigidBody3D.new()
	body.name = id
	body.mass = mass
	body.freeze = true
	body.continuous_cd = true
	add_child(body)
	body.position = pos
	Art.box(body,Vector3.ZERO,size,color,false)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	props[id] = body

func make_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	status = Label.new()
	status.position = Vector2(28,20)
	status.add_theme_font_size_override("font_size",22)
	status.add_theme_color_override("font_outline_color",Color("182b32"))
	status.add_theme_constant_override("outline_size",8)
	root.add_child(status)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-440,-90)
	hint.size = Vector2(880,70)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",20)
	hint.add_theme_color_override("font_outline_color",Color("182b32"))
	hint.add_theme_constant_override("outline_size",8)
	root.add_child(hint)
	var cross = Label.new()
	cross.text = "·"
	cross.add_theme_font_size_override("font_size",36)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.add_child(cross)
	menu = PanelContainer.new()
	menu.position = Vector2(380,120)
	menu.custom_minimum_size = Vector2(520,470)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("20363df5")
	style.set_corner_radius_all(14)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	menu.add_theme_stylebox_override("panel",style)
	root.add_child(menu)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	menu.add_child(column)
	var title = Label.new()
	title.text = "БРИГАДА НА ЧАС"
	title.add_theme_font_size_override("font_size",30)
	column.add_child(title)
	info = Label.new()
	info.text = "Квартира № 14 / кооператив на 1–4 игроков\nРанний прототип · локальная сеть / прямой IP"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(info)
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "IP компьютера-хоста"
	column.add_child(address)
	button(column,"Создать комнату",host_game)
	button(column,"Подключиться",join_game)
	button(column,"Продолжить",func():
		if active:
			menu.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	mic_enabled = CheckBox.new()
	mic_enabled.text = "Включить микрофон · говорить по V"
	mic_enabled.toggled.connect(func(on):
		if on:
			voice.start_input())
	column.add_child(mic_enabled)
	button(column,"Выйти",func(): get_tree().quit())

func button(parent: Control, text: String, callback: Callable) -> void:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 38
	b.pressed.connect(callback)
	parent.add_child(b)

func host_game() -> void:
	if active:
		return
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT,3)
	if err != OK:
		info.text = "Не удалось открыть UDP %s: %s" % [PORT,error_string(err)]
		return
	multiplayer.server_relay = false
	multiplayer.multiplayer_peer = peer
	local_id = 1
	active = true
	for prop in props.values():
		prop.freeze = false
	spawn(1,Vector3(0,0.15,4))
	menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("HOST_READY port=",PORT)

func join_game() -> void:
	if active:
		return
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address.text.strip_edges(),PORT)
	if err != OK:
		info.text = error_string(err)
		return
	multiplayer.multiplayer_peer = peer
	info.text = "Подключаемся…"

func connected() -> void:
	local_id = multiplayer.get_unique_id()
	active = true
	menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	register_player.rpc_id(1)
	print("CLIENT_CONNECTED id=",local_id)

func peer_connected(_id: int) -> void:
	pass

@rpc("any_peer","call_remote","reliable")
func register_player() -> void:
	if not multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	if workers.has(id) or workers.size() >= 4:
		return
	for old_id in workers:
		spawn.rpc_id(id,old_id,workers[old_id].position)
	spawn.rpc(id,Vector3(-2+workers.size(),0.15,4))

@rpc("authority","call_local","reliable")
func spawn(id: int, pos: Vector3) -> void:
	if workers.has(id):
		return
	var p = Worker.new()
	add_child(p)
	p.position = pos
	p.target = pos
	p.setup(id,local_id)
	workers[id] = p
	peak_peers = maxi(peak_peers,workers.size())
	last_input[id] = Time.get_ticks_msec()
	print("SPAWN id=",id," count=",workers.size())

func peer_left(id: int) -> void:
	remove_worker(id)

@rpc("authority","call_remote","reliable")
func despawn(id: int) -> void:
	remove_worker(id)

func remove_worker(id: int) -> void:
	if workers.has(id):
		workers[id].queue_free()
		workers.erase(id)
	if holding.has(id):
		holding.erase(id)
	voice.remove_peer(id)
	last_input.erase(id)
	next_action.erase(id)
	voice_times.erase(id)

func disconnect_game(reason: String) -> void:
	active = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for id in workers.keys():
		peer_left(id)
	for prop in props.values():
		prop.freeze = true
	menu.show()
	info.text = reason
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			menu.visible = not menu.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu.visible else Input.MOUSE_MODE_CAPTURED
		if active and not menu.visible:
			if event.physical_keycode == KEY_F:
				if multiplayer.is_server():
					interact(local_id)
				else:
					request_interact.rpc_id(1)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x*0.0022
		pitch = clampf(pitch-event.relative.y*0.0022,-1.4,1.4)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func input_state(move: Vector2, angles: Vector2, jump: bool, use: bool) -> void:
	if multiplayer.is_server():
		accept_input(multiplayer.get_remote_sender_id(),move,angles,jump,use)

func accept_input(id: int, move: Vector2, angles: Vector2, jump: bool, use: bool) -> void:
	if not workers.has(id) or not move.is_finite() or not angles.is_finite():
		return
	var p = workers[id]
	p.move_input = move.limit_length(1)
	p.look = Vector2(wrapf(angles.x,-PI,PI),clampf(angles.y,-1.4,1.4))
	p.jump = p.jump or jump
	last_input[id] = Time.get_ticks_msec()
	p.set_meta("use",use)

@rpc("any_peer","call_remote","reliable")
func request_interact() -> void:
	if multiplayer.is_server():
		interact(multiplayer.get_remote_sender_id())

func nearest_station(id: int) -> String:
	var nearest = ""
	var best = 2.4
	for station in world.spots:
		var distance = workers[id].position.distance_to(world.spots[station]-Vector3(0,1,0))
		if distance < best:
			best = distance
			nearest = station
	return nearest

func interact(id: int) -> void:
	if not workers.has(id):
		return
	var now = Time.get_ticks_msec()
	if now < next_action.get(id,0):
		return
	next_action[id] = now+300
	if nearest_station(id) == "valve":
		task.valve = not task.valve
		return
	if holding.has(id):
		holding.erase(id)
		return
	var best = 2.3
	var found = ""
	for key in props:
		if (key in holding.values() and key != "cabinet") or (key == "cabinet" and task.mount):
			continue
		var distance = props[key].position.distance_to(workers[id].position+Vector3.UP)
		if distance < best:
			best = distance
			found = key
	if found != "":
		holding[id] = found

func _physics_process(dt: float) -> void:
	if not active:
		return
	var move = Vector2.ZERO
	var jump = false
	var use = false
	if not menu.visible and not test_mode:
		move = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).limit_length(1)
		jump = Input.is_physical_key_pressed(KEY_SPACE)
		use = Input.is_physical_key_pressed(KEY_E)
	if test_mode and test_join:
		move = Vector2(0,0.3) if report_timer < 1.0 else Vector2.ZERO
	if multiplayer.is_server():
		accept_input(local_id,move,Vector2(yaw,pitch),jump,use)
	else:
		input_state.rpc_id(1,move,Vector2(yaw,pitch),jump,use)
		if workers.has(local_id):
			workers[local_id].look = Vector2(yaw,pitch)
	for id in workers:
		if multiplayer.is_server():
			if Time.get_ticks_msec()-last_input.get(id,0)>300:
				workers[id].move_input = Vector2.ZERO
				workers[id].set_meta("use",false)
			workers[id].simulate(dt)
		else:
			workers[id].smooth(dt)
	if multiplayer.is_server():
		server_tasks(dt)
		tick += dt
		if tick >= 0.05:
			tick = 0
			var poses = {}
			for id in workers:
				poses[id] = [workers[id].position,workers[id].look]
			var objects = {}
			for key in props:
				objects[key] = props[key].transform
			snapshot.rpc(poses,objects,task,holding)
	voice.talking = mic_enabled.button_pressed and not menu.visible and Input.is_physical_key_pressed(KEY_V)
	update_hud()
	if shot_mode:
		report_timer += dt
		if report_timer > 2:
			shot_mode = false
			capture_screen.call_deferred()
	if test_mode:
		report_timer += dt
		if not test_join and report_timer>2.0 and not test_changed:
			test_changed = true
			task.pipe = 0.5
		if test_join and report_timer>3 and report_timer<4:
			test_sent_voice = true
			var data = PackedByteArray()
			data.resize(640)
			uplink_voice.rpc_id(1,data)
		if report_timer > (10.0 if not test_join else 6.0):
			print("TEST_RESULT peers=",workers.size()," peak=",peak_peers," voice=",voice_packets," pipe=",task.pipe," pos=",workers.get(local_id).position if workers.has(local_id) else Vector3.ZERO)
			get_tree().quit()

func server_tasks(dt: float) -> void:
	if not (task.pipe>=1 and task.paint>=1 and task.mount):
		task.time += dt
	if not task.valve and task.pipe < 1.0:
		task.water = minf(task.water+dt*0.006,1)
	else:
		task.water = maxf(0,task.water-dt*0.012)
	for key in props:
		var carriers = []
		for id in holding:
			if holding[id] == key:
				carriers.append(id)
		if carriers.is_empty():
			continue
		var body = props[key]
		if key == "cabinet" and workers.size()>1 and carriers.size()<2:
			continue
		var target = Vector3.ZERO
		for id in carriers:
			var p = workers[id]
			target += p.position+Vector3(0,1.25,0)-p.global_basis.z*1.5
		target /= carriers.size()
		body.linear_velocity = ((target-body.position)*8).limit_length(9)
		body.angular_velocity *= 0.8
	for id in workers:
		if not workers[id].get_meta("use",false):
			continue
		var station = nearest_station(id)
		if station == "pipe" and task.valve:
			task.pipe = minf(task.pipe+dt*0.17,1)
		if station == "paint":
			task.paint = minf(task.paint+dt*0.10,1)
		if station == "mount" and props.cabinet.position.distance_to(world.spots.mount)<2.2:
			task.mount = true
			for owner in holding.keys():
				if holding[owner] == "cabinet":
					holding.erase(owner)
			props.cabinet.freeze = true
			props.cabinet.position = world.spots.mount+Vector3(0,0,0.15)
			props.cabinet.rotation = Vector3.ZERO

@rpc("authority","call_remote","unreliable_ordered",1)
func snapshot(poses: Dictionary, objects: Dictionary, tasks: Dictionary, held: Dictionary) -> void:
	for id in workers.keys():
		if not poses.has(id):
			remove_worker(id)
	for id in poses:
		if workers.has(id):
			workers[id].target = poses[id][0]
			if id != local_id:
				workers[id].look = poses[id][1]
	for key in objects:
		if props.has(key):
			props[key].transform = objects[key]
	task = tasks
	holding = held

func update_hud() -> void:
	var done = int(task.pipe>=1)+int(task.paint>=1)+int(task.mount)
	status.text = "БРИГАДА НА ЧАС  /  КВАРТИРА №14\nМастеров: %d/4   •   Работа: %d/3\nТруба %d%%   |   Стена %d%%   |   Шкаф %s\nВода: %d%%   •   %s" % [workers.size(),done,int(task.pipe*100),int(task.paint*100),"✓" if task.mount else "—",int(task.water*100),"МИКРОФОН: V" if mic_enabled.button_pressed else "Микрофон выключен"]
	if done == 3:
		status.text += "\nЗАКАЗ ВЫПОЛНЕН!  Время: %d сек." % int(task.time)
	var context = ""
	if workers.has(local_id):
		var station = nearest_station(local_id)
		match station:
			"valve": context = "F — %s вентиль" % ("открыть" if task.valve else "закрыть")
			"pipe": context = "Удерживай E — чинить трубу" if task.valve else "Сначала закрой красный вентиль (F)"
			"paint": context = "Удерживай E — красить стену"
			"mount": context = "Принеси шкаф и удерживай E — закрепить"
		if holding.has(local_id):
			context += "  •  Несёшь %s / F — отпустить" % holding[local_id]
			if holding[local_id] == "cabinet" and workers.size()>1:
				context += " · Нужны двое (F у шкафа)"
	hint.text = context+"\nWASD — ходить  •  Пробел — прыжок  •  F — взять  •  V — голос  •  Esc — меню"
	world.water.scale = Vector3(1+task.water*12,1,1+task.water*8)
	var mesh: MeshInstance3D = world.paint.get_child(0)
	mesh.material_override.albedo_color = Color("977a65").lerp(Color("79aea1"),task.paint)

func send_voice(data: PackedByteArray) -> void:
	if not active:
		return
	if multiplayer.is_server():
		play_voice.rpc(1,data)
	else:
		uplink_voice.rpc_id(1,data)

@rpc("any_peer","call_remote","unreliable",2)
func uplink_voice(data: PackedByteArray) -> void:
	if not multiplayer.is_server() or data.size() != 640:
		return
	var id = multiplayer.get_remote_sender_id()
	if not workers.has(id):
		return
	var now = Time.get_ticks_msec()
	if now-voice_times.get(id,0)<12:
		return
	voice_times[id] = now
	voice_packets += 1
	voice.receive(id,data)
	play_voice.rpc(id,data)

@rpc("authority","call_remote","unreliable",2)
func play_voice(id: int, data: PackedByteArray) -> void:
	if id != local_id:
		voice_packets += 1
		voice.receive(id,data)

func capture_screen() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://preview.png")
	print("SCREENSHOT ",ProjectSettings.globalize_path("user://preview.png"))
	get_tree().quit()
