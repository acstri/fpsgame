extends Area3D
class_name DeathZone

@export var player_group := "player"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(player_group):
		return

	# Prefer a real death method on the player if it exists
	if body.has_method("die"):
		body.die()
		return

	# Fallback: emit damage or set HP to 0 if your player uses a health component
	if body.has_method("take_damage"):
		body.take_damage(999999)
		return

	# Last resort: free the player (not ideal, but prevents softlock)
	body.queue_free()
