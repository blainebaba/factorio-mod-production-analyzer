
data:extend({
    {
        -- Keyboard shortcut to trace
        type = "custom-input",
        name = "add-monitor",
        key_sequence = "SHIFT + A",
        action = "lua",
        order = "b"
    },
    {
        -- Invisible entity to attach the traces to and color the map.
        type = "simple-entity",
        name = "canvas",
        picture = {filename = "__core__/graphics/empty.png", size=1},
        priority = "extra-high",
        flags = {"not-blueprintable", "not-deconstructable", "hidden", "not-flammable"},
        selectable_in_game = false,
        mined_sound = nil,
        minable = nil,
        collision_box = nil,
        selection_box = nil,
        collision_mask = {},
        render_layer = "explosion",
        vehicle_impact_sound = nil,
        tile_height = 1,
        tile_width = 1,
        friendly_map_color = {1, 1, 1}, -- white
    },
})
