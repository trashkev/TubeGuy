extends RigidBody2D

var grabbed = false
var grabber :Node2D
func _physics_process(delta):
	if grabbed:
		global_transform.origin = grabber.global_position
func grab(p_grabber :Node2D):
	grabber = p_grabber
	if grabbed:
		return
	freeze = true
	grabbed = true

func drop(impulse = Vector2.ZERO):
	if grabbed:
		freeze = false
		apply_central_impulse(impulse)
		grabbed = false
