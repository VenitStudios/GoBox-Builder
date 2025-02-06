extends Node3D

@export var camera_distance : float = 2.0
@export var camera_distance_range : Array = [0.1, 64.0]
@onready var camera_zoom_vel = 0.0

@export var model : VoxelModel

@onready var mouse_collision_point : Vector3
@onready var mouse_collision_normal : Vector3
@onready var mouse_collision_collider : Node3D

@onready var current_color : Color 

@onready var is_new_project : bool = true
@onready var project_name : String = "New Project"
@onready var project_path : String = ""

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.as_text():
			"Mouse Wheel Up": camera_zoom_vel -= 32 * (1 + camera_distance) * get_physics_process_delta_time()
			"Mouse Wheel Down": camera_zoom_vel += 32 * (1 + camera_distance) * get_physics_process_delta_time()
	
	if event is InputEventMouseMotion:
		if (event.button_mask == 4 or (event.button_mask == 1 and %NavOverlay.get_rect().has_point(%NavOverlay.get_global_mouse_position()))) and not Input.is_key_pressed(KEY_SHIFT):
			%CameraMount.rotation.y -= event.relative.x * get_physics_process_delta_time()
			%CameraMount.rotation.x -= event.relative.y * get_physics_process_delta_time()
		if event.button_mask == 4  and Input.is_key_pressed(KEY_SHIFT):
			%Camera.position.x -= event.relative.x * get_physics_process_delta_time() * 0.5
			%CameraMount.position.y += event.relative.y * get_physics_process_delta_time() * 0.5
		
		
	if Input.is_key_pressed(KEY_O) or Input.is_key_pressed(KEY_F):
		%Camera.position.x = 0
		%CameraMount.position.y = 0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cast_data = ScreenPointToRay()
		mouse_collision_point = cast_data.RayPoint
		mouse_collision_normal = cast_data.RayNormal
		mouse_collision_collider = cast_data.RayCollider


func _process(delta: float) -> void:
	camera_zoom_vel = snappedf(clamp(camera_zoom_vel / 16, -2, 2), 0.1)
	camera_distance = clamp( camera_distance + camera_zoom_vel, camera_distance_range.min(), camera_distance_range.max() )
	%Camera.position.z = lerp(%Camera.position.z, camera_distance, delta * 8)
	%NavOverlayHinge.rotation = %CameraMount.rotation
	
	%ZoomMeter.min_value = camera_distance_range.min()
	%ZoomMeter.max_value = camera_distance_range.max()
	%ZoomMeter.value = %ZoomMeter.max_value - camera_distance
	
	
	%PerfStats.text = "FPS %s Frame Time %sms" % [Engine.get_frames_per_second(), str(delta * 1000).substr(0, 4)]
	%CurrentColor.color = current_color
	
	
	if model: 
		%PerfStats.text += "\nVoxels %s Colors %s Indices %s" % [model.voxels.size(), model.colors.size(), model.indices.size()]
	
	get_window().title = project_name.capitalize() + " - GoBox Editor"
	
	if Input.is_action_just_pressed("RightClick"):
		if mouse_collision_collider && model:
			var pos = floor(mouse_collision_point - mouse_collision_normal * 0.5)
			model.create_voxel(pos, current_color, VoxelModel.FLAGS.DELETE)
	if Input.is_action_just_pressed("LeftClick"):
		if mouse_collision_collider && model:
			var pos = floor(mouse_collision_point - mouse_collision_normal * 0.5) + mouse_collision_normal
			model.create_voxel(pos, current_color, VoxelModel.FLAGS.SOLID)
	if mouse_collision_collider && model:
		var pos = floor(mouse_collision_point - mouse_collision_normal * 0.5) + mouse_collision_normal + (Vector3.ONE * 0.5)
		%CursorHighlight.global_position = pos


func zoom_meter_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			camera_distance = %ZoomMeter.max_value - (%ZoomMeter.get_local_mouse_position().x) / %ZoomMeter.size.x * %ZoomMeter.max_value 


func ScreenPointToRay() -> Dictionary:
	var SpaceState = get_world_3d().direct_space_state
	
	var OutputDictionary = {
		"RayPoint": Vector3.ZERO,
		"RayNormal": Vector3.ZERO,
		"MousePoint": Vector3.ZERO,
		"RayCollider": null
	}
	
	var MousePos = get_viewport().get_mouse_position()
	var Camera = get_tree().root.get_camera_3d() as Camera3D
	var RayOrigin = Camera.project_ray_origin(MousePos)
	var RayEnd = RayOrigin + Camera.project_ray_normal(MousePos) * 5000
	var RayParamaters = PhysicsRayQueryParameters3D.new()
	RayParamaters.from = RayOrigin
	RayParamaters.to = RayEnd
	var RayOutput = SpaceState.intersect_ray(RayParamaters)
	
	OutputDictionary["MousePoint"] = RayOrigin + Camera.project_ray_normal(MousePos) * 10
	if RayOutput.has("position"):
		OutputDictionary["RayPoint"] = RayOutput.get("position")
		OutputDictionary["RayNormal"] = RayOutput.get("normal")
		OutputDictionary["RayCollider"] = RayOutput.get("collider")
	
	return OutputDictionary


func file_options_item_selected(index: int) -> void:
	var item = %FileOptions.get_item_text(index)
	match item:
		"New": NewProject()
		"Save": QuickSave()
		"Save As": SaveProject()
		"Load": LoadProject()
	%FileOptions.selected = 0

func SaveProject():
	%ProjectSaveDialog.show()
	DirAccess.make_dir_absolute(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/GoBox Builder/")
	%ProjectSaveDialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/GoBox Builder/"
	var absolute_path : String = await %ProjectSaveDialog.file_selected
	var name_from_file_path = absolute_path.get_file().trim_suffix("." + absolute_path.get_extension())
	if not absolute_path.ends_with(".gbp"): absolute_path += ".gbp"
	SaveToFile(name_from_file_path, absolute_path)

func SaveToFile(name_from_file_path, absolute_path):
	if absolute_path == "": return
	var data = {"project_name": name_from_file_path, "project_data": {"project_colors": %ColorGrid.get_all_colors(), "geometry": model.get_data_to_save()}}
	var fs = FileAccess.open(absolute_path, FileAccess.WRITE)
	if fs and fs.is_open():
		fs.store_var(data)
		fs.close()
		%ProjectSaveDialog.current_file = ""
		is_new_project = false


func QuickSave():
	if not is_new_project: SaveToFile(project_name, project_path)
	if is_new_project: SaveProject()

func NewProject():
	%ColorGrid.colors = []
	%ColorGrid._ready()
	
	model.voxels  = []
	model.colors  = []
	model.indices = []
	
	model.update_mesh()
	project_name = "New Project"
	project_path = ""

func LoadProject():
	%ProjectLoadDialog.show()
	%ProjectLoadDialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/GoBox Builder/"
	var absolute_path : String = await %ProjectLoadDialog.file_selected
	var file_data : Dictionary = {}
	var fs = FileAccess.open(absolute_path, FileAccess.READ)
	if fs and fs.is_open():
		file_data = fs.get_var()
	fs.close()
	
	
	%ColorGrid.colors = file_data.project_data.project_colors
	%ColorGrid.load_new_colors()
	
	model.voxels = file_data.project_data.geometry.voxel
	model.colors = file_data.project_data.geometry.color
	model.indices = file_data.project_data.geometry.index
	
	model.update_mesh()
	model.update_trimesh()
	
	is_new_project = false
	project_name = file_data.project_name
	project_path = absolute_path
