extends GPUParticles3D
## Пылинки в воздухе (этап 7). Материал затеняемый и без ambient: пылинку
## видно только там, где её освещает огонь; против огня её подсвечивает
## backlight. В темноте пыли нет.
##
## follow_camera — эмиттер каждый кадр встаёт на активную камеру (в том
## числе на камеру фототура). Частицы в мировых координатах, поэтому при
## движении камеры они остаются висеть, а не едут вместе с ней.

@export var follow_camera := false
## Размер коробки эмиссии, м.
@export var box_size := Vector3(12.0, 4.0, 12.0)


func _ready() -> void:
	var pm := process_material as ParticleProcessMaterial
	if pm != null and not pm.emission_box_extents.is_equal_approx(box_size * 0.5):
		# материал общий у всех экземпляров сцены — свою коробку правим в копии
		pm = pm.duplicate() as ParticleProcessMaterial
		pm.emission_box_extents = box_size * 0.5
		process_material = pm
	# запас 1 м на дрейф пылинок за время жизни
	visibility_aabb = AABB(-box_size * 0.5 - Vector3.ONE, box_size + Vector3.ONE * 2.0)
	set_process(follow_camera)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_position = cam.global_position
