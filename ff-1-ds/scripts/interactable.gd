class_name Interactable
extends Node3D
## A proximity interaction point. It intentionally has no physics shape:
## the party leader's cell distance decides what is in reach.

var prompt: String = ""
var kind: String = ""
var payload: Dictionary = {}
var enabled: bool = true
var focus_offset: Vector3 = Vector3(0.0, 1.1, 0.0)


func setup(new_kind: String, new_prompt: String, new_payload: Dictionary, world_pos: Vector3) -> Interactable:
	kind = new_kind
	prompt = new_prompt
	payload = new_payload
	position = world_pos
	return self


func focus_position() -> Vector3:
	return global_position + focus_offset


func activate() -> Dictionary:
	if not enabled:
		return {}
	return {
		"kind": kind,
		"prompt": prompt,
		"payload": payload
	}
