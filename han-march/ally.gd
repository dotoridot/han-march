extends BTAction

@export var order: String

func _tick(_delta: float) -> Status:
	var options: Dictionary = blackboard.get_var("options")
	if not options.get(order,false):
		return FAILURE
	blackboard.set_var("decision",order)
	return SUCCESS
