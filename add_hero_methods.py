with open('C:/Users/mixao/myproject/game/scripts/hero3d.gd', encoding='utf-8', errors='ignore') as f:
    s = f.read()

methods = '''
func respawn_to_safe() -> void:
	if last_safe_position == Vector3.ZERO:
		return
	global_position = last_safe_position + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	if has_method("reset_physics_interpolation"):
		call("reset_physics_interpolation")
	elif Engine.has_singleton("PhysicsServer3D") == false:  # no-op
		pass

func _physics_process(delta: float) -> void:
	_safe_timer += delta
	if _safe_timer >= 0.5:
		_safe_timer = 0.0
		if is_on_floor():
			last_safe_position = global_position
	# vertical failsafe
	if global_position.y < (lowest_floor_y - 15.0) and last_safe_position != Vector3.ZERO:
		respawn_to_safe()
'''

if '_physics_process' in s and 'last_safe_position' in s and 'respawn_to_safe' not in s:
    # append
    s2 = s + '\n' + methods
    open('C:/Users/mixao/myproject/game/scripts/hero3d.gd', 'w', encoding='utf-8').write(s2)
    print('ok')
else:
    print('no')
