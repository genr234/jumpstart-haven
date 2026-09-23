extends Node2D

@export var enemy_scene: PackedScene
@export var stocks := 3
@export var max_enemies := 4
@export var blast_margin_side := 650.0
@export var blast_margin_top := 700.0
@export var blast_margin_bottom := 450.0

@onready var player: Fighter = $Player
@onready var camera: Camera2D = $Camera2D
@onready var tiles: TileMapLayer = $TileMapLayer
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var spawn_timer: Timer = $SpawnTimer
@onready var hud = $HUD

var stage_rect: Rect2
var blast_rect: Rect2
var kos := 0
var spawned := 0
var time_alive := 0.0
var shake_strength := 0.0
var hitstop_end := 0.0
var is_over := false

func _ready() -> void:
	Engine.time_scale = 1.0

	var rect := tiles.get_used_rect()
	var half := Vector2(tiles.tile_set.tile_size) * 0.5
	var top_left := tiles.to_global(tiles.map_to_local(rect.position) - half)
	var bottom_right := tiles.to_global(tiles.map_to_local(rect.end) - half)
	stage_rect = Rect2(top_left, bottom_right - top_left)
	blast_rect = stage_rect.grow_individual(blast_margin_side, blast_margin_top, blast_margin_side, blast_margin_bottom)

	player.respawn(player_spawn.global_position)
	player.invulnerable = 0.0
	camera.position = stage_rect.get_center()
	camera.reset_smoothing()
	hud.update_stats(0.0, 0, 0.0, stocks)
	spawn_timer.timeout.connect(spawn_enemy)
	spawn_enemy()

func _process(delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() / 1000.0 >= hitstop_end:
		Engine.time_scale = 1.0

	if is_over:
		return

	time_alive += delta
	for f: Fighter in get_tree().get_nodes_in_group("fighters"):
		if not f.is_queued_for_deletion() and not blast_rect.has_point(f.global_position + f.center):
			knock_out(f)
	hud.update_stats(player.damage, kos, time_alive, stocks)

func _physics_process(delta: float) -> void:
	update_camera(delta)

func update_camera(delta: float) -> void:
	var focus := stage_rect
	var interest := blast_rect.grow(-250.0)
	for f: Fighter in get_tree().get_nodes_in_group("fighters"):
		var p := f.global_position + f.center
		focus = focus.expand(p.clamp(interest.position, interest.end))
	focus = focus.grow(150.0)

	var view := get_viewport_rect().size
	var z := clampf(minf(view.x / focus.size.x, view.y / focus.size.y), 0.55, 1.0)
	camera.zoom = camera.zoom.lerp(Vector2(z, z), 1.0 - exp(-3.0 * delta))
	camera.position = camera.position.lerp(focus.get_center(), 1.0 - exp(-5.0 * delta))

	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
	shake_strength = move_toward(shake_strength, 0.0, 80.0 * delta)

func spawn_enemy() -> void:
	# one more enemy every three kos
	var alive := get_tree().get_nodes_in_group("fighters").size() - 1
	if is_over or alive >= mini(1 + kos / 3, max_enemies):
		return
	spawned += 1
	var e: Enemy = enemy_scene.instantiate()
	e.target = player
	e.stage_rect = stage_rect
	e.team = 1
	e.tint = Color(1, 0.45, 0.45)
	# spawn big enemy every 8th enemy
	if spawned % 8 == 0:
		e.weight = 2.0
		e.tint = Color(0.6, 0.15, 0.15)
		e.scale = Vector2(1.4, 1.4)
	var x := randf_range(stage_rect.position.x + 150, stage_rect.end.x - 150)
	e.position = Vector2(x, stage_rect.position.y - 400)
	add_child(e)

func on_hit(force: float) -> void:
	hitstop(0.04 + force / 40000.0)
	shake(minf(force / 120.0, 20.0))

func knock_out(f: Fighter) -> void:
	shake(30.0)
	hitstop(0.15)
	hud.ko_flash()
	if f == player:
		stocks -= 1
		hud.update_stats(0.0, kos, time_alive, stocks)
		if stocks <= 0:
			end_game()
		else:
			player.respawn(player_spawn.global_position)
	else:
		kos += 1
		f.queue_free()

func end_game() -> void:
	is_over = true
	spawn_timer.stop()
	player.set_physics_process(false)
	player.hide()
	hud.show_game_over(kos, time_alive)
	await get_tree().create_timer(3.0, true, false, true).timeout
	get_tree().reload_current_scene()

func hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	hitstop_end = maxf(hitstop_end, Time.get_ticks_msec() / 1000.0 + duration)

func shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)
