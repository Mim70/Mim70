extends CanvasLayer
var game: Node
var root: Control
var menu: PanelContainer
var status: Label
var hint: Label
var info: Label
var address: LineEdit
var mic: CheckBox
var tabs: TabContainer
var repair: Control
var cross: Label
const RepairUI=preload("res://scripts/repair_ui.gd")

func label(text: String, font_size: int=18) -> Label:
	var l=Label.new(); l.text=text; l.add_theme_font_size_override("font_size",font_size)
	return l
func style(color: Color,margin: int=16) -> StyleBoxFlat:
	var s=StyleBoxFlat.new(); s.bg_color=color; s.set_corner_radius_all(10)
	s.content_margin_left=margin; s.content_margin_right=margin; s.content_margin_top=margin; s.content_margin_bottom=margin
	return s
func action(parent: Control,text: String,callback: Callable) -> Button:
	var b=Button.new(); b.text=text; b.custom_minimum_size.y=42; b.pressed.connect(callback); parent.add_child(b)
	return b
func section(name_text: String) -> VBoxContainer:
	var v=VBoxContainer.new(); v.name=name_text; v.add_theme_constant_override("separation",12); tabs.add_child(v); return v
func toggle(parent: Control,text: String,key: String) -> void:
	var box=CheckBox.new(); box.text=text; box.button_pressed=game.settings[key]
	box.toggled.connect(func(on): game.settings[key]=on; game.apply_settings())
	parent.add_child(box)
func slider(parent: Control,text: String,key: String,minimum: float,maximum: float,step: float) -> void:
	var row=HBoxContainer.new(); parent.add_child(row)
	var name_label=label(text,16); name_label.custom_minimum_size.x=205; row.add_child(name_label)
	var control=HSlider.new(); control.min_value=minimum; control.max_value=maximum; control.step=step; control.value=game.settings[key]
	control.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(control)
	var value_label=label("%.2f" % control.value,16); value_label.custom_minimum_size.x=58; row.add_child(value_label)
	control.value_changed.connect(func(value): game.settings[key]=value; value_label.text="%.2f" % value; game.apply_settings())

func setup(owner_game: Node) -> void:
	game=owner_game
	root=Control.new(); add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme=Theme.new(); theme.default_font_size=17
	theme.set_stylebox("normal","Button",style(Color("2d494d"),10))
	theme.set_stylebox("hover","Button",style(Color("42665f"),10))
	theme.set_stylebox("pressed","Button",style(Color("496e64"),10))
	theme.set_stylebox("panel","TabContainer",style(Color("152c33"),20))
	theme.set_color("font_color","Label",Color("e3e8dd"))
	root.theme=theme
	var header=PanelContainer.new(); root.add_child(header); header.position=Vector2(24,20)
	header.add_theme_stylebox_override("panel",style(Color("14292ee8"),14)); header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status=label("БРИГАДА / КВАРТИРА 14",17); header.add_child(status)
	var bottom=PanelContainer.new(); root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left=-460; bottom.offset_right=460; bottom.offset_top=-82; bottom.offset_bottom=-18
	bottom.add_theme_stylebox_override("panel",style(Color("14292ee8"),10)); bottom.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint=label("",16); hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; bottom.add_child(hint)
	cross=label("·",28); root.add_child(cross); cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER); cross.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu=PanelContainer.new(); root.add_child(menu); menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left=-345; menu.offset_right=345; menu.offset_top=-308; menu.offset_bottom=308
	menu.add_theme_stylebox_override("panel",style(Color("10252cf5"),24))
	var column=VBoxContainer.new(); menu.add_child(column); column.add_theme_constant_override("separation",14)
	column.add_child(label("БРИГАДА НА ЧАС",30))
	column.add_child(label("КВАРТИРА 14  /  МАСТЕРСКАЯ  /  v0.2",13))
	tabs=TabContainer.new(); column.add_child(tabs); tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var room=section("Комната")
	info=label("1–4 игрока · прямое подключение по IP",16); info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; room.add_child(info)
	address=LineEdit.new(); address.text="127.0.0.1"; address.placeholder_text="IP компьютера-хоста"; room.add_child(address)
	action(room,"Создать комнату",game.host_game)
	action(room,"Подключиться",game.join_game)
	action(room,"Новый заказ (хост)",game.request_restart)
	room.add_child(label("WASD — ходьба · F — взять · E — работа\nV — голос · Esc — меню / отмена работы",16))
	var graphics=section("Изображение")
	toggle(graphics,"Полноэкранный режим","fullscreen")
	toggle(graphics,"Тени от источников света","shadows")
	var row=HBoxContainer.new(); graphics.add_child(row); row.add_child(label("Сглаживание MSAA",16))
	var aa=OptionButton.new(); for name_text in ["Выключено","2×","4×","8×"]: aa.add_item(name_text)
	aa.selected=game.settings.msaa; row.add_child(aa)
	aa.item_selected.connect(func(index): game.settings.msaa=index; game.apply_settings())
	slider(graphics,"Яркость помещения","brightness",0.35,1.2,0.05)
	slider(graphics,"Поле зрения","fov",65,100,1)
	toggle(graphics,"FX: пылинки в помещении","effects")
	toggle(graphics,"Подробный HUD заданий","details")
	graphics.add_child(label("FX выключены по умолчанию. Блюма, размытия\nи тряски камеры нет. Настройки сохраняются.",14))
	var sound=section("Звук и мышь")
	slider(sound,"Общая громкость","volume",0,1,0.05)
	slider(sound,"Чувствительность мыши","sensitivity",0.3,2.5,0.1)
	mic=CheckBox.new(); mic.text="Включить микрофон (удерживать V)"; sound.add_child(mic)
	mic.toggled.connect(func(on):
		if on: game.voice.start_input())
	sound.add_child(label("Передача только по V в игре. В меню микрофон\nне передаёт звук. Устройство — системное.",15))
	var footer=HBoxContainer.new(); column.add_child(footer)
	var resume=action(footer,"Продолжить",game.resume_game); resume.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	action(footer,"Выйти",func(): get_tree().quit())
	repair=RepairUI.new(); root.add_child(repair); repair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	repair.action_sent.connect(game.local_repair_action)
	repair.cancelled.connect(game.cancel_local_repair)

func _process(_dt: float) -> void:
	if not is_instance_valid(menu) or not is_instance_valid(repair): return
	var playing=game.active and not menu.visible and not repair.visible
	status.get_parent().visible=playing
	hint.get_parent().visible=playing
	cross.visible=playing
