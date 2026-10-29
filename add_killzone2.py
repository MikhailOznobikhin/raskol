with open('C:/Users/mixao/myproject/game/scripts/dungeon.gd', encoding='utf-8', errors='ignore') as f:
    s = f.read()
if 'KillZone' in s:
    print('exists')
    raise SystemExit
code = '''
## KillZone
func _add_kill_zone() -> void:
	var kill := Area3D.new()
	kill.name = "KillZone"
	kill.collision_layer = 1 << 4  # layer 5
	kill.collision_mask = 1 << 1   # layer 2
	var shape := BoxShape3D.new()
	shape.size = Vector3(map_w * T + 40.0, 4.0, map_h * T + 40.0)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(map_w * T * 0.5, -12.0, map_h * T * 0.5)
	kill.add_child(col)
	add_child(kill)
	kill.body_entered.connect(func(body): 
		if body.is_in_group("player") or body is CharacterBody3D:
			if body.has_method("respawn_to_safe"):
				body.respawn_to_safe()
	)
'''
s2 = s + '\n' + code
# add call in _ready if exists
if '_ready()' in s2 and '_add_kill_zone()' not in s2:
    # try to insert after first line of _ready body
    s2 = s2.replace('func _ready() -> void:\n', 'func _ready() -> void:\n\t_add_kill_zone()\n')
with open('C:/Users/mixao/myproject/game/scripts/dungeon.gd', 'w', encoding='utf-8').write(s2)
print('done')
