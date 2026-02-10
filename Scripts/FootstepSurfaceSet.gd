extends Resource
class_name FootstepSurfaceSet

@export var surface_id: StringName = &"default"
@export var clips: Array[AudioStream] = []

@export_group("Optional per-surface tweaks")
@export_range(-60.0, 12.0, 0.1) var volume_db_add := 0.0
@export_range(0.1, 3.0, 0.01) var pitch_min := 0.95
@export_range(0.1, 3.0, 0.01) var pitch_max := 1.08
