class_name PlayerVehicleLibrary
extends RefCounted

const SETTING_KEY_VEHICLE_ID := "player_vehicle_id"
const SETTING_KEY_VEHICLE_SCENE_PATH := "player_vehicle_scene_path"
const SETTING_KEY_VEHICLE_COLOR := "player_vehicle_color"
const SETTING_KEY_VEHICLE_DECALS := "player_vehicle_decals"

const DEFAULT_VEHICLE_ID := "sedan"
const DEFAULT_PAINT_COLOR_HEX := "2a97f5ff"
const PREVIEW_MAX_DIMENSION := 3.4
const RUNTIME_MAX_DIMENSION := 5.2

const _DEFAULT_SCENE_PATH := (
	"res://Assets/SimpleCars/Prefabs/PosZFacing/" + "sedan_seperate_PosZ.prefab.scn"
)
const _PAINT_EXCLUSION_TOKENS := [
	"wheel",
	"tire",
	"rim",
	"glass",
	"window",
	"light",
	"head",
	"tail",
	"interior",
	"seat",
	"steering",
	"mirror",
	"chrome",
]
const _VEHICLES := [
	{
		"id": "sedan",
		"name": "Sedan",
		"scene_path": "res://Assets/SimpleCars/Prefabs/PosZFacing/sedan_seperate_PosZ.prefab.scn",
	},
	{
		"id": "family_van",
		"name": "Family Van",
		"scene_path":
		"res://Assets/SimpleCars/Prefabs/PosZFacing/family_van_seperate_PosZ.prefab.scn",
	},
	{
		"id": "small_4x4",
		"name": "Trail 4x4",
		"scene_path":
		"res://Assets/SimpleCars/Prefabs/PosZFacing/small_4x4_seperate_PosZ.prefab.scn",
	},
	{
		"id": "station_wagon",
		"name": "Station Wagon",
		"scene_path":
		"res://Assets/SimpleCars/Prefabs/PosZFacing/station_wagon_seperate_PosZ.prefab.scn",
	},
	{
		"id": "limo",
		"name": "Limo",
		"scene_path": "res://Assets/SimpleCars/Prefabs/PosZFacing/limo_seperate_PosZ.prefab.scn",
	},
	{
		"id": "mail_truck",
		"name": "Mail Truck",
		"scene_path": "res://Assets/SimpleCars/Prefabs/PosZFacing/mail_seperate_PosZ.prefab.scn",
	},
	{
		"id": "milk_truck",
		"name": "Milk Truck",
		"scene_path": "res://Assets/SimpleCars/Prefabs/PosZFacing/milk_seperate_PosZ.prefab.scn",
	},
	{
		"id": "tow_truck",
		"name": "Tow Truck",
		"scene_path": "res://Assets/SimpleCars/Prefabs/PosZFacing/tow_seperate_PosZ.prefab.scn",
	},
	{
		"id": "pickup_truck",
		"name": "Pickup Truck",
		"scene_path": "res://Assets/SimpleCars/Prefabs/PosZFacing/truck_seperate_PosZ.prefab.scn",
	},
	{
		"id": "cargo_truck",
		"name": "Cargo Truck",
		"scene_path":
		"res://Assets/SimpleCars/Prefabs/PosZFacing/large_truck_seperate_PosZ.prefab.scn",
	},
	{
		"id": "heavy_truck",
		"name": "Heavy Truck",
		"scene_path":
		"res://Assets/SimpleCars/Prefabs/PosZFacing/" + "large_truck_02_seperate_PosZ.prefab.scn",
	},
	{
		"id": "icecream_truck",
		"name": "Ice Cream Truck",
		"scene_path":
		"res://Assets/SimpleCars/Prefabs/PosZFacing/icecream_seperate_PosZ.prefab.scn",
	},
	{
		"id": "swat_truck",
		"name": "SWAT Truck",
		"scene_path": "res://Assets/SimpleCars/Prefabs/PosZFacing/swat_seperate_PosZ.prefab.scn",
	},
	{
		"id": "classic_car",
		"name": "Classic Car",
		"scene_path": "res://Assets/SimpleCars/Prefabs/PosZFacing/old_car_seperate_PosZ.prefab.scn",
	},
]

