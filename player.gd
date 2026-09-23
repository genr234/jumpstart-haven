extends Fighter

func read_input() -> void:
	move_dir = Input.get_axis("left", "right")
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	down_held = Input.is_action_pressed("down")
	attack_pressed = Input.is_action_just_pressed("attack")
