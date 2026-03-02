-- RotaPop: UI.lua
-- Minimal single-icon display for the recommended action.

UI = {}

local FRAME_NAME = "RotaPopFrame"

-- Create the main frame
local f = CreateFrame("Frame", FRAME_NAME, UIParent)
f:SetSize(64, 64)
f:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:SetFrameStrata("HIGH")

-- Drag support: hold Alt to drag
f:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and IsAltKeyDown() then
        self:StartMoving()
    end
end)
f:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
end)

-- Solid dark background so frame is visible even without spell icon
local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(f)
bg:SetColorTexture(0, 0, 0, 0.7)

-- Icon texture
local icon = f:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints(f)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
-- Default placeholder texture (question mark icon)
icon:SetTexture(134400)

-- Border highlight for glow effect
local glow = f:CreateTexture(nil, "OVERLAY")
glow:SetAllPoints(f)
glow:SetColorTexture(1, 1, 1, 0)

UI.frame = f
UI.bg    = bg
UI.icon  = icon
UI.glow  = glow
UI._lastSpellID = nil

f:Show()

-- Update the displayed icon
function UI:SetAction(spellID)
    if spellID then
        if spellID == self._lastSpellID then return end
        self._lastSpellID = spellID
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then
            self.icon:SetTexture(tex)
        end
        -- Simple glow pulse on action change
        self.glow:SetColorTexture(1, 1, 1, 0.6)
        C_Timer.After(0.15, function()
            if self.glow then
                self.glow:SetColorTexture(1, 1, 1, 0)
            end
        end)
    else
        -- No action: show placeholder
        self._lastSpellID = nil
        self.icon:SetTexture(134400)  -- question mark
    end
end

-- Show / hide the frame
function UI:Show()
    local alpha
    if RotaPopDB and RotaPopDB.iconAlpha ~= nil then
        alpha = RotaPopDB.iconAlpha
    else
        alpha = 1.0
    end
    self.frame:SetAlpha(alpha)
    self.frame:Show()
end

function UI:Hide()
    self.frame:Hide()
end

-- Resize the icon
function UI:SetSize(size)
    size = size or 64
    self.frame:SetSize(size, size)
end

-- Fade out when out of combat and not in an instance
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    if not RotaPopDB then return end  -- not yet initialised
    if event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: show
        if RotaPopDB.enabled then
            UI.frame:SetAlpha(RotaPopDB.iconAlpha or 1.0)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat: fade out unless in instance
        local inInstance = select(2, IsInInstance()) ~= "none"
        if not inInstance then
            UI.frame:SetAlpha(0.4)
        end
    end
end)
