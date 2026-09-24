class_name Fighter
extends CharacterBody2D

const SPEED = 700.0
const GROUND_ACCEL = 9000.0
const AIR_ACCEL = 5000.0
const LAUNCH_DRAG = 250.0          # horizontal slow-down while in hitstun
const JUMP_VELOCITY = -1050.0
const DOUBLE_JUMP_VELOCITY = -850.0
const JUMP_CUT = 0.45              # upward speed kept when jump is released early
const MAX_FALL_SPEED = 1100.0
const FAST_FALL_SPEED = 1500.0
const COYOTE_TIME = 0.1
const JUMP_BUFFER = 0.12
const DROP_TIME = 0.25
const SPIN_TIME = 0.4

const ATTACK_DAMAGE = 10.0
const SPIN_DAMAGE = 7.0
const ATTACK_ACTIVE_TIME = 0.12
const ATTACK_COOLDOWN = 0.28
const BASE_KNOCKBACK = 450.0
const KNOCKBACK_SCALING = 11.0
const INVULNERABLE_AFTER_HIT = 0.25

const PLATFORM_LAYER = 3           # physics layer of the one-way platforms

@export var weight := 1.0
@export var tint := Color.WHITE
@export var team := 0
@export var sprite_faces_left := false

var damage := 0.0
var facing := 1.0
var can_double_jump := false
var jumping := false
var hitstun := 0.0
var invulnerable := 0.0
var attack_time := 0.0
var cooldown := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var drop_time := 0.0
var already_hit: Array[Fighter] = []

# Filled in by read_input() every physics frame.
var move_dir := 0.0
var jump_pressed := false
var jump_held := false
var down_held := false
var attack_pressed := false

@onready var sprite: Node2D = $Sprite
@onready var anim := sprite as AnimatedSprite2D  # null for a plain Sprite2D
@onready var center: Vector2 = $CollisionShape2D.position
@onready var sprite_home: Vector2 = sprite.position
@onready var sprite_scale: Vector2 = sprite.scale
var hitbox: Area2D
var spinbox: Area2D
var slash: Polygon2D
var spin_tween: Tween
var squash_tween: Tween

func _ready() -> void:
	add_to_group("fighters")
	collision_layer = 2
	collision_mask = 1
	set_collision_mask_value(PLATFORM_LAYER, true)
	sprite.modulate = tint
	hitbox = make_area(Vector2(90, 80))
	spinbox = make_area(Vector2(120, 130))
	spinbox.position = center
	slash = make_slash()
	hitbox.add_child(slash)

func read_input() -> void:
	pass

func _physics_process(delta: float) -> void:
	read_input()
	cooldown -= delta
	hitstun -= delta
	invulnerable -= delta
	coyote -= delta
	jump_buffer -= delta
	drop_time -= delta
	var in_control := hitstun <= 0.0
	var on_floor := is_on_floor()

	if on_floor:
		coyote = COYOTE_TIME
		can_double_jump = true
	else:
		velocity += get_gravity() * delta
		if in_control and down_held and velocity.y > 0.0:
			velocity.y = FAST_FALL_SPEED
		else:
			velocity.y = minf(velocity.y, MAX_FALL_SPEED)

	if in_control and down_held and on_floor:
		drop_time = DROP_TIME
	set_collision_mask_value(PLATFORM_LAYER, drop_time <= 0.0)

	if jump_pressed:
		jump_buffer = JUMP_BUFFER
	if in_control and jump_buffer > 0.0:
		if coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			jumping = true
			coyote = 0.0
			jump_buffer = 0.0
			squash(Vector2(0.75, 1.25))
		elif jump_pressed and can_double_jump:
			velocity.y = DOUBLE_JUMP_VELOCITY
			jumping = true
			can_double_jump = false
			jump_buffer = 0.0
			spin()

	if jumping and velocity.y >= 0.0:
		jumping = false
	elif jumping and not jump_held:
		velocity.y *= JUMP_CUT
		jumping = false

	var target_x := move_dir * SPEED if in_control else 0.0
	var accel := LAUNCH_DRAG
	if in_control:
		accel = GROUND_ACCEL if on_floor else AIR_ACCEL
	velocity.x = move_toward(velocity.x, target_x, accel * delta)
	if in_control and move_dir != 0.0:
		facing = signf(move_dir)
	sprite.set("flip_h", (facing < 0.0) != sprite_faces_left)

	if in_control and attack_pressed and cooldown <= 0.0:
		attack()

	hitbox.position = center + Vector2(55 * facing, 0)
	slash.scale.x = facing
	if attack_time > 0.0:
		attack_time -= delta
		hit_overlaps(hitbox, ATTACK_DAMAGE)
	if spin_tween and spin_tween.is_running():
		hit_overlaps(spinbox, SPIN_DAMAGE)

	sprite.modulate.a = 0.35 if invulnerable > 0.0 and int(invulnerable * 20.0) % 2 == 0 else 1.0

	var was_in_air := not on_floor
	var fall_speed := velocity.y
	move_and_slide()
	if was_in_air and is_on_floor():
		stop_spin()
		jumping = false
		if fall_speed > 400.0:
			squash(Vector2(1.3, 0.75))
	update_anim()

