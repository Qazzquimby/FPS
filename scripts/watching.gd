extends Node

var condition_history := {}

func watch_condition(condition: Callable, max_age: float) -> String:
	var condition_id := str(condition.hash())
	if not condition_history.has(condition_id):
		condition_history[condition_id] = {
			"last_true": -100000.0,
			"condition": condition
		}
	return condition_id

func _process(_delta):
	var current_time = Time.get_ticks_msec()/1000.0
	
	for condition_id in condition_history.keys():
		var condition_data = condition_history[condition_id]	
		var current_value = condition_data["condition"].call()
		if current_value:
			condition_data["last_true"] = current_time		

func was_true(condition_id: String, duration: float) -> bool:
	if not condition_history.has(condition_id):
		return false

	var current_time = Time.get_ticks_msec()/1000.0

	var condition_data = condition_history[condition_id]
	var oldest_time_to_check =  current_time - duration

	return condition_data["last_true"] > oldest_time_to_check
