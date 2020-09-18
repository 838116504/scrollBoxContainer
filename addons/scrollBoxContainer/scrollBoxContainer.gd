tool
extends Container

const EasyButton = preload("res://addons/easyButton/easyButton.gd")
const DEFAULT_ITEM_SEPARATION = 1
const DEFAULT_DRAG_ENABLE = true
const DEFAULT_MID_BTN_SCROLL_ENABLE = true
const DEFAULT_SCROLL_STEP = 1.0
const DEFAULT_CURSOR_DRAG_H = preload("hDragCursor.png")
const DEFAULT_CURSOR_DRAG_V = preload("vDragCursor.png")
const BOOL_THEME_NAMES = { "drag_enable":DEFAULT_DRAG_ENABLE, "mid_button_scroll_enable":DEFAULT_MID_BTN_SCROLL_ENABLE }
const ICON_THEME_NAMES = { "cursor_drag_h":Object(), "cursor_drag_v":Object() }
const STYLE_THEME_NAMES = { "bottom_button_normal":Object(), "left_button_normal":Object(), "right_button_normal":Object(), "top_button_normal":Object() }
const CLASS_NAME = "ScrollBoxContainer"

var scrollContainer := ScrollContainer.new()
var boxContainer := HBoxContainer.new()
var btnsBC := HBoxContainer.new()
var firstBtn := EasyButton.new()
var secondBtn := EasyButton.new()
var pressedPos = null		# middle button pressed position
var dragValue := 0.0
export var vertical := false setget set_vertical, get_vertical
var dragEnable := DEFAULT_DRAG_ENABLE
var midBtnScrollEnable := DEFAULT_MID_BTN_SCROLL_ENABLE
var hDragCursor := DEFAULT_CURSOR_DRAG_H
var vDragCursor := DEFAULT_CURSOR_DRAG_V
enum { MOUSE_OUT = 0, MOUSE_IN_FIRST_BTN, MOUSE_IN_SECOND_BTN }
var mouseIn := MOUSE_OUT
var arrowBtnPressed = null

func get_class() -> String:
	return CLASS_NAME

func get_parent_class():
	return Container

static func get_parent_class_static():
	return Container

func _init():
	boxContainer.size_flags_vertical = SIZE_EXPAND_FILL
	
	var emptyStyle = StyleBoxEmpty.new()
	scrollContainer.add_child(boxContainer)
	scrollContainer.add_stylebox_override("bg", emptyStyle)
	var scrollbars = [scrollContainer.get_h_scrollbar(), scrollContainer.get_v_scrollbar()]
	for i in scrollbars:
		i.add_stylebox_override("grabber", emptyStyle)
		i.add_stylebox_override("grabber_highlight", emptyStyle)
		i.add_stylebox_override("grabber_pressed", emptyStyle)
		i.add_stylebox_override("scroll", emptyStyle)
		i.add_stylebox_override("scroll_focus", emptyStyle)
		i.add_icon_override("decrement", Object())
		i.add_icon_override("decrement_hightlight", Object())
		i.add_icon_override("increment", Object())
		i.add_icon_override("increment_hightlight", Object())
	scrollContainer.scroll_vertical_enabled = false
	scrollContainer.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	scrollContainer.get_v_scrollbar().custom_step = 1.0
	scrollContainer.get_h_scrollbar().custom_step = 1.0

	btnsBC.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	btnsBC.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var emptyFont = DynamicFont.new()
	
	firstBtn.hide()
	firstBtn.add_font_override("font", emptyFont)
	firstBtn.add_stylebox_override("pressed", emptyStyle)
	firstBtn.add_stylebox_override("hover", emptyStyle)
	firstBtn.add_stylebox_override("focus", emptyStyle)
	firstBtn.add_stylebox_override("disabled", emptyStyle)

	secondBtn.hide()
	secondBtn.add_font_override("font", emptyFont)
	secondBtn.add_stylebox_override("pressed", emptyStyle)
	secondBtn.add_stylebox_override("hover", emptyStyle)
	secondBtn.add_stylebox_override("focus", emptyStyle)
	secondBtn.add_stylebox_override("disabled", emptyStyle)

	btnsBC.add_child(firstBtn)
	btnsBC.add_spacer(false)
	btnsBC.get_child(btnsBC.get_child_count() - 1).mouse_filter = MOUSE_FILTER_IGNORE
	btnsBC.add_child(secondBtn)

	.add_child(scrollContainer)
	.add_child(btnsBC)

	_update_button_style()
	_update_item_separation()
	firstBtn.connect("button_down", self, "_on_firstBtn_button_down")
	firstBtn.connect("button_up", self, "_on_firstBtn_button_up")
	secondBtn.connect("button_down", self, "_on_secondBtn_button_down")
	secondBtn.connect("button_up", self, "_on_secondBtn_button_up")

