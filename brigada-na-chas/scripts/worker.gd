extends CharacterBody3D
const Art = preload("res://scripts/apartment.gd")
var ragdoll: Node3D
var fallen_time=0.0
var on_ladder=false
var peer_id: int
var camera: Camera3D
var visual: Node3D
var move_input = Vector2.ZERO
var look = Vector2.ZERO
var jump = false
var target = Vector3.ZERO
var local_player = false

func setup(id: int, local_id: int) -> void:
	collision_layer = 2
	collision_mask = 1
	peer_id = id
	local_player = id == local_id
	var col = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)
	visual = Node3D.new()
	add_child(visual)
	var colors = [Color("e6ac55"),Color("5bafa5"),Color("b77782"),Color("8a91bc")]
	Art.sphere(visual,Vector3(0,1.03,0),Vector3(0.58,0.82,0.38),colors[id % 4])
	Art.sphere(visual,Vector3(0,1.60,0),Vector3(0.38,0.43,0.37),Color("d5ac8d"))
	Art.sphere(visual,Vector3(0,1.77,0),Vector3(0.46,0.25,0.43),Color("e2b35f"))
	Art.cylinder(visual,Vector3(0,1.72,-0.04),0.26,0.04,Color("e2b35f"),Vector3.ZERO,"plaster")
	for x in [-0.16,0.16]:
		Art.sphere(visual,Vector3(x,0.37,0),Vector3(0.24,0.73,0.29),Color("40545c"))
		Art.box(visual,Vector3(x,0.12,-0.07),Vector3(0.25,0.20,0.43),Color("463e34"),false,"fabric",0.07)
		var arm=Art.sphere(visual,Vector3(x*2,1.05,0),Vector3(0.21,0.65,0.23),colors[id % 4]); arm.rotation.z=-signf(x)*0.15
		Art.sphere(visual,Vector3(x*2.2,0.73,0),Vector3(0.20,0.22,0.22),Color("66594b"))
	for x in [-0.10,0.10]: Art.sphere(visual,Vector3(x,1.63,-0.175),Vector3(0.045,0.04,0.03),Color("303c3b"))
	var label = Art.label(visual,"МАСТЕР %s" % str(id).right(3),Vector3(0,2.2,0),24)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.fov = 78
	add_child(camera)
	camera.current = local_player
	visual.visible = not local_player

func simulate(dt: float) -> void:
	if is_instance_valid(ragdoll):
		fallen_time-=dt
		if local_player: camera.global_position=ragdoll.parts[1].global_position+Vector3(0,0.3,0)
		if fallen_time<=0: recover()
		return
	if on_ladder: return
	rotation.y = look.x
	camera.rotation.x = look.y
	var direction = Basis(Vector3.UP,look.x) * Vector3(move_input.x,0,move_input.y)
	var traction=5.0 if get_meta("slippery",false) else 24.0
	velocity.x = move_toward(velocity.x,direction.x*4.4,traction*dt)
	velocity.z = move_toward(velocity.z,direction.z*4.4,traction*dt)
	if not is_on_floor():
		velocity.y -= 20*dt
	elif jump:
		velocity.y = 6
	jump = false
	move_and_slide()
	if position.y < -8:
		position = Vector3(0,1,4)

func smooth(dt: float) -> void:
	if is_instance_valid(ragdoll):
		if local_player: camera.global_position=ragdoll.parts[1].global_position+Vector3(0,0.3,0)
		return
	position = position.lerp(target,1-exp(-18*dt))
	rotation.y = look.x
	camera.rotation.x = look.y

func fall(authoritative: bool=true) -> void:
	if is_instance_valid(ragdoll): return
	on_ladder=false; fallen_time=3.5; collision_layer=0; collision_mask=0; visual.hide()
	ragdoll=preload("res://scripts/ragdoll.gd").new(); get_parent().add_child(ragdoll); ragdoll.setup(position,authoritative)
func recover() -> void:
	if is_instance_valid(ragdoll): ragdoll.queue_free()
	ragdoll=null; fallen_time=0; on_ladder=false
	position=Vector3(-0.4,0.1,1.4); target=position; velocity=Vector3.ZERO
	collision_layer=2; collision_mask=1; camera.position=Vector3(0,1.65,0); camera.rotation=Vector3.ZERO
	visual.visible=not local_player
func _exit_tree() -> void:
	if is_instance_valid(ragdoll): ragdoll.queue_free()
