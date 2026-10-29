with open('C:/Users/mixao/myproject/game/scripts/dungeon.gd', encoding='utf-8', errors='ignore') as f:
    s=f.read()
idx = s.find('var env')
if idx >= 0:
    start = max(0, idx-60)
    end = min(len(s), idx+900)
    print(s[start:end])
