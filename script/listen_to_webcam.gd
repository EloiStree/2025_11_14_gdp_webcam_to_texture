
class_name ListenToWebcam
extends Node

signal on_webcam_texture_created(webcam: CameraTexture)

@export_category("UI")
@export var webcam_option_button: OptionButton
@export var preview_rect: TextureRect
@export var debug_label: Label

@export_category("Webcam Selection")
@export var look_for_webcams: Array[String] = []
@export var camera_index_if_not_found: int = 0

@export_category("Camera Format")
@export var look_for_format: Array[String] = [
	"1280x720 yuyv",
	"1280x720 mjpeg"
]
@export var camera_format_index_if_not_found: int = 0

var feeds: Array[CameraFeed] = []
var feed: CameraFeed
var cam_tex: CameraTexture

var connected := false


func _ready() -> void:
	_log("📷 Initializing camera system...")

	# React when cameras are added/removed.
	if not CameraServer.camera_feeds_updated.is_connected(_on_camera_feeds_updated):
		CameraServer.camera_feeds_updated.connect(_on_camera_feeds_updated)

	CameraServer.monitoring_feeds = true

	if webcam_option_button:
		if not webcam_option_button.item_selected.is_connected(_on_webcam_selected):
			webcam_option_button.item_selected.connect(_on_webcam_selected)

	# Scan once initially.
	_on_camera_feeds_updated()


# ================================================================
# WEBCAM DISCOVERY
# ================================================================

func _on_camera_feeds_updated() -> void:
	feeds = CameraServer.feeds()

	_log("")

	if feeds.is_empty():
		_log("❌ No webcams detected.")

		if webcam_option_button:
			webcam_option_button.clear()
			webcam_option_button.add_item("No webcams detected")
			webcam_option_button.disabled = true

		return

	_log("📋 Available webcams:")

	if webcam_option_button:
		webcam_option_button.clear()
		webcam_option_button.disabled = false

	for i in feeds.size():
		var webcam: CameraFeed = feeds[i]

		var name := webcam.get_name()
		var id := webcam.get_id()

		_log("[%d] %s   ID: %d" % [i, name, id])

		if webcam_option_button:
			webcam_option_button.add_item(name, id)

		# Also print available formats.
		_print_camera_formats(webcam)

	_log("")

	# Select the preferred webcam.
	var selected_index := _find_preferred_webcam()

	if selected_index >= 0:
		_select_webcam(selected_index)


# ================================================================
# PRINT CAMERA INFORMATION
# ================================================================

func _print_camera_formats(webcam: CameraFeed) -> void:
	var formats := webcam.get_formats()

	if formats.is_empty():
		_log("    No formats reported.")
		return

	for i in formats.size():
		var format: Dictionary = formats[i]

		var width: int = format.get("width", 0)
		var height: int = format.get("height", 0)
		var format_name := String(format.get("format", ""))

		_log(
			"    Format [%d]: %dx%d %s"
			% [i, width, height, format_name]
		)


# ================================================================
# FIND PREFERRED WEBCAM
# ================================================================

func _find_preferred_webcam() -> int:
	# If no names were specified, use the fallback index.
	if look_for_webcams.is_empty():
		return clampi(
			camera_index_if_not_found,
			0,
			feeds.size() - 1
		)

	# Search by name.
	for wanted_name in look_for_webcams:
		var search := wanted_name.to_lower()

		for i in feeds.size():
			var webcam_name := feeds[i].get_name().to_lower()

			if webcam_name.contains(search):
				_log(
					"🎯 Found webcam '%s' → [%d] %s"
					% [
						wanted_name,
						i,
						feeds[i].get_name()
					]
				)

				return i

	# Nothing matched.
	var fallback := clampi(
		camera_index_if_not_found,
		0,
		feeds.size() - 1
	)

	_log(
		"⚠️ No matching webcam found."
	)

	_log(
		"🎯 Using fallback [%d] %s"
		% [
			fallback,
			feeds[fallback].get_name()
		]
	)

	return fallback


# ================================================================
# SELECT WEBCAM FROM UI
# ================================================================

func _on_webcam_selected(index: int) -> void:
	if index < 0 or index >= feeds.size():
		return

	_select_webcam(index)


func _select_webcam(index: int) -> void:
	if index < 0 or index >= feeds.size():
		return

	# Stop previous feed.
	if feed and feed.is_active():
		feed.set_active(false)

	connected = false
	cam_tex = null

	feed = feeds[index]

	_log(
		"🎥 Selecting webcam [%d]: %s"
		% [
			index,
			feed.get_name()
		]
	)

	_select_format()


# ================================================================
# SELECT CAMERA FORMAT
# ================================================================

func _select_format() -> void:
	if feed == null:
		return

	var formats := feed.get_formats()

	if formats.is_empty():
		_log("⚠️ Camera has no reported formats.")
		_activate_feed()
		return

	var target_index := -1

	# Convert desired formats to lowercase.
	var wanted_formats: Array[String] = []

	for format_name in look_for_format:
		wanted_formats.append(format_name.to_lower())

	# Find matching format.
	for i in formats.size():
		var format: Dictionary = formats[i]

		var width: int = format.get("width", 0)
		var height: int = format.get("height", 0)
		var format_name := String(
			format.get("format", "")
		).to_lower()

		var description := "%dx%d %s" % [
			width,
			height,
			format_name
		]

		for wanted in wanted_formats:
			if wanted in description:
				target_index = i

				_log(
					"🎯 Selected format [%d]: %s"
					% [
						i,
						description
					]
				)

				break

		if target_index != -1:
			break

	# Fallback format.
	if target_index == -1:
		target_index = clampi(
			camera_format_index_if_not_found,
			0,
			formats.size() - 1
		)

		_log(
			"🎯 Using fallback format [%d]"
			% target_index
		)

	var result := feed.set_format(
		target_index,
		{}
	)

	if result:
		_log("✅ Camera format applied.")
	else:
		_log("⚠️ Camera rejected requested format. Driver fallback may be used.")

	_activate_feed()


# ================================================================
# ACTIVATE CAMERA
# ================================================================

func _activate_feed() -> void:
	if feed == null:
		return

	_log(
		"⚡ Activating: %s"
		% feed.get_name()
	)

	feed.set_active(true)

	await get_tree().process_frame
	await get_tree().process_frame

	if not feed.is_active():
		_log("❌ Failed to activate webcam.")
		connected = false
		return

	_log("✅ Webcam activated.")

	cam_tex = CameraTexture.new()
	cam_tex.camera_feed_id = feed.get_id()

	connected = true

	if preview_rect:
		preview_rect.texture = cam_tex

	on_webcam_texture_created.emit(cam_tex)

	_log(
		"📺 CameraTexture connected to preview."
	)


# ================================================================
# PROCESS
# ================================================================

func _process(_delta: float) -> void:
	if not connected:
		return

	if cam_tex == null:
		return

	var width := cam_tex.get_width()
	var height := cam_tex.get_height()

	if width > 32 and height > 32:
		if debug_label:
			debug_label.text = (
				"Connected: %s\n"
				+ "Resolution: %dx%d"
			) % [
				feed.get_name(),
				width,
				height
			]


# ================================================================
# LOGGING
# ================================================================

func _log(message: String) -> void:
	print(message)

	if debug_label:
		debug_label.text += message + "\n"
