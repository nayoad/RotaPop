-- RotaPop: APL.lua
-- SimC APL parser and executor.

APL = {}

APL._lists = {}  -- name -> array of action entries
APL._vars  = {}  -- variable storage for set_variable / variable actions

-- Register a named action list
function APL:RegisterList(name, actions)
    self._lists[name] = actions
end

-- Evaluate the "default" action list and return (actionName, spellID) for the
-- first action whose condition passes and whose spell is castable.
function APL:GetNextAction()
    return self:_evalList("default")
end

-- Internal: evaluate a named list recursively
function APL:_evalList(listName)
    local list = self._lists[listName]
    if not list then return nil, nil end

    for _, entry in ipairs(list) do
        -- Set current action context (used for charges_fractional substitution)
        APL._currentAction = entry.action
        -- Check condition (if any)
        local condPassed = true
        if entry.condition and entry.condition ~= "" then
            condPassed = self:EvalCondition(entry.condition)
        end

        if condPassed then
            -- Skip non-cast actions
            if entry.action == "auto_attack" or entry.action == "pool_resource" then
                -- no-op; keep evaluating

            elseif entry.action == "set_variable" then
                self:EvalAction(entry)
                -- keep evaluating (set_variable never returns a spell)

            elseif (entry.action == "call_action_list" or entry.action == "run_action_list") and entry.list_name then
                local a, id = self:_evalList(entry.list_name)
                if a then return a, id end

            else
                -- Check castable
                local spellID = State._spellIDs[entry.action]
                if spellID then
                    local cd = State.cooldowns[entry.action] or 0
                    local usable = State.castable[entry.action]
                    if usable and cd <= 0 then
                        return entry.action, spellID
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Convert a SimC condition string to a Lua-evaluable string
function APL:SimToLua(str)
    if not str or str == "" then return "true" end

    -- Protect != before replacing =
    str = str:gsub("!=", "\0NE\0")
    -- Replace single = (not already ==, <=, >=) with ==
    str = str:gsub("([^=<>~!])=([^=])", "%1==%2")
    -- Restore !=  -> ~=
    str = str:gsub("\0NE\0", "~=")

    -- Logical operators
    str = str:gsub("%&", " and ")
    str = str:gsub("%|", " or ")
    -- Logical negation: !( and !word
    str = str:gsub("!(%()", "not (")
    str = str:gsub("!(%w)", "not %1")

    -- Absolute value
    str = str:gsub("@", "math.abs")

    -- debuff.X.field (must come BEFORE buff.X so 'buff' inside 'debuff' is not partially matched)
    str = str:gsub("debuff%.([%w_]+)%.up",      function(n) return "(State.debuffs['"..n.."'] and State.debuffs['"..n.."'].up)" end)
    str = str:gsub("debuff%.([%w_]+)%.down",    function(n) return "(not (State.debuffs['"..n.."'] and State.debuffs['"..n.."'].up))" end)
    str = str:gsub("debuff%.([%w_]+)%.remains", function(n) return "(State.debuffs['"..n.."'] and State.debuffs['"..n.."'].remains or 0)" end)
    str = str:gsub("debuff%.([%w_]+)%.stack",   function(n) return "(State.debuffs['"..n.."'] and State.debuffs['"..n.."'].stack or 0)" end)

    -- buff.X.field
    str = str:gsub("buff%.([%w_]+)%.up",       function(n) return "(State.buffs['"..n.."'] and State.buffs['"..n.."'].up)" end)
    str = str:gsub("buff%.([%w_]+)%.down",     function(n) return "(not (State.buffs['"..n.."'] and State.buffs['"..n.."'].up))" end)
    str = str:gsub("buff%.([%w_]+)%.remains",  function(n) return "(State.buffs['"..n.."'] and State.buffs['"..n.."'].remains or 0)" end)
    str = str:gsub("buff%.([%w_]+)%.stack",    function(n) return "(State.buffs['"..n.."'] and State.buffs['"..n.."'].stack or 0)" end)
    str = str:gsub("buff%.([%w_]+)%.max_stack",function(n) return "(State.buffs['"..n.."'] and State.buffs['"..n.."'].stack or 0)" end)

    -- dot.X.field (order: refreshable before ticking before remains)
    str = str:gsub("dot%.([%w_]+)%.refreshable", function(n)
        return "((State.dotRemains['"..n.."'] or 0) < (State.dotDuration['"..n.."'] or 0) * 0.3)"
    end)
    str = str:gsub("dot%.([%w_]+)%.ticking", function(n)
        return "((State.dotRemains['"..n.."'] or 0) > 0)"
    end)
    str = str:gsub("dot%.([%w_]+)%.remains", function(n)
        return "(State.dotRemains['"..n.."'] or 0)"
    end)
    str = str:gsub("dot%.([%w_]+)%.down", function(n)
        return "((State.dotRemains['"..n.."'] or 0) <= 0)"
    end)

    -- active_dot.X
    str = str:gsub("active_dot%.([%w_]+)", function(n)
        return "(State.activeDots['"..n.."'] or 0)"
    end)

    -- cooldown.X.ready / cooldown.X.remains
    str = str:gsub("cooldown%.([%w_]+)%.ready",   function(n) return "((State.cooldowns['"..n.."'] or 0) <= 0)" end)
    str = str:gsub("cooldown%.([%w_]+)%.remains", function(n) return "(State.cooldowns['"..n.."'] or 0)" end)

    -- talent.X.enabled
    str = str:gsub("talent%.([%w_]+)%.enabled", function(n) return "(State.talents['"..n.."'] == true)" end)

    -- prev_gcd.1.X
    str = str:gsub("prev_gcd%.1%.([%w_]+)", function(n) return "(State.prevGCD=='"..n.."')" end)

    -- charges_fractional (must come before bare charges)
    str = str:gsub("charges_fractional", function()
        return "(State.charges[APL._currentAction] and State.charges[APL._currentAction].fractional or 1)"
    end)

    -- charges (bare): not preceded by '.' and not followed by letter/digit/underscore
    str = str:gsub("([^%.%a_])(charges)([^%a_%d])", function(pre, _, post)
        return pre.."(State.charges[APL._currentAction] and State.charges[APL._currentAction].current or 0)"..post
    end)
    str = str:gsub("^(charges)([^%a_%d])", function(_, post)
        return "(State.charges[APL._currentAction] and State.charges[APL._currentAction].current or 0)"..post
    end)

    -- stealthed
    str = str:gsub("stealthed%.rogue", "State.stealthed")
    str = str:gsub("stealthed%.all",   "State.stealthed")

    -- spell_targets / active_enemies
    str = str:gsub("spell_targets", "State.targets")
    str = str:gsub("active_enemies", "State.targets")

    -- target.time_to_die / time_to_die
    str = str:gsub("target%.time_to_die", "State.timeToDie")
    str = str:gsub("time_to_die",         "State.timeToDie")

    -- target.health.pct / health.pct
    str = str:gsub("target%.health%.pct", "(State.health / State.healthMax * 100)")
    str = str:gsub("health%.pct",         "(State.health / State.healthMax * 100)")

    -- energy.regen / energy.deficit / energy (order matters; guard against re-matching State.energyX)
    -- Only match when NOT preceded by '.' (avoids re-substituting already-expanded State.energyMax/etc.)
    str = str:gsub("([^%.%a_])energy%.regen",   function(pre) return pre.."State.energyRegen" end)
    str = str:gsub("^energy%.regen",            "State.energyRegen")
    str = str:gsub("([^%.%a_])energy%.deficit", function(pre) return pre.."(State.energyMax - State.energy)" end)
    str = str:gsub("^energy%.deficit",          "(State.energyMax - State.energy)")
    -- bare energy: not preceded by '.' and not followed by a letter/digit/underscore
    str = str:gsub("([^%.%a_])(energy)([^%a_%d])", function(pre, _, post) return pre.."State.energy"..post end)
    str = str:gsub("^(energy)([^%a_%d])",           function(_, post) return "State.energy"..post end)

    -- maelstrom.deficit / maelstrom (order matters)
    str = str:gsub("maelstrom%.deficit", "(State.maelstromMax - State.maelstrom)")
    -- bare maelstrom: preceded by non-word/non-dot, followed by non-word (prevents matching maelstrom_weapon)
    str = str:gsub("([^%w_%.])(maelstrom)([^%a_%d])", function(pre, _, post) return pre.."State.maelstrom"..post end)
    str = str:gsub("^(maelstrom)([^%a_%d])", function(_, post) return "State.maelstrom"..post end)

    -- combo_points.deficit / combo_points (order matters)
    str = str:gsub("combo_points%.deficit", "(State.comboPointsMax - State.comboPoints)")
    str = str:gsub("combo_points",          "State.comboPoints")

    -- gcd.remains
    str = str:gsub("gcd%.remains", "0")

    -- gcd.max -> State.gcd
    str = str:gsub("gcd%.max", "State.gcd")

    -- action.X.cast_time
    str = str:gsub("action%.([%w_]+)%.cast_time", function(n)
        local sid = "State._spellIDs['"..n.."']"
        return "(C_Spell.GetSpellInfo("..sid..") and select(4,C_Spell.GetSpellInfo("..sid..")) or 0)/1000"
    end)

    -- flame_shock_saturated variable
    str = str:gsub("variable%.flame_shock_saturated", "State.flameshockSaturated")

    -- pet.X.active -> true (treat as always active)
    str = str:gsub("pet%.[%w_]+%.active", "true")

    -- ti_chain_lightning / ti_lightning_bolt -> talent.thorims_invocation.enabled
    str = str:gsub("ti_chain_lightning", "(State.talents['thorims_invocation'] == true)")
    str = str:gsub("ti_lightning_bolt",  "(State.talents['thorims_invocation'] == true)")

    -- fight_remains -> timeToDie
    str = str:gsub("fight_remains", "State.timeToDie")

    -- variable.X -> APL._vars value
    str = str:gsub("variable%.([%w_]+)", function(n) return "(APL._vars['"..n.."'] or 0)" end)

    return str
end

-- Restricted environment for condition evaluation (avoids exposing all of _G)
local _condEnv = setmetatable({
    State = State,
    APL   = APL,
    math  = math,
    C_Spell = C_Spell,
}, { __index = function() return nil end })

-- Evaluate a set_variable entry: stores result in APL._vars[entry.variable]
function APL:EvalAction(entry)
    if not entry or entry.action ~= "set_variable" then return end
    local varName = entry.variable
    if not varName then return end
    local valStr = entry.value or entry.condition or "0"
    local luaStr = self:SimToLua(valStr)
    local fn, err = load("return (" .. luaStr .. ")", "set_variable", "t", _condEnv)
    if fn then
        local ok, result = pcall(fn)
        if ok then
            self._vars[varName] = result
        end
    end
end

-- Compile and evaluate a SimC condition string; returns bool
function APL:EvalCondition(condStr)
    local luaStr = self:SimToLua(condStr)
    local fn, err = load("return (" .. luaStr .. ")", "condition", "t", _condEnv)
    if not fn then
        -- Silently ignore parse errors (treat as false)
        return false
    end
    local ok, result = pcall(fn)
    if ok then
        return result and true or false
    end
    return false
end
