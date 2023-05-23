local myutils = require("myutils")
local const = require("analyzer.const")

---@alias Direction
---| "up"
---| "down"

local analyze = {}

---get inserters which pickup/inserter at the position
---@param di Direction scan direction
function analyze.get_inserters(pos, di, surface)
    -- move 1 or 2 tile in four directions
    local inserters = {}
    for _, aixs in ipairs({"x", "y"}) do
        for _, delta in ipairs({1, -1, 2, -2}) do
            local target_pos = {x = pos.x, y = pos.y}
            target_pos[aixs] = target_pos[aixs] + delta
            local entity = surface.find_entities_filtered({position = target_pos, type = const.INSERTER})[1]
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
function analyze.get_mining_drill(belt, surface)
    -- move 1 or 2 tile in four directions
    local pos = belt.position
    local miners = {}
    for _, aixs in ipairs({"x", "y"}) do
        for _, delta in ipairs({1, -1}) do
            local target_pos = {x = pos.x, y = pos.y}
            target_pos[aixs] = target_pos[aixs] + delta
            local entity = surface.find_entities_filtered({position = target_pos, type = const.MINING_DRILL})[1]
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
function analyze.scan_machines(start_belt, surface, di)
    local machines = {}
    local all_entities = {start_belt}
    local cur_batch = {start_belt}
    local next_batch = {}
    while #cur_batch > 0 do
        for _, cur in pairs(cur_batch) do
            if cur.type == const.ASSEMBLING_MACHINE then
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
                    if cur.type == const.TRANSPORT_BELT or cur.type == const.SPLITTER or cur.type == const.UNDERGROUND_BELT then            
                        -- connected belts
                        if cur.type == const.UNDERGROUND_BELT and cur.belt_to_ground_type == (di == "down" and "input" or "output") then
                            table.insert(neighbours, cur.neighbours)
                        else
                            myutils.table.insertAll(neighbours, cur.belt_neighbours[(di == "down" and "outputs" or "inputs")])
                        end
                        -- connected inserters
                        if cur.type == const.TRANSPORT_BELT or cur.type == const.UNDERGROUND_BELT then
                            myutils.table.insertAll(neighbours, analyze.get_inserters(cur.position, di, surface))
                        elseif cur.type == const.SPLITTER then
                            -- TODO
                        end
                        -- connected mining drill
                        if di == "up" then
                            myutils.table.insertAll(neighbours, analyze.get_mining_drill(cur, surface))
                        end
                    -- inserter
                    elseif cur.type == const.INSERTER then
                        local connect_pos
                        if di == "down" then
                            connect_pos = myutils.inserter.get_insert_position(cur.position, cur.pickup_position)
                        else
                            connect_pos = cur.pickup_position
                        end
                        -- connected belts, machines, furnance, boiler
                        local e = surface.find_entities_filtered({
                            position = connect_pos, 
                            type = {const.TRANSPORT_BELT, const.UNDERGROUND_BELT, const.SPLITTER, const.ASSEMBLING_MACHINE, const.FURNACE, const.BOILER}
                            })[1]
                        if e ~= nil then
                            table.insert(neighbours, e)
                        end
                        -- connected inserters
                        myutils.table.insertAll(neighbours, analyze.get_inserters(connect_pos, di, surface))
                    end
                end

                for _,n in pairs(neighbours) do
                    local key = myutils.get_id(n)
                    if all_entities[key] == nil then
                        all_entities[key] = n
                        table.insert(next_batch, n)
                        if myutils.table.containsValue({const.ASSEMBLING_MACHINE, const.FURNACE, const.MINING_DRILL, const.BOILER}, n.type) then
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
function analyze.compute_resources(entities, di)
    local resources = {}
    for _, e in pairs(entities) do

        local product_scale = 1
        if di == "up" and e.productivity_bonus ~= nil then
            product_scale = 1 + e.productivity_bonus
        end

        -- recipe resources
        if e.type == const.ASSEMBLING_MACHINE or e.type == const.FURNACE then
            if di == "down" and myutils.table.containsValue(const.FULL_OUTPUT_STATUS, e.status) or
                di == "up" and myutils.table.containsValue(const.NO_INPUT_STATUS, e.status) then
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

        if e.type == const.MINING_DRILL then
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
            if e.burner.currently_burning ~= nil and not myutils.table.containsValue(const.FULL_OUTPUT_STATUS, e.status) then
                local res = e.burner.currently_burning
                local energy_usage_per_sec
                if e.type == const.BOILER then
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
function analyze.match_resources(consumption, production)
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

return analyze