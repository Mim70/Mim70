extends Control
signal action_sent(command: String,value: float)
signal cancelled
var state: Dictionary = {}
var clock = 0.0
var send_clock = 0.0
var last_cell = -1
var font: Font = ThemeDB.fallback_font
const GOLD = Color("e8bb72")
const MINT = Color("7cbda8")
const WHITE = Color("e0e4da")
const MUTED = Color("8fa5a6")
const RED = Color("da866e")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	hide()

func open(data: Dictionary) -> void:
	state=data.duplicate(true); show(); last_cell=-1
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	queue_redraw()

func _process(dt: float) -> void:
	if not visible or state.is_empty(): return
	clock+=dt; send_clock+=dt
	if send_clock>=0.05:
		send_clock=0
		var turn=float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
		action_sent.emit("turn",turn)
		if state.kind=="paint":
			var at=local_mouse()
			var cell=-1
			if Rect2(145,170,640,280).has_point(at): cell=int((at.y-170)/56)*8+int((at.x-145)/80)
			action_sent.emit("brush",float(cell))
			action_sent.emit("paint",float(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)))
			action_sent.emit("sand",float(Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)))
	queue_redraw()

func scale_factor() -> float:
	return minf(size.x/960.0,size.y/600.0)
func local_mouse() -> Vector2:
	return (get_local_mouse_position()-(size-Vector2(960,600)*scale_factor())/2)/scale_factor()

func _input(event: InputEvent) -> void:
	if not visible: return
	if state.kind=="chandelier":
		if event is InputEventKey and event.pressed:
			if event.physical_keycode in [KEY_1,KEY_2,KEY_3]: action_sent.emit("bulb",event.physical_keycode-KEY_1)
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP: action_sent.emit("screw",1)
			if event.button_index==MOUSE_BUTTON_LEFT:
				var at=local_mouse()
				var hit_id=-1
				for note in state.notes:
					var center=Vector2(145+note.lane*105,170+note.age/0.9*260)
					if not note.hit and center.distance_to(at)<38: hit_id=note.id; break
				action_sent.emit("hit",hit_id)
	if event is InputEventKey and not event.echo:
		if event.physical_keycode==KEY_ESCAPE and event.pressed:
			cancelled.emit(); get_viewport().set_input_as_handled(); return
		if event.physical_keycode==KEY_SPACE:
			if event.pressed:
				action_sent.emit("confirm",0); action_sent.emit("press",0)
			else: action_sent.emit("release",0)
			get_viewport().set_input_as_handled()
		if event.physical_keycode==KEY_R and event.pressed: action_sent.emit("reload",0)
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var at=local_mouse()
		if state.kind=="electric":
			if state.phase==0 and Rect2(270,190,420,220).has_point(at): action_sent.emit("flip",float(int((at.y-190)/110)*3+int((at.x-270)/140)))
			if state.phase==1 and Rect2(220,280,520,110).has_point(at): action_sent.emit("probe",float(int((at.x-220)/130)))
		if state.kind=="tea" and state.phase==0 and Rect2(200,260,560,130).has_point(at): action_sent.emit("ingredient",float(int((at.x-200)/140)))
		if state.kind=="pipe" and state.phase==0:
			if Rect2(310,160,320,320).has_point(at):
				action_sent.emit("rotate",float(int((at.y-160)/80)*4+int((at.x-310)/80)))
		if state.kind=="mount" and state.phase==1:
			for i in 4:
				if at.distance_to(screw_position(i))<28: action_sent.emit("select",float(i))
		get_viewport().set_input_as_handled()

func text(at: Vector2,value: String,color: Color=WHITE,font_size: int=20) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func bar(rect: Rect2,value: float,color: Color) -> void:
	draw_style_box(panel(Color("263d42")),rect)
	if value>0: draw_style_box(panel(color),Rect2(rect.position,Vector2(rect.size.x*clampf(value,0,1),rect.size.y)))
func panel(color: Color) -> StyleBoxFlat:
	var p=StyleBoxFlat.new(); p.bg_color=color; p.set_corner_radius_all(8); return p