var vehicle_select_utils := VehicleSelectUtils.new()


static func list_vehicles() -> Array[Dictionary]:
	var vehicles: Array[Dictionary] = []
	for entry in _VEHICLES:
		vehicles.append((entry as Dictionary).duplicate(true))
	return vehicles


static func get_default_paint_color() -> Color:
	return Color.from_string(DEFAULT_PAINT_COLOR_HEX, Color.DODGER_BLUE)


static func get_vehicle_scene_path(vehicle_id: String) -> String:
	var vehicle := get_vehicle_by_id(vehicle_id)
	if vehicle.is_empty():
		return _DEFAULT_SCENE_PATH
	return str(vehicle.get("scene_path", _DEFAULT_SCENE_PATH))


func get_vehicle_scene_path_instance(vehicle_id: String) -> String:
	return get_vehicle_scene_path(vehicle_id)


static func get_vehicle_by_id(vehicle_id: String) -> Dictionary:
	var normalized_id := vehicle_id.strip_edges().to_lower()
	for entry in _VEHICLES:
		var vehicle := entry as Dictionary
		if str(vehicle.get("id", "")) == normalized_id:
			return vehicle.duplicate(true)
	return {}


func get_vehicle_by_id_instance(vehicle_id: String) -> Dictionary:
	return get_vehicle_by_id(vehicle_id)


static func resolve_vehicle_id(settings: Dictionary) -> String:
	var vehicle_id := str(settings.get(SETTING_KEY_VEHICLE_ID, DEFAULT_VEHICLE_ID))
	if get_vehicle_by_id(vehicle_id).is_empty():
		return DEFAULT_VEHICLE_ID
	return vehicle_id


static func resolve_scene_path(settings: Dictionary) -> String:
	var stored_path := str(settings.get(SETTING_KEY_VEHICLE_SCENE_PATH, ""))
	if not stored_path.is_empty() and ResourceLoader.exists(stored_path):
		return stored_path
	return get_vehicle_scene_path(resolve_vehicle_id(settings))


static func resolve_vehicle_scene_path(settings: Dictionary) -> String:
	return resolve_scene_path(settings)


func resolve_vehicle_scene_path_instance(settings: Dictionary) -> String:
	return PlayerVehicleLibrary.resolve_vehicle_scene_path(settings)


static func resolve_paint_color(settings: Dictionary) -> Color:
	var default_color := get_default_paint_color()
	var encoded_color := str(settings.get(SETTING_KEY_VEHICLE_COLOR, DEFAULT_PAINT_COLOR_HEX))
	return Color.from_string(encoded_color, default_color)


static func instantiate_vehicle_from_settings(settings: Dictionary, max_dimension: float) -> Node3D:
	var scene_path := resolve_scene_path(settings)
	if not ResourceLoader.exists(scene_path):
		scene_path = _DEFAULT_SCENE_PATH
	if not ResourceLoader.exists(scene_path):
		return null

	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		return null

	var instance := packed_scene.instantiate() as Node3D
	if instance == null:
		return null

	fit_instance_to_dimension(instance, max_dimension)
	ensure_overlay_lightmap_size_hints(instance)

	var decal_data: Array = settings.get(SETTING_KEY_VEHICLE_DECALS, []) as Array
	if decal_data is Array and decal_data.size() > 0:
		apply_vehicle_decals(instance, decal_data)

	return instance


func instantiate_vehicle_from_settings_instance(
	settings: Dictionary, max_dimension: float
) -> Node3D:
	return instantiate_vehicle_from_settings(settings, max_dimension)


static func fit_instance_to_dimension(instance: Node3D, max_dimension: float) -> void:
	var bounds: AABB = _calculate_bounds(instance)
	if bounds == AABB():
		return

	var largest_dimension := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest_dimension > 0.001 and max_dimension > 0.001:
		var scale_factor := max_dimension / largest_dimension
		instance.scale = Vector3.ONE * scale_factor
		bounds = _calculate_bounds(instance)

	if bounds == AABB():
		return

	instance.position -= Vector3(
		bounds.position.x + (bounds.size.x * 0.5),
		bounds.position.y,
		bounds.position.z + (bounds.size.z * 0.5)
	)


