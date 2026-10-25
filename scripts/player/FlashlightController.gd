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
var spill_light: SpotLight3D
@onready var actor: PlayerController = get_parent()

func _ready() -> void:
	actor.torch.visible = false
	actor.torch.light_energy = 2.2
	actor.torch.spot_attenuation = 1.5
	actor.torch.light_color = Color("f5ebd7")
	actor.torch.light_cull_mask = 1 | 4
	spill_light = SpotLight3D.new()
	spill_light.name = "FlashlightSoftSpill"
	spill_light.light_energy = 0.16
	spill_light.light_color = Color("e1e6ed")
	spill_light.spot_range = 12
	spill_light.spot_angle = 55
	spill_light.spot_attenuation = 1.5
	spill_light.light_cull_mask = 1 | 4
	spill_light.visible = false
	actor.camera.add_child(spill_light)
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
		spill_light.visible = on
		Audio.effect("click", -8.0)

func _sync_models() -> void:
	if not is_instance_valid(world_model) or not is_instance_valid(actor.body_visual):
		return
	actor.view_arms.update_pose(raise_amount, press_amount)
	actor.body_visual.update_pose()
	var belt := actor.to_global(Vector3(0.225, 0.98 - (1.64 - actor.head.position.y) * 0.6, 0.015))
	world_model.global_transform = actor.view_arms.torch_global_transform()
	if raise_amount < 0.001:
		world_model.global_transform = Transform3D(actor.global_basis * Basis(Vector3.RIGHT, PI / 2), belt)
	world_model.set_render_layer(2)
	view_model.visible = raise_amount > 0.025
	view_model.transform = actor.view_arms.torch_pose
	var lens := view_model.position + Vector3(0, 0, -0.17)
	var downward := smoothstep(0.65, 1.2, -actor.head.rotation.x)
	actor.torch.position = lens.lerp(Vector3(0.14,-0.08,-0.18),downward)
	spill_light.transform = actor.torch.transform
	world_model.update_switch(is_lit, press_amount)
	view_model.update_switch(is_lit, press_amount)