func screw_position(i: int) -> Vector2:
	return [Vector2(260,225),Vector2(690,225),Vector2(260,405),Vector2(690,405)][i]

func _draw() -> void:
	if state.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.05,0.06,0.15 if state.kind=="chandelier" else 0.80))
	var scale=scale_factor()
	draw_set_transform((size-Vector2(960,600)*scale)/2,0,Vector2.ONE*scale)
	draw_style_box(panel(Color(0.078,0.157,0.184,0.83) if state.kind=="chandelier" else Color("14282f")),Rect2(15,12,930,570))
	var titles={"chandelier":"07 / ЛЮСТРА: ДЕРЖИСЬ И КРУТИ","valve":"01 / ПЕРЕКРЫТЬ ВОДУ","pipe":"02 / СОБРАТЬ ТРУБОПРОВОД","paint":"03 / ПОКРАСИТЬ СТЕНУ","mount":"04 / ЗАКРЕПИТЬ ШКАФ","electric":"05 / ПОЧИНИТЬ ЩИТОК","tea":"06 / ЧАЙ ДЛЯ ХОЗЯЙКИ"}
	text(Vector2(50,62),titles[state.kind],GOLD,27)
	text(Vector2(50,98),"КВАРТИРА 14   /   МАСТЕРСКАЯ",MUTED,14)
	text(Vector2(820,60),"ESC — выйти",MUTED,13)
	match state.kind:
		"chandelier": draw_chandelier()
		"valve": draw_valve()
		"pipe": draw_pipe()
		"paint": draw_paint()
		"mount": draw_mount()
		"electric": draw_electric()
		"tea": draw_tea()
	text(Vector2(50,534),str(state.get("message","")),GOLD,17)
	text(Vector2(50,560),"Ошибки: %d    •    Мир и остальные игроки продолжают работать" % state.errors,MUTED,14)
	draw_set_transform(Vector2.ZERO)

func draw_valve() -> void:
	text(Vector2(50,132),"A / D — повернуть вентиль. Пробел — зафиксировать давление в зелёной зоне.",WHITE,17)
	var center=Vector2(250,315)
	draw_circle(center,111,Color("293d43")); draw_arc(center,95,0,TAU,64,RED,14,true)
	for i in 6:
		var dir=Vector2.from_angle(state.angle*4+i*TAU/6)
		draw_line(center+dir*22,center+dir*91,RED,11,true)
	draw_circle(center,25,GOLD)
	text(Vector2(450,233),"ДАВЛЕНИЕ В КОНТУРЕ",MUTED,16)
	bar(Rect2(450,270,400,28),1,Color("34464a"))
	draw_rect(Rect2(450+(state.target-0.13)*400,270,104,28),Color("527e67"))
	var px=450+state.pressure*400
	draw_line(Vector2(px,260),Vector2(px,308),GOLD,4)
	text(Vector2(450,347),"%.1f bar" % (state.pressure*10),WHITE,32)
	text(Vector2(450,390),"Закрыто контуров: %d / 4" % state.round,MINT,21)
	bar(Rect2(450,418,400,12),1-state.flow,MINT)

func draw_torque() -> void:
	text(Vector2(150,213),"Удерживай ПРОБЕЛ, отпусти внутри зелёной зоны.",WHITE,23)
	text(Vector2(150,248),"Недотяжка даст течь. Перетяжка сорвёт резьбу.",MUTED,18)
	bar(Rect2(150,300,650,45),1,Color("324249"))
	draw_rect(Rect2(150+650*0.65,300,650*0.23,45),Color("507e64"))
	var px=150+650*state.torque
	draw_line(Vector2(px,287),Vector2(px,360),GOLD,5)
	text(Vector2(150,415),"Момент: %d Н·м" % int(state.torque*50),GOLD,30)
	text(Vector2(480,415),"Этап 2/2 · Муфты: %d / 3" % state.round,MINT,24)

