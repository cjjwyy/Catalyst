class_name SoundManager
extends Node

# T3.3: 程序合成占位音效; 反应连锁触发短促"叮", 音高随连锁对数升阶, 里程碑换基频。
# 逻辑测试只验证 tone 数据与 pitch 计算, 不依赖真实音频输出。

var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "ChainTone"
	player.volume_db = -8.0
	add_child(player)

func play_chain(chain: int) -> void:
	if player == null:
		return
	var base_freq := 523.0  # C5
	if chain >= 1000:
		base_freq = 1046.5  # C6
	elif chain >= 500:
		base_freq = 880.0   # A5
	elif chain >= 100:
		base_freq = 784.0   # G5
	elif chain >= 50:
		base_freq = 698.5   # F5
	elif chain >= 10:
		base_freq = 659.3   # E5
	player.pitch_scale = pitch_for_chain(chain)
	player.stream = make_tone(base_freq, 0.09)
	player.play()

# pitch_scale = 1 + 0.05 * log2(chain), 与行动计划 T3.3 一致
func pitch_for_chain(chain: int) -> float:
	var c: int = maxi(chain, 1)
	return 1.0 + 0.05 * (log(maxf(float(c), 1.0)) / log(2.0))

func make_tone(freq: float, duration: float = 0.09) -> AudioStreamWAV:
	var sample_rate := 22050
	var frames := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var t := 0.0
	for i in range(frames):
		t = float(i) / sample_rate
		var env := exp(-t * 22.0)
		var wave := sin(TAU * freq * t) * 0.55 + sin(TAU * freq * 2.0 * t) * 0.18
		var v := int(clamp(wave * env, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xff
		data[i * 2 + 1] = (v >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
