extends SceneTree
var game
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.host_game()
	await physics_frame
	var p = game.workers[1]
	p.position = Vector3(-6,0,-5)
	game.interact(1)
	assert(game.task.valve)
	p.position = Vector3(-4,0,-5)
	p.set_meta("use",true)
	game.server_tasks(7)
	assert(game.task.pipe == 1.0)
	p.position = Vector3(1,0,-5.5)
	game.server_tasks(11)
	assert(game.task.paint == 1.0)
	p.position = Vector3(5.7,0,-4.5)
	game.props.cabinet.position = Vector3(6,1,-4)
	game.server_tasks(0.1)
	assert(game.task.mount)
	assert(game.props.cabinet.freeze)
	game.accept_input(1,Vector2(90,90),Vector2.ZERO,false,false)
	assert(p.move_input.length() <= 1.001)
	game.accept_input(1,Vector2(NAN,0),Vector2.ZERO,false,false)
	assert(p.move_input.is_finite())
	print("LOGIC_PASS valve pipe paint cabinet input_validation")
	quit()
