extends CharacterBody3D

#export vars
@export var look_sensitivity : float = 0.0008
@export var jump_velocity := 6.0
@export var auto_bhop := true

#camera bob vars
const HEADBOB_MOVE_AMOUNT = 0.06
const HEADBOB_FREQUENCY = 2.4
var headbob_time := 0.0

#ground movement settings
@export var walk_speed := 7.0
@export var sprint_speed := 8.5
@export var ground_accel := 16.0
@export var ground_decel := 7.0
@export var ground_friction := 4.5
var previous_position = Vector3.ZERO

#air movement for bhop and surf
@export var air_cap := 1.10
@export var air_accel := 1100.0
@export var air_move_speed := 900.0

var spawn = Vector3.ZERO
var gravity = 16

const RAY_LENGTH = 1000

signal boost_box

#store input direction pressed
var wish_dir := Vector3.ZERO
var strafe_dir := Vector3.ZERO

#returns our movement speed when called as a float
func get_move_speed() -> float:
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed


#called when player is added to node tree
func _ready() -> void:
	
	spawn = position
	
	#set the global player var to the player 
	Global.player = self
	
	for child in %Body.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)
	

#controls player inputs
func _unhandled_input(event):
	#allows us to toggle between ui mouse movement and camera mouse movement
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	
	#camera rotation 
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity)
			%Camera.rotate_x(-event.relative.y * look_sensitivity)
			%Camera.rotation.x = clamp(%Camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	#lets player reset position
	if Input.is_action_just_pressed("reset"):
		position = spawn
		velocity = Vector3(0,0,0)
	
	if Input.is_action_just_pressed("save"):
		spawn = position
	
	if Input.is_action_pressed("boost"):
		var space_state = get_world_3d().direct_space_state
		var cam = $"%Camera"
		var mousepos = get_viewport().get_mouse_position()
		
		var origin = cam.project_ray_origin(mousepos)
		var end = origin + cam.project_ray_normal(mousepos) * RAY_LENGTH
		var query = PhysicsRayQueryParameters3D.create(origin,end, 2)
	
		
		var result = space_state.intersect_ray(query)
		var backwards = -end
		
		
		if result:
			print(result["collider_id"])
			velocity += (backwards * .00015)
		
		
	if Input.is_action_just_pressed("alternate") and !is_on_floor():
		self.velocity.y = -gravity * 2
		await is_on_floor()
		print("play")
		$HardLand.play("HardLand")

#function to be called for air physics and movement
func _handle_air_physics(delta):
	#gravity acceleration calculation
	self.velocity.y -= gravity * delta
	
	#used for source feeling air physics 
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	
	#wish speed if wish_dir > 0 length capped to air cap 
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	
	#add speed in air until we are capped the if statement goes until we reach cap move speed
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap) 
		self.velocity += accel_speed * wish_dir
		
	
	#determines the speed when you landed and adds it to debug screen
	var ret_move_speed = abs((position - previous_position) / delta)
	Global.debug.add_property("MovementSpeed",ret_move_speed, 1)
	previous_position = position 

#function to be called for ground physics and movement
func _handle_ground_physics(delta):
	#similar to air movement accel and friction on ground
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * delta * get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir
		
	#friction
	var control = max(self.velocity.length(), ground_decel)
	var drop = control * ground_friction * delta
	#choose between the largest value which should be our speed otherwise its 0 
	var new_speed = max(self.velocity.length() - drop, 0.0)
	#prevents divide by 0
	Global.debug.add_property("Current velocity",new_speed, 3)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	#new velocity is a ratio of original speed multiplied by the friction decimal
	self.velocity *= new_speed
	if Input.is_action_pressed("jump"):
		self.velocity += Vector3(
			(self.velocity.x * (2 / (1 + abs(self.velocity.x)))), 
			0,
			(self.velocity.z * (2 / (1 + abs(self.velocity.z)))))
	
	
	_headbob_effect(delta)

#function that handles all physics process every frame, calls ground and air physics
func _physics_process(delta):

	
	#variable to find our input vector normalized
	var input_dir = Input.get_vector("left", "right", "forward", "back").normalized()
	
	#changes/negates input directions based on where camera is facing to give movement relative to front of player
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	strafe_dir = wish_dir.normalized()
	
	#if statement to check where to pass movement to
	if is_on_floor():
		#jump function
		if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
			self.velocity.y = jump_velocity
		_handle_ground_physics(delta)
	else:
		_handle_air_physics(delta)
	
	#slippery
	move_and_slide()
	

func _headbob_effect(delta):
	headbob_time += delta * self.velocity.length()
	%Camera.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * .5) * HEADBOB_MOVE_AMOUNT, #controls horizontal movement
		sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT, #controls vertical movement
		0 #z movement isnt necessary
		)


func _process(delta):
	pass
