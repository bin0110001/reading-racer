extends SceneTree

const GameplayControllerScript = preload("res://scripts/reading/systems/GameplayController.gd")
const ReadingContentLoaderScript = preload("res://scripts/reading/content_loader.gd")


func _initialize() -> void:
	var controller := GameplayControllerScript.new(ReadingContentLoaderScript.new())
	var paths := [
		"res://Assets/PolygonIcons/Models/SM_Icon_Text_A.fbx",
		"res://Assets/PolygonIcons/Models/SM_Icon_Play_01.fbx",
	]
	for path in paths:
		print("=== ", path, " ===")
		var scene := controller._instantiate_scene(path)
		print("scene=", scene)
		if scene != null:
			_print_node_materials(scene)
	quit()


func _print_node_materials(node: Node, depth: int = 0) -> void:
	var indent := "  ".repeat(depth)
	print(indent, node.name, " [", node.get_class(), "]")
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		print(indent, "  mesh=", mesh_instance.mesh)
		if mesh_instance.mesh is ArrayMesh:
			var array_mesh := mesh_instance.mesh as ArrayMesh
			for surface_index in range(array_mesh.get_surface_count()):
				var surface_material := mesh_instance.get_surface_override_material(surface_index)
				if surface_material == null:
					surface_material = array_mesh.surface_get_material(surface_index)
				print(indent, "  surface=", surface_index, " material=", surface_material)
				if surface_material is StandardMaterial3D:
					var standard_material := surface_material as StandardMaterial3D
					print(indent, "    resource_name=", standard_material.resource_name)
					print(indent, "    albedo_texture=", standard_material.albedo_texture)
	for child in node.get_children():
		if child is Node:
			_print_node_materials(child, depth + 1)
