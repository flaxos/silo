# src/sim/core/sim_clock.gd
class_name SimClock
extends RefCounted

const MINUTES_PER_TICK: int = 10
const TICKS_PER_HOUR: int = 6
const HOURS_PER_DAY: int = 24
const TICKS_PER_DAY: int = 144
const DAYS_PER_YEAR: int = 365
const TICKS_PER_YEAR: int = 52560 # 144 * 365

var current_tick: int = 0

func _init(p_start_tick: int = 0) -> void:
	current_tick = p_start_tick

func advance_tick() -> void:
	current_tick += 1

func advance_ticks(count: int) -> void:
	if count > 0:
		current_tick += count

func get_tick() -> int:
	return current_tick

func get_tick_of_day() -> int:
	return current_tick % TICKS_PER_DAY

func get_minute_of_day() -> int:
	return get_tick_of_day() * MINUTES_PER_TICK

func get_hour_of_day() -> int:
	return get_tick_of_day() / TICKS_PER_HOUR

func get_minute_of_hour() -> int:
	return (get_tick_of_day() % TICKS_PER_HOUR) * MINUTES_PER_TICK

func get_total_days() -> int:
	return current_tick / TICKS_PER_DAY

func get_day_of_year() -> int:
	return (get_total_days() % DAYS_PER_YEAR) + 1

func get_year() -> int:
	return (get_total_days() / DAYS_PER_YEAR) + 1

static func ticks_for_minutes(minutes: int) -> int:
	return (minutes + MINUTES_PER_TICK - 1) / MINUTES_PER_TICK

static func ticks_for_hours(hours: int) -> int:
	return hours * TICKS_PER_HOUR

static func ticks_for_days(days: int) -> int:
	return days * TICKS_PER_DAY

func get_formatted_clock() -> String:
	return "%02d:%02d" % [get_hour_of_day(), get_minute_of_hour()]

func get_formatted_time() -> String:
	return "Year %d, Day %03d, %02d:%02d (Tick %d)" % [
		get_year(),
		get_day_of_year(),
		get_hour_of_day(),
		get_minute_of_hour(),
		current_tick
	]

func serialize() -> Dictionary:
	return {
		"current_tick": current_tick
	}

func deserialize(data: Dictionary) -> void:
	current_tick = data.get("current_tick", 0)
