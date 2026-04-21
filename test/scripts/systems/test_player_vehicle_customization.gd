# gdlint: disable=max-line-length
class_name TestPlayerVehicleCustomization
extends GdUnitTestSuite

const GPUCameraBrush = preload(
	"res://addons/gpu-texture-painter/gpu-texture-painter-f4faff9106b51a2e95ef6d74abec774ce86cd453/addons/gpu_texture_painter/brush/camera_brush.gd"
)
const PlayerVehicleLibraryScript = preload("res://scripts/reading/player_vehicle_library.gd")
const PhonemePlayerScript = preload("res://scripts/reading/phoneme_player.gd")
const ReadingSettingsStoreScript = preload("res://scripts/reading/settings_store.gd")

var vehicle_select_utils := VehicleSelectUtils.new()
var _owned_nodes: Array[Node] = []
var _owned_paint_owners: Array[PaintHelperOwnerStub] = []


func _own_node(node: Node) -> Node:
	_owned_nodes.append(node)
	return node


func _own_paint_owner(paint_owner: PaintHelperOwnerStub) -> PaintHelperOwnerStub:
	_owned_paint_owners.append(paint_owner)
	return paint_owner


func after_each() -> void:
	for paint_owner in _owned_paint_owners:
		if is_instance_valid(paint_owner):
			paint_owner.cleanup()
	_owned_paint_owners.clear()
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()
	collect_orphan_node_details()


class PaintHelperOwnerStub:
	extends RefCounted
	const PAINT_LOG_LEVEL_NONE := 0
	const PAINT_LOG_LEVEL_ERROR := 1
	const PAINT_LOG_LEVEL_WARN := 2
	const PAINT_LOG_LEVEL_INFO := 3
	const PAINT_LOG_LEVEL_VERBOSE := 4
	const BRUSH_PRESETS := [
		{"label": "Fine", "size": 0.12},
		{"label": "Small", "size": 0.20},
		{"label": "Medium", "size": 0.35},
		{"label": "Large", "size": 0.50},
		{"label": "XL", "size": 0.72},
	]
	const BRUSH_SHAPE_OPTIONS := [
		{"label": "Circle", "id": "circle"},
		{"label": "Square", "id": "square"},
		{"label": "Star", "id": "star"},
		{"label": "Smoke", "id": "smoke"},
	]
	const PAINT_COLOR_OPTIONS := VehicleSelect.PAINT_COLOR_OPTIONS

	var paint_log_level := PAINT_LOG_LEVEL_VERBOSE
	var selected_vehicle_id := "sedan"
	var selected_vehicle_color := Color(0.15, 0.45, 0.9, 1.0)
	var paint_brush_size := 0.35
	var selected_brush_shape := "circle"
	var selected_paint_color_index := 0
	var brush_size_buttons: Array = []
	var paint_color_buttons: Array = []
	var paint_color_palette: GridContainer = GridContainer.new()
	var brush_controls_parent: VBoxContainer = VBoxContainer.new()
	var camera_brush: CameraBrush = GPUCameraBrush.new()
	var brush_shape_selector: OptionButton = OptionButton.new()
	var brush_shape_preview: TextureRect = TextureRect.new()
	var vehicle_name_label: Label = Label.new()
	var vehicle_preview_instance: Node3D = null
	var overlay_atlas_manager: Node = null
	var overlay_apply_count := 0
	var overlay_refresh_pending := false
	var paint_hit_count := 0
	var last_paint_hit: Dictionary = {}
	var selected_vehicle_rotation := Vector3.ZERO
	var selected_vehicle_decals: Array = []
	var paint_color_selection_calls := 0
	var brush_size_selection_calls := 0

	func _init() -> void:
		for option in BRUSH_SHAPE_OPTIONS:
			brush_shape_selector.add_item(str(option.get("label", "")))

	func _on_paint_color_selected(index: int) -> void:
		paint_color_selection_calls += 1
		selected_paint_color_index = index

	func _on_brush_size_selected(_index: int) -> void:
		brush_size_selection_calls += 1

	func _find_closest_brush_preset_index(brush_size: float) -> int:
		var closest_index := 0
		var closest_distance := INF
		for index in range(BRUSH_PRESETS.size()):
			var preset_size := float(BRUSH_PRESETS[index].get("size", brush_size))
			var distance := absf(preset_size - brush_size)
			if distance < closest_distance:
				closest_distance = distance
				closest_index = index
		return closest_index

	func cleanup() -> void:
		for node in [
			paint_color_palette,
			brush_controls_parent,
			camera_brush,
			brush_shape_selector,
			brush_shape_preview,
			vehicle_name_label,
		]:
			if is_instance_valid(node):
				node.free()