func _get_minimum_size():
	if boxContainer.rect_size.x > rect_size.x:
		var minimumSize = btnsBC.get_minimum_size()
		minimumSize.y = max(minimumSize.y, boxContainer.get_minimum_size().y)
		return minimumSize
	return Vector2(0.0, max(btnsBC.get_minimum_size().y, boxContainer.get_minimum_size().y))

func _ready():
	set_process(false)

func _notification(what):
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_THEME_CHANGED:
			dragEnable = ControlMethod.get_bool(self, "drag_enable") if ControlMethod.has_bool(self, "drag_enable") else DEFAULT_DRAG_ENABLE
			midBtnScrollEnable = ControlMethod.get_bool(self, "mid_button_scroll_enable") if ControlMethod.has_bool(self, "mid_button_scroll_enable") else DEFAULT_MID_BTN_SCROLL_ENABLE
			hDragCursor = get_icon("cursor_drag_h") if has_icon("cursor_drag_h") else DEFAULT_CURSOR_DRAG_H
			vDragCursor = get_icon("cursor_drag_v") if has_icon("cursor_drag_v") else DEFAULT_CURSOR_DRAG_V
			_update_button_style()
			_update_item_separation()
		NOTIFICATION_WM_FOCUS_OUT:
			_drag_end()
		NOTIFICATION_SORT_CHILDREN:
			for i in .get_children():
				if i == scrollContainer || i == btnsBC:
					continue
				
				.remove_child(i)
				boxContainer.add_child(i)
				minimum_size_changed()

func _input(p_event):
	if p_event is InputEventMouseButton:
		match p_event.button_index:
			BUTTON_MIDDLE:
				if p_event.pressed:
					if dragEnable && get_global_rect().has_point(p_event.position):
						pressedPos = p_event.position
						dragValue = 0.0
						if vertical:
							Input.set_custom_mouse_cursor(vDragCursor)
						else:
							Input.set_custom_mouse_cursor(hDragCursor)
						get_tree().set_input_as_handled()
				elif pressedPos:
					_drag_end()
					get_tree().set_input_as_handled()
			BUTTON_WHEEL_UP:
				if midBtnScrollEnable && get_global_rect().has_point(p_event.position):
					scroll(-get_scroll_step() * p_event.factor * 3.0)
					get_tree().set_input_as_handled()
			BUTTON_WHEEL_DOWN:
				if midBtnScrollEnable && get_global_rect().has_point(p_event.position):
					scroll(get_scroll_step() * p_event.factor * 3.0)
					get_tree().set_input_as_handled()
	elif p_event is InputEventMouseMotion:
		var arrowRect = btnsBC.get_global_rect()
		var firstRect = arrowRect
		var secondRect = arrowRect
		if vertical:
			firstRect.size.y = firstBtn.get_stylebox("normal").get_minimum_size().y
			secondRect.size.y = secondBtn.get_stylebox("normal").get_minimum_size().y
			secondRect.position.y += arrowRect.size.y - secondRect.size.y
		else:
			firstRect.size.x = firstBtn.get_stylebox("normal").get_minimum_size().x
			secondRect.size.x = secondBtn.get_stylebox("normal").get_minimum_size().x
			secondRect.position.x += arrowRect.size.x - secondRect.size.x
		if mouseIn == MOUSE_IN_FIRST_BTN:
			if not firstRect.has_point(p_event.position):
				mouseIn = MOUSE_OUT
				_on_firstArrowBtn_mouse_exited()
		elif mouseIn == MOUSE_IN_SECOND_BTN:
			if not secondRect.has_point(p_event.position):
				mouseIn = MOUSE_OUT
				_on_secondArrowBtn_mouse_exited()
		if mouseIn == MOUSE_OUT && (!vertical && boxContainer.rect_size.x > scrollContainer.rect_size.x) || (vertical && boxContainer.rect_size.y > scrollContainer.rect_size.y):
			if firstRect.has_point(p_event.position):
				var bar = _get_scroll_bar()
				if bar.value > bar.min_value:
					mouseIn = MOUSE_IN_FIRST_BTN
					_on_firstArrowBtn_mouse_entered()
			elif secondRect.has_point(p_event.position):
				var bar = _get_scroll_bar()
				if (!vertical && bar.value < bar.max_value - scrollContainer.rect_size.x) || (vertical && bar.value < bar.max_value - scrollContainer.rect_size.y):
					mouseIn = MOUSE_IN_SECOND_BTN
					_on_secondArrowBtn_mouse_entered()
		if pressedPos:
			var newDrag = p_event.position.x - pressedPos.x
			scroll(-dragValue + newDrag)
			dragValue = newDrag
			get_tree().set_input_as_handled()

