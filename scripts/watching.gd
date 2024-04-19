extends Node

var condition_history := {}
var time_elapsed := {}

func watch_condition(condition: Callable, max_age: float) -> String:
	var condition_id := str(condition.hash())
	if not condition_history.has(condition_id):
		condition_history[condition_id] = {
			"history": [],
			"max_age": max_age,
			"condition": condition
		}
		time_elapsed[condition_id] = 0.0
	return condition_id

#func _process(_delta):
	#print('watch process')
	#return
	##for condition_id in condition_history.keys():
		##var condition_data = condition_history[condition_id]
		##var current_time = Time.get_ticks_msec()/1000.0
		##var value_time = {
			##"value": condition_data["condition"].call(),
			##"time": current_time
			##}
		##condition_data["history"].push_front(value_time)
		##
		##var old_time_cutoff = current_time - condition_data["max_duration"]
		##while condition_data["history"].size() > 0 and condition_data["history"].back()["time"] < old_time_cutoff:
			##condition_data["history"].pop_back()
##
		##while time_elapsed[condition_id] >= condition_data["duration"]:
			##condition_data["history"].push_front(condition_data["condition"].call())
			##time_elapsed[condition_id] -= condition_data["duration"]
			##if condition_data["history"].size() > 120:
				##condition_data["history"].pop_back()

func was_true(condition_id: String, duration: float) -> bool:
	if not condition_history.has(condition_id):
		return false

	var condition_data = condition_history[condition_id]
	var oldest_time_to_check = Time.get_ticks_msec()/1000.0 - duration
	for entry in condition_data["history"]:
		if entry["time"] < oldest_time_to_check:
			return false
		if not entry["value"]:
			return false
	return true
