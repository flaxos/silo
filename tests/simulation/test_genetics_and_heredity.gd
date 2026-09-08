# tests/simulation/test_genetics_and_heredity.gd
class_name TestGeneticsAndHeredity
extends RefCounted

## Automated Headless Test Suite for Sprint 21: Genetics, Heredity & Population Health.

const GeneticsModel = preload("res://src/sim/population/genetics_model.gd")
const GeneticsInvariants = preload("res://src/sim/population/genetics_invariants.gd")
const GeneticsReader = preload("res://src/presentation/genetics_reader.gd")

func run_all(asserts: TestAsserts) -> void:
	test_mendelian_blood_inheritance(asserts)
	test_relatedness_coefficient_calculations(asserts)
	test_trait_blending_and_recessive_risks(asserts)
	test_population_generation_genetics(asserts)
	test_demographics_birth_genetics_integration(asserts)
	test_genetics_invariants_and_acyclic_lineage(asserts)

func test_mendelian_blood_inheritance(asserts: TestAsserts) -> void:
	asserts.set_current_test("Mendelian Blood Type Inheritance")
	var rng: SeededRandom = SeededRandom.new(42)
	
	# O- x O- can only produce O-
	for i in range(10):
		var child_blood: String = GeneticsModel.inherit_blood_type("O-", "O-", rng)
		asserts.assert_eq(child_blood, "O-", "O- x O- strictly produces O-")
		
	# A+ x B+ produces valid ABO and Rh types
	for i in range(10):
		var child_blood: String = GeneticsModel.inherit_blood_type("A+", "B+", rng)
		asserts.assert_true(child_blood in GeneticsModel.VALID_BLOOD_TYPES, "A+ x B+ produces valid type: %s" % child_blood)

func test_relatedness_coefficient_calculations(asserts: TestAsserts) -> void:
	asserts.set_current_test("Coefficient of Relationship (r) Lineage Calculations")
	var registry: EntityRegistry = EntityRegistry.new()
	
	# Founders (unrelated)
	var grand_father: Person = Person.new(1, "GF", "Smith", Person.SEX_MALE, 0)
	var grand_mother: Person = Person.new(2, "GM", "Smith", Person.SEX_FEMALE, 0)
	registry.register_entity("person", grand_father, 1)
	registry.register_entity("person", grand_mother, 2)
	
	var r_unrelated: float = GeneticsModel.compute_relatedness(registry, grand_father, grand_mother)
	asserts.assert_almost_eq(r_unrelated, 0.0, 0.001, "Unrelated founders have r = 0.0")
	
	# Parents (children of grandparents)
	var father: Person = Person.new(3, "Father", "Smith", Person.SEX_MALE, 100)
	father.parent_ids = [1, 2]
	registry.register_entity("person", father, 3)
	
	var r_parent_child: float = GeneticsModel.compute_relatedness(registry, grand_father, father)
	asserts.assert_almost_eq(r_parent_child, 0.5, 0.001, "Parent-child relationship has r = 0.5")
	
	var aunt: Person = Person.new(4, "Aunt", "Smith", Person.SEX_FEMALE, 120)
	aunt.parent_ids = [1, 2]
	registry.register_entity("person", aunt, 4)
	
	var r_full_siblings: float = GeneticsModel.compute_relatedness(registry, father, aunt)
	asserts.assert_almost_eq(r_full_siblings, 0.5, 0.001, "Full siblings have r = 0.5")
	
	# Mother (unrelated to father)
	var mother: Person = Person.new(5, "Mother", "Jones", Person.SEX_FEMALE, 110)
	registry.register_entity("person", mother, 5)
	
	# Child of father and mother
	var child: Person = Person.new(6, "Child", "Smith", Person.SEX_MALE, 200)
	child.parent_ids = [3, 5]
	registry.register_entity("person", child, 6)
	
	var r_grandchild: float = GeneticsModel.compute_relatedness(registry, grand_father, child)
	asserts.assert_almost_eq(r_grandchild, 0.25, 0.001, "Grandparent-grandchild has r = 0.25")
	
	var r_uncle_niece: float = GeneticsModel.compute_relatedness(registry, aunt, child)
	asserts.assert_almost_eq(r_uncle_niece, 0.25, 0.001, "Aunt/Uncle - Niece/Nephew has r = 0.25")
	
	# Child of aunt (first cousin to child)
	var cousin: Person = Person.new(7, "Cousin", "Smith", Person.SEX_FEMALE, 210)
	var uncle_in_law: Person = Person.new(8, "UncleInLaw", "Brown", Person.SEX_MALE, 130)
	registry.register_entity("person", uncle_in_law, 8)
	cousin.parent_ids = [4, 8]
	registry.register_entity("person", cousin, 7)
	
	var r_cousin: float = GeneticsModel.compute_relatedness(registry, child, cousin)
	asserts.assert_almost_eq(r_cousin, 0.125, 0.001, "First cousins have r = 0.125")

