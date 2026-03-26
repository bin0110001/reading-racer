## Scene Loader Tests - Validates all .tscn files load without errors
## Phase 2: Basic scene structure validation
extends GdUnitTestSuite

const SCENE_PATHS = [
	"res://scenes/main.tscn",
	"res://scenes/reading_mode.tscn",
	"res://scenes/level_select.tscn",
]


func test_all_scenes_load_without_errors() -> void:
	"""Smoke test: verify all project scenes can be instantiated."""
	for scene_path in SCENE_PATHS:
		assert_that(ResourceLoader.exists(scene_path)).is_true()

		var scene = load(scene_path)
		assert_that(scene).is_not_null()
		assert_that(scene is PackedScene).is_true()

		var instance = scene.instantiate()
		assert_that(instance).is_not_null()
		instance.queue_free()


func test_main_scene_structure() -> void:
	"""Verify main.tscn has basic expected structure."""
	var scene = load("res://scenes/main.tscn")
	var instance = scene.instantiate()

	# Main scene should have a root node
	assert_that(instance).is_not_null()
	assert_that(instance is Node).is_true()

	instance.queue_free()


func test_reading_mode_scene_structure() -> void:
	"""Verify reading_mode.tscn has basic expected structure."""
	var scene = load("res://scenes/reading_mode.tscn")
	var instance = scene.instantiate()

	# Reading mode should have a root node
	assert_that(instance).is_not_null()
	assert_that(instance is Node).is_true()

	instance.queue_free()


func test_level_select_scene_structure() -> void:
	"""Verify level_select.tscn has basic expected structure."""
	var scene = load("res://scenes/level_select.tscn")
	var instance = scene.instantiate()

	# Level select should have a root node
	assert_that(instance).is_not_null()
	assert_that(instance is Node).is_true()

	instance.queue_free()