static func apply_paint_color(instance: Node3D, paint_color: Color) -> void:
	var painted_surfaces := _apply_paint_recursive(instance, paint_color)
	if painted_surfaces > 0:
		return

	var first_mesh := _find_first_mesh_instance(instance)
	if first_mesh == null or first_mesh.mesh == null:
		return

	for surface_index in range(first_mesh.mesh.get_surface_count()):
		var override_material := first_mesh.get_surface_override_material(surface_index)
		var base_material := override_material
		if base_material == null:
			base_material = first_mesh.mesh.surface_get_material(surface_index)
		var tinted = _create_tinted_material(base_material, paint_color)
		first_mesh.set_surface_override_material(surface_index, tinted)


func apply_paint_color_instance(instance: Node3D, paint_color: Color) -> void:
	apply_paint_color(instance, paint_color)


func fit_instance_to_dimension_instance(instance: Node3D, max_dimension: float) -> void:
	fit_instance_to_dimension(instance, max_dimension)


static func ensure_overlay_lightmap_size_hints(
	instance: Node3D, fallback_size: Vector2i = Vector2i(64, 64)
) -> void:
	for mesh_instance in _collect_mesh_instances(instance):
		if mesh_instance.mesh == null:
			continue
		if mesh_instance.mesh.lightmap_size_hint != Vector2i.ZERO:
			continue

		var mesh_copy := mesh_instance.mesh.duplicate(true) as Mesh
		if mesh_copy == null:
			continue
		mesh_copy.lightmap_size_hint = fallback_size
		mesh_instance.mesh = mesh_copy


static func build_vehicle_settings(
	vehicle_id: String, paint_color: Color, paint_decals: Array = []
) -> Dictionary:
	var paint_color_hex = paint_color.to_html(true)
	var settings = {
		SETTING_KEY_VEHICLE_ID:
		resolve_vehicle_id(
			{
				SETTING_KEY_VEHICLE_ID: vehicle_id,
			}
		),
		SETTING_KEY_VEHICLE_SCENE_PATH: get_vehicle_scene_path(vehicle_id),
		SETTING_KEY_VEHICLE_COLOR: paint_color_hex,
		SETTING_KEY_VEHICLE_DECALS: paint_decals,
	}
	return settings


func build_vehicle_settings_instance(
	vehicle_id: String, paint_color: Color, paint_decals: Array = []
) -> Dictionary:
	return build_vehicle_settings(vehicle_id, paint_color, paint_decals)


static func _apply_paint_recursive(node: Node, paint_color: Color) -> int:
	var painted_surfaces := 0
	if node is MeshInstance3D:
		painted_surfaces += _paint_mesh_instance(node as MeshInstance3D, paint_color)

	for child in node.get_children():
		painted_surfaces += _apply_paint_recursive(child, paint_color)

	return painted_surfaces


static func _paint_mesh_instance(mesh_instance: MeshInstance3D, paint_color: Color) -> int:
	if mesh_instance.mesh == null:
		return 0

	var painted_surfaces := 0
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var override_material := mesh_instance.get_surface_override_material(surface_index)
		var base_material := override_material
		if base_material == null:
			base_material = mesh_instance.mesh.surface_get_material(surface_index)
		if not _should_paint_surface(mesh_instance, base_material):
			continue

		mesh_instance.set_surface_override_material(
			surface_index, _create_tinted_material(base_material, paint_color)
		)
		painted_surfaces += 1

	return painted_surfaces


static func _should_paint_surface(mesh_instance: MeshInstance3D, material: Material) -> bool:
	var name_tokens := mesh_instance.name.to_lower()
	if material != null:
		name_tokens += " %s" % str(material.resource_name).to_lower()

	for token in _PAINT_EXCLUSION_TOKENS:
		if name_tokens.contains(token):
			return false

	if material is BaseMaterial3D:
		var base_material := material as BaseMaterial3D
		if base_material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
		if base_material.albedo_color.a < 0.95:
			return false

	return true


