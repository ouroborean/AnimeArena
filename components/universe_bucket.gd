extends Bucket
class_name UniverseBucket

var universe: CharacterConcept.Universe



static func new_universe_bucket(max, trig, p_uni, p_scale, curr = 0):
	var bucket = load("res://components/universe_bucket.gd").new()
	bucket.ap = curr
	bucket.maximum = max
	bucket.trigger = trig
	bucket.scale = p_scale
	bucket.universe = p_uni
	
	return bucket

func bucket_name():
	return CharacterConcept.Universe.keys()[universe].capitalize()
