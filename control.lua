local myutils = require("myutils")
local Monitor = require("analyzer.Monitor")
local const = require("analyzer.const")
local analyze = require("analyzer.analyze")

---add monitor to a belt, compute production and consumption from directly connected machines.
script.on_event('add-monitor-key', function(event)
    local player = game.players[event.player_index] -- LuaPlayer 
    local e = player.selected -- return selected entity 
    local surface = player.surface

    if not e then
        return
    end

    if not myutils.is_belt(e) then
        game.print({"pa.monitor-only-on-belt"})
        return
    end

    Monitor.add_or_remove_monitor(e, player, surface)
end)

script.on_event('instant-analyze-key', function(event)
    local player = game.players[event.player_index] -- LuaPlayer 
    local entity = player.selected -- return selected entity 
    local surface = player.surface

    if not entity then
        return
    end

    if not myutils.is_belt(entity) then
        game.print({"pa.analyze-only-on-belt"})
        return
    end

    local downstream_machines = analyze.scan_machines(entity, surface, "down")
    local upstream_machines = analyze.scan_machines(entity, surface, "up")

    local consumption = analyze.compute_resources(downstream_machines, "down")
    local production = analyze.compute_resources(upstream_machines, "up")
    local matched_resources = analyze.match_resources(consumption, production)

    local res_list_str = ""
    for res,cp in pairs(matched_resources) do
        res_list_str = res_list_str .. "[img=item." .. res .. "]" .. 
                "[color=0.5,1,0.5]" .. (cp.p and myutils.decimal_round_up(cp.p) or "-") .."[/color]" .. "→" .. 
                "[color=1,0.5,0.5]" .. (cp.c and myutils.decimal_round_up(cp.c) or "-") .. "[/color]\n"
    end
    game.print({"", {"pa.analyze-result"}, ":\n", res_list_str})
end)
