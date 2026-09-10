extends Node3D
const Art=preload("res://scripts/apartment.gd")
var parts: Array=[]
func setup(pos: Vector3,authoritative: bool) -> void:
	var positions=[Vector3(0,1.0,0),Vector3(0,1.6,0),Vector3(-0.39,1.0,0),Vector3(0.39,1.0,0),Vector3(-0.16,0.39,0),Vector3(0.16,0.39,0)]
	var sizes=[Vector3(0.55,0.7,0.35),Vector3(0.36,0.42,0.36),Vector3(0.2,0.65,0.22),Vector3(0.2,0.65,0.22),Vector3(0.23,0.72,0.27),Vector3(0.23,0.72,0.27)]
	for i in 6:
		var body=RigidBody3D.new(); add_child(body); body.position=pos+positions[i]
		body.mass=8 if i==0 else 2; body.freeze=not authoritative; body.collision_layer=4; body.collision_mask=1; body.continuous_cd=true
		var col=CollisionShape3D.new(); var shape=BoxShape3D.new(); shape.size=sizes[i]; col.shape=shape; body.add_child(col)
		Art.sphere(body,Vector3.ZERO,sizes[i],Color("d5ac8d") if i==1 else (Color("e6ac55") if i<4 else Color("40545c")))
		body.linear_velocity=Vector3(2,1,2); body.angular_velocity=Vector3(1,0,2)
		parts.append(body)
	for i in range(1,6):
		var joint=PinJoint3D.new(); add_child(joint)
		joint.position=pos+([Vector3.ZERO,Vector3(0,1.35,0),Vector3(-0.28,1.25,0),Vector3(0.28,1.25,0),Vector3(-0.16,0.7,0),Vector3(0.16,0.7,0)][i])
		joint.node_a=joint.get_path_to(parts[0]); joint.node_b=joint.get_path_to(parts[i]); joint.exclude_nodes_from_collision=true
func poses() -> Array:
	var result=[]
	for body in parts: result.append(body.transform)
	return result
func apply_poses(data: Array) -> void:
	for i in mini(data.size(),parts.size()): parts[i].transform=data[i]
