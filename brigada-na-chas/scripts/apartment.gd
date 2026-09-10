extends RefCounted
static var textures: Dictionary = {}
static var meshes: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if textures.has(kind): return textures[kind]
	var image = Image.create(256,256,false,Image.FORMAT_RGB8)
	var noise = FastNoiseLite.new()
	noise.seed = 823
	noise.frequency = 0.055
	for y in 256:
		for x in 256:
			var n = noise.get_noise_2d(x,y)
			var v = 0.86+n*0.12
			match kind:
				"wood":
					v=0.88+0.045*sin(x*0.19+noise.get_noise_2d(x*0.04,y*0.7)*2)+n*0.018
				"fabric": v=0.8+n*0.09+0.07*sin(x*PI*0.5)*sin(y*PI*0.5)
				"tile": v=0.9+n*0.04 if x%64>2 and y%64>2 else 0.56
				"plaster": v=0.94+n*0.018+noise.get_noise_2d(x*4,y*4)*0.007
				"metal": v=0.84+n*0.05+0.02*sin(y*3)
			image.set_pixel(x,y,Color(v,v,v))
	image.generate_mipmaps()
	textures[kind]=ImageTexture.create_from_image(image)
	return textures[kind]

static func material(color: Color, kind: String = "plaster") -> StandardMaterial3D:
	var m=StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=0.9
	m.albedo_texture=texture(kind)
	m.uv1_triplanar=true
	m.uv1_scale=Vector3.ONE*1.2
	if kind=="metal":
		m.metallic=0.65; m.roughness=0.32
	return m

static func rounded_mesh(size: Vector3, radius: float) -> ArrayMesh:
	var key=str(size)+str(radius)
	if meshes.has(key): return meshes[key]
	var tool=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half=size*0.5
	var inner=half-Vector3.ONE*radius
	var faces=[[Vector3.RIGHT,Vector3.BACK,Vector3.UP],[Vector3.LEFT,Vector3.FORWARD,Vector3.UP],[Vector3.UP,Vector3.RIGHT,Vector3.BACK],[Vector3.DOWN,Vector3.RIGHT,Vector3.FORWARD],[Vector3.BACK,Vector3.LEFT,Vector3.UP],[Vector3.FORWARD,Vector3.RIGHT,Vector3.UP]]
	for axes in faces:
		var n: Vector3=axes[0]; var u: Vector3=axes[1]; var v: Vector3=axes[2]
		var a=absf(u.dot(half)); var b=absf(v.dot(half)); var h=absf(n.dot(half))
		var xs=[-a,-a+radius*0.3,-a+radius,a-radius,a-radius*0.3,a]
		var ys=[-b,-b+radius*0.3,-b+radius,b-radius,b-radius*0.3,b]
		for i in 5:
			for j in 5:
				var points=[Vector2(xs[i],ys[j]),Vector2(xs[i+1],ys[j]),Vector2(xs[i+1],ys[j+1]),Vector2(xs[i],ys[j+1])]
				for idx in [0,1,2,0,2,3]:
					var p=n*h+u*points[idx].x+v*points[idx].y
					var q=p.clamp(-inner,inner)
					var normal=(p-q).normalized()
					tool.set_normal(normal)
					tool.set_uv(Vector2(points[idx].x,points[idx].y))
					tool.add_vertex(q+normal*radius)
	var mesh=tool.commit()
	meshes[key]=mesh
	return mesh

static func box(parent: Node3D,pos: Vector3,size: Vector3,color: Color,collision: bool=true,kind: String="plaster",radius: float=0.025) -> Node3D:
	var root: Node3D=StaticBody3D.new() if collision else Node3D.new()
	parent.add_child(root); root.position=pos
	var mesh=MeshInstance3D.new()
	var r=minf(radius,minf(size.x,minf(size.y,size.z))*0.45)
	mesh.mesh=rounded_mesh(size,r)
	mesh.material_override=material(color,kind)
	root.add_child(mesh)
	if collision:
		var hit=CollisionShape3D.new(); var shape=BoxShape3D.new()
		shape.size=size; hit.shape=shape; root.add_child(hit)
	return root

