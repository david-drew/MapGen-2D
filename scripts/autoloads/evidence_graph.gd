extends Node
#class_name EvidenceGraph

## EvidenceGraph - Phase 2: Central Claim Tracking System
## Manages all claims, their relationships, and confidence scores
## Autoload singleton - register in Project Settings
##
## SETUP: Add to Project Settings -> Autoload as "EvidenceGraph"

# ============================================================================
# CLAIM STORAGE
# ============================================================================

## All claims in the evidence graph (claim_id -> ClaimData)
var claims: Dictionary = {}

## Claims grouped by tag (tag -> Array[claim_id])
## Used for proof gate evaluation
var claims_by_tag: Dictionary = {}

## Claims about specific entities (entity_key -> Array[claim_id])
## Allows fast lookup of all claims about an NPC, location, etc.
var claims_by_entity: Dictionary = {}

## Claims from specific clues (clue_id -> Array[claim_id])
var claims_by_source: Dictionary = {}

# ============================================================================
# STATISTICS
# ============================================================================

var total_claims_added: int = 0
var total_corroborations: int = 0
var total_contradictions: int = 0

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a new claim is added to the graph
signal claim_added(claim_id: String, claim: ClaimData)

## Emitted when claim confidence changes
signal confidence_changed(claim_id: String, old_value: float, new_value: float, reason: String)

## Emitted when a claim is corroborated by another clue
signal claim_corroborated(claim_id: String, by_clue_id: String, new_confidence: float)

## Emitted when a claim is contradicted
signal claim_contradicted(claim_id: String, by_clue_id: String, new_confidence: float)

## Emitted when a claim becomes highly confident
signal claim_confidence_threshold(claim_id: String, threshold: String)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	"""Initialize graph"""
	pass


func clear_all_data() -> void:
	"""Reset all claim data (for new game)"""
	claims.clear()
	claims_by_tag.clear()
	claims_by_entity.clear()
	claims_by_source.clear()
	
	total_claims_added = 0
	total_corroborations = 0
	total_contradictions = 0
	
	print("EvidenceGraph: All data cleared")

# ============================================================================
# ADDING CLAIMS
# ============================================================================

func add_claim(claim: ClaimData, from_clue_id: String) -> String:
	"""
	Add a claim to the evidence graph
	Returns the claim_id
	"""
	
	# Generate ID if needed
	if claim.claim_id == "":
		claim.claim_id = claim.generate_claim_id()
	
	# Store source
	claim.source_clue_id = from_clue_id
	
	# Check if claim already exists
	if claims.has(claim.claim_id):
		# Claim already exists - this is corroboration
		_corroborate_existing_claim(claim.claim_id, from_clue_id)
		return claim.claim_id
	
	# Add new claim
	claims[claim.claim_id] = claim
	total_claims_added += 1
	
	# Index by tags
	for tag in claim.contributes_to_tags:
		if not claims_by_tag.has(tag):
			claims_by_tag[tag] = []
		claims_by_tag[tag].append(claim.claim_id)
	
	# Index by entity (subject and object)
	_index_claim_by_entity(claim.claim_id, claim.subject)
	_index_claim_by_entity(claim.claim_id, claim.object)
	
	# Index by source clue
	if not claims_by_source.has(from_clue_id):
		claims_by_source[from_clue_id] = []
	claims_by_source[from_clue_id].append(claim.claim_id)
	
	# Emit signal
	claim_added.emit(claim.claim_id, claim)
	
	print("EvidenceGraph: Added claim [%s] from clue '%s'" % [claim.claim_id, from_clue_id])
	
	return claim.claim_id


func add_claims_from_clue(clue_data, from_clue_id: String) -> Array[String]:
	"""
	Add all claims from a ClueData object
	Returns array of claim_ids
	"""
	var claim_ids: Array[String] = []
	
	# Check if clue has claims array (Phase 2 format)
	if not clue_data.has("claims") or not clue_data.claims is Array:
		return claim_ids
	
	for claim_dict in clue_data.claims:
		var claim = ClaimData.from_dict(claim_dict)
		claim.source_clue_id = from_clue_id
		
		# Add tags from clue's supports array
		if clue_data.has("supports_tags"):
			for tag in clue_data.supports_tags:
				if tag not in claim.contributes_to_tags:
					claim.contributes_to_tags.append(tag)
		
		var claim_id = add_claim(claim, from_clue_id)
		claim_ids.append(claim_id)
	
	return claim_ids


