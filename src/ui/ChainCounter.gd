extends Label

func pop_anim(magnitude: float = 1.5) -> void:
	scale = Vector2(magnitude, magnitude)
	var t = create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func set_chain(n: int) -> void:
	text = "连锁: %d" % n
	# T3.4: 里程碑放大更明显, 但上限 2.2 倍防止遮挡
	var magnitude := 1.5
	if n >= 1000:
		magnitude = 2.2
	elif n >= 500:
		magnitude = 2.0
	elif n >= 100:
		magnitude = 1.8
	elif n >= 50:
		magnitude = 1.65
	pop_anim(magnitude)

func set_total(n: int) -> void:
	text = "总和: %d" % n
