local myutils = require("myutils")

local TRANSPORT_BELT = "transport-belt"
local UNDERGROUND_BELT = "underground-belt"
local SPLITTER = "splitter"
local INSERTER = "inserter"
local ASSEMBLING_MACHINE = "assembling-machine"
local FURNACE = "furnace"
local MINING_DRILL = "mining-drill"
local BOILER = "boiler"

local NO_INPUT_STATUS
local FULL_OUTPUT_STATUS
do
    local s = defines.entity_status
    NO_INPUT_STATUS = {s.fluid_ingredient_shortage, s.item_ingredient_shortage, s.no_ingredients}
    FULL_OUTPUT_STATUS = {s.full_output}
end

---@alias Direction
---| "up"
---| "down"

---get inserters which pickup/inserter at the position
---@param di Direction scan direction
local function get_inserters(pos, di, surface)
    -- move 1 or 2 tile in four directions
    local inserters = {}
    for _, aixs in ipairs({"x", "y"}) do
        for _, delta in ipairs({1, -1, 2, -2}) do
            local target_pos = {x = pos.x, y = pos.y}
            target_pos[aixs] = target_pos[aixs] + delta
            local entity = surface.find_entities_filtered({position = target_pos, type = "inserter"})[1]
            if entity ~= nil then
                local attach_position
                if di == "down" then
                    attach_position = entity.pickup_position
                else
                    attach_position = myutils.inserter.get_insert_position(entity.position, entity.pickup_position)
                end
                -- make sure this inserter is picking up / inserting to this belt.
                if myutils.pos_equal(attach_position, pos) then
                    local key = myutils.get_id(entity)
                    inserters[key] = entity
                end
            end
        end
    end
    return inserters
end

---get mining drill which drops resources to the belt
local function get_mining_drill(belt, surface)
    -- move 1 or 2 tile in four directions
    local pos = belt.position
    local miners = {}
    for _, aixs in ipairs({"x", "y"}) do
        for _, delta in ipairs({1, -1}) do
            local target_pos = {x = pos.x, y = pos.y}
            target_pos[aixs] = target_pos[aixs] + delta
            local entity = surface.find_entities_filtered({position = target_pos, type = "mining-drill"})[1]
            if entity ~= nil then
                -- make sure resources is dropped at the position
                if entity.drop_target == belt then
                    local key = myutils.get_id(entity)
                    miners[key] = entity
                end
            end
        end
    end
    return miners
end

---Detect connected machines from a belt downstream/upstream.
---This method will scan through the connected belts and inserters.
---Can detects assembling machine, furnace and miner
---@return table machines array
local function scan_machines(start_belt, surface, di)
    local machines = {}
    local all_entities = {start_belt}
    local cur_batch = {start_belt}
    local next_batch = {}
    while #cur_batch > 0 do
        for _, cur in pairs(cur_batch) do
            if cur.type == ASSEMBLING_MACHINE then
                local key = myutils.get_id(cur)
                if all_entities[key] == nil then
                    all_entities[key] = cur
                    machines[key] = cur
                end
            else
                -- not machine, continue to get neighbours
                local neighbours = {}
                do
                    -- belts
                    if cur.type == TRANSPORT_BELT or cur.type == SPLITTER or cur.type == UNDERGROUND_BELT then            
                        -- connected belts
                        if cur.type == UNDERGROUND_BELT and cur.belt_to_ground_type == (di == "down" and "input" or "output") then
                            table.insert(neighbours, cur.neighbours)
                        else
                            myutils.table.insertAll(neighbours, cur.belt_neighbours[(di == "down" and "outputs" or "inputs")])
                        end
                        -- connected inserters
                        if cur.type == TRANSPORT_BELT or cur.type == UNDERGROUND_BELT then
                            myutils.table.insertAll(neighbours, get_inserters(cur.position, di, surface))
                        elseif cur.type == SPLITTER then
                            -- TODO
                        end
                        -- connected mining drill
                        if di == "up" then
                            myutils.table.insertAll(neighbours, get_mining_drill(cur, surface))
                        end
                    -- inserter
                    elseif cur.type == INSERTER then
                        local connect_pos
                        if di == "down" then
                            connect_pos = myutils.inserter.get_insert_position(cur.position, cur.pickup_position)
                        else
                            connect_pos = cur.pickup_position
                        end
                        -- connected belts, machines, furnance, boiler
                        local e = surface.find_entities_filtered({
                            position = connect_pos, 
                            type = {TRANSPORT_BELT, UNDERGROUND_BELT, SPLITTER, ASSEMBLING_MACHINE, FURNACE, BOILER}
                            })[1]
                        if e ~= nil then
                            table.insert(neighbours, e)
                        end
                        -- connected inserters
                        myutils.table.insertAll(neighbours, get_inserters(connect_pos, di, surface))
                    end
                end

                for _,n in pairs(neighbours) do
                    local key = myutils.get_id(n)
                    if all_entities[key] == nil then
                        all_entities[key] = n
                        table.insert(next_batch, n)
                        if myutils.table.containsValue({ASSEMBLING_MACHINE, FURNACE, MINING_DRILL, BOILER}, n.type) then
                            table.insert(machines, n)
                        end
                    end
                end
            end
        end
        cur_batch = next_batch
        next_batch = {}
    end
    return machines
