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

local s = defines.entity_status
const.NO_INPUT_STATUS = {s.fluid_ingredient_shortage, s.item_ingredient_shortage, s.no_ingredients}
const.FULL_OUTPUT_STATUS = {s.full_output}

return const