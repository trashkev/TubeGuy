extends Node2D

@onready var area = $Area2D
var grabbing :bool = false
var grabbedGrabbable :RigidBody2D

func _physics_process(delta):
	if Input.is_action_pressed("grab") and area.has_overlapping_bodies():
		for body in area.get_overlapping_bodies():
			if body.is_in_group("grabbable"):
				grabbing = true
				grabbedGrabbable = body
				grabbedGrabbable.grab(self)
				break
	if not Input.is_action_pressed("grab") and grabbing:
		grabbedGrabbable.drop()
		grabbing = false
