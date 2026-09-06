extends Node
# Verify the 4 owner-retired Nexus characters read as removed (baki/aizen/synshenron/accelerator) and that
# similarly-named siblings/partial matches are NOT (maizenin, eis/nuova shenron, jack/yujiro hanma, kakashi).
func _ready():
	print("=== Nexus removal probe ===")
	var bh = BucketHandler.new()
	var fails := 0
	for p in ["baki", "aizen", "synshenron", "accelerator"]:
		if bh._is_removed(p): print("  PASS  removed from Nexus: ", p)
		else: fails += 1; print("  FAIL  still present: ", p)
	for p in ["maizenin", "eisshenron", "nuovashenron", "jackhanma", "yujirohanma", "kakashi"]:
		if not bh._is_removed(p): print("  PASS  untouched: ", p)
		else: fails += 1; print("  FAIL  wrongly removed: ", p)
	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
