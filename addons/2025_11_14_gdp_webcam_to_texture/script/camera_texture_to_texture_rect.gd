class_name CameraTextureToTextureRect extends Node

@export var to_affect:TextureRect
@export var texture_width :=0
@export var texture_height :=0

func set_texture_with_camera_texture(cam_texture:CameraTexture):
	to_affect.texture = cam_texture
	texture_width = cam_texture.get_width()
	texture_height= cam_texture.get_height()
