extends CharacterBody2D

@export var speed = 350.0
@export var jump_velocity = -350.0
@onready var player_animation: AnimatedSprite2D = $player_animation

signal fireball_fired(position, rotation)

var player_health = 100
signal health_changed(current)

var is_attacking = false

var alive = true
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var last_direction: float = 1.0  # 1.0 = right, -1.0 = left

var max_health = 100

func _ready():
	player_health = max_health  # also add this line to your existing _ready!
	player_animation.animation_finished.connect(_on_animation_finished)

func take_damage(amount):
	if not alive:
		return
	player_health -= amount
	print("player hit! health: ", player_health)
	health_changed.emit(player_health)
	if player_health <= 0:
		die()

func _physics_process(delta):
	if !alive:
		return

	# Handle attack input first
	if Input.is_action_just_pressed("basic_attack") and not is_attacking:
		is_attacking = true
		player_animation.play("basic_attack")
		var dir = (get_global_mouse_position() - global_position).angle()
		fireball_fired.emit(global_position, dir)

	# Only set movement animations if NOT attacking
	if not is_attacking:
		if not is_on_floor():
			player_animation.play("jump")
		elif velocity.x > 1 or velocity.x < -1:
			player_animation.play("walk")
		else:
			player_animation.play("idle")

	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction: float = Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * speed
		last_direction = direction
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()

	# Use last_direction so the sprite keeps facing the right way when standing still
	player_animation.flip_h = (last_direction == -1.0)

func _on_animation_finished():
	if player_animation.animation == "basic_attack":
		is_attacking = false

func die() -> void:
	player_animation.play("death")
	alive = false
	