extends Node3D
const Art=preload("res://scripts/apartment.gd")
var body: Node3D
var bubble: Label3D
var bubble_time=0.0
var walk_time=0.0
var home=Vector3(-5,0,0)
var legs: Array=[]
func setup(index: int) -> void:
	body=Node3D.new(); add_child(body)
	var coat=[Color("7d6983"),Color("777d52"),Color("55757b")][index]
	var skirt=Art.cylinder(body,Vector3(0,0.5,0),0.32,0.70,coat,Vector3.ZERO,"fabric")
	skirt.mesh.top_radius=0.23
	Art.sphere(body,Vector3(0,1.0,0),Vector3(0.56,0.64,0.4),coat)
	Art.sphere(body,Vector3(0,1.43,-0.03),Vector3(0.39,0.43,0.38),Color("dab69a"))
	Art.sphere(body,Vector3(0,1.57,0.04),Vector3(0.43,0.31,0.40),Color("ccc7b8"))
	Art.sphere(body,Vector3(0,1.59,0.23),Vector3(0.22,0.22,0.22),Color("ccc7b8"))
	Art.sphere(body,Vector3(0,1.39,-0.235),Vector3(0.09,0.10,0.13),Color("cfab8b"))
	for x in [-0.095,0.095]:
		var glasses=Art.ring(body,Vector3(x,1.46,-0.225),0.07,Color("786851")); glasses.scale=Vector3(1,1,0.4)
		Art.sphere(body,Vector3(x,1.46,-0.23),Vector3(0.025,0.035,0.02),Color("363f3e"))
	Art.box(body,Vector3(0,1.46,-0.23),Vector3(0.07,0.016,0.015),Color("786851"),false,"metal")
	for x in [-0.18,0.18]:
		Art.sphere(body,Vector3(x*1.7,0.98,0),Vector3(0.2,0.53,0.2),coat)
		Art.sphere(body,Vector3(x*1.7,0.75,-0.06),Vector3(0.14,0.17,0.16),Color("dab69a"))
		legs.append(Art.box(body,Vector3(x,0.13,-0.03),Vector3(0.2,0.19,0.34),Color("51443d"),false,"fabric",0.05))
	Art.box(body,Vector3(0,0.78,-0.22),Vector3(0.36,0.52,0.035),Color("c3b79d"),false,"fabric",0.02)
	Art.cylinder(body,Vector3(0.42,0.43,-0.05),0.025,0.86,Color("75563d"),Vector3.ZERO,"wood")
	bubble=Art.label(self,"",Vector3(0,2.08,0),25)
	bubble.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	bubble.outline_size=7
	bubble.modulate=Color("fff0c9")
func speak(text: String) -> void:
	bubble.text=text
	bubble_time=6
func animate(dt: float,moving: bool) -> void:
	walk_time+=dt
	for i in legs.size(): legs[i].position.z=-0.03+sin(walk_time*6+i*PI)*0.06 if moving else -0.03
	body.position.y=sin(walk_time*3)*0.009
	bubble_time=maxf(0,bubble_time-dt)
	bubble.visible=bubble_time>0
