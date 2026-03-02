-- RotaPop: State.lua
-- Tracks game state for APL evaluation. Midnight (12.x) APIs only.

State = {}

local ENERGY    = Enum.PowerType.Energy    or 3
local COMBO     = Enum.PowerType.ComboPoints or 4
local MAELSTROM = Enum.PowerType.Maelstrom or 11

-- Registry for buff/debuff/cooldown/spell IDs populated by spec modules
State._buffIDs    = {}   -- name -> spellID
State._debuffIDs  = {}   -- name -> spellID
State._spellIDs   = {}   -- name -> spellID
State._talentIDs  = {}   -- name -> talentID (or name for lookup)
State._dotIDs     = {}   -- name -> spellID (same as debuff but tracked separately for active_dot count)

-- Public state fields (reset each update)
State.time          = 0
State.inCombat      = false
State.health        = 0
State.healthMax     = 1
State.energy        = 0
State.energyMax     = 100
State.comboPoints   = 0
State.comboPointsMax = 5
State.maelstrom    = 0
State.maelstromMax = 100
State.targets       = 1
State.gcd           = 1.5
State.haste         = 1.0
State.stealthed     = false
State.prevGCD       = ""
State.buffs         = {}
State.debuffs       = {}
State.cooldowns     = {}
State.castable      = {}
State.talents       = {}
State.dotRemains    = {}  -- name -> seconds remaining on target
State.activeDots    = {}  -- name -> number of targets with this dot
State.dotDuration   = {}  -- name -> base duration (seconds), populated by RegisterDot
State.charges       = {}  -- name -> { current, max, fractional }
State.flameshockSaturated = false
State.energyRegen   = 10  -- updated each tick via GetPowerRegen
State.timeToDie     = 300 -- estimated time to target death (default: long fight)

-- Register a buff (player aura) by name and spellID
function State:RegisterBuff(name, spellID)
    self._buffIDs[name] = spellID
end

-- Register a debuff (target aura) by name and spellID
function State:RegisterDebuff(name, spellID)
    self._debuffIDs[name] = spellID
end

-- Register a spell by name and spellID (for cooldown / castable tracking)
function State:RegisterSpell(name, spellID)
    self._spellIDs[name] = spellID
end

-- Register a talent name (checked via C_ClassTalents on Update)
function State:RegisterTalent(name)
    self._talentIDs[name] = true
end

-- Register a dot (debuff with remains + active count tracking)
function State:RegisterDot(name, spellID, duration)
    self._dotIDs[name] = spellID
    self._debuffIDs[name] = spellID  -- also register as debuff
    if duration then
        self.dotDuration[name] = duration
    end
end

-- Register a spell that has charges (charge tracking is automatic in Update() for all registered spells)
function State:RegisterChargedSpell(name, spellID)
    self._spellIDs[name] = spellID  -- also register normally
end

-- Wipe cached values
function State:Reset()
    self.buffs     = {}
    self.debuffs   = {}
    self.cooldowns = {}
    self.castable  = {}
    self.talents   = {}
    self.dotRemains = {}
    self.activeDots = {}
    self.charges    = {}
    self.timeToDie  = 300
end

