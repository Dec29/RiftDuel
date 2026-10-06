class_name ViewPalette
extends RefCounted

const BACKGROUND := Color("1a1e24")
const GROUND := Color("2e3440")
const HIGH := Color("3b4252")
const GRID := Color("434c5e")
const BLUE := Color("5e9cd3")
const RED := Color("bf616a")
const BALL := Color("eceff4")
const ARROW := Color("ebcb8b")
const LEGAL := Color("a3be8c80")
const DISABLED := Color("4c566a")
const ATTACK_RANGE := Color("ebcb8b66")
const HEAL_RANGE := Color("88c0d066")
const BLOCKER := Color("d08770")
const TEXT := Color("eceff4")
const MUTED_TEXT := Color("aeb6c2")

const HUD_SURFACE := Color("242b33")
const HUD_INSET := Color("2b323a")
const HUD_RULE := Color("3b444e")
const HUD_HOVER := Color("424c59")
const HUD_DISABLED_TEXT := Color("8994a2")
const HUD_PADDING := 20
const HUD_TITLE_SIZE := 18
const MENU_TEXT_SIZE := 16
const INFO_FONT_SIZE := 15
const INFO_LINE_HEIGHT := 26
const INFO_PARAGRAPH_GAP := 6
const INFO_SCROLL_SPEED := 14.0
const HUD_HEALTH_TEXT_Y := 140
const HUD_STATUS_ROW_GAP := 48
const HUD_STATUS_BAR_GAP := 14
const HUD_DETAIL_TEXT_Y := 238
const HUD_DETAIL_LINE_HEIGHT := 32
const CARD_SYMBOL_RADIUS := 15.0

const ARENA_GRID := Color("39414d")
const PLATFORM_EDGE := Color("788595")
const UNIT_SURFACE := Color("20262e")
const UNIT_INSET_RATIO := 0.14
const UNIT_DIRECTION_RATIO := 0.44
const UNIT_NAME_SIZE := 10

const CELL_SIZE := 36
const BOARD_ORIGIN := Vector2i(64, 72)
const BOARD_SIZE := Vector2i(21, 11) * CELL_SIZE
const SCREEN_SIZE := Vector2i(1280, 720)
const CARD_SIZE := Vector2i(98, 116)
const CARD_GAP := 8
const HUD_ORIGIN := BOARD_ORIGIN + Vector2i(BOARD_SIZE.x + CELL_SIZE + CARD_GAP, 0)
const HUD_WIDTH := SCREEN_SIZE.x - HUD_ORIGIN.x - BOARD_ORIGIN.x / 2
const CARD_ORIGIN := Vector2i(SCREEN_SIZE.x - BOARD_ORIGIN.x / 2 - (CARD_SIZE.x + CARD_GAP) * 8 + CARD_GAP, SCREEN_SIZE.y - CARD_SIZE.y - BOARD_ORIGIN.x / 2)
