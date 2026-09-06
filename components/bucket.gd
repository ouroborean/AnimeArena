extends Node
class_name Bucket

var ap: int
var maximum: int
var scale: float
var trigger
var contribution_history: Array

signal bucket_filled()

func bucket_name():
	return "bucket"

static func create(max, trig, p_scale, curr = 0):
	var bucket = load("res://components/bucket.gd").new()
	bucket.ap = curr
	bucket.maximum = max
	bucket.trigger = trig
	bucket.scale = p_scale
	
	return bucket

func report_ap():
	return ap

func report_max():
	return maximum

func add_ap(quantity):
	ap += quantity

func empty_ap():
	ap = 0

func scale_maximum(scale_mod = 1.0):
	maximum *= (scale * scale_mod)
	
func report_contribution_history(history_range=0):
	var output = []
	if history_range > 0:
		for i in range(history_range):
			output.append(contribution_history[i])
	else:
		return contribution_history
	return output
	
