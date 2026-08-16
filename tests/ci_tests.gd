extends SceneTree

# CI 专用核心自检入口: run_tests 失败时以非零码退出, 让 GitHub Actions 正确失败。
func _initialize() -> void:
	var ok: bool = CatalystTests.run_all()
	quit(0 if ok else 1)