func draw_pipe() -> void:
	if state.phase==1: draw_torque(); return
	text(Vector2(50,132),"Соедини вход с выходом. Правильный маршрут засчитается автоматически.",WHITE,17)
	text(Vector2(170,288),"ВХОД →",MINT,22); text(Vector2(650,368),"→ ВЫХОД",GOLD,22)
	for i in 16:
		var rect=Rect2(310+(i%4)*80,160+int(i/4)*80,76,76)
		draw_style_box(panel(Color("2b4348")),rect)
		var c=rect.get_center(); var mask=int(state.masks[i])
		var dirs=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
		for d in 4:
			if mask&(1<<d):
				draw_line(c,c+dirs[d]*40,Color("122b32"),20,true)
				draw_line(c,c+dirs[d]*40,Color("96b3ad"),12,true)
		draw_circle(c,8,Color("b5c7ba"))

func draw_paint() -> void:
	text(Vector2(50,132),"ЛКМ — валик · ПКМ — снять лишнее · R — набрать краску · Пробел — сдать",WHITE,17)
	for i in 40:
		var amount=float(state.cells[i]); var rect=Rect2(145+(i%8)*80,170+int(i/8)*56,78,54)
		var color=Color("87745b").lerp(MINT,clampf(amount,0,1))
		if amount>1.25: color=RED
		draw_style_box(panel(color),rect)
		if amount>=0.65 and amount<=1.25: text(rect.position+Vector2(28,36),"✓",Color("284b44"),24)
		if amount>1.25:
			for n in 3: draw_line(rect.position+Vector2(15+n*19,8),rect.position+Vector2(15+n*19,40),Color("8e4d3b"),4,true)
	bar(Rect2(145,467,300,13),state.ink,GOLD)
	text(Vector2(460,482),"Ровное покрытие: %d / 40 (нужно 38)" % state.quality,WHITE,17)

func draw_mount() -> void:
	if state.phase==0:
		text(Vector2(50,132),"A / D — наклонить шкаф. Удержи пузырёк в центре 2,5 секунды.",WHITE,18)
		draw_set_transform((size-Vector2(960,600)*scale_factor())/2+Vector2(480,325)*scale_factor(),state.tilt*0.2,Vector2.ONE*scale_factor())
		draw_style_box(panel(Color("638577")),Rect2(-230,-110,460,220))
		draw_line(Vector2(0,-95),Vector2(0,95),Color("263c3c"),3)
		draw_style_box(panel(GOLD),Rect2(-170,-10,340,35))
		draw_style_box(panel(Color("354b44")),Rect2(-65,-5,130,25))
		draw_circle(Vector2(clampf(state.tilt*130,-55,55),7),9,MINT)
		for x in [-14,14]: draw_line(Vector2(x,-5),Vector2(x,20),WHITE,2)
		draw_set_transform((size-Vector2(960,600)*scale_factor())/2,0,Vector2.ONE*scale_factor())
		bar(Rect2(250,470,460,14),state.stable/2.5,MINT)
	else:
		text(Vector2(50,132),"Выбери саморез мышью. Удерживай пробел и отпускай в зелёной зоне.",WHITE,17)
		draw_style_box(panel(Color("587a70")),Rect2(220,185,510,260))
		for i in 4:
			var at=screw_position(i)
			draw_circle(at,26,GOLD if i==state.selected else Color("203f44"))
			draw_circle(at,19,MINT if state.screws[i]>=1 else Color("9aa6a1"))
			draw_line(at+Vector2(-10,0),at+Vector2(10,0),Color("314348"),4)
			draw_line(at+Vector2(0,-10),at+Vector2(0,10),Color("314348"),4)
		bar(Rect2(300,298,345,27),1,Color("284043"))
		draw_rect(Rect2(300+345*0.65,298,345*0.23,27),MINT)
		var px=300+345*state.torque
		draw_line(Vector2(px,288),Vector2(px,338),GOLD,4)
		text(Vector2(315,480),"Крепления: %d / 4" % state.screws.count(1.0),MINT,24)

