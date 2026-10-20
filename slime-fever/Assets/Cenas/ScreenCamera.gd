extends Camera2D

var shake_amount: float = 0.0
var default_offset: Vector2

func _ready() -> void:
	# Adiciona a câmera a um grupo global para ser encontrada facilmente
	add_to_group("camera")
	default_offset = offset

func _process(delta: float) -> void:
	if shake_amount > 0:
		# Sorteia uma posição aleatória com base na intensidade atual do shake
		offset = default_offset + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		# Reduz o tremor gradualmente a cada frame (suavização)
		shake_amount = lerp(shake_amount, 0.0, delta * 14.0)
		
		# Se o tremor ficar muito baixo, desliga e reseta a posição original
		if shake_amount < 0.1:
			shake_amount = 0.0
			offset = default_offset

# Função pública que qualquer objeto pode chamar para tremer a tela
func start_shake(intensity: float) -> void:
	shake_amount = intensity

