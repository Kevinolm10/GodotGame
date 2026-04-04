extends Node

# ─── Player Stats ────────────────────────────────────────────────────────────
var health           : int = 100
var max_health       : int = 100

# ─── Level / XP ──────────────────────────────────────────────────────────────
var level            : int = 1
var xp               : int = 0
var xp_to_next_level : int = 100

# ─── Gold  ──────────────────────────────────────────────────────────────
var gold : int = 0

# ─── Inventory ───────────────────────────────────────────────────────────────
var inventory        : Array = []

# ─── Combat Stats ────────────────────────────────────────────────────────────
var kill_count       : int = 0

# ─── Reset (called on full game over, not just death) ────────────────────────
func reset() -> void:
	health           = 100
	max_health       = 100
	level            = 1
	xp               = 0
	xp_to_next_level = 100
	inventory        = []
	kill_count       = 0
	gold = 0
