extends SceneTree
## Проверка звука этапа 10: шины, зоны реверба по комнатам, тон помещения,
## случайные звуки без повтора, треск факелов, шаги по воде, licenses.md.
## Запуск:
##   godot --headless --path . --script res://debug/audio_check.gd
## Печатает строки AUDIO OK/FAIL и итог AUDIO RESULT=PASS|FAIL.
## Уровень и герой грузятся через load(): их скрипты ссылаются на автолоады,
## которых ещё нет, когда компилируется сам этот скрипт.

const BUSES := ["Music", "SFX", "Ambience", "Footsteps", "Reverb_Small", "Reverb_Large"]
const LICENSES := "res://_docs/licenses.md"

var fails := 0
var dungeon: Node3D
var frames := 0


func _initialize() -> void:
	dungeon = load("res://scripts/dungeon.gd").new()
	root.add_child(dungeon)
	dungeon.build()


func _process(_dt: float) -> bool:
	# Пара кадров: зонам нужно попасть в физическое пространство.
	frames += 1
	if frames < 4:
		return false
	_check_buses()
	_check_reverb_zones()
	_check_ambience()
	_check_torches()
	_check_footsteps()
	_check_licenses()
	print("AUDIO RESULT=", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	return true


func _ok(cond: bool, what: String) -> void:
	print("AUDIO ", "OK   " if cond else "FAIL ", what)
	if not cond:
		fails += 1


func _check_buses() -> void:
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		_ok(i > 0 and AudioServer.get_bus_send(i) == &"Master", "шина %s → Master" % b)
	for b in ["Reverb_Small", "Reverb_Large"]:
		var i := AudioServer.get_bus_index(b)
		_ok(i > 0 and AudioServer.get_bus_effect_count(i) == 1
			and AudioServer.get_bus_effect(i, 0) is AudioEffectReverb, "реверб на шине " + b)


## Зона под точкой — так же, как её ищет сам AudioStreamPlayer3D.
func _zone_at(pos: Vector3) -> Area3D:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = pos
	q.collision_mask = zone_mask()
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for hit in dungeon.get_world_3d().direct_space_state.intersect_point(q, 8):
		var a := hit["collider"] as Area3D
		if a != null and a.reverb_bus_enabled:
			return a
	return null


func _check_reverb_zones() -> void:
	var rooms: Array[Dictionary] = dungeon.audio.rooms
	var small := rooms.filter(func(r): return not r["large"])
	var large := rooms.filter(func(r): return r["large"])
	for r in rooms:
		print("AUDIO room cells=", (r["cells"] as Array).size(), " bus=",
			(r["area"] as Area3D).reverb_bus_name, " amount=", (r["area"] as Area3D).reverb_bus_amount)
	_ok(not small.is_empty() and not large.is_empty(), "есть и малые, и большие комнаты")
	for pair in [[small, &"Reverb_Small"], [large, &"Reverb_Large"]]:
		if (pair[0] as Array).is_empty():
			continue
		var c: Vector2i = pair[0][0]["cells"][0]
		var zone: Area3D = _zone_at(dungeon.cell_center(c.x, c.y) + Vector3(0, 1.6, 0))
		_ok(zone != null and zone.reverb_bus_name == pair[1]
			and zone.reverb_bus_amount >= 0.5 and zone.reverb_bus_amount <= 0.8001,
			"точка в комнате попадает в зону %s" % pair[1])
	# Коридор шириной в две клетки — без зоны (сухой звук).
	var corridor := Vector2i(-1, -1)
	for y in dungeon.map_h:
		for x in dungeon.map_w:
			if corridor.x < 0 and not dungeon.is_wall(x, y) and dungeon.audio.room_at(
					dungeon.cell_center(x, y)).is_empty():
				corridor = Vector2i(x, y)
	_ok(corridor.x >= 0 and _zone_at(dungeon.cell_center(corridor.x, corridor.y)
		+ Vector3(0, 1.0, 0)) == null, "коридор вне зон реверба")


func _check_ambience() -> void:
	var tone: AudioStreamPlayer = dungeon.audio.room_tone
	_ok(tone != null and tone.playing and tone.bus == &"Ambience"
		and is_equal_approx(tone.volume_db, -18.0)
		and (tone.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"тон помещения: луп, Ambience, −18 дБ, играет")
	var shots: Node3D = dungeon.audio.rooms[0]["oneshots"]
	var last := ""
	var repeats := 0
	var kinds := {}
	for i in 60:
		var k: String = shots.play_random()
		if k == last:
			repeats += 1
		last = k
		kinds[k] = true
		var p: AudioStreamPlayer3D = shots._player
		if p.volume_db < -12.0 or p.volume_db > -6.0 or p.pitch_scale < 0.9 or p.pitch_scale > 1.1:
			repeats += 100
	_ok(repeats == 0 and kinds.size() == 5 and not kinds.has(""),
		"случайные звуки: 5 видов, без повтора подряд, −12..−6 дБ, тон 0.9–1.1")
	_ok(shots.min_interval == 8.0 and shots.max_interval == 25.0, "интервал 8–25 с")
	var drips := dungeon.find_children("DripSound", "AudioStreamPlayer3D", true, false)
	_ok(not drips.is_empty(), "капель со звуком: %d" % drips.size())


func _check_torches() -> void:
	var crackles := dungeon.find_children("Crackle", "AudioStreamPlayer3D", true, false)
	var good := 0
	for c in crackles:
		var p := c as AudioStreamPlayer3D
		if p.playing and p.bus == &"SFX" and p.max_distance == 10.0 and p.unit_size == 2.0 \
				and p.area_mask == zone_mask() \
				and (p.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD:
			good += 1
	_ok(not crackles.is_empty() and good == crackles.size(),
		"факелы трещат: %d из %d" % [good, crackles.size()])


func _check_footsteps() -> void:
	var puddle: Node3D = dungeon.puddles[0]
	_ok(dungeon.surface_at(puddle.position) == "water", "в луже поверхность water")
	var c: Vector2i = dungeon.audio.rooms[0]["cells"][0]
	var dry: Vector3 = dungeon.cell_center(c.x, c.y)
	var far_from_water := true
	for p in dungeon.puddles:
		if Vector2(p.position.x - dry.x, p.position.z - dry.z).length() < 2.0:
			far_from_water = false
	_ok(not far_from_water or dungeon.surface_at(dry) == "stone", "на сухом полу поверхность stone")
	var hero: CharacterBody3D = load("res://scripts/hero3d.gd").new()
	hero.position = puddle.position + Vector3(0, 0.2, 0)
	root.add_child(hero)
	var heard := []
	hero.footstep.connect(func(s): heard.append(s))
	hero.footstep.emit(hero.surface_under())
	var water_stream: AudioStream = hero.footsteps.stream
	hero.footstep.emit("stone")
	var stone_stream: AudioStream = hero.footsteps.stream
	_ok(heard == ["water", "stone"] and water_stream is AudioStreamRandomizer
		and water_stream != stone_stream and hero.footsteps.bus == &"Footsteps",
		"шаг в луже звучит водой, на камне — камнем")
	for s in hero.footsteps._sets:
		var r: AudioStreamRandomizer = hero.footsteps._sets[s]
		_ok(r.streams_count >= 3 and is_equal_approx(r.random_pitch, 1.1)
			and is_equal_approx(r.random_volume_offset_db, 2.0), "рандомизатор шагов " + s)
	hero.queue_free()


func _check_licenses() -> void:
	var text := FileAccess.get_file_as_string(LICENSES)
	_ok(not text.is_empty(), "есть " + LICENSES)
	var missing: Array[String] = []
	for dir in ["res://audio", "res://assets/audio"]:
		for f in _audio_files(dir):
			if not text.contains(f.get_file()):
				missing.append(f)
	_ok(missing.is_empty(), "licenses.md перечисляет все звуки" +
		("" if missing.is_empty() else ": нет " + ", ".join(missing)))


func _audio_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["wav", "ogg", "mp3"]:
			out.append(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_audio_files(dir.path_join(sub)))
	return out


## Sfx.AUDIO_ZONE_MASK, но через узел автолоада — по той же причине, что load().
func zone_mask() -> int:
	return root.get_node("Sfx").AUDIO_ZONE_MASK
