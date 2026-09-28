local _, ns = ...

-- How many quest turn-ins trigger a workout popup
ns.QUESTS_PER_WORKOUT = 5

ns.ICON = "Interface\\Icons\\Spell_Nature_Strength" -- flexed arm

-- XP bar: every rep gives XP_PER_REP unless changed per movement in the Movements tab. Level n needs n * XP_LEVEL_STEP to reach the next level
-- (100, 200, 300, ...), capped at XP_LEVEL_CAP (so every level after 10 needs 1000).
ns.XP_PER_REP = 1
ns.XP_LEVEL_STEP = 100
ns.XP_LEVEL_CAP = 1000
