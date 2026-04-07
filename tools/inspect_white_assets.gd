extends SceneTree


func _initialize() -> void:
	var paths := [
		"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_1.prefab.scn",
		"res://Assets/Synty/PolygonGingerBread/Prefabs/SM_Prop_Gingerbread_House_01.prefab.scn",
		"res://Assets/Synty/PolygonEaster/Materials/PolygonEaster_01.material",
		"res://Assets/Synty/PolygonGingerBread/Materials/PolygonGingerbread_01_A.material",
		"res://models/Library/mesh-library.tres",
	]
	for path in paths:
		print("=== ", path, " ===")
		var resource := load(path)
		print(
			"load_type=", typeof(resource), " class=", resource.get_class() if resource else "null"
		)
		if resource == null:
			continue
		if resource is PackedScene:
			var node := (resource as PackedScene).instantiate()
			_print_node_materials(node)
			node.free()
		elif resource is MeshLibrary:
			var mesh_library := resource as MeshLibrary
			for item_id in mesh_library.get_item_list():
				var mesh := mesh_library.get_item_mesh(item_id)
				print("item=", item_id, " mesh=", mesh)
				if mesh is ArrayMesh:
					var array_mesh := mesh as ArrayMesh
					for surface_index in range(array_mesh.get_surface_count()):
						var material := array_mesh.surface_get_material(surface_index)
						print("  surface=", surface_index, " material=", material)
						if material is StandardMaterial3D:
							var standard_material := material as StandardMaterial3D
							print("    albedo_texture=", standard_material.albedo_texture)
							print("    resource_path=", standard_material.resource_path)
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
				var material := array_mesh.surface_get_material(surface_index)
				print(indent, "  surface=", surface_index, " material=", material)
				if material is StandardMaterial3D:
					var standard_material := material as StandardMaterial3D
					print(indent, "    albedo_texture=", standard_material.albedo_texture)
					print(indent, "    resource_path=", standard_material.resource_path)
	for child in node.get_children():
		if child is Node:
			_print_node_materials(child, depth + 1)