static func _create_tinted_material(material: Material, paint_color: Color) -> Material:
	if material is BaseMaterial3D:
		var duplicated := material.duplicate(true) as BaseMaterial3D
		var source_color := duplicated.albedo_color
		if source_color == Color.WHITE:
			duplicated.albedo_color = paint_color
		else:
			duplicated.albedo_color = source_color.lerp(paint_color, 0.7)
		return duplicated

	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = paint_color
	return fallback


static func apply_vehicle_decals(instance: Node3D, decals: Array) -> int:
	var added_decal_count := 0
	for decal_info in decals:
		if typeof(decal_info) != TYPE_DICTIONARY:
			continue

		var local_position = _decode_vector3(decal_info.get("position", {}))
		var local_normal = _decode_vector3(decal_info.get("normal", {}))
		if local_normal.length() < 0.001:
			continue

		var color = Color.from_string(str(decal_info.get("color", "")), get_default_paint_color())
		var size = float(decal_info.get("size", 0.35))

		# Place decals in instance-local coordinates
		# so this works before instance is added to the scene tree
		var local_decal_position = local_position + local_normal * 0.001
		var local_decal_normal = local_normal.normalized()

		var brush_shape = str(decal_info.get("shape", "circle"))
		var decal_texture = _create_decal_texture(color, brush_shape)

		# Use Decal projection for accurate surface adherence and alpha shape.
		var decal_pose := Transform3D()
		decal_pose.origin = local_decal_position
		var up_dir: Vector3 = Vector3.UP
		if absf(local_decal_normal.dot(up_dir)) > 0.995:
			up_dir = Vector3.RIGHT
		decal_pose = decal_pose.looking_at(local_decal_position + local_decal_normal, up_dir)

		# Keep Decal node path as primary painting mechanism.
		var decal_node = Decal.new()
		decal_node.texture_albedo = decal_texture
		decal_node.albedo_mix = 1.0
		decal_node.modulate = Color(1, 1, 1, 1)

		decal_node.size = Vector3(
			size * 1.5,
			size * 1.5,
			maxf(size * 0.12, 0.06),
		)
		decal_node.transform = decal_pose
		# Project onto all preview layers so the decal can actually affect the car meshes.
		decal_node.cull_mask = -1
		instance.add_child(decal_node)
		added_decal_count += 1
		if OS.is_debug_build():
			print(
				"[PlayerVehicleLibrary][PAINT] Added decal | ",
				{
					"shape": brush_shape,
					"size": size,
					"local_position": local_position,
					"local_normal": local_normal,
					"cull_mask": decal_node.cull_mask,
					"decal_size": decal_node.size,
					"child_count": instance.get_child_count(),
				},
			)

	return added_decal_count


func apply_vehicle_decals_instance(instance: Node3D, decals: Array) -> int:
	return apply_vehicle_decals(instance, decals)


static func _create_decal_texture(color: Color, brush_shape: String = "circle") -> Texture2D:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.38
	var feather := maxf(size * 0.08, 2.0)

	match brush_shape:
		"square":
			for y in range(size):
				for x in range(size):
					var pos := Vector2(float(x) + 0.5, float(y) + 0.5) - center
					var max_dist: float = max(absf(pos.x), absf(pos.y))
					var alpha: float = clamp(1.0 - ((max_dist - radius) / feather), 0.0, 1.0)
					image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
		"star":
			var outer_radius := radius
			var inner_radius := outer_radius * 0.42
			for y in range(size):
				for x in range(size):
					var pos = Vector2(float(x) + 0.5, float(y) + 0.5) - center
					var r = pos.length()
					if r == 0.0:
						image.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))
						continue
					var angle = atan2(pos.y, pos.x)
					var spoke = (cos(5.0 * angle) * 0.5) + 0.5
					var radius_at_angle = lerp(inner_radius, outer_radius, spoke)
					var alpha: float = clamp(1.0 - ((r - radius_at_angle) / feather), 0.0, 1.0)
					image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
		"smoke":
			var smoke_shape = _create_smoke_brush_shape(size)
			for y in range(size):
				for x in range(size):
					var c = smoke_shape.get_pixel(x, y)
					image.set_pixel(x, y, Color(color.r, color.g, color.b, c.a))
		"circle":
			for y in range(size):
				for x in range(size):
					var offset := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
					var alpha: float = clamp(1.0 - ((offset - radius) / feather), 0.0, 1.0)
					image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
		_:
			for y in range(size):
				for x in range(size):
					var offset := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
					var alpha: float = clamp(1.0 - ((offset - radius) / feather), 0.0, 1.0)
					image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))

	return ImageTexture.create_from_image(image)


