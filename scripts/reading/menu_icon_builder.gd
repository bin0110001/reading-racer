class_name MenuIconBuilder
extends RefCounted

const ICON_VIEWPORT_SIZE := Vector2i(192, 192)


static func create_icon_texture(
	owner: Node,
	scene_path: String,
	icon_scale: float = 0.8,
	icon_rotation_degrees: Vector3 = Vector3.ZERO
) -> Texture2D:
	if owner == null:
		return null

	var viewport := SubViewport.new()
	viewport.name = "MenuIconViewport_%s" % scene_path.get_file().get_basename()
	viewport.size = ICON_VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	owner.add_child(viewport)

	var root := Node3D.new()
	viewport.add_child(root)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	light.light_energy = 1.5
	root.add_child(light)

	var camera := Camera3D.new()
	camera.current = true
	camera.position = Vector3(0.0, 0.0, 2.8)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	root.add_child(camera)

	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		return viewport.get_texture()

	var icon_node := packed_scene.instantiate()
	if icon_node is Node3D:
		var icon_root := icon_node as Node3D
		icon_root.scale = Vector3.ONE * icon_scale
		icon_root.rotation_degrees = icon_rotation_degrees
		icon_root.position = Vector3.ZERO
	root.add_child(icon_node)

	return viewport.get_texture()
