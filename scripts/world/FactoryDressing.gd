class_name FactoryDressing
extends Node3D
var world: FactoryWorld
var key_light: SpotLight3D

func _ready() -> void:
	# Back wall: sheet steel, actual seams, pipework and electrical service boxes.
	for i in 5:
		WorldBuilder.box(self, Vector3(3.8 + i * 2.05, 1.72, -3.78), Vector3(1.99, 2.65, 0.10), Color("59636a"), true, 0.35)
		for y: float in [0.48, 2.93]:
			WorldBuilder.cylinder(self, Vector3(3.8 + i * 2.05, y, -3.70), 0.023, 0.025, Color("a0a7a3"), Vector3(PI/2,0,0))
	for y: float in [3.15, 3.48]:
		_pipe(Vector3(3.0,y,-3.43),Vector3(12.5,y,-3.43),0.044,Color("8e9391"))
	_pipe(Vector3(12.5,3.48,-3.43),Vector3(12.5,0.8,-3.43),0.057,Color("8e9391"))
	var valve := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.095
	torus.outer_radius = 0.13
	torus.rings = 20
	torus.ring_segments = 12
	valve.mesh = torus
	valve.material_override = WorldBuilder.material(Color("9b5147"),0.25)
	valve.position = Vector3(12.5,1.68,-3.23)
	valve.rotation.x = PI/2
	add_child(valve)
	WorldBuilder.box(self,Vector3(12.5,1.68,-3.23),Vector3(0.23,0.025,0.025),Color("9b5147"),false,0.25)
	WorldBuilder.box(self,Vector3(12.5,1.68,-3.23),Vector3(0.025,0.23,0.025),Color("9b5147"),false,0.25)
	WorldBuilder.box(self,Vector3(4.0,1.55,-3.50),Vector3(0.72,1.1,0.35),Color("77827e"),true,0.35)
	WorldBuilder.text(self,"ЩР / 04",Vector3(4.0,1.8,-3.31),0.10,Color("292e2d"))
	WorldBuilder.text(self,"⚡",Vector3(4.0,1.4,-3.31),0.21,Color("dfbb69"))
	_pipe(Vector3(4.0,2.1,-3.5),Vector3(4.0,3.5,-3.5),0.025,Color("303a3b"))
	WorldBuilder.text(self,"М–13 / ОБРАБОТКА СЫРЬЯ",Vector3(8.2,3.77,-3.64),0.20,Color("d6d2bc"))
	# Finished goods at the edge of the room, clear of the production route.
	for x: float in [5.25,6.0,6.75]:
		WorldBuilder.box(self,Vector3(x,0.13,10.8),Vector3(0.12,0.26,1.25),Color("6d6047"))
	for z: float in [10.35,10.63,10.91,11.19]:
		WorldBuilder.box(self,Vector3(6.0,0.31,z),Vector3(1.65,0.09,0.22),Color("927a51"))
	for i in 3:
		WorldBuilder.box(self,Vector3(5.45+i*0.55,0.58,10.8),Vector3(0.48,0.44,0.65),Color("a98c5d"))
		WorldBuilder.box(self,Vector3(5.45+i*0.55,0.805,10.8),Vector3(0.06,0.006,0.65),Color("cbb98d"),false)
	# Air receiver, feet and pressure gauge.
	var tank := StaticBody3D.new()
	tank.position = Vector3(12.5,0.95,10.35)
	add_child(tank)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.34
	cylinder.height = 1.75
	shape.shape = cylinder
	tank.add_child(shape)
	WorldBuilder.cylinder(tank,Vector3.ZERO,0.32,1.6,Color("6c4540"))
	WorldBuilder.cylinder(tank,Vector3(0,0.81,0),0.27,0.05,Color("78817f"))
	WorldBuilder.cylinder(tank,Vector3(0,0.82,0.15),0.095,0.045,Color("d3d0bb"),Vector3(PI/2,0,0))
	WorldBuilder.text(tank,"6 БАР",Vector3(0,0.82,0.177),0.026,Color("252c2c"))
	WorldBuilder.text(self,"СЖАТЫЙ ВОЗДУХ",Vector3(12.5,2.15,11.84),0.13,Color("c9c8b5"),Vector3(0,PI,0))
	# A key light adds form and real shadows to the machine, with a gentle warm tone.
	key_light = SpotLight3D.new()
	key_light.position = Vector3(7.6,3.9,3.6)
	key_light.light_color = Color("f5e4ca")
	key_light.light_energy = 1.8
	key_light.spot_range = 9.0
	key_light.spot_angle = 58
	key_light.shadow_enabled = int(Storage.settings.quality)>0
	key_light.shadow_bias = 0.08
	key_light.shadow_normal_bias = 1.2
	add_child(key_light)
	key_light.look_at(Vector3(8.0,0.5,0.3))
	key_light.add_to_group("quality_lights")

func _pipe(a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var pipe := WorldBuilder.cylinder(self,(a+b)*0.5,radius,a.distance_to(b),color)
	pipe.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func _process(_delta: float) -> void:
	# Atmospheric blackout also affects this extra fixture.
	key_light.light_energy = 0.0 if world.events != null and world.events.blackout_active else 1.8