func draw_electric() -> void:
	if state.phase==0:
		text(Vector2(70,139),"Каждый тумблер меняет себя и соседей. Включи все шесть ламп.",WHITE,18)
		for i in 6:
			var rect=Rect2(270+(i%3)*140,190+int(i/3)*110,130,100)
			draw_style_box(panel(Color("28434a")),rect)
			draw_circle(rect.get_center()+Vector2(0,-17),15,MINT if state.fuses[i] else RED)
			text(rect.position+Vector2(35,85),"ВКЛ" if state.fuses[i] else "ВЫКЛ",WHITE,18)
	else:
		text(Vector2(100,170),"Контрольные щупы: нажимай контакты в указанном порядке",WHITE,20)
		text(Vector2(260,220),"3 → 1 → 4 → 2",GOLD,32)
		for i in 4:
			var rect=Rect2(220+i*130,280,120,100)
			draw_style_box(panel(Color("3b5956")),rect)
			text(rect.position+Vector2(45,65),str(i+1),GOLD,38)
		text(Vector2(290,448),"Проверено: %d / 4" % state.round,MINT,24)

func draw_tea() -> void:
	var names=["ЗАВАРКА","САХАР","КИПЯТОК","ЛИМОН"]
	if state.phase==0:
		text(Vector2(75,153),"Бабушкин рецепт (порядок важен):",WHITE,22)
		var recipe=""
		for i in state.recipe: recipe+=names[i]+"  →  "
		text(Vector2(75,199),recipe.trim_suffix("  →  "),GOLD,21)
		for i in 4:
			var rect=Rect2(200+i*140,260,130,130)
			draw_style_box(panel(Color("3a524f")),rect)
			draw_circle(rect.get_center()+Vector2(0,-15),25,[Color("776044"),WHITE,Color("8bb8bb"),GOLD][i])
			text(rect.position+Vector2(12,110),names[i],WHITE,16)
		text(Vector2(280,450),"Добавлено: %d / 4" % state.round,MINT,24)
	else:
		text(Vector2(95,180),"Чай заваривается. Пробел — снять в зелёной зоне.",WHITE,24)
		bar(Rect2(150,290,650,42),1,Color("334b4d"))
		draw_rect(Rect2(150+650*0.60,290,650*0.23,42),MINT)
		var x=150+650*state.brew
		draw_line(Vector2(x,275),Vector2(x,348),GOLD,5)
		text(Vector2(115,425),"После заварки возьми чашку F и отнеси хозяйке.",GOLD,22)

func draw_chandelier() -> void:
	text(Vector2(50,127),"ЛКМ по кружкам НА ПОЛОСЕ • 1/2/3 — лампочка • колёсико вверх — вкручивать",WHITE,16)
	for i in 3:
		draw_line(Vector2(145+i*105,166),Vector2(145+i*105,474),Color("28464b"),3)
	draw_rect(Rect2(100,387,305,86),Color(0.3,0.65,0.5,0.18))
	draw_line(Vector2(100,430),Vector2(405,430),MINT,3)
	for note in state.notes:
		if not note.hit:
			var at=Vector2(145+note.lane*105,170+note.age/0.9*260)
			draw_circle(at,23,GOLD if absf(note.age-0.9)<0.15 else WHITE)
			draw_arc(at,30,0,TAU,32,MINT,2,true)
	for i in 3:
		var at=Vector2(535+i*125,265)
		draw_circle(at,34,GOLD if state.bulbs[i]>=1 else Color("63706a"))
		if state.selected==i: draw_arc(at,43,0,TAU,32,MINT,3,true)
		text(at+Vector2(-9,8),str(i+1),WHITE,25)
		bar(Rect2(at.x-43,323,86,12),state.bulbs[i],MINT)
	text(Vector2(490,380),"Крути колёсико, продолжая ловить кружки",WHITE,16)
	text(Vector2(490,413),"Попадания: %d / 18" % state.score,MINT,22)
	bar(Rect2(490,449,355,18),state.wobble,RED)
	text(Vector2(490,492),"Друг держит лестницу" if state.supported else "Раскачка — при заполнении упадёшь",GOLD,16)
	if state.climb<1: text(Vector2(110,260),"Поднимаемся…",GOLD,28)
