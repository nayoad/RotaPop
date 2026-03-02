-- RotaPop: State.lua
-- Tracks game state for APL evaluation. Midnight (12.x) APIs only.

State = {}

local ENERGY    = Enum.PowerType.Energy    or 3
local COMBO     = Enum.PowerType.ComboPoints or 4

-- Registry for buff/debuff/cooldown/spell IDs populated by spec modules
State._buffIDs    = {}   -- name -> spellID
State._debuffIDs  = {}   -- name -> spellID
State._spellIDs   = {}   -- name -> spellID
State._talentIDs  = {}   -- name -> talentID (or name for lookup)

-- Public state fields (reset each update)
State.time          = 0
State.inCombat      = false
State.health        = 0
State.healthMax     = 1
State.energy        = 0
State.energyMax     = 100
State.comboPoints   = 0
State.comboPointsMax = 5
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

-- Wipe cached values
function State:Reset()
    self.buffs     = {}
    self.debuffs   = {}
    self.cooldowns = {}
    self.castable  = {}
    self.talents   = {}
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

    self.comboPoints    = UnitPower("player", COMBO) or 0
    self.comboPointsMax = UnitPowerMax("player", COMBO) or 5

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

    -- Talents: safe wrapper using C_ClassTalents
    for name in pairs(self._talentIDs) do
        self.talents[name] = self:_checkTalent(name)
    end
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
