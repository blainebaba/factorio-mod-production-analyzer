local myutils = {}
myutils.inserter = {}
myutils.table = {}
myutils.math2d = require("math2d")
local inserter = myutils.inserter
local math2d = myutils.math2d

-- ------------------------------
-- general
-- ------------------------------
function myutils.is_belt(e)
    local belt_types = { 'transport-belt', 'splitter', 'underground-belt' }
    for _, belt_type in pairs(belt_types) do
        if e.type == belt_type then
            return true
        end
    end
    return false
end

function myutils.join(delimeter, ...) 
    local s = ""
    for _, v in pairs({...}) do
        s = s .. v .. delimeter
    end
    return s
end

function myutils.pos_equal(p1, p2) 
    return p1.x == p2.x and p1.y == p2.y
end

-- generate unique id for entity
function myutils.get_id(e)
    return myutils.join(",", e.position.x, e.position.y)
end

function myutils.count_by_type(t)
    local counters = {}
    for _,e in pairs(t) do
         counters[e.type] = (counters[e.type] or 0) + 1
    end
    return counters
end

---keep at most two digits of decimal
function myutils.decimal_round_up(num) 
    return math.floor(num * 100) / 100
end

function myutils.print(t)
    game.print(serpent.block(t))
end

-- ------------------------------
-- table
-- ------------------------------

function myutils.table.size(t)
    local size = 0
    for _, _ in pairs(t) do
        size = size + 1
    end
    return size
end

function myutils.table.insertAll(to, from)
    for _,v in pairs(from) do
        table.insert(to, v)
    end
end

function myutils.table.containsValue(table, value)
    for _,v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

function myutils.table.first(table)
    for k,v in pairs(table) do
        return k, v
    end
    return nil, nil
end

-- ------------------------------
-- inserter
-- ------------------------------

function myutils.inserter.get_insert_position(pos, pickup_pos)
    return math2d.position.add(pos, math2d.position.subtract(pos, pickup_pos))
end


return myutils