func _index_claim_by_entity(claim_id: String, entity: Dictionary) -> void:
	"""Index a claim by its entity for fast lookup"""
	var entity_key = _get_entity_key(entity)
	
	if not claims_by_entity.has(entity_key):
		claims_by_entity[entity_key] = []
	
	if claim_id not in claims_by_entity[entity_key]:
		claims_by_entity[entity_key].append(claim_id)


func _get_entity_key(entity: Dictionary) -> String:
	"""Generate a lookup key for an entity"""
	var entity_type = entity.get("type", "unknown")
	
	match entity_type:
		"npc":
			return "npc:%s" % entity.get("entity_id", "")
		"npc_pool":
			var pool = entity.get("pool", "")
			var arch = entity.get("archetype", "")
			return "pool:%s:%s" % [pool, arch] if arch else "pool:%s" % pool
		"object_tag":
			return "tag:%s" % entity.get("tag", "")
		"place":
			var region = entity.get("region", "")
			var building = entity.get("building_type", "")
			if region and building:
				return "place:%s:%s" % [region, building]
			elif building:
				return "place::%s" % building
			elif region:
				return "place:%s:" % region
			else:
				return "place::"
		_:
			return "unknown:%s" % entity_type

# ============================================================================
# CORROBORATION & CONTRADICTION
# ============================================================================

func _corroborate_existing_claim(claim_id: String, by_clue_id: String) -> void:
	"""A clue corroborates an existing claim"""
	var claim = claims.get(claim_id, null)
	if not claim:
		return
	
	# Check if this clue already corroborated this claim
	if by_clue_id in claim.supported_by_clues:
		return
	
	claim.add_supporting_clue(by_clue_id)
	
	# Increase confidence (default: +0.15 per corroboration)
	var boost = 0.15
	var old_confidence = claim.confidence_current
	claim.update_confidence(boost, by_clue_id, "corroboration")
	
	total_corroborations += 1
	
	# Emit signals
	confidence_changed.emit(claim_id, old_confidence, claim.confidence_current, "corroboration")
	claim_corroborated.emit(claim_id, by_clue_id, claim.confidence_current)
	
	# Check thresholds
	_check_confidence_thresholds(claim_id, old_confidence, claim.confidence_current)
	
	print("EvidenceGraph: Claim '%s' corroborated by '%s' (confidence: %.2f → %.2f)" % [
		claim_id, by_clue_id, old_confidence, claim.confidence_current
	])


func contradict_claim(claim_id: String, by_clue_id: String, penalty: float = 0.2) -> void:
	"""Mark a claim as contradicted by evidence"""
	var claim = claims.get(claim_id, null)
	if not claim:
		push_warning("EvidenceGraph: Cannot contradict claim, not found: %s" % claim_id)
		return
	
	# Check if already contradicted by this clue
	if by_clue_id in claim.refuted_by_clues:
		return
	
	claim.add_refuting_clue(by_clue_id)
	
	# Decrease confidence
	var old_confidence = claim.confidence_current
	claim.update_confidence(-penalty, by_clue_id, "contradiction")
	
	total_contradictions += 1
	
	# Emit signals
	confidence_changed.emit(claim_id, old_confidence, claim.confidence_current, "contradiction")
	claim_contradicted.emit(claim_id, by_clue_id, claim.confidence_current)
	
	print("EvidenceGraph: Claim '%s' contradicted by '%s' (confidence: %.2f → %.2f)" % [
		claim_id, by_clue_id, old_confidence, claim.confidence_current
	])


func process_claim_relationships(clue_id: String, supports_tags: Array, refutes_claims: Array) -> void:
	"""
	Process a clue's support/refute relationships with existing claims
	Called after discovering a clue
	"""
	
	# Handle supports (corroboration)
	for tag in supports_tags:
		var supported_claims = get_claims_by_tag(tag)
		for claim_id in supported_claims:
			var claim = claims.get(claim_id, null)
			if claim and claim.source_clue_id != clue_id:
				_corroborate_existing_claim(claim_id, clue_id)
	
	# Handle refutes (contradiction)
	for refuted_claim_id in refutes_claims:
		if claims.has(refuted_claim_id):
			contradict_claim(refuted_claim_id, clue_id)


