extends CharacterBody2D

const SPEED = 800.0
const JUMP_VELOCITY = -800.0
const DOUBLE_JUMP_VELOCITY = -700.0
const SPIN_TIME = 0.4

var can_double_jump := false
var spin_tween: Tween

@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		can_double_jump = true

	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif can_double_jump:
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false
			spin()
	
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	var was_in_air := not is_on_floor()
	move_and_slide()
	
	if was_in_air and is_on_floor():
		stop_spin()
	
func spin() -> void:
	stop_spin()
	var dir := -1.0 if velocity.x < 0 else 1.0
	spin_tween = create_tween()
	spin_tween.tween_property(sprite, "rotation", TAU * dir, SPIN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	spin_tween.tween_callback(func(): sprite.rotation = 0.0)

func stop_spin() -> void:
	if spin_tween:
		spin_tween.kill()
	sprite.rotation = 0.0

func _ready() -> void:
	var tiles: TileMapLayer = get_parent().get_node("TileMapLayer")
	var rect := tiles.get_used_rect()
	var half := Vector2(tiles.tile_set.tile_size) * 0.5
	var top_left := tiles.to_global(tiles.map_to_local(rect.position) - half)
	var bottom_right := tiles.to_global(tiles.map_to_local(rect.end) - half)
	
	$Camera2D.limit_bottom = int(bottom_right.y)
