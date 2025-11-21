class_name CameraTextureToTextureRect
extends Node

@export var to_affect: TextureRect
@export var texture_width := 0
@export var texture_height := 0

# Shader uniform configuration
@export var shader_uniform_name := "albedo_tex" # default for your shader

func set_texture_with_camera_texture(cam_texture: CameraTexture):
	# Apply to TextureRect for preview
	to_affect.texture = cam_texture
	texture_width = cam_texture.get_width()
	texture_height = cam_texture.get_height()

	var material := to_affect.material
	if material == null:
		return

	# ---- SHADER MATERIAL ----
	if material is ShaderMaterial:
		material.set_shader_parameter(shader_uniform_name, cam_texture)
		return
