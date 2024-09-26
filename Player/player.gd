extends CharacterBody3D

# Constants for movement and animations
const SPEED = 5.0
const JUMP_VELOCITY = 3.5
const TURN_SPEED = 5.0 # Speed for changing directions smoothly
const JUMP_DELAY = 0.5 # Time in seconds to delay the jump
const RUN_JUMP_DELAY = 0.1 # Time in seconds to delay the jump
const ROTATION_SPEED = 5.0 # Speed of rotation for smooth flipping

var current_velocity := Vector3.ZERO
var jump_timer := 0.0 # Timer to control jump delay
var is_jump_queued := false # Flag to determine if jump is queued
var is_facing_right = true
var is_turning = false # Flag to check if turn animation is playing
var target_rotation := 0.0

enum {IDLE, RUN, SPRINT}
var curAnim = IDLE

# References to the AnimationPlayer and Skeleton3D
@onready var anim_tree = $Player/AnimationTree
@onready var visual_model = $Player/Armature/Skeleton3D

func _physics_process(delta: float) -> void:
	# Get the input direction
	var input_dir := Input.get_vector("move_up", "move_down", "move_left", "move_right")
	var target_direction := (transform.basis * Vector3(0, 0, input_dir.y)).normalized()

	# Add gravity if not on the floor
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		# Reset to idle when not moving horizontally
		if velocity.x == 0:
			curAnim = IDLE

	# Handle jump logic with delay
	if Input.is_action_just_pressed("jump") and is_on_floor():
		is_jump_queued = true
		jump_timer = JUMP_DELAY if velocity.x == 0 else RUN_JUMP_DELAY
		jump()

	if is_jump_queued:
		jump_timer -= delta
		if jump_timer <= 0.0:
			velocity.y = JUMP_VELOCITY
			is_jump_queued = false  # Reset jump queue

	# Handle movement direction and turn logic
	if target_direction != Vector3.ZERO:
		current_velocity.x = lerp(current_velocity.x, target_direction.x * SPEED, TURN_SPEED * delta)

		if is_on_floor():
			curAnim = RUN

		# Queue a turn but only flip after the turn animation finishes
		if current_velocity.x > 0 and not is_facing_right:
			queue_turn()  # Turning right
		elif current_velocity.x < 0 and is_facing_right:
			queue_turn()  # Turning left
	else:
		# Decelerate if no input
		current_velocity.x = move_toward(current_velocity.x, 0, SPEED * delta)

	# Smooth rotation to avoid stuttering
	smooth_rotate(delta)
	
	# Set the velocity and move the character
	velocity.x = current_velocity.x
	move_and_slide()

	# Update animations based on state
	handle_animations()

# Handle animations based on the current state
func handle_animations():
	match curAnim:
		IDLE:
			anim_tree.set("parameters/Movement/transition_request", "Idle")
		RUN:
			anim_tree.set("parameters/Movement/transition_request", "Run")

# Trigger the jump animation
func jump():
	if velocity.x == 0:
		anim_tree.set("parameters/Jump/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		anim_tree.set("parameters/RunJump/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# Queue a turn and play the turn animation
func queue_turn() -> void:
	is_turning = true
	anim_tree.set("parameters/Turn/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# Flip the character after the turn animation finishes
func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if anim_name == "SlowTurn":
		flip_character()
		is_turning = false

# Flip the character's visual model after the turn animation is done
func flip_character():
	is_facing_right = !is_facing_right
	target_rotation = 0 if is_facing_right else PI
		
# Gradual rotation for smoother flip
func smooth_rotate(delta: float) -> void:
	var current_rotation = visual_model.rotation.z
	visual_model.rotation.z = lerp(current_rotation, target_rotation, ROTATION_SPEED * delta)
