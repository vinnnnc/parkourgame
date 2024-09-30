extends CharacterBody3D

# Constants for movement and animations
@export var SPEED = 5.0
@export var TURN_SPEED = 2.0 # Speed for changing directions smoothly
@export var ROTATION_SPEED = 4.5 # Speed of model rotation for smooth flipping
@export var JUMP_VELOCITY = 4 # Jump velocity
@export var WALL_JUMP_VELOCITY_X = 5
@export var WALL_JUMP_VELOCITY_y = 5
var WALL_JUMP_VELOCITY = Vector3(WALL_JUMP_VELOCITY_X, WALL_JUMP_VELOCITY_y, 0) # Speed for wall jumping
@export var JUMP_DELAY = 0.5 # Time in seconds to delay the jump
@export var RUN_JUMP_DELAY = 0.2 # Time in seconds to delay the run jump

#asd
# Variables
var current_velocity := Vector3.ZERO
var can_wall_jump = false
var jump_timer := 0.0 # Timer to control jump delay
var is_jump_queued := false # Flag to determine if jump is queued
var is_turning = false # Flag to check if turn animation is playing
var current_direction = RIGHT
var is_facing_right = true
const RIGHT = 0.0
const LEFT = -PI
enum {IDLE, RUN, SPRINT}
var curAnim = IDLE
var timer = 0
# References to the AnimationPlayer and Skeleton3D
@onready var anim_tree = $AnimationTree
@onready var visual_model = $Armature/Skeleton3D
@onready var player_raycast_left = $RayCast3DLeft # Raycast for left wall detection
@onready var player_raycast_right = $RayCast3DRight # Raycast for right wall detection

# Variables for motion and wall interaction
var bounce_force = 200
var stop_duration = 0.5  # Time to stop after hitting a wall (in seconds)
var stop_timer = 0.0
var is_bouncing = false

func _physics_process(delta: float) -> void:
	detect_raycasts()
	# Listener for movements
	handle_movements(delta)
	# Wall jump logic
	wall_jump()
	# Update animations based on state
	handle_animations()
	# Set the velocity and move the character
	move_and_slide()

