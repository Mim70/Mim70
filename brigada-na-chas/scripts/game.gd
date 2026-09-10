extends Node3D
const Art = preload("res://scripts/apartment.gd")
const Worker = preload("res://scripts/worker.gd")
const Voice = preload("res://scripts/voice.gd")
const PORT = 27840
const Rules = preload("res://scripts/repair_rules.gd")
const Interface = preload("res://scripts/game_ui.gd")
const Options = preload("res://scripts/options.gd")
var settings: Dictionary = {}
var ui: CanvasLayer
var sessions: Dictionary = {}
var action_rates: Dictionary = {}
var notices = ""
var notice_until = 0
var screenshot_kind = ""
var restart_confirmation = false
var closing_repair = false
var repair_test_requested = false
var repair_test_actions = 0
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
	settings = Options.load_settings()
	world = Art.build(self)
	make_prop("cabinet",Vector3(2,1,2),Vector3(1.5,1.1,0.5),Color("658f84"),18)
	make_prop("paint_can",Vector3(-4.5,1.15,3),Vector3(0.45,0.45,0.45),Color("d7b663"),2)
	make_prop("toolbox",Vector3(-5.5,1.1,3),Vector3(0.65,0.35,0.4),Color("c66d50"),4)
	make_prop("plank",Vector3(0,0.5,2),Vector3(2.6,0.15,0.4),Color("b49365"),5)
	make_ui()
	voice = Voice.new()
	add_child(voice)
	voice.packet_ready.connect(send_voice)
	apply_settings(false)
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connected_to_server.connect(connected)
	multiplayer.connection_failed.connect(func(): disconnect_game("Не удалось подключиться. Проверь IP и UDP 27840."))
	multiplayer.server_disconnected.connect(func(): disconnect_game("Хост отключился. Комната закрыта."))
	var args = OS.get_cmdline_user_args()
	shot_mode = "--screenshot" in args
	for arg in args:
		if arg.begins_with("--capture="):
			screenshot_kind=arg.trim_prefix("--capture=")
			shot_mode=true
	if shot_mode:
		host_game()
		yaw = 0.1
		pitch = -0.12
		if screenshot_kind=="room":
			workers[1].position=Vector3(-1.2,0.05,5.8)
			yaw=-0.48; pitch=-0.12
	if "--test-host" in args or "--test-client" in args:
		test_mode = true
		ui.repair.set_process(false)
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
	Art.prop_visual(body,id)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	props[id] = body

func make_ui() -> void:
	ui=Interface.new()
	add_child(ui)
	ui.setup(self)
	menu=ui.menu
	address=ui.address
	info=ui.info
	status=ui.status
	hint=ui.hint
	mic_enabled=ui.mic

func apply_settings(save: bool=true) -> void:
	get_viewport().msaa_3d=int(settings.msaa)
	world.environment.ambient_light_energy=settings.brightness
	world.dust.emitting=settings.effects
	for light in world.lights: light.shadow_enabled=settings.shadows
	for worker in workers.values(): worker.camera.fov=settings.fov
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,settings.volume)))
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if save: Options.save_settings(settings)

func resume_game() -> void:
	if active:
		menu.hide()
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func request_restart() -> void:
	if not active or not multiplayer.is_server():
		info.text="Новый заказ может начать только хост."
		return
	if not restart_confirmation:
		restart_confirmation=true
		info.text="Сбросить текущий ремонт? Нажми «Новый заказ» ещё раз."
		return
	restart_confirmation=false
	reset_order.rpc()
	resume_game()

@rpc("authority","call_local","reliable")
func reset_order() -> void:
	sessions.clear()
	holding.clear()
	task={"valve":false,"pipe":0.0,"paint":0.0,"mount":false,"water":0.0,"time":0.0}
	var starts={"cabinet":Vector3(2,1,2),"paint_can":Vector3(-4.5,1.15,3),"toolbox":Vector3(-5.5,1.1,3),"plank":Vector3(0,0.5,2)}
	for key in props:
		props[key].freeze=not multiplayer.is_server()
		props[key].position=starts[key]
		props[key].rotation=Vector3.ZERO
		props[key].linear_velocity=Vector3.ZERO
		props[key].angular_velocity=Vector3.ZERO
	ui.repair.hide()
	for id in workers:
		workers[id].position=Vector3(0,0.15,4)
		workers[id].target=workers[id].position

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
	p.camera.fov=settings.fov
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
	sessions.erase(id)
	action_rates.erase(id)
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
	voice.talking=false
	sessions.clear()
	ui.repair.hide()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for id in workers.keys():
		peer_left(id)
	for prop in props.values():
		prop.freeze = true
	menu.show()
	info.text = reason
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			menu.visible = not menu.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu.visible else Input.MOUSE_MODE_CAPTURED
		if active and not menu.visible and not ui.repair.visible:
			if event.physical_keycode == KEY_E:
				if multiplayer.is_server(): begin_repair(local_id)
				else: request_repair.rpc_id(1)
			if event.physical_keycode == KEY_F:
				if multiplayer.is_server():
					interact(local_id)
				else:
					request_interact.rpc_id(1)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x*0.0022*settings.sensitivity
		pitch = clampf(pitch-event.relative.y*0.0022*settings.sensitivity,-1.4,1.4)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func input_state(move: Vector2, angles: Vector2, jump: bool, use: bool) -> void:
	if multiplayer.is_server():
		accept_input(multiplayer.get_remote_sender_id(),move,angles,jump,use)

