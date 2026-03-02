-- RotaPop: Spells/RogueSubtlety.lua
-- Subtlety Rogue spec module (Spec ID 261) – TWW Season 2 / Midnight APL

if UnitClassBase("player") ~= "ROGUE" then return end

RotaPop:RegisterSpec(261, function()

-- ============================================================
-- Spell IDs
-- ============================================================
local spells = {
    shadowstrike        = 185438,
    backstab            = 53,
    eviscerate          = 196819,
    rupture             = 1943,
    black_powder        = 319175,
    symbols_of_death    = 212283,
    shadow_dance        = 185313,
    shadowblades        = 121471,
    secret_technique    = 280719,
    shuriken_tornado    = 277925,
    shuriken_toss       = 114014,
    shuriken_storm      = 197835,
    cheap_shot          = 1833,
    kidney_shot         = 408,
    vanish              = 1856,
    shadowstep          = 36554,
    cold_blood          = 382245,
    echoing_reprimand   = 385616,
    thistle_tea         = 381623,
    sepsis              = 385408,
    serrated_bone_spike = 385424,
    flagellation        = 323654,
    coup_de_grace       = 441423,
    unseen_blade        = 441386,
}

for name, id in pairs(spells) do
    State:RegisterSpell(name, id)
end

-- ============================================================
-- Buff IDs (player auras)
-- ============================================================
local buffs = {
    symbols_of_death        = 212283,
    shadow_dance            = 185422,
    stealth                 = 115191,
    subterfuge              = 115192,
    shadow_blades           = 121471,
    shuriken_tornado        = 277925,
    flagellation            = 323654,
    flagellation_persist    = 394755,
    the_rotten              = 394427,
    danse_macabre           = 393969,
    deeper_daggers          = 383405,
    finality_eviscerate     = 385947,
    finality_rupture        = 385949,
    finality_black_powder   = 385948,
    cold_blood              = 382245,
    darkest_night           = 457280,
    thistle_tea             = 381623,
    supercharged_combo_points = 450394,
    coup_de_grace           = 441423,
    goremaws_bite           = 394403,
    deathstalkers_mark_buff = 457836,
    shadow_techniques       = 196911,
    premeditation           = 343173,
    shot_in_the_dark        = 257508,
    perforated_veins        = 394254,
    echoing_reprimand       = 385616,
}

for name, id in pairs(buffs) do
    State:RegisterBuff(name, id)
end

-- ============================================================
-- Debuff IDs (target auras)
-- ============================================================
local debuffs = {
    find_weakness        = 91021,
    deathstalkers_mark   = 457829,
    sepsis               = 385408,
    serrated_bone_spike  = 385424,
    flagellation         = 323654,
}

for name, id in pairs(debuffs) do
    State:RegisterDebuff(name, id)
end

-- Dots (tracked on target + active count, with pandemic duration)
State:RegisterDot("rupture", 1943, 24)

-- ============================================================
-- Talent names
-- ============================================================
local talents = {
    "shadow_dance", "subterfuge", "secret_technique", "danse_macabre",
    "flagellation", "sepsis", "serrated_bone_spike", "echoing_reprimand",
    "shuriken_tornado", "cold_blood", "thistle_tea", "the_rotten",
    "deeper_daggers", "finality", "goremaws_bite", "darkest_night",
    "supercharger", "coup_de_grace", "death_perception", "symbolic_victory",
    "improved_shuriken_storm", "premeditation", "shadow_techniques",
    "relentless_strikes", "alacrity", "perforated_veins", "unseen_blade",
    "disorienting_strikes",
}

for _, name in ipairs(talents) do
    State:RegisterTalent(name)
end

-- ============================================================
-- APL Action Lists
-- ============================================================

-- default
APL:RegisterList("default", {
    { action = "call_action_list", list_name = "cds" },
    { action = "call_action_list", list_name = "stealth_opener",
      condition = "stealthed.all" },
    { action = "call_action_list", list_name = "finish",
      condition = "combo_points>=5|(combo_points>=4&talent.deeper_daggers.enabled)|(combo_points>=3&buff.coup_de_grace.up)" },
    { action = "call_action_list", list_name = "build" },
})

-- cds (cooldowns)
APL:RegisterList("cds", {
    { action = "symbols_of_death" },
    { action = "shadow_dance",
      condition = "!buff.shadow_dance.up&!buff.symbols_of_death.up" },
    { action = "shadowblades",
      condition = "buff.symbols_of_death.up" },
    { action = "flagellation",
      condition = "buff.symbols_of_death.up" },
    { action = "sepsis",
      condition = "buff.symbols_of_death.up" },
    { action = "secret_technique",
      condition = "buff.symbols_of_death.up&combo_points>=5" },
    { action = "shuriken_tornado",
      condition = "buff.symbols_of_death.up&energy>=60" },
    { action = "cold_blood",
      condition = "combo_points>=5" },
    { action = "thistle_tea",
      condition = "energy.deficit>=100" },
    { action = "echoing_reprimand" },
})

-- stealth_opener
APL:RegisterList("stealth_opener", {
    { action = "cheap_shot",
      condition = "!debuff.find_weakness.up" },
    { action = "shadowstrike",
      condition = "buff.premeditation.up|combo_points<=3" },
    { action = "shuriken_storm",
      condition = "active_enemies>=3&buff.premeditation.up" },
})

-- finish
APL:RegisterList("finish", {
    { action = "coup_de_grace",
      condition = "buff.coup_de_grace.up" },
    { action = "secret_technique",
      condition = "buff.symbols_of_death.up" },
    { action = "eviscerate",
      condition = "buff.finality_eviscerate.down|debuff.deathstalkers_mark.up" },
    { action = "black_powder",
      condition = "active_enemies>=3&buff.finality_black_powder.down" },
    { action = "rupture",
      condition = "dot.rupture.remains<4&target.time_to_die>8" },
    { action = "eviscerate" },
})

-- build
APL:RegisterList("build", {
    { action = "shuriken_storm",
      condition = "active_enemies>=3" },
    { action = "shadowstrike",
      condition = "stealthed.all|debuff.find_weakness.up" },
    { action = "backstab" },
})

end) -- RotaPop:RegisterSpec(261)
