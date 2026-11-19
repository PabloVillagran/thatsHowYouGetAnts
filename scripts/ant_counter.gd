extends Label

@onready var ant_source: Node = get_node("../../AntSource")


func _process(_delta: float) -> void:
	var live_count: int = ant_source.queen_ants.size() + ant_source.worker_ants.size() + ant_source.warrior_ants.size()
	text = "Live ants: %s" % live_count
