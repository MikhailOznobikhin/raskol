files = ['C:/Users/mixao/myproject/game/scripts/main3d.gd', 'C:/Users/mixao/myproject/game/scripts/dungeon.gd']
for fn in files:
    try:
        with open(fn, encoding='utf-8', errors='ignore') as f:
            s=f.read()
        idx = s.find('WorldEnvironment')
        if idx >= 0:
            start = max(0, idx-150)
            end = min(len(s), idx+500)
            print('===', fn, '===')
            print(s[start:end])
            print()
    except Exception as e:
        pass