func accept_input(id: int, move: Vector2, angles: Vector2, jump: bool, use: bool) -> void:
	if not workers.has(id) or not move.is_finite() or not angles.is_finite():
		return
	var p = workers[id]
	p.move_input = Vector2.ZERO if sessions.has(id) else move.limit_length(1)
	p.look = Vector2(wrapf(angles.x,-PI,PI),clampf(angles.y,-1.4,1.4))
	p.jump = (p.jump or jump) and not sessions.has(id)
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
	if nearest_station(id) == "valve" and not holding.has(id):
		begin_repair(id)
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
	if not menu.visible and not ui.repair.visible and not test_mode:
		move = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).limit_length(1)
		jump = Input.is_physical_key_pressed(KEY_SPACE)
		use = false
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
			snapshot.rpc(poses,objects,task,holding,sessions)
	voice.talking = mic_enabled.button_pressed and not menu.visible and Input.is_physical_key_pressed(KEY_V)
	update_hud()
	if shot_mode:
		report_timer += dt
		if report_timer > 2:
			shot_mode = false
			if screenshot_kind in ["valve","pipe","paint","mount"]:
				ui.repair.open(Rules.create(screenshot_kind,18))
			elif screenshot_kind=="settings":
				menu.show(); ui.tabs.current_tab=1
			set_physics_process(false)
			capture_screen.call_deferred()
	if test_mode:
		report_timer += dt
		if not test_join and report_timer>2.0 and not test_changed:
			test_changed = true
			task.pipe = 0.5
			for peer_id in workers:
				if peer_id!=1: workers[peer_id].position=Vector3(-6,0.1,-5)
		if test_join and report_timer>2.5 and not repair_test_requested:
			repair_test_requested=true
			request_repair.rpc_id(1)
		if test_join and sessions.has(local_id):
			var repair=sessions[local_id]
			request_repair_action.rpc_id(1,"turn",clampf((repair.target-repair.pressure)*8,-1,1))
			if absf(repair.pressure-repair.target)<0.08:
				request_repair_action.rpc_id(1,"confirm",0.0)
			repair_test_actions+=1
		if test_join and report_timer>3 and report_timer<4:
			test_sent_voice = true
			var data = PackedByteArray()
			data.resize(640)
			uplink_voice.rpc_id(1,data)
		if report_timer > (10.0 if not test_join else 6.0):
			print("TEST_RESULT peers=",workers.size()," peak=",peak_peers," voice=",voice_packets," pipe=",task.pipe," valve=",task.valve," repair_actions=",repair_test_actions," pos=",workers.get(local_id).position if workers.has(local_id) else Vector3.ZERO)
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
	for id in sessions.keys():
		if not workers.has(id) or workers[id].position.distance_to(world.spots[sessions[id].kind]-Vector3.UP)>3.2:
			sessions.erase(id)
			continue
		var repair=sessions[id]
		# A mounted cabinet must stay nearby until all screws are secure.
		if repair.kind=="mount" and props.cabinet.position.distance_to(world.spots.mount)>2.2:
			notify_player(id,"Шкаф унесли от крепления. Верните его и начните заново.")
			sessions.erase(id)
			continue
		Rules.advance(repair,dt)
		if repair.kind=="paint": task.paint=float(repair.quality)/40.0*0.99
		if repair.kind=="pipe" and repair.phase==1: task.pipe=0.5+float(repair.round)/3.0*0.49
		if repair.done:
			finish_repair(repair.kind)
			sessions.erase(id)


@rpc("authority","call_remote","unreliable_ordered",1)
func snapshot(poses: Dictionary, objects: Dictionary, tasks: Dictionary, held: Dictionary, repairs: Dictionary) -> void:
	for id in workers.keys():
		if not poses.has(id):
			remove_worker(id)
	for id in poses:
		if not workers.has(id): spawn(id,poses[id][0])
		if workers.has(id):
			workers[id].target = poses[id][0]
			if id != local_id:
				workers[id].look = poses[id][1]
	for key in objects:
		if props.has(key):
			props[key].transform = objects[key]
	task = tasks
	holding = held
	sessions = repairs
	if not repairs.has(local_id): closing_repair=false

