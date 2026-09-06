class_name Trigger

var condition
var payload

static func from_condition(trigger_condition: Condition, trigger_payload) -> Trigger:
	var trigger = Trigger.new()
	trigger.set_condition(trigger_condition)
	trigger.assign_payload(trigger_payload)

	return trigger

static func always(trigger_payload) -> Trigger:
	var trigger = Trigger.new()
	trigger.set_condition(Condition.always())
	trigger.assign_payload(trigger_payload)
	return trigger

func set_condition(cond):
	condition = cond

func assign_payload(pload):
	payload = pload

func check(context):
	if condition.satisfied(context):
		payload.call(context)
		return true
	return false
