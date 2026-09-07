# tests/simulation/test_relationships_and_household_dynamics.gd
class_name TestRelationshipsAndHouseholdDynamics
extends RefCounted

## Automated Headless Test Suite for Sprint 20: Relationships, Romance & Household Dynamics.

const Relationship = preload("res://src/sim/population/relationship.gd")
const RelationshipSystem = preload("res://src/sim/population/relationship_system.gd")
const RelationshipInvariants = preload("res://src/sim/population/relationship_invariants.gd")
const RelationshipReader = preload("res://src/presentation/relationship_reader.gd")

func run_all(asserts: TestAsserts) -> void:
	test_relationship_dimensions_and_status(asserts)
	test_interaction_and_familiarity(asserts)
	test_incest_taboo_enforcement(asserts)
	test_partnership_formation_and_cohabitation(asserts)
	test_separation_and_emotional_fallout(asserts)
	test_bereavement_grief(asserts)
	test_determinism_and_invariants(asserts)

func _create_test_world(seed_val: int = 42) -> WorldState:
	var ws: WorldState = WorldState.new(seed_val)
	PopulationGenerator.generate_population(ws, 100)
	OccupationAssignment.setup_workplaces_and_assignments(ws)
	return ws

func test_relationship_dimensions_and_status(asserts: TestAsserts) -> void:
	asserts.set_current_test("Relationship Dimensions, Clamping & Status Transitions")
	var rel: Relationship = Relationship.new(10, 5)
	asserts.assert_true(rel.person_a_id == 5 and rel.person_b_id == 10, "Person IDs ordered properly (5 < 10)")
	asserts.assert_true(rel.status == Relationship.STATUS_STRANGER, "Initial status is stranger")
	
	rel.familiarity = 25.0
	rel.update_status()
	asserts.assert_true(rel.status == Relationship.STATUS_ACQUAINTANCE, "Familiarity >= 15 yields acquaintance")
	
	rel.familiarity = 40.0
	rel.affection = 60.0
	rel.update_status()
	asserts.assert_true(rel.status == Relationship.STATUS_FRIEND, "Familiarity >= 35 & affection >= 50 yields friend")
	
	rel.familiarity = 80.0
	rel.affection = 80.0
	rel.update_status()
	asserts.assert_true(rel.status == Relationship.STATUS_CLOSE_FRIEND, "Familiarity >= 70 & affection >= 70 yields close friend")
	
	rel.attraction = 60.0
	rel.update_status()
	asserts.assert_true(rel.status == Relationship.STATUS_ROMANTIC_INTEREST, "Attraction >= 50 & affection >= 50 yields romantic interest")

func test_interaction_and_familiarity(asserts: TestAsserts) -> void:
	asserts.set_current_test("Daily Life Interaction & Familiarity Growth")
	var ws: WorldState = _create_test_world(101)
	var rel_sys: RelationshipSystem = RelationshipSystem.new()
	rel_sys.setup(ws)
	
	var registry: EntityRegistry = ws.entity_registry
	var p1: Person = registry.get_entity(1) as Person
	var p2: Person = registry.get_entity(2) as Person
	
	p1.current_location_id = 10
	p2.current_location_id = 10
	
	var rel: Relationship = rel_sys.get_or_create_relationship(p1.id, p2.id)
	var initial_fam: float = rel.familiarity
	
	rel_sys._interact(ws, p1, p2)
	asserts.assert_true(rel.familiarity > initial_fam, "Interaction increases familiarity")
	asserts.assert_true(rel.shared_history_ticks == 6, "Shared history ticks accumulated")

func test_incest_taboo_enforcement(asserts: TestAsserts) -> void:
	asserts.set_current_test("Incest Taboo Prevents Close Family Romance")
	var ws: WorldState = _create_test_world(102)
	var rel_sys: RelationshipSystem = RelationshipSystem.new()
	rel_sys.setup(ws)
	var registry: EntityRegistry = ws.entity_registry
	
	var parent: Person = Person.new(1001, "Parent", "Test", Person.SEX_MALE, 0)
	var child: Person = Person.new(1002, "Child", "Test", Person.SEX_FEMALE, 1000)
	child.parent_ids = [parent.id]
	parent.children_ids = [child.id]
	parent.life_stage = Person.STAGE_ADULT
	child.life_stage = Person.STAGE_ADULT
	
	registry.register_entity("person", parent)
	registry.register_entity("person", child)
	
	asserts.assert_true(rel_sys._is_incestuous(parent, child) == true, "Parent-child recognized as incestuous")
	
	var sib1: Person = Person.new(1003, "Sib1", "Test", Person.SEX_MALE, 100)
	var sib2: Person = Person.new(1004, "Sib2", "Test", Person.SEX_FEMALE, 200)
	sib1.parent_ids = [parent.id]
	sib2.parent_ids = [parent.id]
	sib1.life_stage = Person.STAGE_ADULT
	sib2.life_stage = Person.STAGE_ADULT
	
	registry.register_entity("person", sib1)
	registry.register_entity("person", sib2)
	
	asserts.assert_true(rel_sys._is_incestuous(sib1, sib2) == true, "Siblings recognized as incestuous")

