-- RotaPop: UI.lua
-- Highlights the recommended action button using the built-in overlay glow system.

UI = {}

UI._activeButton = nil   -- currently glowing button frame
UI._lastSpellID  = nil   -- last recommended spell ID

-- All standard actionbar button frame name patterns to scan
local BUTTON_PATTERNS = {
    -- Blizzard default bars
    function(i) return _G["ActionButton"..i] end,              -- slots 1-12
    function(i) return _G["MultiBarBottomLeftButton"..i] end,  -- slots 49-60
    function(i) return _G["MultiBarBottomRightButton"..i] end, -- slots 61-72
    function(i) return _G["MultiBarRightButton"..i] end,       -- slots 73-84
    function(i) return _G["MultiBarLeftButton"..i] end,        -- slots 85-96
    -- TWW additional bars
    function(i) return _G["MultiBar5Button"..i] end,
    function(i) return _G["MultiBar6Button"..i] end,
    function(i) return _G["MultiBar7Button"..i] end,
    -- Bartender4 naming convention
    function(i) return _G["BT4Button"..i] end,
    -- ElvUI naming convention
    function(i) return _G["ElvUI_Bar1Button"..i] end,
    function(i) return _G["ElvUI_Bar2Button"..i] end,
    function(i) return _G["ElvUI_Bar3Button"..i] end,
}

-- Find the action button frame that currently has the given spellID on it
local function FindButtonForSpell(spellID)
    if not spellID then return nil end

    -- Scan all action slots 1-120
    for slot = 1, 120 do
        local slotType, id = GetActionInfo(slot)
        if slotType == "spell" and id == spellID then
            -- Found the slot — now find the button frame
            -- Try each button pattern with index 1-12
            for _, patternFn in ipairs(BUTTON_PATTERNS) do
                for i = 1, 12 do
                    local btn = patternFn(i)
                    if btn and btn.action and btn.action == slot then
                        return btn
                    end
                end
            end
            -- Fallback: try direct slot-to-button mapping for default bars
            if slot >= 1 and slot <= 12 then
                return _G["ActionButton"..slot]
            elseif slot >= 25 and slot <= 36 then
                return _G["ActionButton"..(slot - 24)]  -- page 3 mapped to main bar
            elseif slot >= 49 and slot <= 60 then
                return _G["MultiBarBottomLeftButton"..(slot - 48)]
            elseif slot >= 61 and slot <= 72 then
                return _G["MultiBarBottomRightButton"..(slot - 60)]
            elseif slot >= 73 and slot <= 84 then
                return _G["MultiBarRightButton"..(slot - 72)]
            elseif slot >= 85 and slot <= 96 then
                return _G["MultiBarLeftButton"..(slot - 84)]
            end
        end
    end
    return nil
end

-- Set the recommended action (spellID) and glow its button
function UI:SetAction(spellID)
    if spellID == self._lastSpellID then return end

    -- Remove glow from old button
    if self._activeButton then
        if ActionButton_HideOverlayGlow then
            ActionButton_HideOverlayGlow(self._activeButton)
        end
        self._activeButton = nil
    end

    self._lastSpellID = spellID

    if not spellID then return end

    -- Find and glow the new button
    local btn = FindButtonForSpell(spellID)
    if btn then
        if ActionButton_ShowOverlayGlow then
            ActionButton_ShowOverlayGlow(btn)
        end
        self._activeButton = btn
    end
end

-- Clear all glows (called on disable / out of combat)
function UI:ClearGlow()
    if self._activeButton then
        if ActionButton_HideOverlayGlow then
            ActionButton_HideOverlayGlow(self._activeButton)
        end
        self._activeButton = nil
    end
    self._lastSpellID = nil
end

-- No-op stubs so Main.lua calls don't error
function UI:Show() end
function UI:Hide()
    self:ClearGlow()
end
function UI:SetSize() end
