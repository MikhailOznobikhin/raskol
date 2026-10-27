# Иконки предметов

Каталог `scripts/item_catalog.gd` собирает ItemType из `assets/text/lore.json` и ищет
иконку в таком порядке (первое совпадение выигрывает):

1. `assets/ui/icons/<id>.png`
2. `assets/ui/icons/icon_<id>.png`
3. `assets/ui/icons/<icon>.png` и `assets/ui/icons/icon_<icon>.png`
4. то же в старой папке `assets/ui/`

Поэтому сюда класть файлы нужно только для предметов, у которых иконки ещё нет.
Формат: PNG, 64×64, прозрачный фон, предмет по центру с отступом ~4 px.
Имя файла = `id` предмета из lore.json (или значение его поля `icon`).

## Уже есть (лежат в assets/ui/, скачивать не нужно)

- `ring_power.png` → `assets/ui/icon_ring.png`
- `amulet_ward.png` → `assets/ui/icon_amulet.png`
- `scroll_fire.png` → `assets/ui/icon_scroll.png`
- `potion_heal.png` → `assets/ui/icon_potion.png`
- `boots_wanderer.png` → `assets/ui/icon_boots.png`
- `cloak_shadow.png` → `assets/ui/icon_cloak.png`

## Нужны (под эти id предметы появятся, когда добавим оружие и броню)

- `weapon_iron.png` — меч/клинок (двуручный, слот «ОРУЖИЕ»)
- `shield_round.png` — круглый щит (слот «ЩИТ»)
- `helmet_iron.png` — шлем (слот «ШЛЕМ»)
- `chest_chain.png` — кольчуга/нагрудник (слот «БРОНЯ»)
- `belt_leather.png` — кожаный пояс (слот «ПОЯС»)
- `guards_leather.png` — рукавицы (слот «РУКАВИЦЫ»)

Если вместо точного id положить `icon_<имя>.png`, поиск тоже сработает.
Без иконки предмет всё равно работает — в слоте виден только фон ячейки.