end

---Compute consumptions/productions of assembling machines, mining drills and furnaces
---For upstream, compute product. For downstream, compute ingredients.
local function compute_resources(entities, di)
    local resources = {}
    for _, e in pairs(entities) do

        local product_scale = 1
        if di == "up" and e.productivity_bonus ~= nil then
            product_scale = 1 + e.productivity_bonus
        end

        -- recipe resources
        if e.type == ASSEMBLING_MACHINE or e.type == FURNACE then
            if di == "down" and myutils.table.containsValue(FULL_OUTPUT_STATUS, e.status) or
                di == "up" and myutils.table.containsValue(NO_INPUT_STATUS, e.status) then
                -- Ignore full output downstream machines and missing input upstream machines.
            else
                if e.get_recipe() ~= nil then
                    local time = e.get_recipe().energy / e.crafting_speed
                    local recipe_res = (di == "down" and e.get_recipe().ingredients or e.get_recipe().products)
                    for _,res in pairs(recipe_res) do
                        -- only consider items, exclude fluids.
                        if game.item_prototypes[res.name] ~= nil then
                            resources[res.name] = (resources[res.name] or 0) + (res.amount * (1 / time) * product_scale)
                        end
                    end
                end
            end
        end

        if e.type == MINING_DRILL then
            if di == "up" then
                if e.mining_target ~= nil then
                    local mining_time = e.mining_target.prototype.mineable_properties.mining_time
                    local mining_speed = e.prototype.mining_speed
                    resources[e.mining_target.name] = (resources[e.mining_target.name] or 0) + (mining_speed / mining_time * product_scale)
                end
            end
        end

        -- furnace/boiler coal consumption
        if e.burner ~= nil and di == "down" then
            if e.burner.currently_burning ~= nil and not myutils.table.containsValue(FULL_OUTPUT_STATUS, e.status) then
                local res = e.burner.currently_burning
                local energy_usage_per_sec
                if e.type == BOILER then
                    local flow_speed = e.fluidbox.get_flow(2) * 60
                    -- energy consumption perportion to flow speed, max flow speed 60/s 
                    energy_usage_per_sec = (e.prototype.max_energy_usage * 60) * (flow_speed / 60);
                else
                    energy_usage_per_sec = e.prototype.max_energy_usage * 60
                end
                local total_enerygy = res.fuel_value
                resources[res.name] = (resources[res.name] or 0) + (energy_usage_per_sec / total_enerygy * product_scale)
            end
        end
    end
    return resources
end

