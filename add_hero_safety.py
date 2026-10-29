with open('C:/Users/mixao/myproject/game/scripts/hero3d.gd', encoding='utf-8', errors='ignore') as f:
    s = f.read()
old = 'signal died'
new = '''var last_safe_position: Vector3 = Vector3.ZERO
var _safe_timer := 0.0
var lowest_floor_y := 0.0

signal died'''
if old in s and 'last_safe_position' not in s:
    s2 = s.replace(old, new)
    open('C:/Users/mixao/myproject/game/scripts/hero3d.gd', 'w', encoding='utf-8').write(s2)
    print('ok')
else:
    print('no')
