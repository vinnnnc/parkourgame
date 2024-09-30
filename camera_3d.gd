extends Camera3D

var target: CharacterBody3D
@export var smooth_speed: float = 5.0
@export var enable_cam_follow = true

func _ready():
	# Adjust the path based on your scene hierarchy
	target = get_node("/root/Node3D/Player")
	
	# Ensure the target is found
	if target == null:
		print("CharacterBody3D node not found!")

func _physics_process(delta):
	# Get the current position of the camera
	var current_pos = global_transform.origin
	# Get the position of the character the camera should follow
	var target_pos = target.global_transform.origin + Vector3(0, 2, 5) # Offset behind the character
	
	# Smoothly interpolate the camera position
	if enable_cam_follow:
		global_transform.origin = current_pos.lerp(target_pos, smooth_speed * delta)
