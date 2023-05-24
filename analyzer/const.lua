local myutils = require("myutils")

-- defines constants
local const = {
    TRANSPORT_BELT = "transport-belt",
    UNDERGROUND_BELT = "underground-belt",
    SPLITTER = "splitter",
    INSERTER = "inserter",
    ASSEMBLING_MACHINE = "assembling-machine",
    FURNACE = "furnace",
    MINING_DRILL = "mining-drill",
    BOILER = "boiler",
}

do
    local s = defines.entity_status
    const.NO_INPUT_STATUS = {s.fluid_ingredient_shortage, s.item_ingredient_shortage, s.no_ingredients}
    const.FULL_OUTPUT_STATUS = {s.full_output}
end

do
    local e=defines.events
    const.REMOVE_EVENTS = {e.on_player_mined_entity, e.on_robot_pre_mined, e.on_entity_died, e.script_raised_destroy}
    const.ADD_EVENTS = {e.on_built_entity, e.on_robot_built_entity, e.script_raised_revive, e.script_raised_built}

    const.ADD_REMOVE_EVENTS = {}
    myutils.table.insertAll(const.ADD_REMOVE_EVENTS, const.ADD_EVENTS)
    myutils.table.insertAll(const.ADD_REMOVE_EVENTS, const.REMOVE_EVENTS)
end

return const