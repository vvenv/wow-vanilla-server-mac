-- Wowee 的 classic profile 里若干训练师 API 会返回 nil，
-- 而暴雪原版 Blizzard_TrainerUI.lua 直接把返回值喂给 format()，
-- 触发 "bad argument #2 to 'rawformat' (string expected, got nil)"，
-- 结果整个技能详情（含名称）渲染中断。
-- 这里把可能为 nil 的返回值统一兜成字符串。

local FALLBACK = "?"

-- Wowee 未实现该函数；原版 TrainerUI 会调用它
if type(IsTrainerServiceLearnSpell) ~= "function" then
    function IsTrainerServiceLearnSpell(id)
        return 1, nil
    end
end

local _info = GetTrainerServiceInfo
if type(_info) == "function" then
    function GetTrainerServiceInfo(id)
        local name, sub, stype, expanded = _info(id)
        if type(name) ~= "string" then name = FALLBACK end
        if type(sub)  ~= "string" then sub  = "" end
        return name, sub, stype, expanded
    end
end

local _abilityReq = GetTrainerServiceAbilityReq
if type(_abilityReq) == "function" then
    function GetTrainerServiceAbilityReq(id, i)
        local name, hasReq = _abilityReq(id, i)
        if type(name) ~= "string" then name = FALLBACK end
        return name, hasReq
    end
end

local _skillReq = GetTrainerServiceSkillReq
if type(_skillReq) == "function" then
    function GetTrainerServiceSkillReq(id)
        local skill, rank, hasReq = _skillReq(id)
        if skill ~= nil and type(skill) ~= "string" then skill = FALLBACK end
        if skill ~= nil and rank == nil then rank = 0 end
        return skill, rank, hasReq
    end
end

local _stepReq = GetTrainerServiceStepReq
if type(_stepReq) == "function" then
    function GetTrainerServiceStepReq(id)
        local step, met = _stepReq(id)
        if step ~= nil and type(step) ~= "string" then step = FALLBACK end
        return step, met
    end
end

local _numReq = GetTrainerServiceNumAbilityReq
if type(_numReq) == "function" then
    function GetTrainerServiceNumAbilityReq(id)
        local n = _numReq(id)
        if type(n) ~= "number" then n = 0 end
        return n
    end
end

local _cost = GetTrainerServiceCost
if type(_cost) == "function" then
    function GetTrainerServiceCost(id)
        local money, cp1, cp2 = _cost(id)
        if type(money) ~= "number" then money = 0 end
        if type(cp1)   ~= "number" then cp1   = 0 end
        if type(cp2)   ~= "number" then cp2   = 0 end
        return money, cp1, cp2
    end
end

local _levelReq = GetTrainerServiceLevelReq
if type(_levelReq) == "function" then
    function GetTrainerServiceLevelReq(id)
        local lvl = _levelReq(id)
        if type(lvl) ~= "number" then lvl = 1 end
        return lvl
    end
end
