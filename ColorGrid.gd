extends GridContainer

@export var ColorAmt : int = 64
@export var shades : int = 16
var buttons : Array[ColorPickerButton]
var colors : PackedColorArray


func _ready() -> void:
	for c in get_children(): 
		c.queue_free()
		buttons.erase(c)
	for c in ColorAmt:
		var cpb = add_new_button()
		cpb.color = generate_color(c, ColorAmt)
	for s in shades:
		var cpb = add_new_button()
		cpb.color = Color(float(s + 1) / shades, float(s + 1) / shades, float(s + 1) / shades, 1.0)

func get_all_colors() -> PackedColorArray:
	colors = []
	for c in get_children():
		if c is ColorPickerButton:
			if not colors.has(c.color):
				colors.append(c.color)
	return colors

func load_new_colors():
	for c in get_children(): 
		c.queue_free()
		buttons.erase(c)
	for color in colors:
		var cpb = add_new_button()
		cpb.color = color

func _physics_process(delta: float) -> void:
	for c in buttons:
		c.custom_minimum_size = Vector2.ONE * ((get_node("../../../").size.x / columns) - 2) 

func generate_color(index, amount) -> Color: 
	var hue = float(index) / amount
	var saturation = 1.0
	var value = 1.0
	
	return Color.from_hsv(hue, saturation, value)

func add_new_button():
	var cpb = ColorPickerButton.new()
	add_child(cpb)
	buttons.append(cpb)
	cpb.custom_minimum_size = Vector2(24, 24)
	cpb.color = Color.WHITE
	cpb.button_mask = MOUSE_BUTTON_MASK_RIGHT
	cpb.gui_input.connect(button_gui_input.bind(cpb))
	return cpb

func _on_button_pressed() -> void:
	var b = add_new_button()
	move_child(b, 0)
	get_tree().current_scene.current_color = b.color

func button_gui_input(event: InputEvent, button : ColorPickerButton) -> void:
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed:
			get_tree().current_scene.current_color = button.color
