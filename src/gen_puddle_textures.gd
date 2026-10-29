extends SceneTree
## Генератор текстур лужи (Этап 5).
##
## Лужа — это не плоскость, а декаль (res://scenes/props/puddle.tscn):
## альбом текстуры декали используется как маска, а ORM задаёт глянец.
## Поэтому нужны:
##   puddle_mask_N.png — RGBA, тёмный «мокрый» цвет, альфа = маска пятна;
##   puddle_orm.png    — R = AO 1, G = шероховатость 0.04 (глянец), B = металл 0;
##   puddle_normal.png — плоская нормаль: с ней работает normal_fade, и лужа
##                       проецируется только на пол, а не на стены.
##
## Запуск (пересоздать текстуры после правки формы/контраста):
##   godot --headless --path . --script res://src/gen_puddle_textures.gd
## Скрипт лежит в src/, а не в tools/: каталог tools/ целиком в .gitignore,
## а генератор должен попадать в историю (как src/make_materials.gd).

const DIR := "res://textures/decals"
const SIZE := 512
const VARIANTS := 4


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for v in VARIANTS:
		_mask(v)
	_orm()
	_flat_normal()
	print("PUDDLES textures=%d dir=%s" % [VARIANTS + 2, DIR])
	quit()


## Маска лужи: неровное пятно с мягким краем. Радиальный градиент даёт
## «центр пятна», шум сдвигает границу и делает её рваной, поэтому лужа
## не читается кругом. Три октавы шума — чтобы край был крупный, а не «шум».
func _mask(variant: int) -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.frequency = 0.011
	noise.seed = 1000 + variant
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	# В каждой маске два-три пятна со своими центрами: лужа собирается
	# из нескольких луж, как на реальном неровном полу.
	var blobs: Array[Vector3] = []
	# Радиусы в долях текстуры: пятно занимает почти весь квадрат, иначе
	# на декали 1.5 м остаётся лужица 0.4 м. Края всё равно рваные — их
	# срезает шум, поэтому квадратной лужа не выглядит.
	var centers := [
		[Vector2(0.5, 0.5), 0.34],
		[Vector2(0.33, 0.63), 0.24],
		[Vector2(0.68, 0.36), 0.20],
	]
	for i in mini(2 + variant % 2, centers.size()):
		var c: Vector2 = centers[i][0]
		var r: float = centers[i][1]
		blobs.append(Vector3(c.x, c.y, r))
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / float(SIZE)
			var w := float(y) / float(SIZE)
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var best := 0.0
			for b in blobs:
				var d := Vector2(u - b.x, w - b.y).length() / b.z
				# край пятна: радиус + шум, чтобы граница была рваной
				var edge: float = 1.0 - d + (n - 0.5) * 0.85
				best = maxf(best, edge)
			var m := smoothstep(0.0, 0.22, best)
			# у самого края пятно светлее — тонкая плёнка воды; в центре
			# глубже и холоднее, иначе под оранжевыми факелами лужа
			# читается коричневой грязью, а не водой
			var wet := smoothstep(0.0, 0.7, best)
			var c2 := Color(0.062, 0.072, 0.082).lerp(Color(0.028, 0.036, 0.046), wet)
			c2.a = m
			img.set_pixel(x, y, c2)
	img.save_png("%s/puddle_mask_%d.png" % [DIR, variant])


## ORM: AO = 1, шероховатость почти нулевая (вода — зеркало), металл = 0.
## Металл нулевой важен: у металла отражения только от окружения, у
## диэлектрика есть ещё и блик от факела — именно его видно в луже.
func _orm() -> void:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGB8)
	img.fill(Color(1.0, 0.02, 0.0))
	img.save_png(DIR + "/puddle_orm.png")


## Плоская нормаль (0,0,1 в текстуре). Нужна не для рельефа, а чтобы у
## декали включился путь с нормалями: без texture_normal normal_fade
## игнорируется и лужа залезает на вертикальные поверхности.
func _flat_normal() -> void:
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.5, 0.5, 1.0))
	img.save_png(DIR + "/puddle_normal.png")
