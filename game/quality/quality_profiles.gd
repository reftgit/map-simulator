class_name QualityProfiles
extends RefCounted
## The available quality profiles and the default selection rule:
## iOS -> "high", Android -> "low", anything else (desktop, editor, tests) ->
## "none" (scene defaults). No GPU detection; the rule is per platform only.
## Overrides, strongest first: a debug experiment's "profile" key, then
## `--quality=<name>` on the command line, then the platform rule.

const NONE := "none"
const PROFILES := {
	"high": preload("res://game/quality/profiles/high.tres"),
	"low": preload("res://game/quality/profiles/low.tres"),
}


static func names() -> Array[String]:
	var all: Array[String] = [NONE]
	for profile_name: String in PROFILES:
		all.append(profile_name)
	return all


## Platform rule, for `platform` or else Platform.current().
static func default_name(platform: Platform = null) -> String:
	var on := platform if platform else Platform.current()
	if on.is_ios():
		return "high"
	if on.is_android():
		return "low"
	return NONE


## Profile name from `--quality=<name>` among `args`, or "" when absent or unknown.
static func name_from_args(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with("--quality="):
			var requested := arg.trim_prefix("--quality=")
			if requested in names():
				return requested
			push_warning("QualityProfiles: unknown profile '%s'" % requested)
	return ""


## Settings of a profile by name; "none" or an unknown name gives {}.
static func settings_for(profile_name: String) -> Dictionary:
	var profile: QualityProfile = PROFILES.get(profile_name)
	return profile.to_settings() if profile else {}
