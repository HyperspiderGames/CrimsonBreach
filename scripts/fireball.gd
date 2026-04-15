extends Area2D

var speed = 450
var hit = false  # stops movement during animation

func _ready():
	body_entered.connect(_on_body_entered)
	add_to_group("fireball")  # ← add this!

func _process(delta):
	if not hit:
		position += transform.x * speed * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(25)  # your fireball damage value
	hit = true
	$AnimatedSprite2D.play("hit")  # whatever your hit animation is called
	await $AnimatedSprite2D.animation_finished
	queue_free()
