# src/sim/core/base_system.gd
class_name BaseSystem
extends RefCounted

var system_id: String = ""
var execution_order: int = 100
var is_enabled: bool = true

func _init(p_id: String = "", p_order: int = 100) -> void:
	system_id = p_id
	execution_order = p_order

func setup(_world_state: Variant) -> void:
	pass

func handle_event(_world_state: Variant, _event_type: String, _event_data: Dictionary) -> void:
	pass

func tick(_world_state: Variant) -> void:
	pass

func teardown(_world_state: Variant) -> void:
	pass
