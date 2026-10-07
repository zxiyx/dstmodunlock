-- 1.3.7: character-skin downgrade shield.
-- Dengxian's VM force-writes '<prefab>_none' onto managed character skins every
-- ~12-15 seconds, bypassing every ownership check. Every skin change must pass
-- through Skinner:SetSkinName, so the shield sits on that funnel: when a
-- non-user source tries to downgrade a managed skin, re-apply the managed skin
-- instead. User paths (lobby spawn, wardrobe) and saved-skin restores are
-- allowed through; the OnLoad path additionally restores a saved managed skin
-- that the vanilla resume check would have dropped.
return function(ctx)
    local G = ctx.G
    local Log = ctx.common.Log
    local dbg = G.rawget(G, "debug")
    local add_component_post_init = ctx.AddComponentPostInit
    if G.type(add_component_post_init) ~= "function" then return end

    local function ManagedCharSkin(name)
        if G.type(name) ~= "string" or name == "" then return nil end
        if G.string.sub(name, -5) == "_none" then return nil end
        local skins = G.rawget(G, "XD_ITEMSKINS")
        local data = skins ~= nil and G.rawget(skins, name) or nil
        if G.type(data) == "table" and data.ischaracterskins == true then
            return data
        end
        return nil
    end

    local function IsUserPath(source)
        if G.string.find(source, "mods/unlock/", 1, true) ~= nil then return true end
        if G.string.find(source, "scripts/networking.lua", 1, true) ~= nil then return true end
        if G.string.find(source, "components/wardrobe.lua", 1, true) ~= nil then return true end
        return false
    end

    local blocked_count = 0
    local ok, err = G.pcall(add_component_post_init, "skinner", function(self)
        if self._selfuse_shield then return end

        local old = self.SetSkinName
        if G.type(old) == "function" then
            self._selfuse_shield = true
            function self.SetSkinName(s, skinname, ...)
                local inst = s.inst
                if inst ~= nil and G.type(inst.userid) == "string" and inst.userid ~= "" then
                    local current = s.skin_name
                    if ManagedCharSkin(current) ~= nil and G.type(skinname) == "string"
                        and skinname ~= current and ManagedCharSkin(skinname) == nil then
                        local source = "?"
                        if dbg ~= nil and G.type(dbg.getinfo) == "function" then
                            local info = dbg.getinfo(2, "S")
                            source = info ~= nil and G.tostring(info.source) or "?"
                        end
                        if not IsUserPath(source) then
                            blocked_count = blocked_count + 1
                            if blocked_count <= 8 then
                                Log("blocked skin reset from (" .. source .. "); reapplying '"
                                    .. G.tostring(current) .. "'")
                            end
                            return old(s, current, ...)
                        end
                    end
                end
                return old(s, skinname, ...)
            end
        end

        -- Resume: the vanilla OnLoad drops a saved skin whose client check
        -- fails; restore it afterwards when it is a managed character skin.
        local old_onload = self.OnLoad
        if G.type(old_onload) == "function" and not self._selfuse_shield_onload then
            self._selfuse_shield_onload = true
            function self.OnLoad(s, data)
                local r = old_onload(s, data)
                if G.type(data) == "table" then
                    local saved = data.skin_name
                    local entry = ManagedCharSkin(saved)
                    local inst = s.inst
                    if entry ~= nil and inst ~= nil and inst.prefab ~= nil
                        and entry.base_prefab == inst.prefab and s.skin_name ~= saved then
                        local old_set = s.SetSkinName
                        if G.type(old_set) == "function" then
                            old_set(s, saved, true)
                            Log("restored saved character skin on load: " .. G.tostring(saved))
                        end
                    end
                end
                return r
            end
        end
    end)
    if ok then
        Log("skin reset shield ready")
    else
        Log("skin reset shield skipped: " .. G.tostring(err))
    end
end
