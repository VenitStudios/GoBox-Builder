class_name VoxelModel extends StaticBody3D

@export var voxels : PackedVector3Array
@export var colors : PackedColorArray
@export var indices : Array[PackedInt64Array]

@export var voxel_size : float = 0.25

@onready var MI3D := MeshInstance3D.new()
@onready var mesh := ArrayMesh.new()
@onready var collider := CollisionShape3D.new()

@onready var tool = SurfaceTool.new()
@onready var VOXEL_MESH_MATERIAL = preload("res://Shaders/VoxelMeshMaterial.tres")
const POST_PROCESS_BORDER = preload("res://Shaders/PostProcessBorder.tres")
enum FLAGS {
	SOLID,
	DELETE
}

func _ready() -> void:
	add_child(MI3D)
	add_child(collider)
	MI3D.mesh = mesh
	
	# add a single voxel as a start
	create_voxel(Vector3.ZERO, Color.WHITE)
	
# cube stuff
# modified from: https://github.com/xen-42/Simplified-godot-voxel-terrain/blob/main/Chunk.gd

func create_voxel(offset : Vector3, color : Color, flag : FLAGS = FLAGS.SOLID):
	match flag:
		FLAGS.SOLID:
			if not voxels.has(offset):
				voxels.append(offset)
				if not colors.has(color): colors.append(color)
				indices.append(PackedInt64Array([voxels.find(offset), colors.find(color)]))
		FLAGS.DELETE:
			if voxels.has(offset) and voxels.size() > 1:
				var vindex = voxels.find(offset)
			
				# Iterate backwards through indices to avoid index issues after removal
				for i in range(indices.size() - 1, -1, -1):
					var index_pair = indices[i]
					if index_pair[0] == vindex:
						indices.remove_at(i)
				
				voxels.remove_at(vindex)
				
				# Adjust indices of subsequent voxels
				for i in range(indices.size()):
					var index_pair = indices[i]
					if index_pair[0] > vindex:
						indices[i] = PackedInt64Array([index_pair[0] - 1, index_pair[1]])
	update_mesh()
	update_trimesh()

func update_mesh():
	mesh.clear_surfaces()
	mesh.clear_blend_shapes()
	tool.clear()
	
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	VOXEL_MESH_MATERIAL.next_pass = POST_PROCESS_BORDER
	
	tool.set_material(VOXEL_MESH_MATERIAL)
	for index in indices:
		for face in FACES:
			create_face(voxels[index[0]], face, colors[index[1]])
	
	tool.commit(mesh)

func update_trimesh(): collider.shape = mesh.create_trimesh_shape()

func get_data_to_save() -> Dictionary: return {"voxel": voxels, "color": colors, "index": indices}

#region mesh construction data
func create_face(offset : Vector3, i : PackedInt64Array, color : Color):
	var a = (vertices[i[0]] + offset)
	var b = (vertices[i[1]] + offset)
	var c = (vertices[i[2]] + offset)
	var d = (vertices[i[3]] + offset)
	
	tool.set_normal((b-a).cross(c-a))
	tool.set_color(color)
	tool.add_triangle_fan(([a, b, c]))
	tool.set_normal((b-a).cross(c-a))
	
	tool.add_triangle_fan(([a, c, d]))

const vertices = [
	Vector3(0, 0, 0), #0
	Vector3(1, 0, 0), #1
	Vector3(0, 1, 0), #2
	Vector3(1, 1, 0), #3
	Vector3(0, 0, 1), #4
	Vector3(1, 0, 1), #5
	Vector3(0, 1, 1), #6
	Vector3(1, 1, 1)  #7
]

const FACES = [TOP, BOTTOM, LEFT, RIGHT, FRONT, BACK]

const TOP = [2, 3, 7, 6]
const BOTTOM = [0, 4, 5, 1]
const LEFT = [6, 4, 0, 2]
const RIGHT = [3, 1, 5, 7]
const FRONT = [7, 5, 4, 6]
const BACK = [2, 0, 1, 3]
#endregion
