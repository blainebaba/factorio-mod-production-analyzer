local analyze = require("analyzer.analyze")
local myutils = require("myutils")


local Monitor = {}
local prototype = {}

-- key to stores all available monitors in global variable
local MONITOR_GLOBAL_KEY = "belt-analyzer-monitors"
Monitor.MONITOR_GLOBAL_KEY = MONITOR_GLOBAL_KEY

local monitor_container = global[MONITOR_GLOBAL_KEY] or require("monitor_container")
global[MONITOR_GLOBAL_KEY] = monitor_container

function Monitor.new(canvas, belt, player, surface)
    local monitor = {
        canvas = canvas,
        belt = belt,
        player = player,
        surface = surface,
        texts = {}
    }
    setmetatable(monitor, {__index = prototype})
    return monitor
end

function prototype:draw_monitor_canvas(matched_resources)

    -- generate text
    local text = "[color=red]←[/color]"
    local res_count = 0
    for res, cp in pairs(matched_resources) do
        if res_count >= 2 then
            break
        end
        text = text ..  "[img=item." .. res .. "]"
        text = text .. "[color=0.5,1,0.5]" .. (cp.p and myutils.decimal_round_up(cp.p) or "-") .."[/color]"
        text = text .. ":[color=1,0.5,0.5]" .. (cp.c and myutils.decimal_round_up(cp.c) or "-") .."[/color]"
        res_count = res_count + 1
    end

    -- delete existing text
    if myutils.table.size(self.texts) > 0 then
        for _, text_id in pairs(self.texts) do
            rendering.destroy(text_id)
        end
        self.texts = {}
    end

    -- draw text
    local text_id = rendering.draw_text({text = text, surface = self.surface, target = self.canvas, color = {1,1,1,1}, 
        alignment = "left", vertical_alignment = "middle", use_rich_text = true, scale=3, scale_with_zoom = true, only_in_alt_mode = true})
    table.insert(self.texts, text_id)
end

function prototype:update_monitor()

    local downstream_machines = analyze.scan_machines(self.belt, self.surface, "down")
    local upstream_machines = analyze.scan_machines(self.belt, self.surface, "up")

    local consumption = analyze.compute_resources(downstream_machines, "down")
    local production = analyze.compute_resources(upstream_machines, "up")

    local matched_resources = analyze.match_resources(consumption, production)

    self:draw_monitor_canvas(matched_resources)
end

--add monitor if not exist, otherwise remove
function Monitor.add_or_remove_monitor(belt, player, surface)
    -- create or delete monitor
    local key = myutils.get_id(belt)
    if monitor_container.get(key) ~= nil then
        monitor_container.get(key).canvas.destroy()
        monitor_container.remove(key)
    else
        local canvas = surface.create_entity({
            name = 'canvas',
            position = belt.position,
        })
        local monitor = Monitor.new(canvas, belt, player, surface)
        monitor_container.put(key, monitor)
        monitor:update_monitor()
    end
end

local monitor_iter
local MIN_UPDATE_INTERVAL_TICKS = 60
local tick_since_last_update = 0
--- update monitor periodically
script.on_nth_tick(60, function(event)
    tick_since_last_update = tick_since_last_update + 1

    if monitor_iter == nil then
        -- only start next round after min interval
        if tick_since_last_update >= MIN_UPDATE_INTERVAL_TICKS then
            monitor_iter = monitor_container.iter()
            tick_since_last_update = 0
        end
    else
        -- finish this round
        if monitor_iter.has_next() then
            local monitor = monitor_iter.next()
        else
            monitor_iter = nil
        end
    end
end)


return Monitor