func test_player_vehicle_library_default_scene_exists() -> void:
	var player_vehicle_library := PlayerVehicleLibraryScript.new()
	var scene_path := player_vehicle_library.resolve_vehicle_scene_path_instance({})
	assert_that(scene_path.is_empty()).is_false()
	assert_that(ResourceLoader.exists(scene_path)).is_true()


func test_reading_settings_store_persists_vehicle_customization() -> void:
	var store = ReadingSettingsStoreScript.new()
	assert_that(store).is_not_null()
	var original_settings := store.load_settings()
	var updated_settings := ReadingSettingsStoreScript.default_settings()
	updated_settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_ID] = "mail_truck"
	updated_settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_SCENE_PATH] = (
		PlayerVehicleLibraryScript.new().get_vehicle_scene_path_instance("mail_truck")
	)
	updated_settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_COLOR] = "d14b32ff"

	store.save_settings(updated_settings)
	var loaded_settings := store.load_settings()

	(
		assert_that(loaded_settings.get(PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_ID, ""))
		. is_equal("mail_truck")
	)
	(
		assert_that(
			loaded_settings.get(PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_SCENE_PATH, "")
		)
		. is_equal(PlayerVehicleLibraryScript.new().get_vehicle_scene_path_instance("mail_truck"))
	)
	(
		assert_that(loaded_settings.get(PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_COLOR, ""))
		. is_equal("d14b32ff")
	)

	store.save_settings(original_settings)


func test_phoneme_player_leaves_source_stream_unmodified_when_looping() -> void:
	var phoneme_player := _own_node(PhonemePlayerScript.new())
	phoneme_player._ready()

	var source_stream := AudioStreamWAV.new()
	source_stream.mix_rate = 44100
	source_stream.format = AudioStreamWAV.FORMAT_16_BITS
	source_stream.stereo = false
	source_stream.data = PackedByteArray([0, 0, 0, 0])

	phoneme_player.play_looping_phoneme("b", source_stream)

	assert_that(source_stream.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)
	assert_that(phoneme_player._phoneme_player.stream).is_same(source_stream)
	var finished_connection := Callable(phoneme_player, "_on_phoneme_player_finished")
	(
		assert_that(phoneme_player._phoneme_player.is_connected("finished", finished_connection))
		. is_true()
	)


func test_player_vehicle_library_fit_instance_scales_to_max_dimension() -> void:
	var player_library = PlayerVehicleLibraryScript.new()
	var model := MeshInstance3D.new()
	model.mesh = BoxMesh.new()
	var root := _own_node(Node3D.new()) as Node3D
	root.add_child(model)

	# Without scaling, one axis of the default BoxMesh is 1.0 units (size vector set in mesh).
	player_library.fit_instance_to_dimension_instance(root, 0.5)

	# The root scale should be reduced to fit the desired range.
	assert_that(root.scale.x < 1.0).is_true()
	assert_that(root.scale.y < 1.0).is_true()
	assert_that(root.scale.z < 1.0).is_true()


