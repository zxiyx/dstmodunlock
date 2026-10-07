-- 棱镜（1392778117）适配。
return function(ctx)
    local G = ctx.G
    local Upvalue, Log = ctx.common.Upvalue, ctx.common.Log
    local CRAFTING_SKINS = ctx.config.crafting_skins
    local legion = { name = "Legion" }

    local function IsLegionItemSkin(name, base)
        local data = legion.skins and legion.skins[name]
        if G.type(data) ~= "table" or data.skin_idx == nil
            or G.type(data.base_prefab) ~= "string"
            or (data.type ~= nil and data.type ~= "item")
            or (base ~= nil and base ~= data.base_prefab) then
            return false
        end
        local public = G.rawget(G, "ls_skineddata")
        if public == nil or public[name] == nil then return false end
        for _, item in G.ipairs((G.PREFAB_SKINS or {})[data.base_prefab] or {}) do
            if item == name then return true end
        end
        return false
    end

    local InstallLegionInventory = ctx.inventory.NewInstaller(IsLegionItemSkin)

    function legion.Install()
        local init = G.rawget(G, "LS_C_Init")
        if init == nil then return false end
        if G.debug == nil or G.type(G.debug.setupvalue) ~= "function" then return false end
        if legion.init ~= init then
            legion.ready = false
            legion.skins = nil
            local setskin = Upvalue(init, "EE")
            local lookup = Upvalue(setskin, "nE")
            local skins = Upvalue(lookup, "f")
            local owned, owned_index = Upvalue(setskin, "LE")
            local protect = Upvalue(init, "TE")
            local gate, gate_index = Upvalue(protect, "j")
            local builds = Upvalue(gate, "l")
            -- Fail closed if an update changes either half of this interface.
            if G.type(setskin) ~= "function" or G.type(skins) ~= "table"
                or G.type(owned) ~= "function"
                or (protect ~= nil and (G.type(gate) ~= "function" or G.type(builds) ~= "table")) then
                if legion.failed_init ~= init then
                    Log("Legion interface changed; adapter inactive. Please update this patch.")
                    legion.failed_init = init
                end
                return false
            end
            legion.skins = skins
            legion.original_owned = owned
            G.debug.setupvalue(setskin, owned_index, function(name, userid)
                if IsLegionItemSkin(name) then return true end
                return owned(name, userid)
            end)
            if protect ~= nil then
                G.debug.setupvalue(protect, gate_index, function(base, build)
                    if builds[base] ~= nil and builds[base][build] ~= nil then return false end
                    return gate(base, build)
                end)
            end
            legion.init = init
            legion.ready = true
            -- The native Legion selector shares LE. Restore its original filtering
            -- when the user explicitly disables crafting skins in this patch.
            if not CRAFTING_SKINS and G.TheNet ~= nil and not G.TheNet:IsDedicated() then
                local selector = G.require("widgets/redux/craftingmenu_skinselector")
                local previous = selector.GetSkinsList
                selector.GetSkinsList = function(self, ...)
                    local list = previous(self, ...)
                    local result = {}
                    for _, entry in G.ipairs(list or {}) do
                        if not IsLegionItemSkin(entry.item)
                            or legion.original_owned(entry.item, self.owner.userid) then
                            result[#result + 1] = entry
                        end
                    end
                    return result
                end
            end
        end
        InstallLegionInventory()
        return true
    end

    function legion.GetBase(target)
        local component = target.components and target.components.skinedlegion
        if legion.ready and component ~= nil then return component.prefab or target.prefab end
    end

    function legion.IsSkin(name, base, target)
        if not IsLegionItemSkin(name, base) then return false end
        local component = target.components.skinedlegion
        return component.overkey == nil or legion.skins[name][component.overkey] ~= nil
    end

    function legion.GetSkin(target)
        return target.components.skinedlegion:GetSkin() or target.skinname
    end

    function legion.Apply(target, skin, userid)
        target.components.skinedlegion:SetSkin(skin, userid)
    end

    return legion
end
