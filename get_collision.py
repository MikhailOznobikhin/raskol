with open('C:/Users/mixao/myproject/game/scripts/dungeon.gd') as f:
    content = f.read()
idx = content.find('func _build_collision')
if idx >= 0:
    end = content.find('\nfunc ', idx + 1)
    if end == -1:
        end = len(content)
    chunk = content[idx:end]
    open('C:/Users/mixao/myproject/game/collision_chunk.txt', 'w').write(chunk)
    print('done', len(chunk))
else:
    print('not found')
