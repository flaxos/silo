# src/sim/population/genetics_model.gd
class_name GeneticsModel
extends RefCounted

## Deterministic Mendelian genetics, heredity and relatedness service.

const VALID_BLOOD_TYPES: Array[String] = [
	"O+", "A+", "B+", "AB+",
	"O-", "A-", "B-", "AB-"
]

static func inherit_blood_type(father_blood: String, mother_blood: String, rng: SeededRandom) -> String:
	var f_abo: Array[String] = _get_random_abo_alleles(father_blood, rng)
	var m_abo: Array[String] = _get_random_abo_alleles(mother_blood, rng)
	
	var f_rh: Array[String] = _get_random_rh_alleles(father_blood, rng)
	var m_rh: Array[String] = _get_random_rh_alleles(mother_blood, rng)
	
	# Pick one allele from each parent
	var child_abo_1: String = f_abo[rng.randi_range(0, 1)]
	var child_abo_2: String = m_abo[rng.randi_range(0, 1)]
	
	var child_rh_1: String = f_rh[rng.randi_range(0, 1)]
	var child_rh_2: String = m_rh[rng.randi_range(0, 1)]
	
	# Determine phenotype
	var abo_pheno: String = "O"
	if (child_abo_1 == "A" and child_abo_2 == "B") or (child_abo_1 == "B" and child_abo_2 == "A"):
		abo_pheno = "AB"
	elif child_abo_1 == "A" or child_abo_2 == "A":
		abo_pheno = "A"
	elif child_abo_1 == "B" or child_abo_2 == "B":
		abo_pheno = "B"
		
	var rh_pheno: String = "+" if (child_rh_1 == "+" or child_rh_2 == "+") else "-"
	return abo_pheno + rh_pheno

static func _get_random_abo_alleles(blood: String, rng: SeededRandom) -> Array[String]:
	var alleles: Array[String] = []
	if blood.begins_with("AB"):
		alleles.append("A")
		alleles.append("B")
	elif blood.begins_with("A"):
		alleles.append("A")
		alleles.append("O" if rng.rand_chance(0.5) else "A")
	elif blood.begins_with("B"):
		alleles.append("B")
		alleles.append("O" if rng.rand_chance(0.5) else "B")
	else:
		alleles.append("O")
		alleles.append("O")
	return alleles

static func _get_random_rh_alleles(blood: String, rng: SeededRandom) -> Array[String]:
	var alleles: Array[String] = []
	if blood.ends_with("+"):
		alleles.append("+")
		alleles.append("-" if rng.rand_chance(0.5) else "+")
	else:
		alleles.append("-")
		alleles.append("-")
	return alleles

static func compute_relatedness(registry: EntityRegistry, p1: Person, p2: Person) -> float:
	if not p1 or not p2:
		return 0.0
	if p1.id == p2.id:
		return 1.0
		
	# Parent - Child check (r = 0.5)
	if p1.id in p2.parent_ids or p2.id in p1.parent_ids:
		return 0.5
		
	# Sibling check (both parents vs one parent)
	var shared_parents: int = 0
	for pid in p1.parent_ids:
		if pid > 0 and pid in p2.parent_ids:
			shared_parents += 1
	if shared_parents == 2:
		return 0.5 # Full siblings
	elif shared_parents == 1:
		return 0.25 # Half siblings
		
	# Grandparent - Grandchild check (r = 0.25)
	for pid in p1.parent_ids:
		var parent_entity: Person = registry.get_entity(pid) as Person
		if parent_entity and (p2.id in parent_entity.parent_ids or parent_entity.id in p2.parent_ids):
			return 0.25
	for pid in p2.parent_ids:
		var parent_entity: Person = registry.get_entity(pid) as Person
		if parent_entity and (p1.id in parent_entity.parent_ids or parent_entity.id in p1.parent_ids):
			return 0.25
			
	# Uncle / Aunt - Niece / Nephew check (r = 0.25)
	for pid in p1.parent_ids:
		var parent_entity: Person = registry.get_entity(pid) as Person
		if parent_entity:
			var parent_shared_with_p2: int = 0
			for gpid in parent_entity.parent_ids:
				if gpid > 0 and gpid in p2.parent_ids:
					parent_shared_with_p2 += 1
			if parent_shared_with_p2 == 2:
				return 0.25
				
	for pid in p2.parent_ids:
		var parent_entity: Person = registry.get_entity(pid) as Person
		if parent_entity:
			var parent_shared_with_p1: int = 0
			for gpid in parent_entity.parent_ids:
				if gpid > 0 and gpid in p1.parent_ids:
					parent_shared_with_p1 += 1
			if parent_shared_with_p1 == 2:
				return 0.25

	# First Cousins (parents are full siblings, r = 0.125)
	for pid1 in p1.parent_ids:
		var parent1: Person = registry.get_entity(pid1) as Person
		if parent1:
			for pid2 in p2.parent_ids:
				var parent2: Person = registry.get_entity(pid2) as Person
				if parent2 and parent1.id != parent2.id:
					var grand_shared: int = 0
					for gpid in parent1.parent_ids:
						if gpid > 0 and gpid in parent2.parent_ids:
							grand_shared += 1
					if grand_shared == 2:
						return 0.125

	return 0.0

static func inherit_traits(father: Person, mother: Person, rng: SeededRandom, relatedness: float) -> Dictionary:
	var f_stam: float = father.trait_stamina if father else 1.0
	var m_stam: float = mother.trait_stamina if mother else 1.0
	var stamina: float = clampf((f_stam + m_stam) * 0.5 + rng.randf_range(-0.05, 0.05), 0.5, 1.5)
	
	var f_res: float = father.trait_resilience if father else 1.0
	var m_res: float = mother.trait_resilience if mother else 1.0
	var resilience: float = clampf((f_res + m_res) * 0.5 + rng.randf_range(-0.05, 0.05), 0.5, 1.5)
	
	var f_met: float = father.trait_metabolism if father else 1.0
	var m_met: float = mother.trait_metabolism if mother else 1.0
	var metabolism: float = clampf((f_met + m_met) * 0.5 + rng.randf_range(-0.05, 0.05), 0.5, 1.5)
	
	var conditions: Array[String] = []
	# Recessive inbreeding depression risk
	if relatedness >= 0.125:
		var inbreeding_risk: float = relatedness * 0.60
		if rng.rand_chance(inbreeding_risk):
			conditions.append("congenital_frailty")
			
	return {
		"stamina": stamina,
		"resilience": resilience,
		"metabolism": metabolism,
		"conditions": conditions
	}
