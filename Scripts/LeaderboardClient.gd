extends Node
class_name LeaderboardClient

@export var endpoint_url: String = "https://script.google.com/macros/s/AKfycbyIls8-vGLfWzDUYyup38X3Q4X6P9Wk6n7-5PfMv6KTBD7Ni00HI5TH_1QPXvALAjYs8w/exec" # Apps Script /exec URL

signal submitted(ok: bool, response: Dictionary)
signal top_received(ok: bool, top: Array, response: Dictionary)

var _http: HTTPRequest
var _busy := false
var _pending_kind: String = "" # "submit" or "top"

# Simple queue: supports 1 pending fetch after a submit
var _queued_fetch_n: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_http = HTTPRequest.new()
	_http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_http)

	_http.request_completed.connect(_on_request_completed)
	_http.max_redirects = 8

func is_busy() -> bool:
	return _busy

func cancel() -> void:
	if _busy:
		_http.cancel_request()
	_busy = false
	_pending_kind = ""
	_queued_fetch_n = -1

func submit_score(player_name: String, score: int) -> void:
	endpoint_url = endpoint_url.strip_edges()
	if endpoint_url == "":
		submitted.emit(false, {"error": "endpoint_url not set"})
		return
	if _busy:
		submitted.emit(false, {"error": "busy"})
		return

	_busy = true
	_pending_kind = "submit"

	var run_id := str(Time.get_unix_time_from_system())

	var cid := ""
	var profile := get_node_or_null("/root/Player_Profile")
	if profile != null and "client_id" in profile:
		cid = str(profile.client_id)

	var url := "%s?name=%s&score=%s&run_id=%s&client_id=%s" % [
		endpoint_url,
		player_name.uri_encode(),
		str(score).uri_encode(),
		run_id.uri_encode(),
		cid.uri_encode()
	]

	var headers := PackedStringArray(["User-Agent: GodotLeaderboard/1.0"])
	var err := _http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_busy = false
		_pending_kind = ""
		submitted.emit(false, {"error": "request failed", "code": err})


func fetch_top(n: int = 10) -> void:
	endpoint_url = endpoint_url.strip_edges()
	if endpoint_url == "":
		top_received.emit(false, [], {"error": "endpoint_url not set"})
		return

	n = clamp(n, 1, 50)

	if _busy:
		_queued_fetch_n = n
		return

	_busy = true
	_pending_kind = "top"

	var url := "%s?n=%d" % [endpoint_url, n]
	var headers := PackedStringArray(["User-Agent: GodotLeaderboard/1.0"])

	var err := _http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_busy = false
		_pending_kind = ""
		top_received.emit(false, [], {"error": "request failed", "code": err})

func _on_request_completed(_result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var text := body.get_string_from_utf8()
	var trimmed := text.strip_edges()

	var content_type := ""
	for h in headers:
		if h.to_lower().begins_with("content-type:"):
			content_type = h
			break

	# Non-JSON response: log and fail gracefully
	var looks_json := trimmed.begins_with("{") or trimmed.begins_with("[")
	if not looks_json:
		var err_resp := {
			"error": "non_json",
			"http_code": response_code,
			"content_type": content_type,
			"body": trimmed.left(700)
		}
		push_error("Leaderboard: Non-JSON response. code=%d %s\n%s" % [response_code, content_type, trimmed.left(700)])

		if _pending_kind == "top":
			top_received.emit(false, [], err_resp)
		else:
			submitted.emit(false, err_resp)

		_finish_and_maybe_run_queued()
		return

	# JSON parse
	var parsed = JSON.parse_string(trimmed)
	if typeof(parsed) != TYPE_DICTIONARY:
		var err_resp2 := {
			"error": "bad_json_shape",
			"http_code": response_code,
			"content_type": content_type,
			"body": trimmed.left(700)
		}
		push_error("Leaderboard: JSON parsed but not a Dictionary. code=%d\n%s" % [response_code, trimmed.left(700)])

		if _pending_kind == "top":
			top_received.emit(false, [], err_resp2)
		else:
			submitted.emit(false, err_resp2)

		_finish_and_maybe_run_queued()
		return

	var resp: Dictionary = parsed
	var ok_http := response_code >= 200 and response_code < 300
	var ok_app := bool(resp.get("ok", true))
	var ok := ok_http and ok_app

	if _pending_kind == "top":
		var top: Array = []
		if resp.has("top") and typeof(resp["top"]) == TYPE_ARRAY:
			top = resp["top"]
		top_received.emit(ok, top, resp)
	else:
		submitted.emit(ok, resp)

	_finish_and_maybe_run_queued()

func _finish_and_maybe_run_queued() -> void:
	_busy = false
	_pending_kind = ""

	if _queued_fetch_n != -1:
		var n := _queued_fetch_n
		_queued_fetch_n = -1
		# Run queued fetch immediately
		fetch_top(n)
