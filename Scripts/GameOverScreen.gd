extends Control
class_name GameOverScreen

signal restart_pressed()

@export_group("UI Refs")
@export var restart_button: Button
@export var kills_label: Label
@export var leaderboard_label: Label

@export_group("Leaderboard")
@export var default_player_name: String = "tester"
@export var leaderboard_top_n: int = 10
@export var enable_leaderboard_debug: bool = false

var _ready_ok := false

func _ready() -> void:
	visible = false
	_autowire()

	_ready_ok = _validate_ui()
	if not _ready_ok:
		set_process(false)
		return

	restart_button.pressed.connect(_on_restart_pressed)

	var kc := get_node_or_null("/root/KillCounter")
	if kc != null and kc.has_signal("changed"):
		kc.changed.connect(_on_kills_changed)

	var lb := get_node_or_null("/root/Leaderboard_Client")
	if lb != null:
		if lb.has_signal("top_received"):
			lb.top_received.connect(_on_lb_top_received)
		if enable_leaderboard_debug and lb.has_signal("submitted"):
			lb.submitted.connect(func(ok: bool, resp: Dictionary) -> void:
				print("LB submit ok=", ok, " resp=", resp)
			)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_kills()

func show_game_over() -> void:
	if not _ready_ok:
		return

	_refresh_kills()
	visible = true

	if leaderboard_label != null:
		leaderboard_label.text = "Loading leaderboard..."

	_submit_score_and_fetch()

func hide_game_over() -> void:
	visible = false

func _on_restart_pressed() -> void:
	var kc := get_node_or_null("/root/KillCounter")
	if kc != null and kc.has_method("reset"):
		kc.reset()

	restart_pressed.emit()

func _submit_score_and_fetch() -> void:
	var lb := get_node_or_null("/root/Leaderboard_Client")
	if lb == null:
		_set_leaderboard_status("Leaderboard unavailable")
		return

	var kills := _get_kills()
	var player_name := _get_player_name()

	# LeaderboardClient should queue fetch_top if submit is in-flight
	if lb.has_method("submit_score"):
		lb.submit_score(player_name, kills)
	if lb.has_method("fetch_top"):
		lb.fetch_top(leaderboard_top_n)

func _get_kills() -> int:
	var kc := get_node_or_null("/root/KillCounter")
	if kc != null and kc.has_method("get_kills"):
		return int(kc.get_kills())
	return 0

func _get_player_name() -> String:
	var profile := get_node_or_null("/root/Player_Profile")
	if profile != null and "player_name" in profile:
		var n := str(profile.player_name).strip_edges()
		if not n.is_empty():
			return n
	return default_player_name

func _refresh_kills() -> void:
	if kills_label == null:
		return
	kills_label.text = "Kills: %d" % _get_kills()

func _on_kills_changed(_kills: int) -> void:
	if visible:
		_refresh_kills()

# Replace ONLY your _on_lb_top_received() with this version.
# It collapses duplicates by client_id (keeps the best score per client_id),
# then sorts and displays the top N.

func _on_lb_top_received(ok: bool, top: Array, resp: Dictionary) -> void:
	if enable_leaderboard_debug:
		print("LB top ok=", ok, " top_count=", top.size(), " resp=", resp)

	if leaderboard_label == null:
		return

	if not ok:
		var msg := "Leaderboard unavailable"
		if resp.has("error"):
			msg += ": %s" % str(resp.get("error"))
		elif resp.has("http_code"):
			msg += ": HTTP %s" % str(resp.get("http_code"))
		leaderboard_label.text = msg
		return

	if top.is_empty():
		leaderboard_label.text = "No scores yet"
		return

	# 1) Keep best entry per client_id (fallback key if missing)
	var best_by_id: Dictionary = {} # key -> Dictionary(row)
	for item in top:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item

		var cid := str(row.get("client_id", "")).strip_edges()
		if cid.is_empty():
			# fallback so rows without client_id don't all overwrite each other
			cid = "no_cid_%s_%s" % [str(row.get("name", "?")), str(row.get("ts", ""))]

		var score := int(row.get("score", 0))
		if not best_by_id.has(cid):
			best_by_id[cid] = row
		else:
			var prev: Dictionary = best_by_id[cid]
			var prev_score := int(prev.get("score", 0))
			if score > prev_score:
				best_by_id[cid] = row

	# 2) Convert to array
	var unique: Array = []
	for k in best_by_id.keys():
		unique.append(best_by_id[k])

	# 3) Sort by score desc, then ts desc (if present)
	unique.sort_custom(func(a: Variant, b: Variant) -> bool:
		var da := a as Dictionary
		var db := b as Dictionary
		var sa := int(da.get("score", 0))
		var sb := int(db.get("score", 0))
		if sa != sb:
			return sa > sb

		# tie-breaker: timestamp string desc (ISO sorts lexicographically)
		var ta := str(da.get("ts", ""))
		var tb := str(db.get("ts", ""))
		return ta > tb
	)

	# 4) Trim to top N
	var n = clamp(leaderboard_top_n, 1, 50)
	if unique.size() > n:
		unique = unique.slice(0, n)

	# 5) Render
	var lines: Array[String] = ["Top %d (best per player)" % unique.size()]
	for i in range(unique.size()):
		var row := unique[i] as Dictionary
		lines.append("%d. %s - %d" % [
			i + 1,
			str(row.get("name", "?")),
			int(row.get("score", 0))
		])

	leaderboard_label.text = "\n".join(lines)


func _set_leaderboard_status(text: String) -> void:
	if leaderboard_label != null:
		leaderboard_label.text = text

func _autowire() -> void:
	if restart_button == null:
		restart_button = get_node_or_null("PanelContainer/VBoxContainer/RestartButton") as Button
	if kills_label == null:
		kills_label = get_node_or_null("PanelContainer/VBoxContainer/KillsLabel") as Label
	if leaderboard_label == null:
		leaderboard_label = get_node_or_null("PanelContainer/VBoxContainer/LeaderboardLabel") as Label

func _validate_ui() -> bool:
	if restart_button == null:
		push_error("GameOverScreen: restart_button not assigned/found.")
		return false
	if kills_label == null:
		push_warning("GameOverScreen: kills_label not assigned/found (Kills will not display).")
	return true
