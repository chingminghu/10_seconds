extends SceneTree

const ANCHOR_SCENE := preload("res://scenes/anchor/anchor.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _arrival_count: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var test_root := Node2D.new()
	root.add_child(test_root)

	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(300.0, 40.0)
	floor_shape.position = Vector2(150.0, 320.0)
	floor_shape.shape = floor_rectangle
	floor_body.add_child(floor_shape)
	test_root.add_child(floor_body)

	var anchor := ANCHOR_SCENE.instantiate() as Anchor
	anchor.anchor_id = &"TEST"
	anchor.global_position = Vector2(100.0, 300.0)
	anchor.player_arrived.connect(_on_player_arrived)
	test_root.add_child(anchor)

	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.global_position = Vector2(112.0, 300.0)
	test_root.add_child(player)

	for _tick in 3:
		await physics_frame
	assert(_arrival_count == 0, "Arrival triggered outside the ±10 px center tolerance.")

	player.global_position.x = 100.0
	for _tick in 2:
		await physics_frame
	assert(_arrival_count == 1, "Centered grounded player did not trigger arrival.")

	player.teleport_to(Transform2D(0.0, Vector2(150.0, 300.0)))
	for _tick in 2:
		await physics_frame
	player.teleport_to(Transform2D(0.0, Vector2(100.0, 250.0)))
	for _tick in 2:
		await physics_frame
	assert(_arrival_count == 1, "Airborne player incorrectly triggered centered arrival.")

	print("Centered arrival smoke test passed: tolerance and grounded requirement.")
	test_root.queue_free()
	await physics_frame
	quit(0)


func _on_player_arrived(_anchor: Anchor) -> void:
	_arrival_count += 1

