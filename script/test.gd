extends Node

signal webcam_list_updated(text: String)

func _ready() -> void:
	var text := ""

	var count := CameraServer.get_feed_count()

	for i in count:
		var camera: CameraFeed = CameraServer.get_feed(i)

		if camera == null:
			continue

		if not text.is_empty():
			text += "\n"

		text += str(i + 1) + ". " + camera.get_name()

	print(text)
	webcam_list_updated.emit(text)
