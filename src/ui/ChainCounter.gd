extends Label

func pop_anim() -> void:
	scale = Vector2(1.5, 1.5)
	var t = create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func set_chain(n: int) -> void:
	text = "连锁: %d" % n
	pop_anim()

func set_total(n: int) -> void:
	text = "总和: %d" % n