func handle_movements(delta: float) -> void:
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
	if Input.is_action_just_pressed("jump") and (is_on_floor() or can_wall_jump) and !is_jump_queued:
		is_jump_queued = true
		jump_timer = JUMP_DELAY if velocity.x == 0 else RUN_JUMP_DELAY
		if !can_wall_jump:
			jump_anim()

	if is_jump_queued:
		if can_wall_jump:
			jump_timer = 0
		else:
			jump_timer -= delta
		if jump_timer <= 0.0:
			velocity.y = JUMP_VELOCITY
			is_jump_queued = false  # Reset jump queue
	
	# Handle Movement Inputs
	if Input.is_action_just_pressed("move_left") and is_on_floor() and is_facing_right:
		is_facing_right = false
		anim_tree.set("parameters/Turn/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
	if Input.is_action_just_pressed("move_right") and is_on_floor() and !is_facing_right:
		is_facing_right = true
		anim_tree.set("parameters/Turn/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
	if Input.is_action_just_pressed("crouch") and is_on_floor():
		anim_tree.set("parameters/Roll/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	if Input.is_action_just_pressed("move_down") and is_on_floor():
		anim_tree.set("parameters/Slide/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	# Handle movement direction and turn logic
	if target_direction != Vector3.ZERO:
		current_velocity.x = lerp(current_velocity.x, target_direction.x * SPEED, TURN_SPEED * delta)
		# Queue a turn but only flip after the turn animation finishes
		if current_velocity.x > 0 and current_direction == LEFT and !is_turning:
			is_turning = true
		elif current_velocity.x < 0 and current_direction == RIGHT and !is_turning:
			is_turning = true
		if is_on_floor():
			curAnim = RUN
	else:
		# Decelerate if no input
		current_velocity.x = move_toward(current_velocity.x, 0, SPEED * delta)
	change_direction(delta)
	if is_on_floor():
		velocity.x = current_velocity.x

# Handle animations based on the current state
func handle_animations():
	match curAnim:
		IDLE:
			anim_tree.set("parameters/Movement/transition_request", "Idle")
		RUN:
			anim_tree.set("parameters/Movement/transition_request", "Run")

func change_direction(delta: float) -> void:
	if is_turning:
		# Set the target direction (0 for RIGHT, PI for LEFT)
		var target_rotation = LEFT if current_direction == RIGHT else RIGHT

		# Get the current rotation of the character in radians
		var current_rotation = visual_model.rotation.z

		# Smoothly interpolate the rotation towards the target rotation
		visual_model.rotation.z = lerp_angle(current_rotation, target_rotation, ROTATION_SPEED * delta)

		# Normalize the angle difference to ensure it's between -PI and PI
		var angle_diff = wrapf(visual_model.rotation.z - target_rotation, -PI, PI)

		# Check if the rotation is close enough to the target (within a small threshold)
		if abs(angle_diff) < 0.01:
			if target_rotation == LEFT:
				visual_model.rotation.z = PI  # Snap to the exact target rotation
			else:
				visual_model.rotation.z = target_rotation
			current_direction = target_rotation  # Update the current direction
			is_turning = false  # Finish the turn

# Trigger the jump animation
func jump_anim():
	var anim_select = "parameters/Jump/request" if velocity.x == 0 else "parameters/RunJump/request"
	anim_tree.set(anim_select, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# Wall jump logic
func wall_jump():
	if not is_on_floor() and (player_raycast_left.is_colliding() or player_raycast_right.is_colliding()):
		can_wall_jump = true
		#print("Can wall jump!")

		# Handle wall jump when jump button is pressed
		if Input.is_action_just_pressed("jump"):
			var wall_jump_direction := Vector3.ZERO

			if player_raycast_left.is_colliding():
				log_move("Jumped to Right")
				wall_jump_direction = Vector3(WALL_JUMP_VELOCITY.x, WALL_JUMP_VELOCITY.y, 0) # Jump right off the wall
			elif player_raycast_right.is_colliding():
				log_move("Jumped to Left")
				wall_jump_direction = Vector3(-WALL_JUMP_VELOCITY.x, WALL_JUMP_VELOCITY.y, 0) # Jump left off the wall

			velocity = wall_jump_direction # Apply the wall jump velocity
			can_wall_jump = false # Reset wall jump state after jumping
	else:
		can_wall_jump = false

var colliding = false
func detect_raycasts():
	if player_raycast_left.is_colliding() and !colliding:
		colliding = true
		print("Collider: ",player_raycast_left.get_collider().name, " ", player_raycast_left.get_collision_point())
	elif player_raycast_right.is_colliding() and !colliding:
		colliding = true
		print("Collider: ",player_raycast_right.get_collider().name , " ", player_raycast_right.get_collision_point())
	elif !player_raycast_left.is_colliding() and !player_raycast_right.is_colliding():
		colliding = false

# Log Movement Inputs
func log_move(move:String):
	print("Move: ",move)

# Key Inputs
func mov_key_pressed():
	if Input.is_action_just_pressed("move_up"):
		pass
	if Input.is_action_just_pressed("move_down"):
		pass
	if Input.is_action_just_pressed("move_left"):
		pass
	if Input.is_action_just_pressed("move_right"):
		pass
	if Input.is_action_just_pressed("jump"):
		pass
	if Input.is_action_just_pressed("crouch"):
		pass

# Movement Functions
# Run Movements
func mov_run():
	pass

func mov_sprint():
	pass

func mov_turn():
	pass

# Jump Movements
func mov_jump():
	pass

func mov_vault():
	pass

# Crouch Movements
func mov_roll():
	pass

func mov_slide():
	pass

# Wall Movements
func mov_climb():
	pass

func mov_hang():
	pass

func mov_ledge():
	pass

# Pole Movements
func mov_swing():
	pass