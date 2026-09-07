# src/sim/politics/political_event.gd
class_name PoliticalEvent
extends RefCounted

## Canonical event types and definitions for political attitude and trust formation.

const EVENT_FAMILY_BEREAVEMENT: String = "event_family_bereavement"
const EVENT_INDUSTRIAL_ACCIDENT: String = "event_industrial_accident"
const EVENT_DEHYDRATION_SUFFERED: String = "event_dehydration_suffered"
const EVENT_WATER_RATIONED: String = "event_water_rationed"
const EVENT_HOUSING_OVERCROWDED: String = "event_housing_overcrowded"
const EVENT_HOUSING_UPGRADED: String = "event_housing_upgraded"
const EVENT_PROMOTION_HONOR: String = "event_promotion_honor"
const EVENT_DEMOTION_PENALTY: String = "event_demotion_penalty"
const EVENT_COERCIVE_ORDER: String = "event_coercive_order"
const EVENT_CRISIS_RESOLVED: String = "event_crisis_resolved"
const EVENT_INFRASTRUCTURE_FAILURE: String = "event_infrastructure_failure"
const EVENT_EDUCATION_ACHIEVEMENT: String = "event_education_achievement"
const EVENT_CORRUPTION_DISCOVERED: String = "event_corruption_discovered"
const EVENT_NEPOTISM_PASSED_OVER: String = "event_nepotism_passed_over"
const EVENT_FAVOUR_GRANTED: String = "event_favour_granted"
const EVENT_DISCIPLINARY_SANCTION: String = "event_disciplinary_sanction"

# Department Keys
const DEPT_ADMINISTRATION: String = "administration"
const DEPT_ENGINEERING: String = "engineering"
const DEPT_SECURITY: String = "security"
const DEPT_IT: String = "it"
const DEPT_UTILITIES: String = "utilities"
const DEPT_LOGISTICS: String = "logistics"
const DEPT_EDUCATION: String = "education"
