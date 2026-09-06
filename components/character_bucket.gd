extends Bucket
class_name CharacterBucket

var character_concept: CharacterConcept



static func new_character_bucket(curr, trig, p_concept, p_scale):
	var bucket = load("res://components/character_bucket.gd").new()
	bucket.ap = curr
	bucket.maximum = 1
	bucket.trigger = trig
	bucket.scale = p_scale
	bucket.character_concept = p_concept
	
	return bucket

func bucket_name():
	return character_concept.character_name
