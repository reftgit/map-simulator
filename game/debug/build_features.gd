class_name BuildFeatures
extends RefCounted
## What a build may do beyond normal gameplay. Debug builds get the debug
## overlay and its buttons (VIEW, Q, DUMMY, CAR) and performance experiments.
## Release builds exported with the "perf_bench" custom feature (only the
## "* Release Perf" presets) get performance experiments, benchmarks, and the
## STARTUP log, but no overlay or debug buttons. Normal release builds get
## neither. Tests can force both answers.

const PERF_FEATURE := "perf_bench"

## -1 asks the engine; 0 or 1 forces the answer (tests).
static var debug_override := -1
static var perf_feature_override := -1


static func is_debug() -> bool:
	return OS.is_debug_build() if debug_override < 0 else debug_override == 1


static func has_perf_feature() -> bool:
	return OS.has_feature(PERF_FEATURE) if perf_feature_override < 0 else perf_feature_override == 1


## Performance experiments, benchmarks, and the STARTUP log line.
static func perf_enabled() -> bool:
	return is_debug() or has_perf_feature()


static func reset_overrides() -> void:
	debug_override = -1
	perf_feature_override = -1
