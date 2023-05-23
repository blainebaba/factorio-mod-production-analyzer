local analyze = require("analyzer.analyze")
local myutils = require("myutils")

local Monitor = {}
local prototype = {}

-- key to stores all available monitors in global variable
local MONITOR_GLOBAL_KEY = "belt-analyzer-monitors"
Monitor.MONITOR_GLOBAL_KEY = MONITOR_GLOBAL_KEY

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
    if global[MONITOR_GLOBAL_KEY] == nil then
        global[MONITOR_GLOBAL_KEY] = {}
    end
    local key = myutils.get_id(belt)
    if global[MONITOR_GLOBAL_KEY][key] ~= nil then
        global[MONITOR_GLOBAL_KEY][key].canvas.destroy()
        global[MONITOR_GLOBAL_KEY][key] = nil
    else
        local canvas = surface.create_entity({
            name = 'canvas',
            position = belt.position,
        })
        local monitor = Monitor.new(canvas, belt, player, surface)
        global[MONITOR_GLOBAL_KEY][key] = monitor
        monitor:update_monitor()
    end
end

--- update monitor periodically
script.on_nth_tick(60, function(event)
    if global[MONITOR_GLOBAL_KEY] == nil then
        global[MONITOR_GLOBAL_KEY] = {}
    end
    for _, monitor in pairs(global[MONITOR_GLOBAL_KEY]) do
        monitor:update_monitor()
    end
end)


return Monitor