func _process(p_delta):
	if arrowBtnPressed && arrowBtnPressed.get_global_rect().has_point(get_global_mouse_position()):
		scroll(scroll_front() if arrowBtnPressed == firstBtn else scroll_back())

func add_child(p_node, p_unique := false):
	boxContainer.add_child(p_node, p_unique)
	minimum_size_changed()

func get_child(p_id:int):
	if p_id >= get_child_count():
		return null
	return boxContainer.get_child(p_id)

func get_child_count() -> int:
	return boxContainer.get_child_count()

func get_children():
	return boxContainer.get_children()

func move_child(p_node, p_pos):
	boxContainer.move_child(p_node, p_pos)

func remove_child(p_node):
	if p_node.get_parent() == boxContainer:
		boxContainer.remove_child(p_node)
	elif p_node.get_parent() == self:
		.remove_child(p_node)

func _get_default_left_arrow_style():
	var ret = StyleBoxTexture.new()
	ret.texture = preload("leftScrollBtn.png")
	ret.margin_left = ret.texture.get_size().x
	ret.margin_right = 0
	ret.margin_top = ret.texture.get_size().y
	ret.margin_bottom = 0
	return ret

func _get_default_right_arrow_style():
	var ret = StyleBoxTexture.new()
	ret.texture = preload("rightScrollBtn.png")
	ret.margin_left = ret.texture.get_size().x
	ret.margin_right = 0
	ret.margin_top = ret.texture.get_size().y
	ret.margin_bottom = 0
	return ret


func _get_default_up_arrow_style():
	var ret = StyleBoxTexture.new()
	ret.texture = preload("upScrollBtn.png")
	ret.margin_left = ret.texture.get_size().x
	ret.margin_right = 0
	ret.margin_top = ret.texture.get_size().y
	ret.margin_bottom = 0
	return ret

func _get_default_down_arrow_style():
	var ret = StyleBoxTexture.new()
	ret.texture = preload("downScrollBtn.png")
	ret.margin_left = ret.texture.get_size().x
	ret.margin_right = 0
	ret.margin_top = ret.texture.get_size().y
	ret.margin_bottom = 0
	return ret

func _update_button_style():
	if vertical:
		firstBtn.add_stylebox_override("normal", get_stylebox("top_button_normal") if has_stylebox("top_button_normal") else _get_default_up_arrow_style())
		secondBtn.add_stylebox_override("normal", get_stylebox("bottom_button_normal") if has_stylebox("bottom_button_normal") else _get_default_down_arrow_style())
		ControlMethod.add_enum_override(firstBtn, "pressed_scale_pivot", firstBtn.PIVOT_TOP)
		ControlMethod.add_enum_override(secondBtn, "pressed_scale_pivot", secondBtn.PIVOT_BOTTOM)
	else:
		firstBtn.add_stylebox_override("normal", get_stylebox("left_button_normal") if has_stylebox("left_button_normal") else _get_default_left_arrow_style())
		secondBtn.add_stylebox_override("normal", get_stylebox("right_button_normal") if has_stylebox("right_button_normal") else _get_default_right_arrow_style())
		ControlMethod.add_enum_override(firstBtn, "pressed_scale_pivot", firstBtn.PIVOT_LEFT)
		ControlMethod.add_enum_override(secondBtn, "pressed_scale_pivot", secondBtn.PIVOT_RIGHT)

