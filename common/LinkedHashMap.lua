local myutils = require("myutils")

local LinkedHashMap = {}
local prototype = {}
local metatable = {__index = prototype}
script.register_metatable("LinkedHashMapMeta", metatable)

function LinkedHashMap.new() 
    local instance = {
        map = {},
        -- dummy head node for linked list
        head = {is_active = true},
        -- dummy tail node for linked list
        tail = {is_active = true},
    }
    instance.head.next = instance.tail
    instance.tail.last = instance.head

    setmetatable(instance, metatable)
    return instance
end

function prototype:get(key) 
    if self.map[key] ~= nil then
        return self.map[key].value
    end
end

function prototype:put(key, value)
    local entry = {value = value, is_active = true}
    self.map[key] = entry

    entry.last = self.tail.last
    entry.next = self.tail
    entry.last.next = entry
    entry.next.last = entry
end

function prototype:remove(key)
    local entry = self.map[key]
    if entry == nil then
        return
    end

    entry.last.next = entry.next
    entry.next.last = entry.last
    -- handle cases that cur node is removed in iter
    entry.is_active = false
    self.map[key] = nil
end

-- return iterator
function prototype:iter()
    local iter = {}
    local cur = self.head.next

    iter.next = function ()
        while not cur.is_active do
            cur = cur.next
        end

        if cur ~= self.tail then
            cur = cur.next
            return cur.last.value 
        end
    end

    iter.has_next = function ()
        while not cur.is_active do
            cur = cur.next
        end

        return cur ~= self.tail
    end

    return iter
end

function prototype:size()
    return myutils.table.size(self.map)
end

return LinkedHashMap