extends RefCounted

static func material(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.82
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collision: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	parent.add_child(root)
	root.position = pos
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	root.add_child(mesh)
	if collision:
		var hit = CollisionShape3D.new()
		var collider = BoxShape3D.new()
		collider.size = size
		hit.shape = collider
		root.add_child(hit)
	return root

static func label(parent: Node3D, text: String, pos: Vector3, size: int = 40) -> Label3D:
	var l = Label3D.new()
	parent.add_child(l)
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 8
	l.no_depth_test = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return l

static func build(parent: Node3D) -> Dictionary:
	var cream = Color("d8ccb0")
	var teal = Color("427a7a")
	box(parent, Vector3(0,-0.2,0),Vector3(16,0.4,14),Color("b59870"))
	for x in range(-8,8):
		box(parent,Vector3(x+0.5,0.005,0),Vector3(0.025,0.012,14),Color("806b52"),false)
	box(parent,Vector3(0,2,-7),Vector3(16,4,0.3),cream)
	box(parent,Vector3(-8,2,0),Vector3(0.3,4,14),cream)
	box(parent,Vector3(8,2,0),Vector3(0.3,4,14),cream)
	box(parent,Vector3(0,4.1,0),Vector3(16,0.2,14),Color("d7d1c4"))
	box(parent,Vector3(0,2,7),Vector3(16,4,0.3),teal)
	for x in [-7.8,7.8]:
		box(parent,Vector3(x,0.2,0),Vector3(0.07,0.4,14),Color("f2e5cf"),false)
	box(parent,Vector3(0,0.2,-6.8),Vector3(16,0.4,0.07),Color("f2e5cf"),false)
	# Warm afternoon light, framed windows and workbench.
	for x in [-5.5,5.5]:
		box(parent,Vector3(x,2.4,-6.79),Vector3(2.8,1.8,0.05),Color("e8f1d9"),false)
		for offset in [-1.45,0,1.45]:
			box(parent,Vector3(x+offset,2.4,-6.7),Vector3(0.09,1.95,0.08),teal,false)
		for y in [1.43,3.37]:
			box(parent,Vector3(x,y,-6.7),Vector3(3,0.09,0.08),teal,false)
	box(parent,Vector3(-5,0.85,3),Vector3(3,0.18,1.1),Color("725740"))
	for x in [-6.2,-3.8]:
		box(parent,Vector3(x,0.4,3),Vector3(0.15,0.8,0.85),teal)
	box(parent,Vector3(5,0.55,3.5),Vector3(2.8,1.1,1.2),Color("d38d51"))
	box(parent,Vector3(5,1.3,4),Vector3(2.8,0.7,0.25),Color("ba7443"))
	label(parent,"БРИГАДА НА ЧАС\nКВАРТИРА № 14",Vector3(0,3.1,-6.7),48)
	var spots = {"valve": Vector3(-6,1.2,-5), "pipe":Vector3(-4,1,-5), "paint":Vector3(1,1.6,-6.65), "mount":Vector3(6,1.7,-4.5)}
	box(parent,Vector3(-5,0.9,-5),Vector3(3,0.16,0.16),Color("697e83"))
	box(parent,Vector3(-6,0.5,-5),Vector3(0.14,1,0.14),Color("697e83"))
	box(parent,spots.valve,Vector3(0.35,0.35,0.2),Color("d56248"),false)
	label(parent,"01 / ВЕНТИЛЬ",spots.valve+Vector3(0,0.6,0),26)
	label(parent,"ТРУБА",spots.pipe+Vector3(0,0.6,0),26)
	var paint = box(parent,spots.paint,Vector3(3.4,2,0.06),Color("977a65"),false)
	label(parent,"02 / ПОКРАСКА",Vector3(1,2.95,-6.5),28)
	box(parent,spots.mount,Vector3(1.9,1.3,0.05),Color("9fb8ae"),false)
	label(parent,"03 / ПОВЕСИТЬ ШКАФ",Vector3(5.7,2.8,-4.5),26)
	var water = box(parent,Vector3(-4,0.02,-4.8),Vector3(0.3,0.025,0.3),Color("589da8"),false)
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("a7c1cb")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("f0dcc0")
	e.ambient_light_energy = 0.35
	env.environment = e
	parent.add_child(env)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-28,0)
	light.light_color = Color("ffe3b2")
	light.light_energy = 0.65
	light.shadow_enabled = true
	parent.add_child(light)
	for location in [Vector3(-4,3.5,0),Vector3(4,3.5,0)]:
		var fill = OmniLight3D.new()
		fill.position = location
		fill.light_color = Color("ffe5c4")
		fill.light_energy = 1.2
		fill.omni_range = 11
		parent.add_child(fill)
		box(parent,location+Vector3(0,0.3,0),Vector3(1.3,0.07,0.6),Color("eee8da"),false)
	return {"spots":spots,"paint":paint,"water":water}
