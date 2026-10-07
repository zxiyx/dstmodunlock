name = "皮肤解锁"
description = "支持清洁扫把轮换与制作栏选择。适配丰耘 1.1.2.7、棱镜 7.6.9、登仙 20.0。"
author = "鸡腿饭"
version = "1.3.0"
icon_atlas = "icon.xml"
icon = "icon.tex"
api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
client_only_mod = false
all_clients_require_mod = true
-- DST loads larger priorities first. Install after all supported mods.
priority = -10000
configuration_options = {
    {
        name = "crafting_skins",
        label = "制作栏皮肤",
        hover = "显示并允许制作丰耘、棱镜及登仙已注册的物品、装备和建筑皮肤。材料、科技和配方限制照常。",
        options = {
            { description = "开启", data = true },
            { description = "关闭（仅扫把）", data = false },
        },
        default = true,
    },
    {
        name = "selection_mode",
        label = "换肤方式",
        hover = "轮换：按目标当前皮肤选下一个。批量：新目标优先沿用本扫把上次为同类物品选的外观。",
        options = {
            { description = "逐件轮换", data = "cycle" },
            { description = "批量同款", data = "batch" },
        },
        default = "cycle",
    },
    {
        name = "announce",
        label = "显示皮肤名称",
        options = {
            { description = "关闭", data = false },
            { description = "开启", data = true },
        },
        default = false,
    },
}
