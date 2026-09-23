extends CanvasLayer

@onready var percent: Label = %Percent
@onready var stocks: HBoxContainer = %Stocks
@onready var info: Label = %Info
@onready var game_over: Label = %GameOver
@onready var anim: AnimationPlayer = $AnimationPlayer

func update_stats(damage: float, kos: int, time: float, lives: int) -> void:
	percent.text = "%d%%" % int(damage)
	percent.modulate = Color.WHITE.lerp(Color(1, 0.2, 0.15), clampf(damage / 150.0, 0.0, 1.0))
	info.text = "KOs  %d\n%.1fs" % [kos, time]
	for i in stocks.get_child_count():
		stocks.get_child(i).visible = i < lives

func ko_flash() -> void:
	anim.stop()
	anim.play("ko_flash")

func show_game_over(kos: int, time: float) -> void:
	game_over.text = "KO'd!\n%d KOs in %.1fs" % [kos, time]
	anim.play("game_over")
