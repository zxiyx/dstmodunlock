-- All modules live beside this file; do not alter the global require path.
local G = GLOBAL
local modules = {}
local function Load(name)
    if modules[name] == nil then
        local chunk = G.kleiloadlua(MODROOT .. name .. ".lua")
        if G.type(chunk) ~= "function" then
            G.error("[皮肤解锁] Cannot load " .. name .. ": " .. G.tostring(chunk))
        end
        G.setfenv(chunk, env)
        modules[name] = chunk()
    end
    return modules[name]
end

Load("runtime")({
    G = G,
    Load = Load,
    config = {
        version = "1.3.0",
        selection_mode = GetModConfigData("selection_mode") or "cycle",
        announce = GetModConfigData("announce") == true,
        crafting_skins = GetModConfigData("crafting_skins") ~= false,
    },
    AddPrefabPostInit = AddPrefabPostInit,
    AddSimPostInit = AddSimPostInit,
    AddComponentPostInit = AddComponentPostInit,
})
