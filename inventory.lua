return function(ctx)
    local G = ctx.G
    local Upvalue = ctx.common.Upvalue
    local inventory = { resolvers = {}, proxy_sources = {} }

    local INVENTORY_METHODS = {"CheckOwnership", "CheckOwnershipGetLatest", "CheckClientOwnership"}
    local function OwnershipWrapper(method, previous, eligible)
        if method == "CheckClientOwnership" then
            return function(inv, userid, name, ...)
                if eligible(name) then return true end
                return previous(inv, userid, name, ...)
            end
        elseif method == "CheckOwnershipGetLatest" then
            return function(inv, name, ...)
                if eligible(name) then return true, 0 end
                return previous(inv, name, ...)
            end
        end
        return function(inv, name, ...)
            if eligible(name) then return true end
            return previous(inv, name, ...)
        end
    end

    function inventory.FindDelegate(root, method, upvalue_name)
        local queue, seen = {root}, {[root] = true}
        local function Add(value)
            if G.type(value) == "function" and not seen[value] and #queue < 64 then
                seen[value] = true
                queue[#queue + 1] = value
            end
        end
        local cursor = 1
        while cursor <= #queue do
            local fn = queue[cursor]
            local previous, slot = Upvalue(fn, upvalue_name)
            if G.type(previous) == "function" then return fn, slot, previous end
            for n = 1, 100 do
                local name, value = G.debug.getupvalue(fn, n)
                if name == nil then break end
                Add(value)
                if G.type(value) == "table" and value ~= G then
                    Add(G.rawget(value, method))
                    -- Inventory proxies can retain their foreign methods in a
                    -- nested table. Do not traverse arbitrary registry contents.
                    for _, source in G.ipairs(inventory.proxy_sources) do
                        if value == source() then
                            for _, nested in G.pairs(value) do
                                if G.type(nested) == "table" then Add(G.rawget(nested, method)) end
                            end
                        end
                    end
                end
            end
            cursor = cursor + 1
        end
    end

    function inventory.NewInstaller(eligible)
        local inventory_indices = {}
        return function()
            if not ctx.config.crafting_skins or G.TheInventory == nil then return end
            local meta = G.getmetatable(G.TheInventory)
            local index = G.type(meta) == "table" and meta.__index or nil
            if G.type(index) ~= "table" then return end
            local installed = inventory_indices[index] or {}
            for _, method in G.ipairs(INVENTORY_METHODS) do
                local previous = index[method]
                if G.type(previous) == "function" and previous ~= installed[method] then
                    -- Adapters may preserve a guarded public method by supplying
                    -- a private delegation point for other mods' ownership checks.
                    local owner, slot, delegate
                    for _, resolve in G.ipairs(inventory.resolvers) do
                        owner, slot, delegate = resolve(previous, method)
                        if owner ~= nil then break end
                    end
                    if owner ~= nil and G.debug.setupvalue ~= nil then
                        G.debug.setupvalue(owner, slot, OwnershipWrapper(method, delegate, eligible))
                        installed[method] = previous
                    else
                        local wrapper = OwnershipWrapper(method, previous, eligible)
                        index[method] = wrapper
                        installed[method] = wrapper
                    end
                end
            end
            inventory_indices[index] = installed
        end

    end

    inventory.methods = INVENTORY_METHODS
    inventory.Wrap = OwnershipWrapper
    return inventory
end
