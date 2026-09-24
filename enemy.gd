class_name Enemy
extends Fighter

const WINDUP_TIME = 0.3

var target: Fighter
var stage_rect: Rect2
var windup := 0.0
var has_landed := false

func read_input() -> void:
	move_dir = 0.0
	jump_pressed = false
	jump_held = true
	down_held = false
	attack_pressed = false

	# rise out of the ground on first landing, and stand still until that finishes
	if not has_landed and is_on_floor():
		has_landed = true
		play_anim(&"appear")
	if anim and anim.animation == &"appear" and anim.is_playing():
		return

	var pos := global_position + center

	if pos.x < stage_rect.position.x or pos.x > stage_rect.end.x or pos.y > stage_rect.end.y:
		windup = 0.0
		move_dir = signf(stage_rect.get_center().x - pos.x)
		jump_pressed = velocity.y > 0.0 and can_double_jump
		return

	if not is_instance_valid(target) or hitstun > 0.0:
		windup = 0.0
		return

	var to_target := target.global_position + target.center - pos

	if windup > 0.0:
		windup -= get_physics_process_delta_time()
		if windup <= 0.0:
			sprite.self_modulate = Color.WHITE
			attack_pressed = true
		return

	if to_target.x != 0.0:
		facing = signf(to_target.x)
	if absf(to_target.x) > 70.0:
		move_dir = facing

	var ahead := pos.x + move_dir * 80.0
	if ahead < stage_rect.position.x or ahead > stage_rect.end.x:
		move_dir = 0.0

	if to_target.y < -120.0:
		if is_on_floor() and randf() < 0.04:
			jump_pressed = true
		elif not is_on_floor() and velocity.y > -100.0 and can_double_jump and randf() < 0.1:
			jump_pressed = true
	elif to_target.y > 120.0 and is_on_floor():
		down_held = true

	if absf(to_target.x) < 110.0 and absf(to_target.y) < 80.0 and cooldown <= 0.0 and randf() < 0.04:
		windup = WINDUP_TIME
		sprite.self_modulate = Color(2.0, 1.8, 0.5)
