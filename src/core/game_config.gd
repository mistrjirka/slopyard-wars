extends RefCounted
## Match tuning and network limits. Values are game units, not real hardware advice.

const PORT := 24680
const MAX_PLAYERS := 4
const START_MINUTE := 480.0      # 08:00, one focused day of bargain hunting
const TOTAL_MINUTES := 840.0     # Deadline 22:00; about 18m 40s before solo time skips
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
