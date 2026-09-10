extends SceneTree
func _initialize() -> void: call_deferred("run")
func key(code: int,down: bool) -> void:
	var e=InputEventKey.new(); e.physical_keycode=code; e.keycode=code; e.pressed=down
	root.push_input(e)
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.host_game()
	game.test_mode=true
	game.set_physics_process(false)
	await physics_frame
	game.workers[1].position=Vector3(-6,0,-5)
	key(KEY_E,true); key(KEY_E,false)
	await physics_frame
	assert(game.sessions.has(1),"E enters station")
	game.update_hud()
	assert(game.ui.repair.visible,"repair overlay visible")
	key(KEY_SPACE,true); key(KEY_SPACE,false)
	assert(game.sessions[1].round==1,"Space routed into valve game")
	key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
	await process_frame
	assert(not game.sessions.has(1) and not game.ui.repair.visible,"Esc cancels repair")
	key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
	await process_frame
	assert(game.menu.visible,"Esc opens settings")
	assert(not game.ui.status.get_parent().visible,"HUD hidden behind settings")
	game.settings.shadows=false; game.settings.effects=false; game.settings.fov=90.0; game.settings.msaa=0
	game.apply_settings(false)
	for light in game.world.lights: assert(not light.shadow_enabled)
	assert(not game.world.dust.emitting and game.workers[1].camera.fov==90)
	assert(game.get_viewport().msaa_3d==0)
	game.resume_game(); assert(not game.menu.visible)
	game.task.paint=1.0; game.request_restart(); assert(game.task.paint==1.0)
	game.request_restart(); assert(game.task.paint==0.0 and game.sessions.is_empty())
	print("INTERACTION_PASS E Space Esc HUD settings restart")
	quit()