func _update_item_separation():
	boxContainer.add_constant_override("separation", get_constant("item_separation") if has_constant("item_separation") else DEFAULT_ITEM_SEPARATION)

func _drag_end():
	if not pressedPos:
		return
	Input.set_custom_mouse_cursor(null)
	pressedPos = null

func _on_firstArrowBtn_mouse_entered():
	firstBtn.show()

func _on_secondArrowBtn_mouse_entered():
	secondBtn.show()

func _on_firstArrowBtn_mouse_exited():
	firstBtn.hide()

func _on_secondArrowBtn_mouse_exited():
	secondBtn.hide()

func _on_firstBtn_button_down():
	scroll(-get_scroll_step())
	arrowBtnPressed = firstBtn
	set_process(true)

func _on_firstBtn_button_up():
	set_process(false)
	arrowBtnPressed = null

func _on_secondBtn_button_down():
	scroll(get_scroll_step())
	arrowBtnPressed = secondBtn
	set_process(true)

func _on_secondBtn_button_up():
	set_process(false)
	arrowBtnPressed = null

func scroll(p_value:int):
	set_scroll(get_scroll() + p_value)

func scroll_front():
	scroll(-get_scroll_step())

func scroll_back():
	scroll(get_scroll_step())

func get_item_container() -> BoxContainer:
	return boxContainer

func get_first_scroll_button() -> EasyButton:
	return firstBtn

func get_second_scroll_button() -> EasyButton:
	return secondBtn

func get_scroll() -> int:
	if vertical:
		return scrollContainer.scroll_vertical
	return scrollContainer.scroll_horizontal

func get_scroll_container() -> ScrollContainer:
	return scrollContainer

func get_scroll_step() -> float:
	return _get_scroll_bar().custom_step

func _get_scroll_bar() -> ScrollBar:
	if vertical:
		return scrollContainer.get_v_scrollbar()
	return scrollContainer.get_h_scrollbar()

func set_scroll(p_value:float):
	var scrollbar
	var length
	if vertical:
		scrollContainer.scroll_vertical = p_value
		scrollbar = scrollContainer.get_v_scrollbar()
		length = scrollContainer.rect_size.y
	else:
		scrollContainer.scroll_horizontal = p_value
		scrollbar = scrollContainer.get_h_scrollbar()
		length = scrollContainer.rect_size.x
	
	match mouseIn:
		MOUSE_IN_FIRST_BTN:
			if scrollbar.value <= scrollbar.min_value:
				mouseIn = MOUSE_OUT
				_on_firstArrowBtn_mouse_exited()
		MOUSE_IN_SECOND_BTN:
			if scrollbar.value >= scrollbar.max_value - length:
				mouseIn = MOUSE_OUT
				_on_secondArrowBtn_mouse_exited()

func set_scroll_step(p_value:float):
	if vertical:
		scrollContainer.get_v_scrollbar().custom_step = p_value
	else:
		scrollContainer.get_h_scrollbar().custom_step = p_value