func test_player_vehicle_library_apply_vehicle_decals_adds_decal_nodes() -> void:
	var player_library = PlayerVehicleLibraryScript.new()
	var root := _own_node(Node3D.new()) as Node3D
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)

	var decals := [
		{
			"position": {"x": 0.0, "y": 0.5, "z": 0.0},
			"normal": {"x": 0.0, "y": 1.0, "z": 0.0},
			"color": "ff0000ff",
			"size": 0.25,
		}
	]

	var added_decal_count := player_library.apply_vehicle_decals_instance(root, decals)
	assert_that(added_decal_count).is_equal(1)

	var decal_count := 0
	var first_decal: Decal = null
	for child in root.get_children():
		if child is Decal:
			decal_count += 1
			if first_decal == null:
				first_decal = child as Decal

	assert_that(decal_count).is_equal(1)
	assert_that(first_decal).is_not_null()
	assert_that(first_decal.texture_albedo).is_not_null()
	var decal_image := (first_decal.texture_albedo as ImageTexture).get_image()
	assert_that(decal_image.get_pixel(0, 0).a).is_equal(0.0)
	assert_that(decal_image.get_pixel(16, 16).a).is_equal(1.0)
	assert_that(first_decal.cull_mask).is_equal(4294967295)
	assert_that(first_decal.size.z).is_less(0.1)


func test_player_vehicle_library_decal_textures_have_feathered_edges() -> void:
	var player_library = PlayerVehicleLibraryScript.new()
	var root := _own_node(Node3D.new()) as Node3D
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)

	var decals := [
		{
			"position": {"x": 0.0, "y": 0.5, "z": 0.0},
			"normal": {"x": 0.0, "y": 1.0, "z": 0.0},
			"color": "ff0000ff",
			"size": 0.25,
			"shape": "circle",
		}
	]

	var added_decal_count := player_library.apply_vehicle_decals_instance(root, decals)
	assert_that(added_decal_count).is_equal(1)

	var first_decal: Decal = null
	for child in root.get_children():
		if child is Decal:
			first_decal = child as Decal
			break

	assert_that(first_decal).is_not_null()
	var decal_image := (first_decal.texture_albedo as ImageTexture).get_image()
	var edge_alpha := decal_image.get_pixel(28, 16).a
	assert_that(edge_alpha > 0.0 and edge_alpha < 1.0).is_true()


func test_build_vehicle_settings_persists_empty_decals() -> void:
	var player_vehicle_library := PlayerVehicleLibraryScript.new()
	var settings := player_vehicle_library.build_vehicle_settings_instance(
		"mail_truck", Color(1, 0, 0), []
	)
	assert_that(settings.has(PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_DECALS)).is_true()
	assert_that(settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_DECALS].size()).is_equal(0)


func test_vehicle_select_brush_shapes_have_soft_edges() -> void:
	var circle_shape := VehicleSelectUtils.create_circular_brush_shape(64)
	var square_shape := VehicleSelectUtils.create_square_brush_shape(64)
	var star_shape := VehicleSelectUtils.create_star_brush_shape(64)
	var smoke_shape := VehicleSelectUtils.create_smoke_brush_shape(64)

	assert_that(circle_shape.get_pixel(0, 0).a).is_equal(0.0)
	assert_that(circle_shape.get_pixel(32, 32).a).is_equal(1.0)
	assert_that(square_shape.get_pixel(0, 0).a).is_equal(0.0)
	assert_that(square_shape.get_pixel(32, 32).a).is_equal(1.0)
	assert_that(star_shape.get_pixel(0, 0).a).is_equal(0.0)
	assert_that(star_shape.get_pixel(32, 32).a).is_equal(1.0)
	assert_that(smoke_shape.get_pixel(0, 0).a).is_equal(0.0)
	assert_that(smoke_shape.get_pixel(32, 32).a).is_greater(0.5)


