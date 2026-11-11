extends RefCounted
## Match tuning and network limits. Values are game units, not real hardware advice.

const PORT := 24680
const MAX_PLAYERS := 4
const START_MINUTE := 480.0      # Day 1, 08:00
const DEFAULT_MATCH_DAYS := 2
const MIN_MATCH_DAYS := 1
const MAX_MATCH_DAYS := 7
const TOTAL_MINUTES := 840.0 + (DEFAULT_MATCH_DAYS - 1) * 1440.0
const DEADLINE := START_MINUTE + TOTAL_MINUTES
const RATE := 0.75               # game minutes per real second; time to read and negotiate
const BUILD_REMINDER_MINUTES := 180.0
const REFRESH_EVERY := 60.0       # game minutes
const SAVE_PATH := "user://highscore.json"
const MAX_CHAT := 24
const MAX_EVENTS := 14
const MAX_TEXT := 240
const INSTALL_MIN := 10.0
const TUNE_MIN := 20.0


static func duration_for_days(days: int) -> float:
	# Start at 08:00 on day one, finish at 22:00 on the chosen final day.
	return 840.0 + (clampi(days, MIN_MATCH_DAYS, MAX_MATCH_DAYS) - 1) * 1440.0


static func deadline_for_days(days: int) -> float:
	return START_MINUTE + duration_for_days(days)
