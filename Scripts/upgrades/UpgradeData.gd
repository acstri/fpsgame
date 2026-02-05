extends Resource
class_name UpgradeData

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""

@export var weight: float = 1.0        # roll chance
@export var max_stacks: int = 99
@export var effect_key: String = ""     # e.g. "damage_up"
@export var effect_value: float = 0.0   # e.g. 0.10 means +10%
