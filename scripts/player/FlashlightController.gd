class_name FlashlightController
extends Node
## A queued, deterministic draw → button press → light → press → holster sequence.
signal state_changed
enum State { HOLSTERED, DRAWING, PRESS_ON, ON, PRESS_OFF, HOLSTERING }
var state := State.HOLSTERED
var desired_on := false
var is_lit := false
var elapsed := 0.0
var raise_amount := 0.0
var press_amount := 0.0
var world_model: FlashlightModel
var view_model: FlashlightModel
@onready var actor: PlayerController = get_parent()

func _ready() -> void:
	actor.torch.visible = false
	world_model = FlashlightModel.new()
	world_model.name = "BeltAndHandFlashlight"
	world_model.render_layer = 8
	actor.add_child(world_model)
	view_model = FlashlightModel.new()
	view_model.name = "FirstPersonFlashlight"
	view_model.render_layer = 4
	actor.camera.add_child(view_model)
	_sync_models()

func toggle() -> void:
	desired_on = not desired_on
	if state == State.HOLSTERED and desired_on:
		_begin(State.DRAWING)
	elif state == State.ON and not desired_on:
		_begin(State.PRESS_OFF)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	var left := delta
	for step in 10:
		if state == State.HOLSTERED or state == State.ON:
			if state == State.HOLSTERED and desired_on:
				_begin(State.DRAWING)
			elif state == State.ON and not desired_on:
				_begin(State.PRESS_OFF)
			else:
				break
		var duration := _duration()
		var used := minf(left, duration - elapsed)
		elapsed += used
		left -= used
		_sample(duration)
		if elapsed < duration - 0.00001:
			break
		match state:
			State.DRAWING: _begin(State.PRESS_ON)
			State.PRESS_ON:
				_switch(true)
				_begin(State.ON)
			State.PRESS_OFF:
				_switch(false)
				_begin(State.HOLSTERING)
			State.HOLSTERING: _begin(State.HOLSTERED)
		if left <= 0.0:
			break
	_sync_models()

func _begin(next: State) -> void:
	state = next
	elapsed = 0.0
	press_amount = 0.0
	if state == State.ON:
		raise_amount = 1.0
	elif state == State.HOLSTERED:
		raise_amount = 0.0
	state_changed.emit()

func _duration() -> float:
	match state:
		State.DRAWING: return 0.52
		State.PRESS_ON: return 0.28
		State.PRESS_OFF: return 0.26
		State.HOLSTERING: return 0.52
	return 0.0

func _sample(duration: float) -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	match state:
		State.DRAWING: raise_amount = smoothstep(0.15, 1.0, t)
		State.PRESS_ON:
			raise_amount = 1.0
			press_amount = sin(t * PI)
			if t >= 0.5: _switch(true)
		State.PRESS_OFF:
			raise_amount = 1.0
			press_amount = sin(t * PI)
			if t >= 0.5: _switch(false)
		State.HOLSTERING: raise_amount = 1.0 - smoothstep(0.0, 0.9, t)

func _switch(on: bool) -> void:
	if is_lit != on:
		is_lit = on
		actor.torch.visible = on
		Audio.effect("click", -8.0)

func _sync_models() -> void:
	if not is_instance_valid(world_model) or not is_instance_valid(actor.body_visual):
		return
	var belt := actor.to_global(Vector3(0.225, 0.98 - (1.64 - actor.head.position.y) * 0.6, 0.015))
	var hand := actor.body_visual.right_hand_position() + actor.global_basis * Vector3(0, -0.035, -0.035)
	world_model.global_position = belt.lerp(hand, raise_amount)
	world_model.global_rotation = actor.global_rotation + Vector3(lerpf(PI / 2.0, actor.head.rotation.x, raise_amount), 0, -0.05 * raise_amount)
	world_model.set_render_layer(8 if raise_amount < 0.02 else 2)
	view_model.visible = raise_amount > 0.025
	view_model.position = Vector3(0.33, -0.66, -0.12).lerp(Vector3(0.265, -0.32, -0.56), raise_amount)
	view_model.rotation = Vector3(lerpf(PI / 2.0, 0.0, raise_amount), 0, -0.05 * raise_amount)
	actor.torch.position = view_model.position + Vector3(0, 0, -0.17)
	world_model.update_switch(is_lit, press_amount)
	view_model.update_switch(is_lit, press_amount)
