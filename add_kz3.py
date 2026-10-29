with open('C:/Users/mixao/myproject/game/scripts/dungeon.gd', encoding='utf-8', errors='ignore') as f:
    s = f.read()
if 'KillZone' in s:
    print('exists')
    raise SystemExit
code = "\n## KillZone\nfunc _add_kill_zone() -> void:\n\tvar kill := Area3D.new()\n\tkill.name = \"KillZone\"\n\tkill.collision_layer = 1 << 4\n\tkill.collision_mask = 1 << 1\n\tvar shape := BoxShape3D.new()\n\tshape.size = Vector3(map_w * T + 40.0, 4.0, map_h * T + 40.0)\n\tvar col := CollisionShape3D.new()\n\tcol.shape = shape\n\tcol.position = Vector3(map_w * T * 0.5, -12.0, map_h * T * 0.5)\n\tkill.add_child(col)\n\tadd_child(kill)\n\tkill.body_entered.connect(func(body):\n\t\tif body.is_in_group(\"player\") or body is CharacterBody3D:\n\t\t\tif body.has_method(\"respawn_to_safe\"):\n\t\t\t\tbody.respawn_to_safe()\n\t)\n"
s2 = s + code
if '_ready()' in s2 and '_add_kill_zone()' not in s2:
    s2 = s2.replace('func _ready() -> void:\n', 'func _ready() -> void:\n\t_add_kill_zone()\n')
with open('C:/Users/mixao/myproject/game/scripts/dungeon.gd', 'w', encoding='utf-8') as f:
    f.write(s2)
print('done')
