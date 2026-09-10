extends SceneTree
const Rules=preload("res://scripts/repair_rules.gd")
var checks=0
func check(value: bool,message: String) -> void:
	if not value: push_error(message); quit(1)
	assert(value,message); checks+=1
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var s=Rules.create("chandelier",12)
	for frame in 1800:
		Rules.advance(s,1.0/120)
		for note in s.notes:
			if not note.hit and note.age>=0.89: Rules.action(s,"hit",note.id)
		Rules.action(s,"bulb",mini(s.bulbs.count(1.0),2))
		Rules.action(s,"screw",1)
		if s.done: break
	check(s.done and not s.fallen,"simultaneous rhythm and bulbs completes")
	var fail=Rules.create("chandelier",5)
	for frame in 600: Rules.advance(fail,1.0/60)
	check(fail.fallen and not fail.done,"misses cause fall")
	var supported=Rules.create("chandelier",5); supported.supported=true
	for frame in 280: Rules.advance(supported,1.0/60)
	check(not supported.fallen,"helper gives more tolerance")
	for seed_value in 30:
		var electric=Rules.create("electric",seed_value)
		for mask in 64:
			var candidate=electric.fuses.duplicate()
			for i in 6:
				if mask&(1<<i): Rules.flip(candidate,i)
			if candidate.count(true)==6:
				for i in 6:
					if mask&(1<<i): Rules.action(electric,"flip",i)
				break
		for i in [2,0,3,1]: Rules.action(electric,"probe",i)
		check(electric.done,"electrical puzzle solvable")
	var game=load("res://main.tscn").instantiate(); root.add_child(game); game.host_game(); game.set_physics_process(false)
	var p=game.workers[1]
	p.position=game.world.ladder.position+Vector3(0,0,0.8); game.begin_repair(1)
	check(game.sessions.has(1) and game.sessions[1].kind=="chandelier","ladder accessible")
	game.sessions[1].bulbs[0]=1.0; game.sessions[1].climb=1
	game.sessions[1].wobble=1.1; game.server_tasks(0.01)
	check(is_instance_valid(p.ragdoll) and not game.sessions.has(1),"host creates physical fall")
	for frame in 20: await physics_frame
	check(p.ragdoll.parts.size()==6 and p.ragdoll.parts[0].position.is_finite(),"six physical ragdoll parts")
	p.recover(); p.position=game.world.ladder.position+Vector3(0,0,0.8); game.begin_repair(1)
	check(game.sessions[1].bulbs[0]==1.0 and not game.sessions[1].fallen,"bulbs survive fall and retry")
	game.cancel_local_repair(); p.on_ladder=false
	game.task.valve=true; p.position=Vector3(-4,0,-5); game.begin_repair(1)
	game.sessions[1].phase=1; game.sessions[1].round=2; game.cancel_local_repair(); game.begin_repair(1)
	check(game.sessions[1].round==2 and game.sessions[1].phase==1,"pipe couplings survive close reopen")
	for level in 3:
		game.load_level(level,level+1)
		check(game.level_index==level and game.world.spots.has("chandelier"),"level rebuild retains ladder")
		game.finish_repair("mount")
		check(is_equal_approx(game.props.cabinet.position.x,7.57),"cabinet fitted to wall")
		for i in 3: game.props["trash_%d" % i].position=game.world.spots.bin
		game.server_tasks(0.01); check(game.completed("cleanup"),"trash accepted")
	print("V03_PASS checks=",checks); quit()
