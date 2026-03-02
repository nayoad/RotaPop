-- RotaPop: Main.lua
-- Entry point for the RotaPop addon.

local addonName, ns = ...
RotaPop = {}
local addon = RotaPop

local defaults = {
    enabled = true,
    iconSize = 64,
    iconAlpha = 1.0,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

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

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            local name = C_Spell.GetSpellName(spellID) or ""
            State.prevGCD = name:lower():gsub(" ", "_")
        end
    end
end)

function addon:OnLogin()
    -- Detect spec and load spell module
    local specIndex = GetSpecialization()
    if specIndex then
        local specID = GetSpecializationInfo(specIndex)
        if specID == 261 then
            -- Subtlety Rogue – loaded via TOC file order
        end
    end

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
            -- Outside combat: keep frame visible (alpha handled by combatFrame)
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
