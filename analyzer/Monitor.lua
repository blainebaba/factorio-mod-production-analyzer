local Monitor = {}
local prototype = {}

function prototype.tostring(t)
    return t
end

function Monitor.new(canvas, belt, player, surface)
    local monitor = {
        canvas = canvas,
        belt = belt,
        player = player,
        surface = surface,
        texts = {}
    }
    setmetatable(monitor, {__index = prototype, __tostring = prototype.tostring})
    return monitor
end

return Monitor