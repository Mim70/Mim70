extends RefCounted
# Shared, deterministic task state. Only the host advances or accepts actions.
static func create(kind: String, seed_value: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var s = {"kind":kind,"phase":0,"elapsed":0.0,"done":false,"errors":0,"message":"","turn":0.0,"score":0,"held":false}
	match kind:
		"valve":
			s.merge({"angle":0.0,"pressure":0.5,"target":0.48,"round":0,"flow":1.0})
		"pipe":
			var masks = []
			for i in 16:
				var mask = 3 if rng.randf()>0.4 else 5
				for j in rng.randi_range(0,3): mask = rotate_mask(mask)
				masks.append(mask)
			for i in [4,5,1,2,6,10,11]:
				masks[i] = 5 if i in [4,6,11] else 3
				for j in rng.randi_range(0,3): masks[i] = rotate_mask(masks[i])
			s.merge({"masks":masks,"torque":0.0,"round":0,"connected":[]})
		"paint":
			var cells = []
			for i in 40: cells.append(rng.randf_range(0.0,0.12))
			s.merge({"cells":cells,"ink":1.0,"brush":-1,"paint":false,"sand":false,"quality":0})
		"mount":
			s.merge({"tilt":rng.randf_range(0.35,0.6),"stable":0.0,"screws":[0.0,0.0,0.0,0.0],"selected":0,"torque":0.0})
	return s

static func rotate_mask(mask: int) -> int:
	return ((mask << 1) & 15) | (mask >> 3)

static func pipe_path(masks: Array) -> Array:
	var cell = 4
	var incoming = 8
	var visited = []
	for step in 17:
		if cell in visited or cell<0 or cell>=16: return []
		visited.append(cell)
		var mask = int(masks[cell])
		if not (mask & incoming): return []
		var outgoing = mask ^ incoming
		if cell == 11 and outgoing == 2: return visited
		var next_cell = cell
		match outgoing:
			1: next_cell -= 4; incoming = 4
			2:
				if cell%4 == 3: return []
				next_cell += 1; incoming = 8
			4: next_cell += 4; incoming = 1
			8:
				if cell%4 == 0: return []
				next_cell -= 1; incoming = 2
			_: return []
		cell = next_cell
	return []

static func action(s: Dictionary, command: String, value: float = 0.0) -> void:
	if s.done or not is_finite(value): return
	match command:
		"turn": s.turn = clampf(value,-1,1)
		"press": s.held = true
		"release":
			if s.kind == "pipe" and s.phase == 1 and s.held:
				if s.torque>=0.65 and s.torque<=0.88:
					s.round += 1
					s.message = "Муфта затянута"
					if s.round == 3: s.done = true
				else:
					s.errors += 1; s.message = "Неверный момент. Попробуй ещё раз"
				s.torque = 0.0
			if s.kind == "mount" and s.phase == 1 and s.held:
				if s.torque>=0.65 and s.torque<=0.88:
					s.screws[s.selected] = 1.0
					s.message = "Саморез закреплён"
					if s.screws.count(1.0) == 4: s.done = true
				else:
					s.errors += 1; s.message = "Сорван шлиц — повтори затяжку"
				s.torque = 0.0
			s.held = false
		"confirm":
			if s.kind == "valve":
				if absf(s.pressure-s.target)<0.13:
					s.round += 1; s.flow = 1.0-s.round/4.0
					s.target = [0.48,0.66,0.35,0.58][mini(s.round,3)]
					s.message = "Контур %d/4 перекрыт" % s.round
					if s.round==4: s.done=true
				else:
					s.errors+=1; s.message="Давление вне зелёной зоны"
			if s.kind == "pipe" and s.phase == 0:
				s.connected = pipe_path(s.masks)
				if not s.connected.is_empty(): s.phase=1; s.message="Маршрут собран. Затяни три муфты"
				else: s.errors+=1; s.message="Течь! Соедини вход слева с выходом справа"
			if s.kind == "paint":
				var good = 0
				for cell in s.cells:
					if cell>=0.65 and cell<=1.25: good+=1
				if good>=38: s.done=true
				else: s.message="Нужно 38/40 ровных участков, сейчас %d" % good
		"rotate":
			if s.kind=="pipe" and s.phase==0 and value>=0 and value<16:
				var i = int(value); s.masks[i]=rotate_mask(s.masks[i])
		"brush":
			if s.kind=="paint": s.brush=clampi(int(value),-1,39)
		"paint":
			if s.kind=="paint": s.paint=value>0
		"sand":
			if s.kind=="paint": s.sand=value>0
		"reload":
			if s.kind=="paint": s.ink=1.0; s.message="Валик снова в краске"
		"select":
			if s.kind=="mount" and not s.held: s.selected=clampi(int(value),0,3)

static func advance(s: Dictionary, dt: float) -> void:
	if s.done: return
	s.elapsed+=dt
	match s.kind:
		"valve":
			s.angle=clampf(s.angle+s.turn*dt*0.8,-1,1)
			s.pressure=clampf(0.5+s.angle*0.35+sin(s.elapsed*1.8)*0.09,0,1)
		"pipe":
			if s.phase==1 and s.held:
				s.torque=minf(1.0,s.torque+dt*0.42)
		"paint":
			if s.brush>=0:
				if s.paint and s.ink>0:
					s.cells[s.brush]=minf(1.7,s.cells[s.brush]+dt*1.7)
					s.ink=maxf(0,s.ink-dt*0.11)
				if s.sand: s.cells[s.brush]=maxf(0,s.cells[s.brush]-dt*0.9)
			s.quality=0
			for cell in s.cells:
				if cell>=0.65 and cell<=1.25: s.quality+=1
		"mount":
			if s.phase==0:
				s.tilt=clampf(s.tilt+s.turn*dt*0.45+sin(s.elapsed*2.5)*dt*0.04,-1,1)
				if absf(s.tilt)<0.07: s.stable+=dt
				else: s.stable=maxf(0,s.stable-dt*0.8)
				if s.stable>=2.5: s.phase=1; s.message="Уровень выставлен. Закрепи четыре самореза"
			elif s.held and s.screws[s.selected]<1:
				s.torque=minf(1.0,s.torque+dt*0.5)
