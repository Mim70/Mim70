extends CharacterBody3D
const Art = preload("res://scripts/apartment.gd")
var peer_id: int
var camera: Camera3D
var visual: Node3D
var move_input = Vector2.ZERO
var look = Vector2.ZERO
var jump = false
var target = Vector3.ZERO
var local_player = false

func setup(id: int, local_id: int) -> void:
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
	Art.box(visual,Vector3(0,0.95,0),Vector3(0.55,0.8,0.35),colors[id % 4],false)
	Art.box(visual,Vector3(0,1.56,0),Vector3(0.37,0.4,0.37),Color("e3b18a"),false)
	Art.box(visual,Vector3(0,1.8,0),Vector3(0.48,0.12,0.48),Color("f3bd55"),false)
	for x in [-0.16,0.16]:
		Art.box(visual,Vector3(x,0.3,0),Vector3(0.22,0.6,0.28),Color("384951"),false)
	var label = Art.label(visual,"МАСТЕР %s" % str(id).right(3),Vector3(0,2.2,0),24)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.fov = 78
	add_child(camera)
	camera.current = local_player
	visual.visible = not local_player

func simulate(dt: float) -> void:
	rotation.y = look.x
	camera.rotation.x = look.y
	var direction = Basis(Vector3.UP,look.x) * Vector3(move_input.x,0,move_input.y)
	velocity.x = move_toward(velocity.x,direction.x*4.4,24*dt)
	velocity.z = move_toward(velocity.z,direction.z*4.4,24*dt)
	if not is_on_floor():
		velocity.y -= 20*dt
	elif jump:
		velocity.y = 6
	jump = false
	move_and_slide()
	if position.y < -8:
		position = Vector3(0,1,4)

func smooth(dt: float) -> void:
	position = position.lerp(target,1-exp(-18*dt))
	rotation.y = look.x
	camera.rotation.x = look.y