static func _create_smoke_brush_shape(size: int = 32) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.38
	var feather := maxf(size * 0.08, 2.0)
	for y in range(size):
		for x in range(size):
			var pos := Vector2(float(x) + 0.5, float(y) + 0.5)
			var dist := pos.distance_to(center)
			var alpha: float = clamp(1.0 - ((dist - radius) / feather), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	var corner_alpha := maxf(
		maxf(image.get_pixel(0, 0).a, image.get_pixel(size - 1, 0).a),
		maxf(image.get_pixel(0, size - 1).a, image.get_pixel(size - 1, size - 1).a)
	)
	if corner_alpha > 0.05:
		return _create_circular_brush_shape(size)
	return image


static func _create_circular_brush_shape(size: int = 32) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.38
	var feather := maxf(size * 0.08, 2.0)
	for y in range(size):
		for x in range(size):
			var offset := Vector2(float(x) + 0.5, float(y) + 0.5)
			var alpha: float = clamp(
				1.0 - ((offset.distance_to(center) - radius) / feather), 0.0, 1.0
			)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return image


static func _create_quadratic_decal_material(decal_texture: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.albedo_texture = decal_texture
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.roughness = 1.0
	mat.metallic = 0.0
	# Transparent decals should still write depth for proper ordering in Godot 4.x
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	mat.params_cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _encode_vector3(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func _decode_vector3(value) -> Vector3:
	if value is Dictionary:
		return Vector3(
			float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0))
		)
	return Vector3.ZERO


static func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null


static func _collect_mesh_instances(
	node: Node, children_acc: Array[MeshInstance3D] = []
) -> Array[MeshInstance3D]:
	if node is MeshInstance3D:
		children_acc.push_back(node)

	for child in node.get_children():
		children_acc = _collect_mesh_instances(child, children_acc)

	return children_acc


static func _calculate_bounds(root: Node3D) -> AABB:
	var state := {
		"has_bounds": false,
		"min": Vector3.ZERO,
		"max": Vector3.ZERO,
	}
	_accumulate_bounds(root, Transform3D.IDENTITY, state)
	if not bool(state.get("has_bounds", false)):
		return AABB()

	var min_point := state.get("min", Vector3.ZERO) as Vector3
	var max_point := state.get("max", Vector3.ZERO) as Vector3
	return AABB(min_point, max_point - min_point)


static func _accumulate_bounds(
	node: Node, parent_transform: Transform3D, state: Dictionary
) -> void:
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform

	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_aabb := mesh_instance.mesh.get_aabb()
			for corner in _get_aabb_corners(mesh_aabb):
				var transformed_corner := current_transform * corner
				_update_bounds_state(state, transformed_corner)

	for child in node.get_children():
		_accumulate_bounds(child, current_transform, state)


static func _get_aabb_corners(bounds: AABB) -> Array[Vector3]:
	var position := bounds.position
	var size := bounds.size
	return [
		position,
		position + Vector3(size.x, 0.0, 0.0),
		position + Vector3(0.0, size.y, 0.0),
		position + Vector3(0.0, 0.0, size.z),
		position + Vector3(size.x, size.y, 0.0),
		position + Vector3(size.x, 0.0, size.z),
		position + Vector3(0.0, size.y, size.z),
		position + size,
	]


static func _update_bounds_state(state: Dictionary, point: Vector3) -> void:
	if not bool(state.get("has_bounds", false)):
		state["has_bounds"] = true
		state["min"] = point
		state["max"] = point
		return

	var min_point := state.get("min", point) as Vector3
	var max_point := state.get("max", point) as Vector3
	state["min"] = Vector3(
		minf(min_point.x, point.x), minf(min_point.y, point.y), minf(min_point.z, point.z)
	)
	state["max"] = Vector3(
		maxf(max_point.x, point.x), maxf(max_point.y, point.y), maxf(max_point.z, point.z)
	)
