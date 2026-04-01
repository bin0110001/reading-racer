## Scene Loader Tests - Validates all .tscn files load without errors
## Phase 2: Basic scene structure validation
extends GdUnitTestSuite

const SCENE_PATHS = [
	"res://scenes/main.tscn",
	"res://scenes/reading_mode.tscn",
	"res://scenes/level_select.tscn",
]
const VEHICLE_SELECT_SCENE_PATH = "res://scenes/vehicle_select.tscn"


func test_all_scenes_load_without_errors() -> void:
	"""Smoke test: verify all project scenes can be instantiated."""
	for scene_path in SCENE_PATHS:
		assert_that(ResourceLoader.exists(scene_path)).is_true()

		var scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
		assert_that(scene).is_not_null()
		assert_that(scene is PackedScene).is_true()

		var instance = scene.instantiate()
		assert_that(instance).is_not_null()
		instance.queue_free()


func test_main_scene_structure() -> void:
	"""Verify main.tscn has basic expected structure."""
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var instance: Node = scene.instantiate() as Node

	# Main scene should have a root node
	assert_that(instance).is_not_null()
	assert_that(instance is Node).is_true()

	instance.queue_free()


func test_reading_mode_scene_structure() -> void:
	"""Verify reading_mode.tscn has basic expected structure."""
	var scene: PackedScene = load("res://scenes/reading_mode.tscn") as PackedScene
	var instance: Node = scene.instantiate() as Node

	# Reading mode should have a root node
	assert_that(instance).is_not_null()
	assert_that(instance is Node).is_true()

	instance.queue_free()


func test_level_select_scene_structure() -> void:
	"""Verify level_select.tscn has basic expected structure."""
	var scene: PackedScene = load("res://scenes/level_select.tscn") as PackedScene
	var instance: Node = scene.instantiate() as Node
	var carousel_scroll = _find_child_by_name(instance, "LevelCarouselScroll")
	var start_button = _find_child_by_name(instance, "StartButton")

	# Level select should have a root node
	assert_that(instance).is_not_null()
	assert_that(instance is Node).is_true()
	assert_that(carousel_scroll).is_not_null()
	assert_that(start_button).is_null()

	instance.queue_free()


func test_vehicle_select_scene_structure() -> void:
	"""Verify vehicle_select.tscn has basic expected structure."""
	var scene: PackedScene = load(VEHICLE_SELECT_SCENE_PATH) as PackedScene
	var instance: Node = scene.instantiate() as Node

	assert_that(instance).is_not_null()
	assert_that(instance is Node).is_true()

	instance.queue_free()


func test_vehicle_select_smoke_controls() -> void:
	"""Smoke test: vehicle select instantiates and control nodes are present."""
	var scene = load(VEHICLE_SELECT_SCENE_PATH)
	var instance = scene.instantiate()
	assert_that(instance).is_not_null()
	add_child(instance)
	await get_tree().process_frame

	var main_vbox = _find_child_by_name(instance, "MainVBox")
	var vehicle_option = _find_child_by_name(instance, "VehicleOption")
	var brush_size_selector = _find_child_by_name(instance, "BrushSizeSelector")
	var rotation_controls = _find_child_by_name(instance, "VehicleRotationControls")
	var rotate_top_button = _find_child_by_name(instance, "RotateVehicleTopButton")
	var rotate_reset_button = _find_child_by_name(instance, "RotateVehicleResetButton")
	var paint_palette = _find_child_by_name(instance, "PaintColorPalette")
	var preview_container = _find_child_by_name(instance, "VehiclePreviewContainer")
	var name_label = _find_child_by_name(instance, "VehicleNameLabel")
	var camera_brush = _find_child_by_name(instance, "CameraBrush")
	var overlay_manager = _find_child_by_name(instance, "OverlayAtlasManager")
	var back_button = _find_child_by_name(instance, "BackButton")
	var paint_snapshot: Dictionary = instance.call("get_paint_debug_snapshot")

	assert_that(main_vbox).is_not_null()
	assert_that(vehicle_option).is_not_null()
	assert_that(brush_size_selector).is_not_null()
	assert_that(rotation_controls).is_not_null()
	assert_that(rotate_top_button).is_not_null()
	assert_that(rotate_reset_button).is_not_null()
	assert_that(back_button).is_not_null()
	assert_that(brush_size_selector.get_child_count()).is_equal(5)
	assert_that(paint_palette).is_not_null()
	assert_that(preview_container).is_not_null()
	assert_that(name_label).is_not_null()
	assert_that(camera_brush).is_not_null()
	assert_that(overlay_manager).is_not_null()
	assert_that(paint_palette.get_child_count()).is_equal(24)
	assert_that(paint_snapshot.get("overlay_manager_ready", false)).is_true()
	assert_that(paint_snapshot.get("camera_brush_ready", false)).is_true()
	assert_that(paint_snapshot.get("brush_viewport_ready", false)).is_true()
	var rotation_degrees: Vector3 = paint_snapshot.get("vehicle_rotation_degrees", Vector3.ZERO)
	assert_that(rotation_degrees.is_equal_approx(Vector3.ZERO)).is_true()

	rotate_top_button.emit_signal("pressed")
	await get_tree().process_frame
	paint_snapshot = instance.call("get_paint_debug_snapshot")
	rotation_degrees = paint_snapshot.get("vehicle_rotation_degrees", Vector3.ZERO)
	assert_that(rotation_degrees.x).is_equal(-90.0)

	rotate_reset_button.emit_signal("pressed")
	await get_tree().process_frame
	paint_snapshot = instance.call("get_paint_debug_snapshot")
	rotation_degrees = paint_snapshot.get("vehicle_rotation_degrees", Vector3.ZERO)
	assert_that(rotation_degrees.is_equal_approx(Vector3.ZERO)).is_true()

	# Basic live methods should run without error
	if instance.has_method("_refresh_vehicle_preview"):
		instance.call("_refresh_vehicle_preview")

	instance.queue_free()