func set_vertical(p_value:bool):
	if vertical == p_value:
		return
	
	vertical = p_value
	if vertical:
		scrollContainer.scroll_vertical_enabled = true
		scrollContainer.get_v_scrollbar().hide()
		scrollContainer.get_v_scrollbar().custom_step = scrollContainer.get_h_scrollbar().custom_step
		scrollContainer.scroll_horizontal_enabled = false
		var newBoxContainer = VBoxContainer.new()
		newBoxContainer.size_flags_horizontal = SIZE_FILL
		newBoxContainer.size_flags_vertical = SIZE_EXPAND_FILL
		for i in boxContainer.get_children():
			boxContainer.remvoe_child(i)
			newBoxContainer.add_child(i)
		scrollContainer.remove_child(boxContainer)
		boxContainer.queue_free()
		scrollContainer.add_child(newBoxContainer)
		boxContainer = newBoxContainer
		_update_item_separation()

		var newArrowBC = VBoxContainer.new()
		newArrowBC.alignment = BoxContainer.ALIGN_END
		newArrowBC.grow_vertical = Control.GROW_DIRECTION_BEGIN
		newArrowBC.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		btnsBC.remove_child(firstBtn)
		btnsBC.remove_child(secondBtn)
		newArrowBC.add_child(firstBtn)
		newArrowBC.add_spacer(false)
		newArrowBC.add_child(secondBtn)
		.remove_child(btnsBC)
		btnsBC.queue_free()
		btnsBC = newArrowBC
		.add_child(btnsBC)
		_update_button_style()
	else:
		scrollContainer.scroll_horizontal_enabled = true
		scrollContainer.get_h_scrollbar().hide()
		scrollContainer.get_h_scrollbar().custom_step = scrollContainer.get_v_scrollbar().custom_step
		scrollContainer.scroll_vertical_enabled = false
		var newBoxContainer = HBoxContainer.new()
		newBoxContainer.size_flags_horizontal = SIZE_EXPAND_FILL
		newBoxContainer.size_flags_vertical = SIZE_FILL
		for i in boxContainer.get_children():
			boxContainer.remvoe_child(i)
			newBoxContainer.add_child(i)
		scrollContainer.remove_child(boxContainer)
		boxContainer.queue_free()
		scrollContainer.add_child(newBoxContainer)
		boxContainer = newBoxContainer
		_update_item_separation()

		var newArrowBC = HBoxContainer.new()
		newArrowBC.alignment = BoxContainer.ALIGN_END
		newArrowBC.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		newArrowBC.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		btnsBC.remove_child(firstBtn)
		btnsBC.remove_child(secondBtn)
		newArrowBC.add_child(firstBtn)
		newArrowBC.add_spacer(false)
		newArrowBC.add_child(secondBtn)
		.remove_child(btnsBC)
		btnsBC.queue_free()
		btnsBC = newArrowBC
		.add_child(btnsBC)
		_update_button_style()

func get_vertical() -> bool:
	return vertical

func _set(p_property:String, p_value):
	var array = p_property.split("/", true, 1)
	if array.size() < 2 || array[0] != get_class():
		return false
	
	if BOOL_THEME_NAMES.has(array[1]):
		if ControlMethod.has_bool_override(self, array[1]) || p_value != null:
			ControlMethod.add_bool_override(self, array[1], p_value)
		else:
			ControlMethod.add_bool_override(self, array[1], BOOL_THEME_NAMES[array[1]])
	elif ICON_THEME_NAMES.has(array[1]):
		if has_icon_override(array[1]) || p_value != null:
			add_icon_override(array[1], p_value)
		else:
			add_icon_override(array[1], ICON_THEME_NAMES[array[1]])
	elif STYLE_THEME_NAMES.has(array[1]):
		if has_stylebox_override(array[1]) || p_value != null:
			add_stylebox_override(array[1], p_value)
		else:
			add_stylebox_override(array[1], STYLE_THEME_NAMES[array[1]])
	elif array[1] == "item_separation":
		if has_constant_override(array[1]) || p_value != null:
			add_constant_override(array[1], p_value)
		else:
			add_constant_override(array[1], DEFAULT_ITEM_SEPARATION)
	else:
		return false
	return true

func _get(p_property:String):
	var array = p_property.split("/", true, 1)
	if array.size() < 2 || array[0] != get_class():
		return null
	
	if BOOL_THEME_NAMES.has(array[1]):
		return ControlMethod.get_bool(self, array[1]) if ControlMethod.has_bool_override(self, array[1]) else BOOL_THEME_NAMES[array[1]]
	if ICON_THEME_NAMES.has(array[1]):
		return get_icon(array[1]) if has_icon_override(array[1]) else ICON_THEME_NAMES[array[1]]
	if STYLE_THEME_NAMES.has(array[1]):
		return get_stylebox(array[1]) if has_stylebox_override(array[1]) else STYLE_THEME_NAMES[array[1]]
	if array[1] == "item_separation":
		return get_constant(array[1]) if has_constant_override("item_separartion") else DEFAULT_ITEM_SEPARATION
	return null