static func cylinder(parent: Node3D,pos: Vector3,radius: float,height: float,color: Color,angles: Vector3=Vector3.ZERO,kind: String="metal") -> MeshInstance3D:
	var node=MeshInstance3D.new(); var shape=CylinderMesh.new()
	shape.top_radius=radius; shape.bottom_radius=radius; shape.height=height; shape.radial_segments=24
	node.mesh=shape; node.material_override=material(color,kind)
	parent.add_child(node); node.position=pos; node.rotation=angles
	return node

static func sphere(parent: Node3D,pos: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var node=MeshInstance3D.new(); var shape=SphereMesh.new()
	shape.radius=0.5; shape.height=1; shape.radial_segments=24; shape.rings=12
	node.mesh=shape; node.material_override=material(color)
	parent.add_child(node); node.position=pos; node.scale=size
	return node

static func ring(parent: Node3D,pos: Vector3,radius: float,color: Color) -> MeshInstance3D:
	var node=MeshInstance3D.new(); var shape=TorusMesh.new()
	shape.inner_radius=radius*0.75; shape.outer_radius=radius
	node.mesh=shape; node.material_override=material(color,"metal")
	parent.add_child(node); node.position=pos; node.rotation.x=PI/2
	return node

static func label(parent: Node3D,text: String,pos: Vector3,size: int=40) -> Label3D:
	var l=Label3D.new(); parent.add_child(l); l.position=pos; l.text=text
	l.font_size=size; l.pixel_size=0.004; l.outline_size=2
	l.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return l

static func prop_visual(parent: Node3D,id: String) -> void:
	if id.begins_with("trash_"):
		sphere(parent,Vector3.ZERO,Vector3(0.6,0.75,0.6),Color("596664"))
		sphere(parent,Vector3(0,0.38,0),Vector3(0.13,0.13,0.13),Color("343f3e"))
		return
	if id=="tea_cup":
		cylinder(parent,Vector3.ZERO,0.09,0.2,Color("ded6c4"),Vector3.ZERO,"plaster")
		ring(parent,Vector3(0.11,0,0),0.06,Color("ded6c4"))
		return
	match id:
		"cabinet":
			box(parent,Vector3.ZERO,Vector3(1.5,1.1,0.5),Color("ddd0ad"),false,"wood",0.045)
			for x in [-0.365,0.365]:
				box(parent,Vector3(x,0,0.265),Vector3(0.71,1.02,0.06),Color("577d76"),false,"wood",0.028)
				box(parent,Vector3(x,0,0.301),Vector3(0.53,0.81,0.025),Color("688e85"),false,"wood",0.018)
				cylinder(parent,Vector3(x*0.3,0.0,0.36),0.025,0.20,Color("cbb78f"))
		"paint_can":
			cylinder(parent,Vector3.ZERO,0.23,0.43,Color("e1b257"))
			cylinder(parent,Vector3(0,0.222,0),0.236,0.025,Color("7c9793"))
			label(parent,"FARBE\nМЯТА",Vector3(0,0,0.236),24)
			var handle=ring(parent,Vector3(0,0.1,0),0.26,Color("52666b")); handle.scale.y=0.8
		"toolbox":
			box(parent,Vector3.ZERO,Vector3(0.65,0.35,0.4),Color("ba6448"),false,"metal",0.05)
			box(parent,Vector3(0,0.17,0),Vector3(0.68,0.10,0.42),Color("37494c"),false,"metal",0.035)
			box(parent,Vector3(0,0.26,0),Vector3(0.28,0.06,0.075),Color("303939"),false)
			for x in [-0.23,0.23]: box(parent,Vector3(x,0.07,0.22),Vector3(0.07,0.13,0.025),Color("d4c8a4"),false,"metal")
		"plank": box(parent,Vector3.ZERO,Vector3(2.6,0.15,0.4),Color("c5a876"),false,"wood",0.012)

static func build(parent: Node3D, level: int=0) -> Dictionary:
	var cream=[Color("cfc4ac"),Color("d0d4ba"),Color("b59b78")][level]; var teal=[Color("557973"),Color("577a90"),Color("75674e")][level]; var white=Color("ded8c5")
	box(parent,Vector3(0,-0.2,0),Vector3(16,0.4,14),Color("7c654e"))
	for row in 14:
		for col in 8:
			var tint=0.93+float((row*7+col*3)%9)*0.011
			box(parent,Vector3(-7+col*2,0.018,-6.5+row),Vector3(1.987,0.036,0.987),Color("ac8e66")*tint,false,"wood",0.008)
	box(parent,Vector3(0,2,-7),Vector3(16,4,0.25),cream)
	box(parent,Vector3(-8,2,-3.5),Vector3(0.25,4,7),cream)
	box(parent,Vector3(-8,2,5.5),Vector3(0.25,4,3),cream)
	box(parent,Vector3(-8,3.4,2),Vector3(0.25,1.2,4),cream)
	box(parent,Vector3(8,2,0),Vector3(0.25,4,14),teal)
	box(parent,Vector3(0,4.1,0),Vector3(16,0.2,14),white)
	box(parent,Vector3(0,2,7),Vector3(16,4,0.25),teal)
	for x in [-7.8,7.8]:
		for y in [0.1,3.87]: box(parent,Vector3(x,y,0),Vector3(0.1,0.18,14),white,false,"wood")
	for z in [-6.8,6.8]:
		for y in [0.1,3.87]: box(parent,Vector3(0,y,z),Vector3(16,0.18,0.1),white,false,"wood")
	# Windows have deep frames, radiator fins, curtains and a sill.
	for x in [-5.5,5.5]:
		var glass=box(parent,Vector3(x,2.55,-6.8),Vector3(2.7,1.75,0.04),Color("abc5c0"),false)
		var gm: StandardMaterial3D=glass.get_child(0).material_override
		gm.emission_enabled=true; gm.emission=Color("afc7cb"); gm.emission_energy_multiplier=0.35
		for off in [-1.42,0,1.42]: box(parent,Vector3(x+off,2.55,-6.63),Vector3(0.09,1.92,0.17),white,false,"wood")
		for y in [1.59,2.5,3.51]: box(parent,Vector3(x,y,-6.63),Vector3(2.95,0.085,0.17),white,false,"wood")
		box(parent,Vector3(x,1.5,-6.45),Vector3(3.1,0.12,0.5),white,false,"wood")
		for i in 13: box(parent,Vector3(x-1.1+i*0.18,0.72,-6.54),Vector3(0.12,0.95,0.2),Color("d2cec1"),false,"metal",0.04)
		cylinder(parent,Vector3(x,3.65,-6.35),0.035,3.5,Color("76634d"),Vector3(0,0,PI/2))
		for side in [-1,1]:
			for fold in 6: box(parent,Vector3(x+side*(1.1+fold*0.1),2.55,-6.27+sin(fold*2)*0.045),Vector3(0.13,2.1,0.09),Color("c8b394"),false,"fabric",0.04)
	if level!=1:
		# Sofa: individual cushions, seams, curved arms, pillows and feet.
		for x in [4.0,6.2]:
			for z in [2.9,3.9]: cylinder(parent,Vector3(x,0.18,z),0.075,0.35,Color("5b4437"),Vector3.ZERO,"wood")
		box(parent,Vector3(5.1,0.5,3.5),Vector3(2.9,0.5,1.35),Color("a66e46"),true,"fabric",0.15)
		for x in [4.38,5.1,5.82]:
			box(parent,Vector3(x,0.85,3.35),Vector3(0.69,0.25,1.1),Color("be885c"),false,"fabric",0.1)
			var back=box(parent,Vector3(x,1.3,4.02),Vector3(0.7,0.9,0.27),Color("b57e52"),false,"fabric",0.12); back.rotation.x=-0.12
		for x in [3.55,6.65]: box(parent,Vector3(x,0.95,3.5),Vector3(0.28,0.8,1.4),Color("b57e52"),true,"fabric",0.13)
		var pillow=box(parent,Vector3(4.15,1.25,3.7),Vector3(0.5,0.5,0.19),Color("597e79"),false,"fabric",0.085); pillow.rotation.z=0.25
		box(parent,Vector3(4.5,0.055,1.6),Vector3(4.2,0.025,2.7),Color("68766b"),false,"fabric",0.01)
		for i in 9: box(parent,Vector3(4.5,0.071,0.5+i*0.27),Vector3(3.8,0.006,0.035),Color("bba989"),false,"fabric",0.002)
	else:
		kitchen(parent)
	# Workbench, pegboard, tools and paint equipment.
	box(parent,Vector3(-5,0.88,3),Vector3(3.1,0.15,1.15),Color("ac8b60"),true,"wood")
	for x in [-6.3,-3.7]:
		for z in [2.6,3.4]: box(parent,Vector3(x,0.44,z),Vector3(0.12,0.88,0.12),teal,true,"metal")
	box(parent,Vector3(-5,0.32,3),Vector3(2.65,0.075,0.85),Color("977e59"),false,"wood")
	for i in 4:
		var handle=cylinder(parent,Vector3(-5.8+i*0.32,1.005,3.2),0.03,0.33,Color("b77141"),Vector3(PI/2,0,0),"wood")
		box(parent,handle.position+Vector3(0,0,-0.2),Vector3(0.12,0.035,0.16),Color("879394"),false,"metal")
	# Detailed exposed plumbing and tile splashback.
	box(parent,Vector3(-5,1.2,-6.75),Vector3(3.4,2.3,0.05),Color("c1c9b8"),false,"tile")
	var spots={"valve":Vector3(-6,1.2,-5),"pipe":Vector3(-4,1,-5),"paint":Vector3(1,1.6,-6.65),"mount":Vector3(7.57,1.8,-3.8)}
	cylinder(parent,Vector3(-5,0.9,-5),0.07,3.2,Color("a97e51"),Vector3(0,0,PI/2))
	cylinder(parent,Vector3(-6,0.5,-5),0.07,1.0,Color("a97e51"))
	for x in [-6.4,-5.1,-4.2,-3.6]: cylinder(parent,Vector3(x,0.9,-5),0.115,0.13,Color("86969a"),Vector3(0,0,PI/2))
	var valve=ring(parent,spots.valve,0.25,Color("b34f35"))
	for angle in [0,PI/3,PI*2/3]:
		var spoke=box(parent,spots.valve,Vector3(0.42,0.045,0.05),Color("b34f35"),false,"metal"); spoke.rotation.z=angle
	cylinder(parent,Vector3(-5,1.24,-5),0.15,0.08,Color("bdc5bc"),Vector3(PI/2,0,0))
	label(parent,"0   5   10",Vector3(-5,1.25,-4.946),17)
	# Patch plaster, exposed brick and masking tape around the paint zone.
	var paint=box(parent,spots.paint,Vector3(3.4,2,0.065),Color("a18d70"),false,"plaster")
	for row in 3:
		for col in 5: box(parent,Vector3(-0.4+col*0.58+(row%2)*0.15,0.5+row*0.2,-6.60),Vector3(0.55,0.18,0.04),Color("aa7258"),false,"plaster",0.008)
	for x in [-0.75,2.75]: box(parent,Vector3(x,1.6,-6.57),Vector3(0.07,2.2,0.008),Color("d7c99e"),false)
	box(parent,Vector3(1,0.65,-5.6),Vector3(0.65,0.12,0.4),Color("c1c9bd"),false,"metal")
	cylinder(parent,Vector3(1.4,0.78,-5.6),0.07,0.38,Color("c9d6c5"),Vector3(0,0,PI/2),"fabric")
	cylinder(parent,Vector3(1.4,0.35,-5.6),0.025,0.6,Color("c79343"),Vector3.ZERO,"wood")
	# Cabinet hanging rail and wall studs.
	box(parent,Vector3(7.82,1.8,-3.8),Vector3(0.07,0.09,1.4),Color("919c96"),false,"metal")
	for z in [-4.35,-3.25]: cylinder(parent,Vector3(7.78,1.8,z),0.028,0.035,Color("3c4546"),Vector3(0,0,PI/2))
	# Open shelving and household clutter.
	for y in [0.55,1.15,1.75]: box(parent,Vector3(7.25,y,0),Vector3(0.85,0.09,2.4),Color("a48b63"),true,"wood")
	for z in [-1.05,1.05]: box(parent,Vector3(7.5,1.1,z),Vector3(0.1,2.3,0.1),teal,true,"metal")
	for i in 7: box(parent,Vector3(7.1,1.45,-0.9+i*0.21),Vector3(0.4,0.5+0.06*sin(i),0.16),Color("a69d79") if i%2 else teal,false,"fabric")
	for x in [-7,7]:
		cylinder(parent,Vector3(x,0.25,5.5),0.25,0.48,Color("ad7960"),Vector3.ZERO,"plaster")
		for i in 9:
			var leaf=sphere(parent,Vector3(x+sin(i*2)*0.18,0.7+i*0.06,5.5+cos(i*2)*0.18),Vector3(0.12,0.55,0.14),Color("587150")); leaf.rotation.z=sin(i)*0.65
	# Small household details give the apartment a lived-in scale.
	box(parent,Vector3(4.7,0.52,1.4),Vector3(1.35,0.11,0.8),Color("79664e"),true,"wood",0.06)
	for x in [4.15,5.25]:
		for z in [1.12,1.68]: cylinder(parent,Vector3(x,0.28,z),0.035,0.48,Color("394547"))
	box(parent,Vector3(4.5,0.61,1.35),Vector3(0.35,0.06,0.48),Color("8c5140"),false,"fabric")
	cylinder(parent,Vector3(5.05,0.68,1.4),0.07,0.18,Color("dad7c7"),Vector3.ZERO,"plaster")
	# Symmetric A-frame ladder: horizontal treads follow the front rails.
	var ladder=Node3D.new(); parent.add_child(ladder); ladder.position=Vector3(-1.8,0,0.2)
	for x in [-0.37,0.37]:
		for side in [-1,1]:
			var rail=box(ladder,Vector3(x,0.9,side*0.43),Vector3(0.09,1.84,0.09),Color("788b8b"),true,"metal")
			rail.rotation.x=-side*0.24
			box(ladder,Vector3(x,0.055,side*0.64),Vector3(0.14,0.11,0.18),Color("374648"),true,"fabric")
	for y in [0.30,0.59,0.88,1.17,1.46]:
		var z=-0.43+(y-0.9)*tan(0.24)
		box(ladder,Vector3(0,y,z),Vector3(0.86,0.07,0.27),Color("b5c0b8"),true,"metal")
	box(ladder,Vector3(0,1.80,0),Vector3(0.92,0.09,0.52),Color("c9b365"),true,"metal")
	for x in [-0.37,0.37]: box(ladder,Vector3(x,0.95,0),Vector3(0.055,0.07,0.83),Color("818f8c"),false,"metal")
	box(parent,Vector3(1,0.057,-4.5),Vector3(3.9,0.016,2.1),Color("c6bba2"),false,"fabric",0.003)
	for x in [-1,3]: box(parent,Vector3(x,0.07,-4.5),Vector3(0.04,0.01,2.1),Color("a8956b"),false)
	# Entry door, trim, handle and electrical wall fittings.
	box(parent,Vector3(-4,1.2,6.82),Vector3(1.2,2.4,0.07),Color("826d53"),false,"wood")
	for x in [-4.7,-3.3]: box(parent,Vector3(x,1.3,6.7),Vector3(0.12,2.6,0.14),white,false,"wood")
	box(parent,Vector3(-4,2.6,6.7),Vector3(1.5,0.13,0.14),white,false,"wood")
	cylinder(parent,Vector3(-3.58,1.08,6.62),0.025,0.20,Color("b9b49d"),Vector3(0,0,PI/2))
	for x in [-7.3,3.3]:
		box(parent,Vector3(x,0.38,-6.77),Vector3(0.17,0.14,0.04),white,false)
		for dx in [-0.035,0.035]: cylinder(parent,Vector3(x+dx,0.38,-6.74),0.015,0.01,Color("475458"),Vector3(PI/2,0,0))
	# A small round clock above the paint patch.
	cylinder(parent,Vector3(1,3.3,-6.72),0.21,0.06,Color("dad9c6"),Vector3(PI/2,0,0))
	box(parent,Vector3(1,3.36,-6.68),Vector3(0.012,0.13,0.012),Color("3c5455"),false)
	var hand=box(parent,Vector3(1.045,3.28,-6.68),Vector3(0.13,0.012,0.012),Color("3c5455"),false); hand.rotation.z=-0.4
	var water=cylinder(parent,Vector3(-4,0.06,-4.8),0.15,0.015,Color("5c929a"),Vector3.ZERO,"metal")
	var env=WorldEnvironment.new(); var e=Environment.new()
	e.background_mode=Environment.BG_COLOR; e.background_color=Color("b5c8ce")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color("dae3df"); e.ambient_light_energy=0.65
	env.environment=e; parent.add_child(env)
	var lights=[]
	for loc in [Vector3(-4,3.45,-2),Vector3(4,3.45,1)]:
		var light=OmniLight3D.new(); parent.add_child(light); light.position=loc
		light.light_color=Color("ffe9cf"); light.light_energy=1.3; light.omni_range=12; light.shadow_enabled=true
		lights.append(light)
		cylinder(parent,loc+Vector3(0,0.4,0),0.38,0.10,Color("ded7bf"))
	var extra=annex(parent,level)
	spots.merge(extra)
	spots.chandelier=ladder.position+Vector3.UP
	var chandelier=Node3D.new(); parent.add_child(chandelier); chandelier.position=ladder.position+Vector3(0,3.2,0)
	cylinder(chandelier,Vector3(0,0.2,0),0.045,0.65,Color("ae915d"))
	var bulbs=[]
	for i in 3:
		var at=Vector3(cos(i*TAU/3)*0.5,-0.25,sin(i*TAU/3)*0.5)
		var arm=box(chandelier,at*0.5,Vector3(0.5,0.055,0.055),Color("b79760"),false,"metal")
		arm.rotation.y=-i*TAU/3
		cylinder(chandelier,at,0.18,0.16,Color("bca985"))
		bulbs.append(sphere(chandelier,at-Vector3(0,0.15,0),Vector3(0.19,0.26,0.19),Color("fff0b8")))
	var lamp=OmniLight3D.new(); chandelier.add_child(lamp); lamp.position.y=-0.6; lamp.omni_range=7; lamp.light_energy=0

	photo_frame(parent,level)
	if level==2:
		for z in [-5,-3,-1]: cylinder(parent,Vector3(7.1,0.5,z),0.37,0.9,Color("9a7751"),Vector3.ZERO,"wood")
		for i in 5: cylinder(parent,Vector3(-6.7,0.2+i*0.13,4.8),0.11,1.5,Color("74583c"),Vector3(PI/2,0,0),"wood")
	var dust=CPUParticles3D.new(); dust.amount=36; dust.lifetime=10; dust.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX; dust.emission_box_extents=Vector3(6,1.5,5)
	dust.gravity=Vector3(0,0.01,0); dust.initial_velocity_min=0.015; dust.initial_velocity_max=0.035
	dust.scale_amount_min=0.015; dust.scale_amount_max=0.025
	var speck=SphereMesh.new(); speck.radius=0.5; speck.height=1; dust.mesh=speck
	dust.color=Color(0.8,0.77,0.6,0.2); dust.emitting=false; parent.add_child(dust); dust.position.y=2
	return {"ladder":ladder,"bulbs":bulbs,"lamp":lamp,"spots":spots,"paint":paint,"water":water,"lights":lights,"environment":e,"dust":dust,"valve":valve}

static func kitchen(parent: Node3D) -> void:
	for z in [2.5,3.6,4.7]:
		box(parent,Vector3(7.25,0.5,z),Vector3(1.1,1,1.05),Color("a8b7a0"),true,"wood")
		box(parent,Vector3(6.68,0.48,z),Vector3(0.055,0.89,0.94),Color("658781"),false,"wood")
		box(parent,Vector3(6.62,0.70,z),Vector3(0.06,0.04,0.3),Color("d3c9a5"),false,"metal")
	box(parent,Vector3(7.2,1.08,3.6),Vector3(1.2,0.12,3.5),Color("d9d3b9"),true,"tile")
	for z in [2.25,2.75]:
		for x in [6.95,7.45]: cylinder(parent,Vector3(x,1.16,z),0.14,0.018,Color("344448"))
	cylinder(parent,Vector3(7.2,1.35,2.5),0.20,0.32,Color("8d9894"))
	box(parent,Vector3(7.2,1.25,5.85),Vector3(1.1,2.5,1.1),Color("dadbd0"),true,"metal",0.08)
	box(parent,Vector3(6.62,1.1,5.8),Vector3(0.07,0.5,0.07),Color("8b9898"),false,"metal")
	box(parent,Vector3(4.5,0.9,2.6),Vector3(1.8,0.12,1.4),Color("bba17a"),true,"wood")
	for x in [3.8,5.2]:
		for z in [2.1,3.1]: cylinder(parent,Vector3(x,0.43,z),0.06,0.85,Color("635443"),Vector3.ZERO,"wood")
	for x in [3,6]:
		box(parent,Vector3(x,0.5,2.6),Vector3(0.55,0.09,0.55),Color("789184"),true,"wood")
		box(parent,Vector3(x,0.98,2.9),Vector3(0.55,0.9,0.08),Color("789184"),true,"wood")
		for z in [2.38,2.82]:
			for dx in [-0.22,0.22]: cylinder(parent,Vector3(x+dx,0.25,z),0.025,0.5,Color("6a7770"))

static func annex(parent: Node3D,level: int) -> Dictionary:
	var wall=[Color("c9b99d"),Color("afbeb3"),Color("a18c6b")][level]
	box(parent,Vector3(-10,-0.2,2),Vector3(4,0.4,10),Color("b3a387"),true,"tile" if level==1 else "wood")
	box(parent,Vector3(-12,2,2),Vector3(0.25,4,10),wall)
	for z in [-3,7]: box(parent,Vector3(-10,2,z),Vector3(4,4,0.25),wall)
	box(parent,Vector3(-10,4.1,2),Vector3(4,0.2,10),Color("d4cbb7"))
	for z in [0,4]: box(parent,Vector3(-7.84,1.35,z),Vector3(0.18,2.7,0.13),Color("dbd5c2"),false,"wood")
	label(parent,["ЧАЙНАЯ / ПРИХОЖАЯ","КЛАДОВАЯ","МАСТЕРСКАЯ"][level],Vector3(-7.65,2.9,2),26).rotation.y=PI/2
	box(parent,Vector3(-10,0.8,3),Vector3(2,0.13,0.9),Color("ac9572"),true,"wood")
	for x in [-10.8,-9.2]: cylinder(parent,Vector3(x,0.4,3),0.06,0.8,Color("6c5a46"),Vector3.ZERO,"wood")
	cylinder(parent,Vector3(-10.5,1.08,3),0.2,0.36,Color("cfb9a0"),Vector3.ZERO,"metal")
	for x in [-10,-9.6]: cylinder(parent,Vector3(x,0.98,3),0.08,0.19,Color("d5cdbc"),Vector3.ZERO,"plaster")
	box(parent,Vector3(-11.79,1.6,-1.5),Vector3(0.13,0.9,0.85),Color("788b87"),false,"metal")
	for i in 6: box(parent,Vector3(-11.70,1.85-int(i/3)*0.35,-1.75+(i%3)*0.25),Vector3(0.05,0.18,0.13),Color("e1ba67"),false,"metal")
	box(parent,Vector3(-10,0.1,5.7),Vector3(1.7,0.2,1.3),Color("593f36"),true,"metal")
	for x in [-10.8,-9.2]: box(parent,Vector3(x,0.6,5.7),Vector3(0.1,1.0,1.3),Color("935c4d"),true,"metal")
	for z in [5.1,6.3]: box(parent,Vector3(-10,0.6,z),Vector3(1.7,1.0,0.1),Color("935c4d"),true,"metal")
	# Open-topped receiving bin: broad rim, no closed visual lid.
	for x in [-10.85,-9.15]: box(parent,Vector3(x,1.13,5.7),Vector3(0.12,0.08,1.5),Color("d7b576"),false,"metal")
	label(parent,"МУСОР СЮДА ↓",Vector3(-10,1.6,5.7),30)
	var lamp=OmniLight3D.new(); parent.add_child(lamp); lamp.position=Vector3(-10,3.3,2); lamp.light_energy=1.1; lamp.omni_range=8
	if level==1:
		for y in [0.6,1.3,2.0]:
			box(parent,Vector3(-11.5,y,0.2),Vector3(0.8,0.09,2.2),Color("8f856d"),true,"wood")
			for z in [-0.5,0.2,0.8]: cylinder(parent,Vector3(-11.4,y+0.17,z),0.11,0.28,Color("9bb293"),Vector3.ZERO,"plaster")
	return {"electric":Vector3(-11.4,1.6,-1.5),"tea":Vector3(-10,1.0,3),"bin":Vector3(-10,0.9,5.7)}

static func photo_frame(parent: Node3D,level: int) -> void:
	var root=Node3D.new(); parent.add_child(root); root.position=Vector3(-7.79,2.25,-3.4); root.rotation.y=PI/2
	box(root,Vector3.ZERO,Vector3(2.95,2.0,0.10),Color("e3d4af"),false,"wood")
	for x in [-1.54,1.54]: box(root,Vector3(x,0,0.02),Vector3(0.13,2.15,0.15),Color("92754c"),false,"wood")
	for y in [-1.06,1.06]: box(root,Vector3(0,y,0.02),Vector3(3.2,0.13,0.15),Color("92754c"),false,"wood")
	var path="res://photos/level_%d.png" % (level+1)
	if FileAccess.file_exists(path):
		var image=Image.load_from_file(path)
		if not image.is_empty():
			image.generate_mipmaps()
			var quad=QuadMesh.new(); var aspect=float(image.get_width())/image.get_height()
			quad.size=Vector2(minf(2.85,1.9*aspect),minf(1.9,2.85/aspect))
			var node=MeshInstance3D.new(); node.mesh=quad; root.add_child(node); node.position.z=0.061
			var mat=StandardMaterial3D.new(); mat.albedo_texture=ImageTexture.create_from_image(image); mat.roughness=1; node.material_override=mat
			return
	label(root,"ВАШЕ ФОТО\nУРОВЕНЬ %d" % (level+1),Vector3(0,0,0.075),65)