---keep resources that exists on both ends. Keep all when nothing is matched.
local function match_resources(consumption, production)
    local matched_resources = {}
    if myutils.table.size(production) == 0 then
        -- no production, keep all consumptions
        for res,count in pairs(consumption) do
            matched_resources[res] = {}
            matched_resources[res].c = count
        end
    else
        -- has production, keep productions and its matching consumptions
        for res,_ in pairs(production) do
            matched_resources[res] = {}
            matched_resources[res].p = production[res]
            matched_resources[res].c = consumption[res]
        end
    end
    return matched_resources
end

local MONITOR_KEY = "belt-analyzer-monitors"

local function draw_monitor_canvas(monitor, text)
    local text_id = rendering.draw_text({text = text, surface = monitor.surface, target = monitor.canvas, color = {1,1,1,1}, 
        alignment = "left", vertical_alignment = "middle", use_rich_text = true, scale=3, scale_with_zoom = true, only_in_alt_mode = true})
    table.insert(monitor.texts, text_id)
end

---analyze and update monitor output
local function update_monitor(monitor)
    local canvas = monitor.canvas
    local belt = monitor.belt
    local surface = monitor.surface

    local downstream_machines = scan_machines(belt, surface, "down")
    local upstream_machines = scan_machines(belt, surface, "up")

    local consumption = compute_resources(downstream_machines, "down")
    local production = compute_resources(upstream_machines, "up")

    local matched_resources = match_resources(consumption, production)

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
    if myutils.table.size(monitor.texts) > 0 then
        for _, text_id in pairs(monitor.texts) do
            rendering.destroy(text_id)
        end
        monitor.texts = {}
    end
    draw_monitor_canvas(monitor, text)
end

---update canvas periodically
script.on_nth_tick(60, function(event)
    if global[MONITOR_KEY] == nil then
        global[MONITOR_KEY] = {}
    end
    for _, ui in pairs(global[MONITOR_KEY]) do
        update_monitor(ui)
    end
end)


---add monitor to a belt, compute production and consumption from directly connected machines.
script.on_event('add-monitor-key', function(event)
    local player = game.players[event.player_index] -- LuaPlayer 
    local e = player.selected -- return selected entity 
    local surface = player.surface

    if not e then
        return
    end

    if not myutils.is_belt(e) then
        game.print("can only attach analyzer to transport belt")
        return
    end

    -- create or delete display canvas
    if global[MONITOR_KEY] == nil then
        global[MONITOR_KEY] = {}
    end
    local key = myutils.get_id(e)
    if global[MONITOR_KEY][key] ~= nil then
        global[MONITOR_KEY][key].canvas.destroy()
        global[MONITOR_KEY][key] = nil
    else
        local canvas = surface.create_entity({
            name = 'canvas',
            position = e.position,
        })
        global[MONITOR_KEY][key] = {canvas = canvas, belt = e, player = player, surface = surface, texts = {}}
        update_monitor(global[MONITOR_KEY][key])
    end
end)

script.on_event('instant-analyze-key', function(event)
    local player = game.players[event.player_index] -- LuaPlayer 
    local entity = player.selected -- return selected entity 
    local surface = player.surface

    if not entity then
        return
    end

    if not myutils.is_belt(entity) then
        game.print("Can only analyze on belt.")
        return
    end

    local downstream_machines = scan_machines(entity, surface, "down")
    local upstream_machines = scan_machines(entity, surface, "up")

    local consumption = compute_resources(downstream_machines, "down")
    local production = compute_resources(upstream_machines, "up")
    local matched_resources = match_resources(consumption, production)

    local output = "Analyze result:\n"
    for res,cp in pairs(matched_resources) do
        output = output .. "[img=item." .. res .. "]" .. 
                "[color=0.5,1,0.5]" .. (cp.p and myutils.decimal_round_up(cp.p) or "-") .."[/color]" .. "→" .. 
                "[color=1,0.5,0.5]" .. (cp.c and myutils.decimal_round_up(cp.c) or "-") .. "[/color]\n"
    end
    game.print(output)
end)
