extends RefCounted
## Match tuning and network limits. Values are game units, not real hardware advice.

const PORT := 24680
const MAX_PLAYERS := 4
const RATE := 2.0                 # game minutes per real second
const TOTAL_MINUTES := 4320.0
const REFRESH_EVERY := 90.0       # game minutes
const SAVE_PATH := "user://highscore.json"
const MAX_CHAT := 24
const MAX_EVENTS := 14
const MAX_TEXT := 240
const INSTALL_MIN := 10.0
const TUNE_MIN := 20.0
