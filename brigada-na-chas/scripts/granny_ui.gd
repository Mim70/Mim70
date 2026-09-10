extends Control
signal closed
var game: Node
var title: Label
var speech: Label
var list: VBoxContainer
func setup(owner_game: Node) -> void:
	game=owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var panel=PanelContainer.new(); add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left=-390; panel.offset_right=390; panel.offset_top=-280; panel.offset_bottom=280
	var style=StyleBoxFlat.new(); style.bg_color=Color("142c32"); style.set_corner_radius_all(14)
	style.content_margin_left=28; style.content_margin_right=28; style.content_margin_top=24; style.content_margin_bottom=24
	panel.add_theme_stylebox_override("panel",style)
	var column=VBoxContainer.new(); column.add_theme_constant_override("separation",14); panel.add_child(column)
	title=Label.new(); title.add_theme_font_size_override("font_size",28); column.add_child(title)
	speech=Label.new(); speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; speech.custom_minimum_size=Vector2(700,120); speech.add_theme_font_size_override("font_size",19); column.add_child(speech)
	var scroll=ScrollContainer.new(); scroll.custom_minimum_size.y=205; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; column.add_child(scroll)
	list=VBoxContainer.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",6); scroll.add_child(list)
	var back=Button.new(); back.text="Понял, работаем!  /  Esc"; back.custom_minimum_size.y=42; back.pressed.connect(func(): closed.emit()); column.add_child(back)
	hide()
func open_dialog() -> void:
	var order=game.Orders.definition(game.level_index)
	title.text=order.granny
	speech.text=order.line+"\nЧто тебе объяснить?"
	for child in list.get_children(): child.queue_free()
	for kind in order.tasks:
		var b=Button.new(); b.custom_minimum_size.y=34
		b.text=("✓  " if game.completed(kind) else "→  ")+game.Orders.NAMES[kind]
		b.pressed.connect(func(): speech.text=game.Orders.advice(kind); game.tracked_kind=kind)
		list.add_child(b)
	show(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		closed.emit(); get_viewport().set_input_as_handled()