func test_vehicle_select_paint_controls_and_clear_flow() -> void:
	"""Verify the vehicle selection screen exposes and responds to paint controls."""
	var settings_store = ReadingSettingsStore.new()
	settings_store.save_settings(ReadingSettingsStore.default_settings())

	var scene = ResourceLoader.load(VEHICLE_SELECT_SCENE_PATH) as PackedScene
	assert_that(scene).is_not_null()

	var instance = scene.instantiate()
	assert_that(instance).is_not_null()
	add_child(instance)
	await get_tree().process_frame

	var brush_size_selector = _find_child_by_name(instance, "BrushSizeSelector")
	var paint_palette = _find_child_by_name(instance, "PaintColorPalette")
	var paint_color_swatch = _find_child_by_name(instance, "PaintColorSwatch_00")
	var clear_paint_button = _find_child_by_name(instance, "ClearPaintButton")
	var camera_brush = _find_child_by_name(instance, "CameraBrush")
	var overlay_manager = _find_child_by_name(instance, "OverlayAtlasManager")

	assert_that(brush_size_selector).is_not_null()
	assert_that(brush_size_selector.get_child_count()).is_equal(5)
	assert_that(paint_palette).is_not_null()
	assert_that(paint_color_swatch).is_not_null()
	assert_that(clear_paint_button).is_not_null()
	assert_that(camera_brush).is_not_null()
	assert_that(overlay_manager).is_not_null()
	assert_that(paint_palette.get_child_count()).is_equal(24)

	if instance.has_method("_on_brush_size_selected"):
		instance.call("_on_brush_size_selected", 2)
	assert_that(float(instance.get("paint_brush_size"))).is_equal(0.35)

	if instance.has_method("_on_paint_color_selected"):
		instance.call("_on_paint_color_selected", 0)
	assert_that(int(instance.get("selected_paint_color_index"))).is_equal(0)

	var decals: Array = instance.get("selected_vehicle_decals")
	assert_that(decals).is_not_null()
	assert_that((decals as Array).size()).is_equal(0)

	if instance.has_method("_on_clear_paint_pressed"):
		instance.call("_on_clear_paint_pressed")

	assert_that((instance.get("selected_vehicle_decals") as Array).size()).is_equal(0)

	instance.queue_free()


func test_vehicle_select_preview_applies_overlay_materials() -> void:
	"""Verify the preview vehicle gets overlay materials after refresh."""
	var scene = ResourceLoader.load(VEHICLE_SELECT_SCENE_PATH) as PackedScene
	assert_that(scene).is_not_null()

	var instance = scene.instantiate()
	assert_that(instance).is_not_null()
	add_child(instance)
	await get_tree().process_frame

	await get_tree().process_frame
	await get_tree().process_frame

	var vehicle_instance = instance.get("vehicle_preview_instance") as Node3D
	assert_that(vehicle_instance).is_not_null()

	var mesh_instance := _find_first_mesh_instance(vehicle_instance)
	assert_that(mesh_instance).is_not_null()
	assert_that(mesh_instance.material_overlay).is_not_null()

	instance.queue_free()


func _find_child_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		if child is Node:
			var found = _find_child_by_name(child as Node, target_name)
			if found != null:
				return found
	return null


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found = _find_first_mesh_instance(child)
		if found != null:
			return found
	return null
