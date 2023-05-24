local analyze = require("analyzer.analyze")
local myutils = require("myutils")
local const = require("analyzer.const")
local LinkedHashMap = require("common.LinkedHashMap")

local Monitor = {}
local prototype = {}
local metatable = {__index = prototype}
script.register_metatable("MonitorMeta", metatable)

-- key to stores all available monitors in global variable
local MONITOR_GLOBAL_KEY = "belt-analyzer-monitors"

local function get_container()
    if global[MONITOR_GLOBAL_KEY] == nil then
        global[MONITOR_GLOBAL_KEY] = LinkedHashMap.new()
    end
    return global[MONITOR_GLOBAL_KEY]
end

function Monitor.new(canvas, belt, player, surface)
    local monitor = {
        canvas = canvas,
        belt = belt,
        player = player,
        surface = surface,
        texts = {},
        downstream_machines = {},
        upstream_machines = {},
    }
    setmetatable(monitor, metatable)
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

---@param scan_machines boolean control whether to re-scan connected machines, when no entities are construct/removed, we can skip the scan.
function prototype:update_monitor(scan_machines)

    if scan_machines then
        self.downstream_machines = analyze.scan_machines(self.belt, self.surface, "down")
        self.upstream_machines = analyze.scan_machines(self.belt, self.surface, "up")
    end

    local consumption = analyze.compute_resources(self.downstream_machines, "down")
    local production = analyze.compute_resources(self.upstream_machines, "up")

    local matched_resources = analyze.match_resources(consumption, production)

    self:draw_monitor_canvas(matched_resources)
end

--add monitor if not exist, otherwise remove
function Monitor.add_or_remove_monitor(belt, player, surface)
    -- create or delete monitor
    local key = belt.unit_number
    local container = get_container()
    if container:get(key) ~= nil then
        container:get(key).canvas.destroy()
        container:remove(key)
    else
        local canvas = surface.create_entity({
            name = 'canvas',
            position = belt.position,
        })
        local monitor = Monitor.new(canvas, belt, player, surface)
        container:put(key, monitor)
        monitor:update_monitor(true)
    end
end

local entities_changed = true
-- set flag when entities are changed
script.on_event(const.ADD_REMOVE_EVENTS, function(_)
    entities_changed = true
end)

local monitor_iter
local MIN_UPDATE_INTERVAL_TICKS = 60
local tick_since_last_round = 0
local entities_changed_in_last_round = true
--- update monitor periodically
script.on_nth_tick(6, function(event)
    tick_since_last_round = tick_since_last_round + 6
    local a = entities_changed

    if monitor_iter == nil then
        -- only start next round after min interval
        if tick_since_last_round >= MIN_UPDATE_INTERVAL_TICKS then
            monitor_iter = get_container():iter()
            tick_since_last_round = 0
            entities_changed_in_last_round = entities_changed
            entities_changed = false
        end
    else
        -- finish this round
        if monitor_iter.has_next() then
            local monitor = monitor_iter.next()
            monitor:update_monitor(entities_changed or entities_changed_in_last_round)
        else
            monitor_iter = nil
        end
    end
end)

-- remove monitor when underlying belts are removed
script.on_event(const.REMOVE_EVENTS, function (event)
    if myutils.is_belt(event.entity) then
        local key = event.entity.unit_number
        local container = get_container()
        if container:get(key) ~= nil then
            container:get(key).canvas.destroy()
            container:remove(key)
        end
    end
end)

return Monitor