-- Called before each APL evaluation
function State:Update()
    self:Reset()

    self.time     = GetTime()
    self.inCombat = UnitAffectingCombat("player") and true or false

    self.health    = UnitHealth("player") or 0
    self.healthMax = UnitHealthMax("player") or 1

    self.energy    = UnitPower("player", ENERGY) or 0
    self.energyMax = UnitPowerMax("player", ENERGY) or 100
    do
        -- GetPowerRegen returns baseRegen (out-of-combat/normal), castRegen (while casting)
        -- Use baseRegen as the normal regen rate for APL time-to-cap calculations
        local baseRegen, castRegen = GetPowerRegen()
        self.energyRegen = baseRegen or castRegen or 10
    end

    self.comboPoints    = UnitPower("player", COMBO) or 0
    self.comboPointsMax = UnitPowerMax("player", COMBO) or 5

    -- Maelstrom (Enhancement Shaman)
    self.maelstrom    = UnitPower("player", MAELSTROM) or 0
    self.maelstromMax = UnitPowerMax("player", MAELSTROM) or 100

    -- Target count: nameplate count, minimum 1
    local plates = C_NamePlate.GetNamePlates()
    self.targets = math.max(1, plates and #plates or 1)

    -- GCD
    local gcdMS = GetSpellBaseCooldown(61304)
    self.gcd = gcdMS and (gcdMS / 1000) or 1.5
    if self.gcd <= 0 then self.gcd = 1.5 end

    -- Haste
    self.haste = (UnitSpellHaste("player") or 0) / 100 + 1

    -- Buffs (player)
    for name, spellID in pairs(self._buffIDs) do
        local aura = C_UnitAuras.GetAuraDataBySpellID("player", spellID)
        if aura then
            self.buffs[name] = {
                up      = true,
                remains = aura.expirationTime and (aura.expirationTime - self.time) or math.huge,
                stack   = aura.applications or 1,
            }
        else
            self.buffs[name] = { up = false, remains = 0, stack = 0 }
        end
    end

    -- Stealth: true if any stealth/shadow dance buff is active
    self.stealthed = (
        (self.buffs["stealth"]       and self.buffs["stealth"].up)       or
        (self.buffs["shadow_dance"]  and self.buffs["shadow_dance"].up)  or
        (self.buffs["subterfuge"]    and self.buffs["subterfuge"].up)    or
        false
    )

    -- Debuffs (target)
    for name, spellID in pairs(self._debuffIDs) do
        local aura = C_UnitAuras.GetAuraDataBySpellID("target", spellID)
        if aura then
            self.debuffs[name] = {
                up      = true,
                remains = aura.expirationTime and (aura.expirationTime - self.time) or math.huge,
                stack   = aura.applications or 1,
            }
        else
            self.debuffs[name] = { up = false, remains = 0, stack = 0 }
        end
    end

    -- Cooldowns and castable
    for name, spellID in pairs(self._spellIDs) do
        local cdInfo = C_Spell.GetSpellCooldown(spellID)
        if cdInfo then
            local remains = 0
            if cdInfo.startTime and cdInfo.startTime > 0 and cdInfo.duration and cdInfo.duration > 0 then
                remains = (cdInfo.startTime + cdInfo.duration) - self.time
                if remains < 0 then remains = 0 end
            end
            self.cooldowns[name] = remains
        else
            self.cooldowns[name] = 0
        end
        self.castable[name] = C_Spell.IsSpellUsable(spellID) and true or false
    end

    -- Spell charges
    self.charges = {}
    for name, spellID in pairs(self._spellIDs) do
        local info = C_Spell.GetSpellCharges(spellID)
        if info then
            local frac = info.currentCharges + (info.currentCharges < info.maxCharges and
                (1 - math.max(0, (info.cooldownStartTime + info.cooldownDuration - self.time)) / math.max(1, info.cooldownDuration)) or 0)
            self.charges[name] = {
                current    = info.currentCharges,
                max        = info.maxCharges,
                fractional = frac,
            }
        else
            self.charges[name] = { current = 1, max = 1, fractional = 1.0 }
        end
    end

    -- Dot tracking (target)
    self.dotRemains = {}
    self.activeDots = {}
    for name, spellID in pairs(self._dotIDs) do
        -- Remains on current target
        local aura = C_UnitAuras.GetAuraDataBySpellID("target", spellID)
        self.dotRemains[name] = aura and aura.expirationTime and (aura.expirationTime - self.time) or 0

        -- Active dot count: check nameplates
        local count = 0
        local plates = C_NamePlate.GetNamePlates()
        if plates then
            for _, plate in ipairs(plates) do
                local unit = plate.namePlateUnitToken
                if unit and UnitCanAttack("player", unit) then
                    local dotAura = C_UnitAuras.GetAuraDataBySpellID(unit, spellID)
                    if dotAura then count = count + 1 end
                end
            end
        end
        self.activeDots[name] = count
    end

    -- Talents: safe wrapper using C_ClassTalents
    for name in pairs(self._talentIDs) do
        self.talents[name] = self:_checkTalent(name)
    end

    -- flame_shock_saturated: all enemies have flame shock, or 6 targets have it
    local fsActive = self.activeDots["flame_shock"] or 0
    self.flameshockSaturated = (fsActive >= self.targets) or (fsActive >= 6)
end

-- Safe talent check. Returns true if the player has the named talent active.
function State:_checkTalent(name)
    local ok, result = pcall(function()
        local configID = C_ClassTalents.GetActiveConfigID()
        if not configID then return false end
        local configInfo = C_Traits.GetConfigInfo(configID)
        if not configInfo then return false end
        for _, treeID in ipairs(configInfo.treeIDs or {}) do
            local nodes = C_Traits.GetTreeNodes(treeID)
            if nodes then
                for _, nodeID in ipairs(nodes) do
                    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                    if nodeInfo and nodeInfo.activeEntry then
                        local entryInfo = C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID)
                        if entryInfo and entryInfo.definitionID then
                            local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                            if defInfo then
                                local spellName = defInfo.spellID and C_Spell.GetSpellName(defInfo.spellID) or nil
                                if spellName then
                                    local normalized = spellName:lower():gsub(" ", "_"):gsub("'", "")
                                    if normalized == name then
                                        return (nodeInfo.activeEntry.rank or 0) > 0
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return false
    end)
    if ok then return result else return false end
end
