extends Area2D
## Кровавый шип — снаряд игрока.

const SPEED := 420.0
const DAMAGE := 18.0

var dir := Vector2.RIGHT
var life := 1.1
var hit_list: Array = []


func _ready() -> void:
	dir = get_meta("dir", Vector2.RIGHT)
	life = get_meta("life", 1.1)
	hit_list = get_meta("hit", [])
	z_index = 20


func _physics_process(delta: float) -> void:
	life -= delta
	global_position += dir * SPEED * delta
	if life <= 0.0:
		_die()
		return
	var mission := get_tree().current_scene
	if mission and mission.has_method("is_wall_at") and mission.is_wall_at(global_position):
		_die()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_dead or e in hit_list:
			continue
		if e.global_position.distance_to(global_position) < 18.0:
			e.take_damage(DAMAGE, dir)
			_die()
			return


func _die() -> void:
	queue_free()