func test_vehicle_select_paint_helpers_syncs_brush_shape_preview_and_bleed() -> void:
	var paint_owner := _own_paint_owner(PaintHelperOwnerStub.new())
	var paint_helpers := VehicleSelectPaintHelpers.new()
	paint_helpers.set_selected_brush_shape(paint_owner, "circle", false)

	assert_that(paint_owner.selected_brush_shape).is_equal("circle")
	assert_that(paint_owner.camera_brush).is_not_null()
	assert_that(paint_owner.camera_brush.min_bleed).is_greater(0)
	assert_that(paint_owner.camera_brush.max_bleed).is_greater_equal(
		paint_owner.camera_brush.min_bleed
	)
	assert_that(paint_owner.camera_brush.color).is_equal(paint_owner.selected_vehicle_color)
	assert_that(paint_owner.brush_shape_preview.texture).is_not_null()

	var preview_image := (paint_owner.brush_shape_preview.texture as ImageTexture).get_image()
	assert_that(preview_image.get_pixel(0, 0).a).is_equal(0.0)
	assert_that(preview_image.get_pixel(32, 32).a).is_equal(1.0)
	assert_that(paint_owner.brush_shape_selector.selected).is_equal(0)


func test_vehicle_select_paint_helpers_increases_bleed_with_brush_size() -> void:
	var paint_owner := _own_paint_owner(PaintHelperOwnerStub.new())
	var paint_helpers := VehicleSelectPaintHelpers.new()

	paint_helpers.set_brush_preset_by_size(paint_owner, 0.12, false)
	var small_bleed := paint_owner.camera_brush.min_bleed

	paint_helpers.set_brush_preset_by_size(paint_owner, 0.72, false)
	var large_bleed := paint_owner.camera_brush.min_bleed

	assert_that(large_bleed).is_greater(small_bleed)


func test_vehicle_select_paint_helpers_sync_does_not_retrigger_selection_handlers() -> void:
	var paint_owner := _own_paint_owner(PaintHelperOwnerStub.new())
	var paint_helpers := VehicleSelectPaintHelpers.new()
	paint_helpers.build_paint_color_palette(paint_owner)
	paint_helpers.build_brush_size_selector(paint_owner, paint_owner.brush_controls_parent)

	assert_that(paint_owner.paint_color_selection_calls).is_equal(0)
	assert_that(paint_owner.brush_size_selection_calls).is_equal(0)

	paint_helpers.set_selected_paint_color(paint_owner, VehicleSelect.PAINT_COLOR_OPTIONS[7], false)
	paint_helpers.set_brush_preset_by_size(paint_owner, 0.72, false)

	assert_that(paint_owner.paint_color_selection_calls).is_equal(0)
	assert_that(paint_owner.brush_size_selection_calls).is_equal(0)
	assert_that(paint_owner.selected_paint_color_index).is_equal(7)
	assert_that(paint_owner.selected_vehicle_color).is_equal(VehicleSelect.PAINT_COLOR_OPTIONS[7])


func test_vehicle_select_overlay_shader_uses_alpha_blending() -> void:
	var shader_path := (
		"res://addons/gpu-texture-painter/"
		+ "gpu-texture-painter-f4faff9106b51a2e95ef6d74abec774ce86cd453/"
		+ "addons/gpu_texture_painter/overlay_shaders/default_overlay.gdshader"
	)
	assert_that(ResourceLoader.exists(shader_path)).is_true()

	var shader := load(shader_path) as Shader
	assert_that(shader).is_not_null()
	assert_that(shader.code.contains("render_mode blend_mix")).is_true()
	assert_that(shader.code.contains("depth_draw_alpha_prepass")).is_false()


func test_player_vehicle_library_sets_overlay_lightmap_hints() -> void:
	var player_vehicle_library := PlayerVehicleLibraryScript.new()
	var vehicle := player_vehicle_library.instantiate_vehicle_from_settings_instance(
		ReadingSettingsStoreScript.default_settings(),
		PlayerVehicleLibraryScript.PREVIEW_MAX_DIMENSION
	)
	assert_that(vehicle).is_not_null()

	var mesh_instance := _find_first_mesh_instance(vehicle)
	assert_that(mesh_instance).is_not_null()
	assert_that(mesh_instance.mesh).is_not_null()
	assert_that(mesh_instance.mesh.lightmap_size_hint != Vector2i.ZERO).is_true()

	vehicle.free()


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null
