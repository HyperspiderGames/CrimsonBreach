extends CharacterBody2D

@export var speed := 120.0
@export var health := 50
@export var patrol_distance := 160.0
@export var player_detection_distance := 110.0
@export var ledge_check_distance := 72.0
@export var wall_check_distance := 16.0
@export var punch_damage := 10
@export var punch_cooldown := 0.6
@export var debug_draw_rays := false

@onready var crimson_animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var patrol_direction := -1.0
var spawn_position := Vector2.ZERO
var gravity := ProjectSettings.get_setting("physics/2d/default_gravity") as float
var player: Node2D
var next_punch_time_msec := 0
var floor_ray_origin := Vector2.ZERO
var floor_ray_target := Vector2.ZERO
var floor_ray_hit := false
var wall_ray_origin := Vector2.ZERO
var wall_ray_target := Vector2.ZERO
var wall_ray_hit := false
var detection_ray_origin := Vector2.ZERO
var detection_ray_target := Vector2.ZERO
var detection_ray_hit := false

func _ready() -> void:
	spawn_position = global_position
	player = _find_player()
	_play_animation("WalkPatrol")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if not is_instance_valid(player):
		player = _find_player()
	_update_detection_ray()

	if _player_is_close():
		velocity.x = 0.0
		_face_player()
		_play_animation("PunchPlayer")
		_try_punch_player()
	else:
		_update_patrol_direction()
		velocity.x = patrol_direction * speed
		crimson_animation.flip_h = patrol_direction < 0.0
		_play_animation("WalkPatrol")

	move_and_slide()

	if debug_draw_rays:
		queue_redraw()

func take_damage(amount: int) -> void:
	health -= amount
	print("Crimson Unit hit! health: ", health)
	if health <= 0:
		die()

func die() -> void:
	if get_parent() != null:
		get_parent().queue_free()
		return
	queue_free()

func _find_player() -> Node2D:
	var player_node := get_tree().get_first_node_in_group("player") as Node2D
	if player_node != null:
		return player_node

	print("Player node not found in group 'player'. Ensure the player node is added to this group.")
	return get_tree().get_root().find_child("player", true, false) as Node2D

func _player_is_close() -> bool:
	if not is_instance_valid(player):
		return false
	var vertical_limit := _get_scaled_collision_extents().y + 32.0
	return global_position.distance_to(player.global_position) <= player_detection_distance \
		and abs(player.global_position.y - global_position.y) <= vertical_limit

func _face_player() -> void:
	if not is_instance_valid(player):
		return
	crimson_animation.flip_h = player.global_position.x < global_position.x

func _update_patrol_direction() -> void:
	if _reached_patrol_limit() or is_on_wall() or _is_wall_ahead() or not _has_floor_ahead():
		patrol_direction *= -1.0

func _reached_patrol_limit() -> bool:
	if patrol_direction > 0.0:
		return global_position.x >= spawn_position.x + patrol_distance
	return global_position.x <= spawn_position.x - patrol_distance

func _has_floor_ahead() -> bool:
	var extents := _get_scaled_collision_extents()
	floor_ray_origin = collision_shape.global_position + Vector2(patrol_direction * (extents.x + 4.0), extents.y - 2.0)
	floor_ray_target = floor_ray_origin + Vector2(0.0, ledge_check_distance)
	floor_ray_hit = not _raycast_hits(floor_ray_origin, floor_ray_target).is_empty()
	return floor_ray_hit

func _is_wall_ahead() -> bool:
	var extents := _get_scaled_collision_extents()
	wall_ray_origin = collision_shape.global_position
	wall_ray_target = wall_ray_origin + Vector2(patrol_direction * (extents.x + wall_check_distance), 0.0)
	wall_ray_hit = not _raycast_hits(wall_ray_origin, wall_ray_target).is_empty()
	return wall_ray_hit

func _raycast_hits(ray_origin: Vector2, ray_target: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(ray_origin, ray_target)
	query.exclude = [self]
	return get_world_2d().direct_space_state.intersect_ray(query)

func _get_collision_extents() -> Vector2:
	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if rectangle_shape != null:
		return rectangle_shape.size * 0.5
	return Vector2(24.0, 48.0)

func _get_scaled_collision_extents() -> Vector2:
	var extents := _get_collision_extents()
	var scale_x := abs(collision_shape.global_scale.x) as float
	var scale_y := abs(collision_shape.global_scale.y) as float
	return Vector2(extents.x * scale_x, extents.y * scale_y)

func _play_animation(animation_name: StringName) -> void:
	if crimson_animation.animation != animation_name:
		crimson_animation.play(animation_name)

func _update_detection_ray() -> void:
	var direction := patrol_direction
	if is_instance_valid(player):
		var offset_x := player.global_position.x - global_position.x
		if abs(offset_x) > 0.001:
			direction = sign(offset_x)
	if is_zero_approx(direction):
		direction = -1.0 if crimson_animation.flip_h else 1.0
	detection_ray_origin = collision_shape.global_position
	detection_ray_target = detection_ray_origin + Vector2(direction * player_detection_distance, 0.0)
	detection_ray_hit = _player_is_close()

func _try_punch_player() -> void:
	if not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	var now := Time.get_ticks_msec()
	if now < next_punch_time_msec:
		return
	next_punch_time_msec = now + int(punch_cooldown * 1000.0)
	player.take_damage(punch_damage)

func _draw() -> void:
	if not debug_draw_rays:
		return
	_draw_debug_ray(floor_ray_origin, floor_ray_target, floor_ray_hit)
	_draw_debug_ray(wall_ray_origin, wall_ray_target, wall_ray_hit)
	_draw_debug_ray(detection_ray_origin, detection_ray_target, detection_ray_hit)

func _draw_debug_ray(ray_origin: Vector2, ray_target: Vector2, hit: bool) -> void:
	if ray_origin == Vector2.ZERO and ray_target == Vector2.ZERO:
		return
	var color := Color.GREEN if hit else Color.RED
	draw_line(to_local(ray_origin), to_local(ray_target), color, 2.0)
	draw_circle(to_local(ray_target), 3.0, color)


func _on_punch_trigger_entered(body: Node2D) -> void:
	if body == player and _player_is_close():
		_try_punch_player()