func play_anim(anim_name: StringName) -> void:
	if anim and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)

func update_anim() -> void:
	# one-shot animations (attack, appear, die) run to the end before looping ones resume
	if anim == null or (anim.is_playing() and not anim.sprite_frames.get_animation_loop(anim.animation)):
		return
	var moving := is_on_floor() and absf(velocity.x) > 50.0
	play_anim(&"walk" if moving and anim.sprite_frames.has_animation(&"walk") else &"idle")

func attack() -> void:
	attack_time = ATTACK_ACTIVE_TIME
	cooldown = ATTACK_COOLDOWN
	already_hit.clear()
	var t := create_tween()
	t.tween_property(sprite, "position", sprite_home + Vector2(25 * facing, 0), 0.05)
	t.tween_property(sprite, "position", sprite_home, 0.1)
	slash.modulate.a = 1.0
	play_anim(&"attack")
	create_tween().tween_property(slash, "modulate:a", 0.0, 0.18)

func hit_overlaps(area: Area2D, amount: float) -> void:
	for body in area.get_overlapping_bodies():
		if body is Fighter and body != self and body.team != team and body not in already_hit:
			already_hit.append(body)
			body.take_hit(self, amount)

func take_hit(attacker: Fighter, amount: float) -> void:
	if invulnerable > 0.0:
		return
	damage += amount
	var dir := signf(global_position.x - attacker.global_position.x)
	if dir == 0.0:
		dir = attacker.facing
	var force := (BASE_KNOCKBACK + damage * KNOCKBACK_SCALING) / weight
	velocity = Vector2(dir, -0.8).normalized() * force
	hitstun = 0.12 + damage * 0.004
	invulnerable = INVULNERABLE_AFTER_HIT
	can_double_jump = true
	jumping = false
	stop_spin()

	sprite.self_modulate = Color(4, 4, 4)
	create_tween().tween_property(sprite, "self_modulate", Color.WHITE, 0.15)

	get_tree().current_scene.on_hit(force)

func respawn(at: Vector2) -> void:
	global_position = at - center
	velocity = Vector2.ZERO
	damage = 0.0
	hitstun = 0.0
	invulnerable = 2.0
	stop_spin()
	reset_physics_interpolation()
	play_anim(&"appear")

func spin() -> void:
	stop_spin()
	already_hit.clear()
	var dir := -1.0 if velocity.x < 0 else 1.0
	spin_tween = create_tween()
	spin_tween.tween_property(sprite, "rotation", TAU * dir, SPIN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	spin_tween.tween_callback(func(): sprite.rotation = 0.0)

func stop_spin() -> void:
	if spin_tween:
		spin_tween.kill()
	sprite.rotation = 0.0

func squash(amount: Vector2) -> void:
	if squash_tween:
		squash_tween.kill()
	sprite.scale = sprite_scale * amount
	squash_tween = create_tween()
	squash_tween.tween_property(sprite, "scale", sprite_scale, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func make_area(size: Vector2) -> Area2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.add_child(col)
	add_child(area)
	return area

func make_slash() -> Polygon2D:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 9:
		var a := lerpf(-1.2, 1.2, i / 8.0)
		outer.append(Vector2(cos(a) * 50.0 - 20.0, sin(a) * 50.0))
		inner.append(Vector2(cos(a) * 30.0 - 20.0, sin(a) * 38.0))
	inner.reverse()
	var poly := Polygon2D.new()
	poly.polygon = outer + inner
	poly.color = Color(1, 1, 0.85)
	poly.modulate.a = 0.0
	return poly
