-- 原版客户端会把 Spell.dbc 中带 SPELL_ATTR_HIDDEN_CLIENTSIDE (0x80) 的法术
-- 排除在技能书之外。Wowee 未做此过滤，导致 Attacking / Closing / Detect /
-- Defensive State (DND) 等内部法术出现在技能书里（它们的图标本就是占位图
-- Interface\Icons\Temp，看起来像"图标缺失"）。
--
-- 本 addon 在 Lua 层重建一套"可见索引 -> 原始索引"的映射，并把所有按索引
-- 取值的技能书 API 一并重定向，保证名称、图标、冷却、施法都对得上。

local DATA = WoweeSpellbookFilterData
if not DATA then return end

local BOOK = "spell"          -- 只过滤玩家技能书，宠物技能书原样放行

-- 保存原始实现
local o_GetNumSpellTabs   = GetNumSpellTabs
local o_GetSpellTabInfo   = GetSpellTabInfo
local o_GetSpellName      = GetSpellName
local o_GetSpellTexture   = GetSpellTexture
local o_GetSpellCooldown  = GetSpellCooldown
local o_IsSpellPassive    = IsSpellPassive
local o_CastSpell         = CastSpell
local o_PickupSpell       = PickupSpell
local o_GetSpellLink      = GetSpellLink
local o_GetSpellDescription = GetSpellDescription
local o_GetSpellAutocast  = GetSpellAutocast

local map  = {}      -- map[可见索引] = 原始索引
local tabs = {}      -- tabs[i] = {name, texture, 新offset, 新numSpells}
local nTabs = 0
local ready = false

local function rawIndex(i, bookType)
    if bookType ~= BOOK or not ready then return i end
    return map[i] or i
end

local function spellIdOf(raw)
    if not o_GetSpellLink then return nil end
    local link = o_GetSpellLink(raw, BOOK)
    if type(link) ~= "string" then return nil end
    local _, _, id = string.find(link, "spell:(%d+)")
    if id then return tonumber(id) end
    return nil
end

local function isHidden(raw)
    local id = spellIdOf(raw)
    if id then
        -- 拿到了确切 ID，以 ID 为准，不再做名字判断（避免同名误伤）
        if DATA.byId[id] then return true end
        return false
    end
    local name = o_GetSpellName(raw, BOOK)
    if name and DATA.byName[name] then return true end
    return false
end

local function rebuild()
    ready = false
    map, tabs = {}, {}
    nTabs = o_GetNumSpellTabs and o_GetNumSpellTabs() or 0
    local vis = 0
    local t = 1
    while t <= nTabs do
        local name, tex, offset, num = o_GetSpellTabInfo(t)
        offset = offset or 0
        num = num or 0
        local newOffset, kept = vis, 0
        local i = offset + 1
        while i <= offset + num do
            if not isHidden(i) then
                vis = vis + 1
                map[vis] = i
                kept = kept + 1
            end
            i = i + 1
        end
        tabs[t] = { name, tex, newOffset, kept }
        t = t + 1
    end
    ready = true
end

-- ---- API 重定向 ----
function GetSpellTabInfo(t)
    if ready and tabs[t] then
        local v = tabs[t]
        return v[1], v[2], v[3], v[4]
    end
    return o_GetSpellTabInfo(t)
end

function GetSpellName(i, bookType)      return o_GetSpellName(rawIndex(i, bookType), bookType) end
function GetSpellTexture(i, bookType)   return o_GetSpellTexture(rawIndex(i, bookType), bookType) end
function GetSpellCooldown(i, bookType)  return o_GetSpellCooldown(rawIndex(i, bookType), bookType) end
function IsSpellPassive(i, bookType)    return o_IsSpellPassive(rawIndex(i, bookType), bookType) end
function CastSpell(i, bookType)         return o_CastSpell(rawIndex(i, bookType), bookType) end
function PickupSpell(i, bookType)       return o_PickupSpell(rawIndex(i, bookType), bookType) end

if o_GetSpellLink then
    function GetSpellLink(i, bookType)  return o_GetSpellLink(rawIndex(i, bookType), bookType) end
end
if o_GetSpellDescription then
    function GetSpellDescription(i, bookType) return o_GetSpellDescription(rawIndex(i, bookType), bookType) end
end
if o_GetSpellAutocast then
    function GetSpellAutocast(i, bookType) return o_GetSpellAutocast(rawIndex(i, bookType), bookType) end
end

-- ---- 触发重建 ----
local f = CreateFrame("Frame", "WoweeSpellbookFilterFrame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("LEARNED_SPELL_IN_TAB")
f:SetScript("OnEvent", function()
    rebuild()
    if SpellBookFrame and SpellBookFrame:IsVisible() and SpellBookFrame_Update then
        SpellBookFrame_Update()
    end
end)
