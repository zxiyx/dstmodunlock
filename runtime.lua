-- Adapter ordering is coordinated here; adapters own all game-mod details.
return function(ctx)
    local G = ctx.G
    ctx.common = ctx.Load("common")(ctx)
    ctx.inventory = ctx.Load("inventory")(ctx)
    ctx.Load("shield")(ctx)
    local hmr = ctx.Load("fengyun")(ctx)
    local legion = ctx.Load("lengjing")(ctx)
    local dengxian = ctx.Load("dengxian")(ctx)
    ctx.inventory.proxy_sources = {hmr.GetInventoryState}
    ctx.inventory.resolvers = {dengxian.FindInventoryDelegate}
    local adapters = {dengxian, hmr, legion}
    local sweeper = ctx.Load("sweeper")(ctx, {legion, dengxian, hmr})
    local errors = {}

    local function InstallAdapters()
        local status = {}
        for _, adapter in G.ipairs(adapters) do
            local ok, result = G.pcall(adapter.Install)
            if not ok then
                if errors[adapter] ~= result then
                    ctx.common.Log(adapter.name .. " adapter inactive: " .. G.tostring(result))
                    errors[adapter] = result
                end
            else
                errors[adapter] = nil
            end
            status[#status + 1] = adapter.name .. "=" .. G.tostring(ok and result == true)
        end
        return G.table.concat(status, "; ")
    end

    InstallAdapters()
    ctx.AddPrefabPostInit("world", function(inst)
        inst:DoTaskInTime(0, InstallAdapters)
    end)
    ctx.AddPrefabPostInit("reskin_tool", sweeper.Install)
    ctx.AddSimPostInit(function()
        local status = InstallAdapters()
        if G.TheWorld ~= nil and G.TheWorld.ismastersim then
            ctx.common.Log("Ready. mode=" .. ctx.config.selection_mode
                .. "; crafting_skins=" .. G.tostring(ctx.config.crafting_skins)
                .. "; " .. status .. "; version=" .. ctx.config.version)
        end
    end)
end
