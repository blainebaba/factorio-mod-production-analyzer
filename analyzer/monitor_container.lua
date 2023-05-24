-- uses as singleton class
-- this is a LinkedHashMap

local container = {}

-- each entry has three values: next, value and last
local monitors = {}
-- dummy head node for linked list
local head = {}
-- dummy tail node for linked list
local tail = {}
head.next = tail
tail.last = head

function container.get(key) 
    if monitors[key] ~= nil then
        return monitors[key].value
    end
end

function container.put(key, container)
    local entry = {value = container}
    monitors[key] = entry

    entry.last = tail.last
    entry.next = tail
    entry.last.next = entry
    entry.next.last = entry
end

function container.remove(key)
    local entry = monitors[key]
    if entry == nil then
        return
    end

    entry.last.next = entry.next
    entry.next.last = entry.last
    monitors[key] = nil
end

-- return iterator
function container.iter()
    local iter = {}
    local cur = head.next

    iter.next = function ()
        if cur ~= tail then
            cur = cur.next
            return cur.last.value
        end
    end

    iter.has_next = function ()
        return cur ~= tail
    end

    return iter
end

return container