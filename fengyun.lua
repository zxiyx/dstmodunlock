-- 丰耘秘境（3609964985）适配。
return function(ctx)
    local G = ctx.G
    local adapter = { name = "HMR" }
    local HANDOFF_KEY = "\31hmr_inventory_hook\7"
    local CRAFTING_SKINS = ctx.config.crafting_skins
    local OwnershipWrapper = ctx.inventory.Wrap
    local INVENTORY_METHODS = ctx.inventory.methods

    function adapter.GetInventoryState()
        return G.rawget(G, HANDOFF_KEY)
    end

    local function GetRegistry()
        local state = adapter.GetInventoryState()
        if G.type(state) == "table" and G.type(state.hmr_is_managed_skin) == "function" then
            return state.hmr_is_managed_skin
        end
    end

    local function IsHMRItemSkin(name, is_managed)
        local prefab = G.Prefabs ~= nil and G.Prefabs[name] or nil
        return G.type(name) == "string"
            and prefab ~= nil and prefab.is_skin == true and prefab.type == "item"
            and G.type(prefab.init_fn) == "function"
            and G.type(prefab.clear_fn) == "function"
            and G.type(is_managed) == "function" and is_managed(name) == true
    end

    -- HMR routes its own skins through this table before any foreign inventory hooks.
    -- Wrap only that branch, on both client and server; no entitlement cache is written.
    local crafting_wrappers = {}
    function adapter.Install()
        if not CRAFTING_SKINS then
            return GetRegistry() ~= nil
        end
        local state = adapter.GetInventoryState()
        if G.type(state) ~= "table" or G.type(state.hmr_methods) ~= "table"
            or GetRegistry() == nil then
            return false
        end
        local function Eligible(name)
            local registry = GetRegistry()
            return registry ~= nil and IsHMRItemSkin(name, registry)
        end
        local function Wrap(method_name)
            local previous = state.hmr_methods[method_name]
            if G.type(previous) ~= "function" or previous == crafting_wrappers[method_name] then
                return
            end
            local wrapper = OwnershipWrapper(method_name, previous, Eligible)
            crafting_wrappers[method_name] = wrapper
            state.hmr_methods[method_name] = wrapper
        end
        for _, method in G.ipairs(INVENTORY_METHODS) do Wrap(method) end
        return true
    end

    function adapter.GetBase(target)
        if GetRegistry() ~= nil then return target.prefab end
    end

    function adapter.IsSkin(name)
        return IsHMRItemSkin(name, GetRegistry())
    end

    adapter.GetSkin = ctx.common.GetSkin
    adapter.Apply = ctx.common.Reskin
    return adapter
end
