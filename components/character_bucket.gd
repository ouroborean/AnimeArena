extends Bucket
class_name CharacterBucket

var character_concept: CharacterConcept
# Universe display key (e.g. "NARUTO") carried directly on the bucket. For characters in the all_chars
# catalogue this is just the enum-key name; for a disk-only bucket (a .dat file with no all_chars entry)
# the concept is synthesized and has no valid Universe ordinal, so the name is resolved from an optional
# nexus_meta.json instead. Empty string = universe unknown -> the web client still lists the bucket on the
# leaderboard, just without a per-universe group. See BucketHandler.get_all_bucket_sets.
var universe_name: String = ""



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
