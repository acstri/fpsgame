extends Node
class_name CombatEvents

signal damage_number(world_pos: Vector3, amount: float, is_crit: bool, is_player_target: bool)
signal hurt_flash(is_player: bool)
