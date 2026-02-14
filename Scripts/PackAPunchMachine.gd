extends Node3D
class_name PackAPunchMachine

@export_group("Interaction")
@export var interact_distance: float = 2.2
@export var prompt_text: String = "Press [E] to Pack-a-Punch"
@export var fail_text: String = "Not enough Essence"
@export var maxed_text: String = "Already max tier"

@export_group("References")
@export var player_path: NodePath = ^"../Player"
@export var prompt_label_path: NodePath = ^"PromptLabel3D"


var _player: Node = null
var _prompt: Node = null
var _in_range := false
var _flash_timer := 0.0
var _flash_message := ""

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_prompt = get_node_or_null(prompt_label_path)
	_set_prompt_visible(false)

func _process(delta: float) -> void:
	if _player == null:
		return

	_in_range = global_position.distance_to(_player.global_position) <= interact_distance
	if _in_range:
		_update_prompt_default()
		if Input.is_action_just_pressed("interact"):
			_try_pack_a_punch()
	else:
		_set_prompt_visible(false)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_message = ""
			if _in_range:
				_update_prompt_default()

func _try_pack_a_punch() -> void:
	var spell_caster := _find_spell_caster(_player)
	if spell_caster == null:
		_flash("SpellCaster not found", 1.0)
		return

	var kind := _get_current_spell_kind(spell_caster)
	if kind == &"":
		_flash("No spell equipped", 1.0)
		return

	if not PackAPunch.can_upgrade(kind):
		_flash(maxed_text, 1.0)
		return

	var cost := PackAPunch.get_next_cost(kind)
	var wallet := get_node_or_null("/root/EssenceWallet")
	if wallet == null:
		_flash("EssenceWallet missing", 1.0)
		return
	if not wallet.spend(cost):
		_flash(fail_text + " (" + str(cost) + ")", 1.0)
		return


	PackAPunch.upgrade(kind)

	_apply_upgraded_spelldata_to_slot(spell_caster, kind)

	_flash("Upgraded to " + PackAPunch.get_display_name(kind), 1.25)

func _apply_upgraded_spelldata_to_slot(spell_caster: Object, kind: StringName) -> void:
	if spell_caster == null:
		return

	if not _has_prop(spell_caster, &"spell"):
		return

	var current_sd: Resource = spell_caster.get("spell")
	if current_sd == null:
		return

	var upgraded := PackAPunch.apply_upgrade_to_spelldata(kind, current_sd)
	spell_caster.set("spell", upgraded)


	# If SpellCaster uses the slot resources as authoritative, it should pick this up on next switch.
	# If it caches current spell internally, refresh if such a method exists (no refactor required).
	if spell_caster.has_method("refresh_current_spelldata"):
		spell_caster.call("refresh_current_spelldata")

func _update_prompt_default() -> void:
	if _prompt == null:
		return
	_set_prompt_visible(true)

	if _flash_message != "":
		_set_prompt_text(_flash_message)
		return

	var spell_caster := _find_spell_caster(_player)
	if spell_caster == null:
		_set_prompt_text(prompt_text)
		return

	var kind := _get_current_spell_kind(spell_caster)
	if kind == &"":
		_set_prompt_text(prompt_text + "\n(No spell equipped)")
		return

	var t := PackAPunch.get_tier(kind)
	if PackAPunch.can_upgrade(kind):
		var cost := PackAPunch.get_next_cost(kind)
		_set_prompt_text("%s\n%s (T%d → T%d) Cost: %d" % [
			prompt_text,
			PackAPunch.get_display_name(kind),
			t, t + 1, cost
		])
	else:
		_set_prompt_text("%s\n%s (T%d) %s" % [
			prompt_text,
			PackAPunch.get_display_name(kind),
			t,
			maxed_text
		])

func _flash(msg: String, seconds: float) -> void:
	_flash_message = msg
	_flash_timer = seconds
	if _in_range:
		_set_prompt_visible(true)
		_set_prompt_text(msg)

func _set_prompt_visible(v: bool) -> void:
	if _prompt == null:
		return
	if _prompt is Node3D:
		_prompt.visible = v
	elif _prompt.has_method("set_visible"):
		_prompt.call("set_visible", v)

func _set_prompt_text(t: String) -> void:
	if _prompt == null:
		return
	if _prompt is Label3D:
		(_prompt as Label3D).text = t
	elif _prompt.has_method("set_text"):
		_prompt.call("set_text", t)
	elif _has_prop(_prompt, &"text"):
		_prompt.set("text", t)

func _find_spell_caster(player: Node) -> Object:
	if player == null:
		return null
	return player.get_node_or_null("SpellCaster")

func _get_current_spell_kind(spell_caster: Object) -> StringName:
	# Your HUD uses: if _spell_caster != null and ("spell" in _spell_caster): sd = _spell_caster.spell
	if spell_caster == null:
		return &""

	if _has_prop(spell_caster, &"spell"):
		var sd: Resource = spell_caster.get("spell")
		return _kind_from_spelldata(sd)

	if spell_caster.has_method("get_current_spelldata"):
		var sd2 = spell_caster.call("get_current_spelldata")
		return _kind_from_spelldata(sd2)

	return &""

func _kind_from_spelldata(sd: Variant) -> StringName:
	if sd == null:
		return &""
	if sd is Resource:
		var r := sd as Resource

		# Recommended: set SpellData.resource_name to "fireball"/"chainlightning"/"magicmissile"
		if r.resource_name != "":
			return StringName(r.resource_name.to_lower())

		# fallback identifiers if you have them
		if _has_prop(r, &"spell_key"):
			return StringName(str(r.get("spell_key")).to_lower())
		if _has_prop(r, &"id"):
			return StringName(str(r.get("id")).to_lower())

	return &""

func _has_prop(obj: Object, prop: StringName) -> bool:
	if obj == null:
		return false
	for p in obj.get_property_list():
		if StringName(p.name) == prop:
			return true
	return false
