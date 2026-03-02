-- RotaPop: Main.lua
-- Entry point for the RotaPop addon.

local addonName, ns = ...
RotaPop = {}
local addon = RotaPop

RotaPop._specInits = {}  -- specID -> init function, registered by spec modules

-- Register a spec initializer function (called by spec modules at load time)
function RotaPop:RegisterSpec(specID, fn)
    self._specInits[specID] = fn
end

-- Detect current spec and run its initializer
function addon:LoadSpec()
    local specIndex = GetSpecialization()
    if not specIndex then
        print("|cff00ccff[RotaPop]|r |cffff9900No spec detected.|r")
        return
    end
    local specID = GetSpecializationInfo(specIndex)
    if not specID then
        print("|cff00ccff[RotaPop]|r |cffff9900GetSpecializationInfo returned nil.|r")
        return
    end
    -- Reset State registries
    State._buffIDs   = {}
    State._debuffIDs = {}
    State._spellIDs  = {}
    State._talentIDs = {}
    State._dotIDs    = {}
    State.dotDuration = {}
    -- Reset APL lists and variables
    APL._lists = {}
    APL._vars  = {}
    -- Run spec init if registered
    if RotaPop._specInits[specID] then
        RotaPop._specInits[specID]()
        print("|cff00ccff[RotaPop]|r APL loaded for spec " .. tostring(specID))
    else
        print("|cff00ccff[RotaPop]|r |cffff9900No APL registered for spec " .. tostring(specID) .. ". Supported: Rogue Subtlety (261), Shaman Enhancement (263).|r")
    end
end

local defaults = {
    enabled = true,
    iconSize = 64,
    iconAlpha = 1.0,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

-- Track last cast for prevGCD
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            -- Initialize SavedVariables
            if not RotaPopDB then
                RotaPopDB = {}
            end
            for k, v in pairs(defaults) do
                if RotaPopDB[k] == nil then
                    RotaPopDB[k] = v
                end
            end
        end

    elseif event == "PLAYER_LOGIN" then
        addon:OnLogin()

    elseif event == "PLAYER_ENTERING_WORLD" then
        addon:OnEnterWorld()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        addon:LoadSpec()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            local name = C_Spell.GetSpellName(spellID) or ""
            State.prevGCD = name:lower():gsub(" ", "_")
        end
    end
end)

function addon:OnLogin()
    -- Detect spec and run its initializer
    addon:LoadSpec()

    -- Apply saved settings to UI
    if UI and UI.frame then
        UI:SetSize(RotaPopDB.iconSize)
        UI.frame:SetAlpha(RotaPopDB.iconAlpha)
    end

    print("|cff00ccff[RotaPop]|r loaded. Type /rotapop to toggle.")
end

function addon:OnEnterWorld()
    -- Start repeating ticker to evaluate APL every 0.1 seconds
    if addon.ticker then
        addon.ticker:Cancel()
    end
    addon.ticker = C_Timer.NewTicker(0.1, function()
        if not RotaPopDB.enabled then
            UI:Hide()
            return
        end
        State:Update()
        local action, spellID = APL:GetNextAction()
        if action and spellID then
            UI:SetAction(spellID)
            UI:Show()
        elseif not State.inCombat then
            -- Outside combat: show placeholder and keep frame visible
            UI:SetAction(nil)
            UI:Show()
        else
            UI:Hide()
        end
    end)
end

-- Slash command
SLASH_ROTAPOP1 = "/rotapop"
SlashCmdList["ROTAPOP"] = function(msg)
    RotaPopDB.enabled = not RotaPopDB.enabled
    if RotaPopDB.enabled then
        print("|cff00ccff[RotaPop]|r |cff00ff00enabled|r.")
    else
        print("|cff00ccff[RotaPop]|r |cffff4444disabled|r.")
        UI:Hide()
    end
end
