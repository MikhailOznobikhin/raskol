with open('C:/Users/mixao/myproject/game/scripts/dungeon.gd', encoding='utf-8', errors='ignore') as f:
    content = f.read()
idx = content.find('func _build_collision')
if idx >= 0:
    end = content.find('\nfunc ', idx + 1)
    if end == -1:
        end = len(content)
    chunk = content[idx:end]
    open('C:/Users/mixao/myproject/game/collision_chunk.txt', 'w', encoding='utf-8').write(chunk)
    print('done')
else:
    print('not found')
