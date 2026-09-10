extends SceneTree
const Rules=preload("res://scripts/repair_rules.gd")
var checks=0
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		push_error("FAILED: "+message)
		quit(1)
		assert(false,message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for seed_value in 60:
		var pipe=Rules.create("pipe",seed_value)
		var solution={4:10,5:9,1:6,2:12,6:5,10:3,11:10}
		for index in solution:
			for turn in 4:
				if pipe.masks[index]!=solution[index]: Rules.action(pipe,"rotate",index)
		check(not Rules.pipe_path(pipe.masks).is_empty(),"generated pipe has solution")
		Rules.action(pipe,"confirm")
		check(pipe.phase==1,"pipe test advances to coupling phase")
		for i in 3:
			Rules.action(pipe,"press"); Rules.advance(pipe,1.8); Rules.action(pipe,"release")
		check(pipe.done,"three correct torques complete pipe")
	var valve=Rules.create("valve",1)
	valve.pressure=0
	Rules.action(valve,"confirm")
	check(valve.round==0 and valve.errors==1,"wrong pressure cannot complete")
	for i in 4:
		valve.pressure=valve.target; Rules.action(valve,"confirm")
	check(valve.done,"valve has four pressure stages")
	var paint=Rules.create("paint",1)
	Rules.action(paint,"confirm"); check(not paint.done,"unpainted wall rejected")
	for i in 40:
		Rules.action(paint,"brush",i); Rules.action(paint,"reload"); Rules.action(paint,"paint",1); Rules.advance(paint,0.48); Rules.action(paint,"paint",0)
	Rules.action(paint,"confirm"); check(paint.done,"proper coating completes paint")
	var over=Rules.create("paint",1)
	Rules.action(over,"brush",0); Rules.action(over,"paint",1); Rules.advance(over,2)
	check(over.cells[0]>1.25,"overpainting creates drips")
	Rules.action(over,"paint",0); Rules.action(over,"sand",1); Rules.advance(over,0.9)
	check(over.cells[0]<1.25,"sanding fixes drips")
	var mount=Rules.create("mount",1)
	mount.tilt=0
	for i in 180: Rules.advance(mount,1.0/60)
	check(mount.phase==1,"level held before screws")
	for i in 4:
		Rules.action(mount,"select",i); Rules.action(mount,"press"); Rules.advance(mount,1.5); Rules.action(mount,"release")
	check(mount.done,"four screws complete mount")
	var invalid=Rules.create("paint",1)
	Rules.action(invalid,"brush",NAN); check(invalid.brush==-1,"NaN ignored")
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.host_game(); await physics_frame
	var p=game.workers[1]
	p.position=Vector3(-4,0,-5); game.begin_repair(1)
	check(not game.sessions.has(1),"pipe blocked until water closed")
	p.position=Vector3(-6,0,-5); game.begin_repair(1)
	check(game.sessions[1].kind=="valve","valve station session opens")
	game.accept_input(1,Vector2.ONE,Vector2.ZERO,true,false)
	check(p.move_input==Vector2.ZERO and not p.jump,"repair locks movement")
	game.sessions[1].done=true; game.server_tasks(0.016)
	check(game.task.valve and not game.sessions.has(1),"server applies completed task")
	p.position=Vector3(1,0,-5.5); p.set_meta("use",true); game.server_tasks(20)
	check(game.task.paint==0,"holding old E input cannot paint")
	game.begin_repair(1); check(game.sessions[1].kind=="paint","paint starts")
	p.position=Vector3(0,0,5); game.server_tasks(0.016)
	check(not game.sessions.has(1),"moving away cancels session")
	game.spawn(22,Vector3(1,0,-5.5)); p.position=Vector3(1,0,-5.5)
	game.begin_repair(1); game.begin_repair(22)
	check(not game.sessions.has(22),"station locked to one player")
	game.remove_worker(1); check(not game.sessions.has(1),"disconnect releases task lock")
	print("LOGIC_PASS v0.2 checks=",checks)
	quit()