func _check_confidence_thresholds(claim_id: String, old_value: float, new_value: float) -> void:
	"""Check if confidence crossed important thresholds"""
	var thresholds = [
		{"value": 0.8, "name": "very_high"},
		{"value": 0.6, "name": "high"},
		{"value": 0.4, "name": "medium"}
	]
	
	for threshold in thresholds:
		if old_value < threshold.value and new_value >= threshold.value:
			claim_confidence_threshold.emit(claim_id, threshold.name)
			break

# ============================================================================
# QUERYING CLAIMS
# ============================================================================

func get_claim(claim_id: String) -> ClaimData:
	"""Get a specific claim"""
	return claims.get(claim_id, null)


func get_claims_by_tag(tag: String) -> Array:
	"""Get all claim IDs that contribute to a specific tag"""
	return claims_by_tag.get(tag, [])


func get_claims_about_entity(entity: Dictionary) -> Array[ClaimData]:
	"""Get all claims about a specific entity"""
	var entity_key = _get_entity_key(entity)
	var claim_ids = claims_by_entity.get(entity_key, [])
	
	var result: Array[ClaimData] = []
	for claim_id in claim_ids:
		var claim = claims.get(claim_id, null)
		if claim:
			result.append(claim)
	
	return result


func get_claims_from_clue(clue_id: String) -> Array[ClaimData]:
	"""Get all claims made by a specific clue"""
	var claim_ids = claims_by_source.get(clue_id, [])
	
	var result: Array[ClaimData] = []
	for claim_id in claim_ids:
		var claim = claims.get(claim_id, null)
		if claim:
			result.append(claim)
	
	return result


func get_high_confidence_claims(min_confidence: float = 0.7) -> Array[ClaimData]:
	"""Get all claims above a confidence threshold"""
	var result: Array[ClaimData] = []
	
	for claim in claims.values():
		if claim.confidence_current >= min_confidence:
			result.append(claim)
	
	return result


func get_contested_claims() -> Array[ClaimData]:
	"""Get all claims that have contradicting evidence"""
	var result: Array[ClaimData] = []
	
	for claim in claims.values():
		if claim.is_contested():
			result.append(claim)
	
	return result

# ============================================================================
# TAG-BASED CONFIDENCE (For Proof Gates)
# ============================================================================

func get_tag_confidence(tag: String) -> float:
	"""
	Get average confidence of all claims supporting a tag
	Used for proof gate evaluation
	"""
	var claim_ids = get_claims_by_tag(tag)
	
	if claim_ids.is_empty():
		return 0.0
	
	var total_confidence = 0.0
	var count = 0
	
	for claim_id in claim_ids:
		var claim = claims.get(claim_id, null)
		if claim:
			total_confidence += claim.confidence_current
			count += 1
	
	return total_confidence / max(1, count)


func get_tag_best_confidence(tag: String) -> float:
	"""Get the highest confidence among claims supporting a tag"""
	var claim_ids = get_claims_by_tag(tag)
	
	if claim_ids.is_empty():
		return 0.0
	
	var best = 0.0
	
	for claim_id in claim_ids:
		var claim = claims.get(claim_id, null)
		if claim and claim.confidence_current > best:
			best = claim.confidence_current
	
	return best

# ============================================================================
# STATISTICS & DEBUGGING
# ============================================================================

func get_stats() -> Dictionary:
	"""Get statistics about the evidence graph"""
	return {
		"total_claims": claims.size(),
		"claims_added": total_claims_added,
		"corroborations": total_corroborations,
		"contradictions": total_contradictions,
		"tags_tracked": claims_by_tag.size(),
		"entities_tracked": claims_by_entity.size(),
		"contested_claims": get_contested_claims().size(),
		"high_confidence_claims": get_high_confidence_claims(0.7).size()
	}


func print_evidence_summary() -> void:
	"""Print debug summary of evidence graph"""
	print("\n=== EVIDENCE GRAPH SUMMARY ===")
	var stats = get_stats()
	print("Total claims: %d" % stats.total_claims)
	print("Corroborations: %d" % stats.corroborations)
	print("Contradictions: %d" % stats.contradictions)
	print("Contested claims: %d" % stats.contested_claims)
	print("High confidence (≥0.7): %d" % stats.high_confidence_claims)
	
	print("\nClaims by Tag:")
	for tag in claims_by_tag.keys():
		var count = claims_by_tag[tag].size()
		var avg_conf = get_tag_confidence(tag)
		print("  %s: %d claims (avg confidence: %.2f)" % [tag, count, avg_conf])
	
	print("==============================\n")