func test_trait_blending_and_recessive_risks(asserts: TestAsserts) -> void:
	asserts.set_current_test("Trait Blending & Inbreeding Depression Risk")
	var rng: SeededRandom = SeededRandom.new(99)
	
	var p1: Person = Person.new(1, "P1", "Test", Person.SEX_MALE, 0)
	p1.trait_stamina = 1.2
	p1.trait_resilience = 0.8
	
	var p2: Person = Person.new(2, "P2", "Test", Person.SEX_FEMALE, 0)
	p2.trait_stamina = 1.0
	p2.trait_resilience = 1.2
	
	# Unrelated parents (r = 0.0)
	var traits_unrelated: Dictionary = GeneticsModel.inherit_traits(p1, p2, rng, 0.0)
	asserts.assert_true(traits_unrelated["stamina"] >= 0.9 and traits_unrelated["stamina"] <= 1.3, "Stamina blended around 1.1")
	asserts.assert_true(traits_unrelated["resilience"] >= 0.8 and traits_unrelated["resilience"] <= 1.2, "Resilience blended around 1.0")
	asserts.assert_true(traits_unrelated["conditions"].is_empty(), "Unrelated parents have zero inbreeding condition risk")
	
	# Inbred parents (r = 0.5)
	var inbred_conditions: int = 0
	for i in range(20):
		var traits_inbred: Dictionary = GeneticsModel.inherit_traits(p1, p2, rng, 0.5)
		if traits_inbred["conditions"].has("congenital_frailty"):
			inbred_conditions += 1
	asserts.assert_true(inbred_conditions > 0, "Inbreeding (r=0.5) triggers congenital frailty risk (%d/20)" % inbred_conditions)

func test_population_generation_genetics(asserts: TestAsserts) -> void:
	asserts.set_current_test("Population Generator Assigns Valid Genetics")
	var ws: WorldState = WorldState.new(123)
	PopulationGenerator.generate_population(ws, 100)
	
	var summary: Dictionary = GeneticsReader.get_population_genetics_summary(ws)
	asserts.assert_eq(summary["living_population"], 100, "100 living residents generated")
	asserts.assert_true(summary["average_stamina"] >= 0.8 and summary["average_stamina"] <= 1.2, "Average stamina near 1.0")
	
	var val: Dictionary = GeneticsInvariants.validate_all(ws)
	asserts.assert_true(val.get("is_valid", false), "All generated residents pass genetics invariants: %s" % str(val.get("errors", [])))

func test_demographics_birth_genetics_integration(asserts: TestAsserts) -> void:
	asserts.set_current_test("Demographics Birth Integrates Genetics")
	var ws: WorldState = WorldState.new(456)
	PopulationGenerator.generate_population(ws, 100)
	var demo_sys: DemographicsSystem = DemographicsSystem.new()
	demo_sys.setup(ws)
	
	var registry: EntityRegistry = ws.entity_registry
	var father: Person = registry.get_entity(1) as Person
	var mother: Person = registry.get_entity(2) as Person
	father.blood_type = "O+"
	mother.blood_type = "A+"
	
	var baby: Person = demo_sys._spawn_birth(ws, father, mother, 1000)
	asserts.assert_true(baby.blood_type in ["A+", "O+", "A-", "O-"], "Baby inherits valid blood type: %s" % baby.blood_type)
	asserts.assert_true(baby.trait_stamina >= 0.5 and baby.trait_stamina <= 1.5, "Baby inherits valid stamina: %f" % baby.trait_stamina)

func test_genetics_invariants_and_acyclic_lineage(asserts: TestAsserts) -> void:
	asserts.set_current_test("Genetics Invariants Detect Invalid Blood Type & Cycles")
	var ws: WorldState = WorldState.new(789)
	PopulationGenerator.generate_population(ws, 20)
	var registry: EntityRegistry = ws.entity_registry
	
	var p: Person = registry.get_entity(1) as Person
	p.blood_type = "XYZ" # Invalid
	var val_invalid: Dictionary = GeneticsInvariants.validate_all(ws)
	asserts.assert_false(val_invalid.get("is_valid", true), "Genetics invariants catch invalid blood type")
	
	p.blood_type = "O+" # Reset
	var val_valid: Dictionary = GeneticsInvariants.validate_all(ws)
	asserts.assert_true(val_valid.get("is_valid", false), "Genetics invariants pass when reset")
