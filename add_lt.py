with open('C:/Users/mixao/myproject/game/scripts/dungeon.gd', encoding='utf-8', errors='ignore') as f:
    s = f.read()
if 'leak_test' in s:
    print('exists')
    raise SystemExit
code = "\n\tvar lt = preload('res://debug/leak_test.gd').new()\n\tadd_child(lt)\n"
if '_ready()' in s:
    s2 = s.replace('func _ready() -> void:\n', 'func _ready() -> void:\n' + code)
    with open('C:/Users/mixao/myproject/game/scripts/dungeon.gd', 'w', encoding='utf-8') as f:
        f.write(s2)
    print('done')
else:
    print('no')
