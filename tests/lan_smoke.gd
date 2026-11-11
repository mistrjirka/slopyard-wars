extends SceneTree
## Launch two headless instances with user arguments "host" and "client".
## Checks real ENet transport, directional authority and snapshot privacy on localhost.
const World = preload("res://src/world/world_rules.gd")
var game: Node
var host_mode := false
var elapsed := 0.0
var send_timer := 0.0
var started := false
var moved := false
var finish_delay := 0.0


func _initialize() -> void:
	_setup.call_deferred()


func _setup() -> void:
	game = root.get_node("Game")
	game.seller.online_enabled = false
	game.score_path = "res://artifacts/lan_scores.json"
	host_mode = "host" in OS.get_cmdline_user_args()
	if host_mode:
		if game.host("Host") != OK:
			quit(1)
	else:
		await create_timer(0.75).timeout
		if game.join_game("127.0.0.1", "Client") != OK:
			quit(1)


func _process(delta: float) -> bool:
	if game == null:
		return false
	elapsed += delta
	if elapsed > 15:
		push_error("LAN smoke timed out: " + ("host" if host_mode else "client"))
		quit(1)
		return false
	if host_mode:
		_host_tick(delta)
	else:
		_client_tick(delta)
	return false


func _host_tick(delta: float) -> void:
	if not started and game.state.players.size() == 2:
		game.start_match()
		game.me().chats[99] = [{"speaker": "private", "text": "host only"}]
		game.text_player(1, "Private host text from Lucky.")
		for pid in game.state.players:
			if pid != 1:
				game.text_player(pid, "Private client text from Lucky.")
		game.act("post_sale", {"item_id": game.me().inventory[0].id, "price": 15})
		started = true
	if not started:
		return
	for peer_id in game.state.players:
		if peer_id != 1 and game.state.players[peer_id].pos.distance_to(World.SPAWN) > 20:
			moved = true
	if moved:
		finish_delay += delta
		if finish_delay > 1:
			print("LAN HOST PASS: observed authoritative client movement")
			quit(0)


func _client_tick(delta: float) -> void:
	if game.state.phase != "playing" or game.me().is_empty():
		return
	send_timer += delta
	if send_timer >= 0.1:
		send_timer = 0.0
		game.act("move", {"direction": Vector2.RIGHT})
	if game.me().pos.distance_to(World.SPAWN) > 24:
		if not game.state.players[1].chats.is_empty():
			push_error("Host private chat leaked to client")
			quit(1)
			return
		if not game.state.players[1].lucky_messages.is_empty() or game.me().lucky_messages.size() != 1 or game.me().lucky_messages[0].text != "Private client text from Lucky.":
			push_error("Lucky texts were not delivered privately to the client")
			quit(1)
			return
		for listing: Dictionary in game.state.listings:
			if listing.has("buyer_max"):
				push_error("Private buyer ceiling leaked to client")
				quit(1)
				return
		print("LAN CLIENT PASS: received movement and filtered snapshots")
		game.act("move", {"direction": Vector2.ZERO})
		quit(0)
