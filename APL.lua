-- RotaPop: APL.lua
-- SimC APL parser and executor.

APL = {}

APL._lists = {}  -- name -> array of action entries

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
            if entry.action == "call_action_list" and entry.list_name then
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

    -- buff.X.field
    str = str:gsub("buff%.([%w_]+)%.up",      function(n) return "(State.buffs['"..n.."'] and State.buffs['"..n.."'].up)" end)
    str = str:gsub("buff%.([%w_]+)%.down",    function(n) return "(not (State.buffs['"..n.."'] and State.buffs['"..n.."'].up))" end)
    str = str:gsub("buff%.([%w_]+)%.remains", function(n) return "(State.buffs['"..n.."'] and State.buffs['"..n.."'].remains or 0)" end)
    str = str:gsub("buff%.([%w_]+)%.stack",   function(n) return "(State.buffs['"..n.."'] and State.buffs['"..n.."'].stack or 0)" end)

    -- debuff.X.field
    str = str:gsub("debuff%.([%w_]+)%.up",      function(n) return "(State.debuffs['"..n.."'] and State.debuffs['"..n.."'].up)" end)
    str = str:gsub("debuff%.([%w_]+)%.down",    function(n) return "(not (State.debuffs['"..n.."'] and State.debuffs['"..n.."'].up))" end)
    str = str:gsub("debuff%.([%w_]+)%.remains", function(n) return "(State.debuffs['"..n.."'] and State.debuffs['"..n.."'].remains or 0)" end)

    -- cooldown.X.remains
    str = str:gsub("cooldown%.([%w_]+)%.remains", function(n) return "(State.cooldowns['"..n.."'] or 0)" end)

    -- talent.X.enabled
    str = str:gsub("talent%.([%w_]+)%.enabled", function(n) return "(State.talents['"..n.."'])" end)

    -- prev_gcd.1.X
    str = str:gsub("prev_gcd%.1%.([%w_]+)", function(n) return "(State.prevGCD=='"..n.."')" end)

    -- stealthed
    str = str:gsub("stealthed%.rogue", "State.stealthed")
    str = str:gsub("stealthed%.all",   "State.stealthed")

    -- active_enemies
    str = str:gsub("active_enemies", "State.targets")

    -- target.time_to_die
    str = str:gsub("target%.time_to_die", "999")

    -- energy.deficit
    str = str:gsub("energy%.deficit", "(State.energyMax - State.energy)")

    -- combo_points
    str = str:gsub("combo_points", "State.comboPoints")

    -- energy (bare, after deficit handled)
    str = str:gsub("energy", "State.energy")

    -- gcd.remains
    str = str:gsub("gcd%.remains", "0")

    -- dot.X.remains  -> State.dotRemains['X'] or 0
    str = str:gsub("dot%.([%w_]+)%.remains", function(n)
        return "(State.dotRemains['"..n.."'] or 0)"
    end)

    -- active_dot.X  -> State.activeDots['X'] or 0
    str = str:gsub("active_dot%.([%w_]+)", function(n)
        return "(State.activeDots['"..n.."'] or 0)"
    end)

    -- charges_fractional -> State.charges[APL._currentAction].fractional
    str = str:gsub("charges_fractional", function()
        return "(State.charges[APL._currentAction] and State.charges[APL._currentAction].fractional or 1)"
    end)

    -- maelstrom (bare resource)
    str = str:gsub("maelstrom", "State.maelstrom")

    -- flame_shock_saturated variable
    str = str:gsub("variable%.flame_shock_saturated", "State.flameshockSaturated")

    -- pet.X.active -> true (treat as always active)
    str = str:gsub("pet%.[%w_]+%.active", "true")

    -- ti_chain_lightning / ti_lightning_bolt -> talent.thorims_invocation.enabled
    str = str:gsub("ti_chain_lightning", "(State.talents['thorims_invocation'])")
    str = str:gsub("ti_lightning_bolt",  "(State.talents['thorims_invocation'])")

    -- fight_remains -> 999 (unknown, treat as long fight)
    str = str:gsub("fight_remains", "999")

    -- variable.X -> 1 (simplify)
    str = str:gsub("variable%.[%w_]+", "1")

    -- gcd.max -> State.gcd
    str = str:gsub("gcd%.max", "State.gcd")

    return str
end

-- Restricted environment for condition evaluation (avoids exposing all of _G)
local _condEnv = setmetatable({
    State = State,
    APL   = APL,
    math  = math,
}, { __index = function() return nil end })

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
