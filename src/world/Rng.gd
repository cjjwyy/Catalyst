class_name RngService
extends RandomNumberGenerator

# T3.8: 游戏逻辑唯一随机源。继承 RandomNumberGenerator, 保持 seed/state/randi_range API 兼容;
# 额外提供确定性 shuffle/pick/fork, 供手牌、世界规则、催化剂尘与预演共用。

func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := self.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func pick(arr: Array):
	if arr.is_empty():
		return null
	return arr[self.randi_range(0, arr.size() - 1)]

func fork() -> RngService:
	var r := RngService.new()
	r.seed = seed
	r.state = state
	return r

func seed_hex() -> String:
	return "%08x" % (seed & 0xffffffff)
