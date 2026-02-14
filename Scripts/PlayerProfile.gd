extends Node
class_name PlayerProfile

const SAVE_PATH := "user://player_profile.cfg"
const SECTION := "profile"
const KEY_NAME := "player_name"
const KEY_CLIENT_ID := "client_id"

var player_name: String = "tester"
var client_id: String = ""

func _ready() -> void:
	load_profile()
	_ensure_client_id()

func set_player_name(new_name: String) -> void:
	player_name = _sanitize_name(new_name)
	save_profile()

func _sanitize_name(s: String) -> String:
	var t := s.strip_edges()
	if t.is_empty():
		return "tester"
	if t.length() > 24:
		t = t.left(24)
	return t

func _ensure_client_id() -> void:
	if client_id.strip_edges() != "":
		return

	# Anonymous per-install ID
	var crypto := Crypto.new()
	client_id = crypto.generate_random_bytes(16).hex_encode()

	save_profile()

func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		player_name = _sanitize_name(str(cfg.get_value(SECTION, KEY_NAME, player_name)))
		client_id = str(cfg.get_value(SECTION, KEY_CLIENT_ID, "")).strip_edges()

func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_NAME, player_name)
	cfg.set_value(SECTION, KEY_CLIENT_ID, client_id)
	cfg.save(SAVE_PATH)
