-- Spells/ShamanEnhancement.lua
-- Enhancement Shaman - Spec ID 263
-- APL source: simulationcraft/simc ActionPriorityLists/default/shaman_enhancement.simc
-- Adapted for RotaPop (Midnight 12.x)

if UnitClassBase("player") ~= "SHAMAN" then return end

RotaPop:RegisterSpec(263, function()

-- Spells (name -> spellID)
State:RegisterSpell("stormstrike",        17364)
State:RegisterSpell("windstrike",         115356)
State:RegisterSpell("lava_lash",          60103)
State:RegisterSpell("crash_lightning",    187874)
State:RegisterSpell("chain_lightning",    188443)
State:RegisterSpell("lightning_bolt",     188196)
State:RegisterSpell("tempest",            452201)
State:RegisterSpell("ascendance",         114051)
State:RegisterSpell("doom_winds",         384352)
State:RegisterSpell("sundering",          197214)
State:RegisterSpell("feral_spirit",       51533)
State:RegisterSpell("primordial_storm",   388074)
State:RegisterSpell("voltaic_blaze",      452214)
State:RegisterSpell("surging_totem",      444995)
State:RegisterSpell("flame_shock",        188389)
State:RegisterSpell("frost_shock",        196840)
State:RegisterSpell("elemental_blast",    117014)
State:RegisterSpell("windfury_weapon",    33757)
State:RegisterSpell("flametongue_weapon", 318038)
State:RegisterSpell("lightning_shield",   192106)

-- Buffs (player auras)
State:RegisterBuff("maelstrom_weapon",          344179)
State:RegisterBuff("ascendance",                114051)
State:RegisterBuff("doom_winds",                384352)
State:RegisterBuff("crash_lightning",           187878)
State:RegisterBuff("stormbringer",              201845)
State:RegisterBuff("hot_hand",                  215785)
State:RegisterBuff("legacy_of_the_frost_witch", 384451)
State:RegisterBuff("whirling_air",              454026)
State:RegisterBuff("whirling_fire",             454025)
State:RegisterBuff("whirling_earth",            454024)
State:RegisterBuff("converging_storms",         198300)
State:RegisterBuff("primordial_storm",          388074)
State:RegisterBuff("tempest",                   454015)
State:RegisterBuff("lightning_rod",             210689)
State:RegisterBuff("voltaic_blaze",             452214)
State:RegisterBuff("feral_spirit",              333957)
State:RegisterBuff("natures_swiftness",         378081)
State:RegisterBuff("windfury_weapon",           33757)
State:RegisterBuff("flametongue_weapon",        318038)
State:RegisterBuff("lightning_shield",          192106)

-- Debuffs (target auras)
State:RegisterDebuff("lashing_flames", 334168)
State:RegisterDebuff("lightning_rod",  210689)
State:RegisterDebuff("chaos_brand",    1490)

-- Dots (tracked on target + active count, with pandemic duration)
State:RegisterDot("flame_shock", 188389, 18)

-- Talents
local talents = {
    "surging_totem", "thorims_invocation", "ascendance", "doom_winds",
    "feral_spirit", "sundering", "splitstream", "fire_nova", "storm_unleashed",
    "deeply_rooted_elements", "elemental_assault", "hot_hand", "lashing_flames",
    "static_accumulation", "elemental_blast", "primordial_storm", "voltaic_blaze",
    "surging_elements", "converging_storms", "tempest", "raging_maelstrom",
    "totemic_rebound", "conductive_energy", "stormweaver", "elemental_tempo",
}
for _, t in ipairs(talents) do
    State:RegisterTalent(t)
end

-- Default routing list
APL:RegisterList("default", {
    { action = "call_action_list", list_name = "single_sb",      condition = "active_enemies==1&!talent.surging_totem.enabled" },
    { action = "call_action_list", list_name = "single_totemic", condition = "active_enemies==1&talent.surging_totem.enabled" },
    { action = "call_action_list", list_name = "aoe",            condition = "active_enemies>1" },
})

-- AoE list
APL:RegisterList("aoe", {
    { action = "voltaic_blaze",    condition = "talent.surging_totem.enabled&dot.flame_shock.remains==0" },
    { action = "surging_totem" },
    { action = "ascendance",       condition = "ti_chain_lightning" },
    { action = "call_action_list", list_name = "buffs" },
    { action = "sundering",        condition = "talent.surging_elements.enabled|buff.whirling_earth.up" },
    { action = "lava_lash",        condition = "buff.whirling_fire.up" },
    { action = "doom_winds" },
    { action = "crash_lightning",  condition = "talent.thorims_invocation.enabled&buff.whirling_air.up&(buff.doom_winds.up|buff.ascendance.up)" },
    { action = "windstrike",       condition = "talent.thorims_invocation.enabled&buff.whirling_air.up&buff.ascendance.up" },
    { action = "stormstrike",      condition = "talent.thorims_invocation.enabled&buff.whirling_air.up&buff.doom_winds.up" },
    { action = "lava_lash",        condition = "talent.splitstream.enabled&buff.hot_hand.up" },
    { action = "tempest",          condition = "buff.maelstrom_weapon.stack>=10&(!buff.ascendance.up|!buff.doom_winds.up)" },
    { action = "primordial_storm", condition = "buff.maelstrom_weapon.stack>=10" },
    { action = "voltaic_blaze",    condition = "talent.fire_nova.enabled" },
    { action = "crash_lightning" },
    { action = "windstrike" },
    { action = "stormstrike",      condition = "buff.doom_winds.up" },
    { action = "chain_lightning",  condition = "buff.maelstrom_weapon.stack>=9" },
    { action = "sundering",        condition = "talent.feral_spirit.enabled" },
    { action = "voltaic_blaze" },
    { action = "stormstrike",      condition = "charges_fractional>=1.8|buff.converging_storms.stack==buff.converging_storms.max_stack" },
    { action = "sundering",        condition = "cooldown.surging_totem.remains>25" },
    { action = "stormstrike",      condition = "!talent.surging_totem.enabled" },
    { action = "lava_lash" },
    { action = "stormstrike" },
    { action = "chain_lightning",  condition = "buff.maelstrom_weapon.stack>=5" },
})

-- Stormbringer single target list
APL:RegisterList("single_sb", {
    { action = "primordial_storm", condition = "buff.maelstrom_weapon.stack>=9|buff.primordial_storm.remains<=4&buff.maelstrom_weapon.stack>=5" },
    { action = "voltaic_blaze",    condition = "dot.flame_shock.remains==0" },
    { action = "lava_lash",        condition = "!debuff.lashing_flames.up" },
    { action = "call_action_list", list_name = "buffs" },
    { action = "sundering",        condition = "talent.surging_elements.enabled|talent.feral_spirit.enabled" },
    { action = "doom_winds" },
    { action = "crash_lightning",  condition = "!buff.crash_lightning.up|talent.storm_unleashed.enabled" },
    { action = "windstrike",       condition = "buff.maelstrom_weapon.stack>0&talent.thorims_invocation.enabled" },
    { action = "ascendance" },
    { action = "stormstrike",      condition = "buff.doom_winds.up&talent.thorims_invocation.enabled" },
    { action = "crash_lightning",  condition = "buff.doom_winds.up&talent.thorims_invocation.enabled" },
    { action = "tempest",          condition = "buff.maelstrom_weapon.stack==10" },
    { action = "lightning_bolt",   condition = "buff.maelstrom_weapon.stack==10" },
    { action = "stormstrike",      condition = "charges_fractional>=1.8" },
    { action = "lava_lash" },
    { action = "stormstrike" },
    { action = "voltaic_blaze" },
    { action = "sundering" },
    { action = "lightning_bolt",   condition = "buff.maelstrom_weapon.stack>=8" },
    { action = "crash_lightning" },
    { action = "lightning_bolt",   condition = "buff.maelstrom_weapon.stack>=5" },
})

-- Totemic single target list
APL:RegisterList("single_totemic", {
    { action = "voltaic_blaze",    condition = "dot.flame_shock.remains==0" },
    { action = "surging_totem" },
    { action = "call_action_list", list_name = "buffs" },
    { action = "lava_lash",        condition = "buff.whirling_fire.up|buff.hot_hand.up" },
    { action = "sundering",        condition = "talent.surging_elements.enabled|buff.whirling_earth.up|talent.feral_spirit.enabled" },
    { action = "doom_winds" },
    { action = "crash_lightning",  condition = "!buff.crash_lightning.up|talent.storm_unleashed.enabled" },
    { action = "primordial_storm", condition = "buff.maelstrom_weapon.stack>=10|buff.primordial_storm.remains<3.5&buff.maelstrom_weapon.stack>=5" },
    { action = "windstrike",       condition = "talent.thorims_invocation.enabled&buff.ascendance.up" },
    { action = "ascendance",       condition = "ti_lightning_bolt" },
    { action = "crash_lightning",  condition = "talent.thorims_invocation.enabled&(buff.doom_winds.up|buff.ascendance.up)" },
    { action = "stormstrike",      condition = "talent.thorims_invocation.enabled&buff.doom_winds.up" },
    { action = "lightning_bolt",   condition = "talent.elemental_tempo.enabled&buff.maelstrom_weapon.stack>=5&cooldown.lava_lash.remains>gcd.max" },
    { action = "crash_lightning",  condition = "!buff.crash_lightning.up" },
    { action = "lava_lash" },
    { action = "sundering",        condition = "cooldown.surging_totem.remains>25" },
    { action = "stormstrike" },
    { action = "voltaic_blaze" },
    { action = "crash_lightning" },
    { action = "lightning_bolt",   condition = "buff.maelstrom_weapon.stack>=5" },
})

-- Buffs list (major CDs only - trinkets/potions omitted)
APL:RegisterList("buffs", {
    { action = "feral_spirit" },
    { action = "ascendance", condition = "buff.doom_winds.up|buff.feral_spirit.up" },
})

end) -- RotaPop:RegisterSpec(263)