func update_hud() -> void:
	var done=int(task.pipe>=1)+int(task.paint>=1)+int(task.mount)
	status.text="КВАРТИРА 14   /   ЗАКАЗ %d/3   /   МАСТЕРОВ %d/4" % [done,workers.size()]
	if settings.details:
		status.text+="\nТруба %d%%  ·  Стена %d%%  ·  Шкаф %s  ·  Вода %d%%" % [int(task.pipe*100),int(task.paint*100),"готов" if task.mount else "не закреплён",int(task.water*100)]
	if done==3: status.text+="\nЗаказ выполнен за %d сек. Новый заказ — в меню Esc." % int(task.time)
	var context=""
	if workers.has(local_id):
		var station=nearest_station(local_id)
		var descriptions={"valve":"E — перекрыть воду / контроль давления","pipe":"E — собрать трубу и затянуть муфты","paint":"E — покраска валиком","mount":"E — уровень и крепление шкафа"}
		context=descriptions.get(station,"")
		if holding.has(local_id):
			var names={"cabinet":"шкаф","paint_can":"краска","toolbox":"ящик инструментов","plank":"доска"}
			context+="  ·  F — отпустить: "+names[holding[local_id]]
			if holding[local_id]=="cabinet" and workers.size()>1: context+=" (нести вдвоём)"
	if Time.get_ticks_msec()<notice_until: context=notices
	hint.text=context+"\nWASD — ходить  ·  F — взять  ·  E — работа  ·  V — голос  ·  Esc — настройки"
	world.water.scale=Vector3(1+task.water*12,1,1+task.water*8)
	world.valve.rotation.z=PI*0.5 if task.valve else 0.0
	var mesh: MeshInstance3D=world.paint.get_child(0)
	mesh.material_override.albedo_color=Color("a18d70").lerp(Color("79aea1"),task.paint)
	if sessions.has(local_id) and not closing_repair:
		if not ui.repair.visible: ui.repair.open(sessions[local_id])
		else: ui.repair.state=sessions[local_id].duplicate(true)
	elif ui.repair.visible:
		ui.repair.hide()
		if not menu.visible: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

@rpc("any_peer","call_remote","reliable")
func request_repair() -> void:
	if multiplayer.is_server(): begin_repair(multiplayer.get_remote_sender_id())

func begin_repair(id: int) -> void:
	if not workers.has(id) or sessions.has(id): return
	var kind=nearest_station(id)
	if kind=="": return
	if (kind=="valve" and task.valve) or (kind=="pipe" and task.pipe>=1) or (kind=="paint" and task.paint>=1) or (kind=="mount" and task.mount):
		notify_player(id,"Эта работа уже выполнена."); return
	for repair in sessions.values():
		if repair.kind==kind:
			notify_player(id,"Здесь уже работает другой мастер."); return
	if kind=="pipe" and not task.valve:
		notify_player(id,"Сначала перекрой воду на красном вентиле."); return
	if kind=="mount" and props.cabinet.position.distance_to(world.spots.mount)>2.2:
		notify_player(id,"Сначала принесите шкаф к креплению на стене."); return
	if kind=="pipe": task.pipe=0.0
	if kind=="paint": task.paint=0.0
	sessions[id]=Rules.create(kind,randi())
	workers[id].move_input=Vector2.ZERO

func finish_repair(kind: String) -> void:
	match kind:
		"valve": task.valve=true
		"pipe": task.pipe=1.0
		"paint": task.paint=1.0
		"mount":
			task.mount=true
			for owner in holding.keys():
				if holding[owner]=="cabinet": holding.erase(owner)
			props.cabinet.freeze=true
			props.cabinet.position=world.spots.mount+Vector3(0,0,0.15)
			props.cabinet.rotation=Vector3.ZERO

func local_repair_action(command: String,value: float) -> void:
	if not active: return
	if multiplayer.is_server(): repair_action(local_id,command,value)
	else: request_repair_action.rpc_id(1,command,value)

@rpc("any_peer","call_remote","reliable")
func request_repair_action(command: String,value: float) -> void:
	if multiplayer.is_server(): repair_action(multiplayer.get_remote_sender_id(),command,value)

func repair_action(id: int,command: String,value: float) -> void:
	if not sessions.has(id): return
	var now=Time.get_ticks_msec()
	var rate=action_rates.get(id,{"start":now,"count":0})
	if now-rate.start>1000: rate={"start":now,"count":0}
	rate.count+=1; action_rates[id]=rate
	if rate.count>130: return
	Rules.action(sessions[id],command,value)

func cancel_local_repair() -> void:
	if multiplayer.is_server(): sessions.erase(local_id)
	else:
		closing_repair=true
		cancel_repair.rpc_id(1)
		sessions.erase(local_id)
	ui.repair.hide()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

@rpc("any_peer","call_remote","reliable")
func cancel_repair() -> void:
	if multiplayer.is_server(): sessions.erase(multiplayer.get_remote_sender_id())

func notify_player(id: int,text: String) -> void:
	if id==local_id: show_notice(text)
	elif id in multiplayer.get_peers(): show_notice.rpc_id(id,text)

@rpc("authority","call_remote","reliable")
func show_notice(text: String) -> void:
	notices=text; notice_until=Time.get_ticks_msec()+4000


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
	get_viewport().get_texture().get_image().save_png("user://preview"+("-"+screenshot_kind if screenshot_kind!="" else "")+".png")
	print("SCREENSHOT ",ProjectSettings.globalize_path("user://preview.png"))
	get_tree().quit()


func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and active and not test_mode and not shot_mode and screenshot_kind=="":
		if ui.repair.visible: cancel_local_repair()
		menu.show()
		voice.talking=false
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