func _get_property_list():
	var ret = []
	if has_constant_override("item_separation"):
		ret.append({ "name":get_class() + "/item_separation", "type":TYPE_INT, "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED })
	else:
		ret.append({ "name":get_class() + "/item_separation", "type":TYPE_INT, "usage":PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE })
	_property_list_add_bool(ret, "drag_enable")
	_property_list_add_bool(ret, "mid_button_scroll_enable")
	_property_list_add_style(ret, "left_button_normal")
	_property_list_add_style(ret, "right_button_normal")
	_property_list_add_style(ret, "top_button_normal")
	_property_list_add_style(ret, "bottom_button_normal")
	_property_list_add_icon(ret, "cursor_drag_h")
	_property_list_add_icon(ret, "cursor_drag_v")
	return ret


func _property_list_add_bool(p_list:Array, p_name:String):
	if ControlMethod.has_bool_override(self, p_name):
		p_list.append({ "name":get_class() + "/" + p_name, "type":TYPE_BOOL, "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED })
	else:
		p_list.append({ "name":get_class() + "/" + p_name, "type":TYPE_BOOL, "usage":PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE })

func _property_list_add_icon(p_list:Array, p_name:String):
	if has_icon_override(p_name):
		p_list.append({ "name":get_class() + "/" + p_name, "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"Texture", "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED })
	else:
		p_list.append({ "name":get_class() + "/" + p_name, "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"Texture", "usage":PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE })

func _property_list_add_style(p_list:Array, p_name:String):
	if has_stylebox_override(p_name):
		p_list.append({ "name":get_class() + "/" + p_name, "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"StyleBox", "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED })
	else:
		p_list.append({ "name":get_class() + "/" + p_name, "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"StyleBox", "usage":PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE })

static func _register_default_theme(p_theme:MyTheme):
	p_theme.set_constant("item_separation", CLASS_NAME, DEFAULT_ITEM_SEPARATION)

	for i in BOOL_THEME_NAMES.keys():
		p_theme.set_bool(i, CLASS_NAME, BOOL_THEME_NAMES[i])

	for i in ICON_THEME_NAMES.keys():
		p_theme.set_icon(i, CLASS_NAME, ICON_THEME_NAMES[i])

	for i in STYLE_THEME_NAMES.keys():
		p_theme.set_stylebox(i, CLASS_NAME, STYLE_THEME_NAMES[i])


func has_constant(p_name:String, p_type:String = "") -> bool:
	if p_type == "" && not has_constant_override(p_name) && p_name == "item_separation":
		p_type = get_class()
	return .has_constant(p_name, p_type)

func has_icon(p_name:String, p_type:String = "") -> bool:
	if p_type == "" && not has_icon_override(p_name):
		p_type = get_class()
	return .has_icon(p_name, p_type)

func has_stylebox(p_name:String, p_type:String = "") -> bool:
	if p_type == "" && not has_stylebox_override(p_name) && STYLE_THEME_NAMES.has(p_name):
		p_type = get_class()
	return .has_stylebox(p_name, p_type)

func get_constant(p_name:String, p_type:String = ""):
	if p_type == "" && not has_constant_override(p_name) && p_name == "item_separation":
		p_type = get_class()
	return .get_constant(p_name, p_type)

func get_icon(p_name:String, p_type:String = ""):
	if p_type == "" && not has_icon_override(p_name) && ICON_THEME_NAMES.has(p_name):
		p_type = get_class()
	return .get_icon(p_name, p_type)

func get_stylebox(p_name:String, p_type:String = ""):
	if p_type == "" && not has_stylebox_override(p_name) && STYLE_THEME_NAMES.has(p_name):
		p_type = get_class()
	return .get_stylebox(p_name, p_type)