func test_partnership_formation_and_cohabitation(asserts: TestAsserts) -> void:
	asserts.set_current_test("Romantic Partnership Formation & Co-habitation Movement")
	var ws: WorldState = _create_test_world(103)
	var rel_sys: RelationshipSystem = RelationshipSystem.new()
	rel_sys.setup(ws)
	var registry: EntityRegistry = ws.entity_registry
	
	var male: Person = Person.new(2001, "Adam", "Smith", Person.SEX_MALE, 0)
	var female: Person = Person.new(2002, "Eve", "Jones", Person.SEX_FEMALE, 0)
	male.life_stage = Person.STAGE_ADULT
	female.life_stage = Person.STAGE_ADULT
	male.partner_id = 0
	female.partner_id = 0
	male.household_id = 1
	male.home_room_id = 10
	female.household_id = 2
	female.home_room_id = 20
	
	registry.register_entity("person", male, male.id)
	registry.register_entity("person", female, female.id)
	
	var rel: Relationship = rel_sys.get_or_create_relationship(male.id, female.id)
	rel.affection = 80.0
	rel.attraction = 80.0
	rel.status = Relationship.STATUS_ROMANTIC_INTEREST
	
	rel_sys._form_partnership(ws, male, female, rel)
	asserts.assert_true(male.partner_id == female.id, "Male partner linked to female")
	asserts.assert_true(female.partner_id == male.id, "Female partner linked to male")
	asserts.assert_true(rel.status == Relationship.STATUS_PARTNER, "Relationship marked as PARTNER")
	asserts.assert_true(female.household_id == male.household_id, "Partners co-habitate in same household")
	asserts.assert_true(female.home_room_id == male.home_room_id, "Partners share home room")

func test_separation_and_emotional_fallout(asserts: TestAsserts) -> void:
	asserts.set_current_test("Partnership Estrangement & Emotional Fallout")
	var ws: WorldState = _create_test_world(104)
	var rel_sys: RelationshipSystem = RelationshipSystem.new()
	rel_sys.setup(ws)
	var registry: EntityRegistry = ws.entity_registry
	
	var p1: Person = Person.new(3001, "John", "Doe", Person.SEX_MALE, 0)
	var p2: Person = Person.new(3002, "Jane", "Doe", Person.SEX_FEMALE, 0)
	p1.life_stage = Person.STAGE_ADULT
	p2.life_stage = Person.STAGE_ADULT
	p1.partner_id = p2.id
	p2.partner_id = p1.id
	p1.stress = 20.0
	p2.stress = 20.0
	p1.morale = 70.0
	p2.morale = 70.0
	
	registry.register_entity("person", p1, p1.id)
	registry.register_entity("person", p2, p2.id)
	
	var rel: Relationship = rel_sys.get_or_create_relationship(p1.id, p2.id)
	rel.status = Relationship.STATUS_PARTNER
	rel.conflict = 90.0
	rel.affection = 10.0
	
	rel_sys._separate_partners(ws, p1, p2, rel)
	asserts.assert_true(p1.partner_id == 0 and p2.partner_id == 0, "Partnerships broken")
	asserts.assert_true(rel.status == Relationship.STATUS_ESTRANGED, "Status estranged")
	asserts.assert_true(p1.stress > 20.0 and p2.stress > 20.0, "Stress spikes from separation")
	asserts.assert_true(p1.morale < 70.0 and p2.morale < 70.0, "Morale drops from separation")

func test_bereavement_grief(asserts: TestAsserts) -> void:
	asserts.set_current_test("Bereavement: Partner Death Inflicts Acute Grief")
	var ws: WorldState = _create_test_world(105)
	var rel_sys: RelationshipSystem = RelationshipSystem.new()
	rel_sys.setup(ws)
	var registry: EntityRegistry = ws.entity_registry
	
	var deceased: Person = Person.new(4001, "Dead", "Person", Person.SEX_MALE, 0)
	var survivor: Person = Person.new(4002, "Alive", "Survivor", Person.SEX_FEMALE, 0)
	survivor.stress = 20.0
	survivor.morale = 80.0
	
	registry.register_entity("person", deceased, deceased.id)
	registry.register_entity("person", survivor, survivor.id)
	
	var rel: Relationship = rel_sys.get_or_create_relationship(deceased.id, survivor.id)
	rel.status = Relationship.STATUS_PARTNER
	
	rel_sys.notify_death(ws, deceased)
	asserts.assert_true(survivor.stress >= 50.0, "Survivor suffers acute grief stress spike")
	asserts.assert_true(survivor.morale <= 40.0, "Survivor suffers acute grief morale collapse")

func test_determinism_and_invariants(asserts: TestAsserts) -> void:
	asserts.set_current_test("Relationship Invariants & Serialization")
	var ws: WorldState = _create_test_world(106)
	var rel_sys: RelationshipSystem = RelationshipSystem.new()
	rel_sys.setup(ws)
	
	# Simulate 24 ticks (4 hours)
	for i in range(24):
		ws.sim_clock.advance_tick()
		rel_sys.tick(ws)
		
	var val: Dictionary = RelationshipInvariants.validate_all(ws)
	asserts.assert_true(val.get("is_valid", false), "Relationship invariants pass: %s" % [str(val.get("errors", []))])
	
	var summary: Dictionary = RelationshipReader.get_relationships_summary(ws)
	asserts.assert_true(summary.get("total_relationships_tracked", 0) > 0, "Relationships tracked in world")
	
	# Serialization test
	var ser: Dictionary = rel_sys.serialize()
	var rel_sys2: RelationshipSystem = RelationshipSystem.new()
	rel_sys2.deserialize(ser)
	asserts.assert_true(rel_sys2.relationships.size() == rel_sys.relationships.size(), "Relationships serialized and restored identically")
