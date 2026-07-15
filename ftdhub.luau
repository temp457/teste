if getgenv().FTD_LOADAT and (tick() - getgenv().FTD_LOADAT) < 4 then return end
getgenv().FTD_LOADAT = tick()
if getgenv().FTD_UNLOAD then pcall(getgenv().FTD_UNLOAD) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
repeat task.wait() until Players.LocalPlayer
local LP = Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end

local HUB_PLACE = 73598910647444
local BATTLE_PLACE = 140424706837320
local WEBHOOK = "https://discord.com/api/webhooks/1526156897965834350/lygPdGLTj0yQ0JDd9reiQBDtc022HpCfoEeiuu9uBhLQtIBsp8FdxInY_5aHtKGL60rB"

local function mapName()
    local gd = RS:FindFirstChild("_GAMEDATA")
    local mn = gd and gd:FindFirstChild("Map")
    return (mn and mn.Value ~= "" and mn.Value) or "unknown"
end

local S = {
    running = false,
    autoPlace = false,
    replay = true,
    autoUpgrade = true,
    gameSpeed = "2",
    autoSkip = true,
    autoVote = true,
    autoReturn = true,
    autoReplay = false,
    burst = false,
    burstN = 8,
    burstMap = {},
    upgradeMap = {},
    difficulty = "mid",
    recording = false,
    autoFish = true,
    feedSlot = "1",
    fodderRarity = "Green (Basic)",
    feedMaxKg = 100,
    autoFeed = false,
    sellRarity = "Basic",
    autoBuy = false,
    autoClaim = true,
    autoLaunch = false,
    autoReconnect = true,
    antiAfk = true,
    webhookLog = true,
    persist = true,
    launchMap = "The Bottom",
    macro = {},
    _clock0 = os.clock(),
    _recCount = 0,
    _playIds = {},
    _replayIdx = 1,
}
local SETTINGS = { "autoPlace", "replay", "autoUpgrade", "gameSpeed", "autoSkip", "autoVote",
    "autoReturn", "autoReplay", "burst", "burstN", "burstMap", "upgradeMap", "difficulty", "autoFish", "feedSlot", "fodderRarity", "feedMaxKg", "autoFeed", "sellRarity", "autoBuy", "autoClaim", "autoLaunch", "autoReconnect", "antiAfk", "webhookLog", "launchMap" }

local Cleanup = { conns = {}, insts = {}, fns = {} }
function Cleanup:conn(c) if c then self.conns[#self.conns + 1] = c end return c end
function Cleanup:inst(i) if i then self.insts[#self.insts + 1] = i end return i end
function Cleanup:add(f) if f then self.fns[#self.fns + 1] = f end return f end
function Cleanup:run()
    self._dead = true
    S.running = false
    S.recording = false
    for _, c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
    for _, f in ipairs(self.fns) do pcall(f) end
    for _, i in ipairs(self.insts) do pcall(function() i:Destroy() end) end
    self.conns, self.insts, self.fns = {}, {}, {}
end
getgenv().FTD_UNLOAD = function() pcall(function() Cleanup:run() end) end

local function saveCfg()
    pcall(function()
        if not writefile then return end
        local t = {}
        for _, k in ipairs(SETTINGS) do t[k] = S[k] end
        local body = HttpService:JSONEncode(t)
        writefile("ftd_config.json", body)
        local m = mapName()
        if m ~= "unknown" then writefile("ftd_config_" .. m .. ".json", body) end
    end)
end
local function applyCfgFile(file)
    pcall(function()
        if not (readfile and isfile and isfile(file)) then return end
        local t = HttpService:JSONDecode(readfile(file))
        for k, v in pairs(t) do if S[k] ~= nil then S[k] = v end end
    end)
end
local function loadCfg(map)
    applyCfgFile("ftd_config.json")
    if map and map ~= "unknown" then applyCfgFile("ftd_config_" .. map .. ".json") end
end
loadCfg()
S.persist = not (isfile and isfile("ftd_persist_off.txt"))
local PERSIST_LOADER = 'if not (isfile and isfile("ftd_persist_off.txt")) then local ok,s=pcall(readfile,"ftdhub.luau") if ok and type(s)=="string" and #s>0 then loadstring(s)() end end'
local function persist()
    if not S.persist then return end
    local q = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if q then pcall(function() q(PERSIST_LOADER) end) end
end
local function setPersist(on)
    S.persist = on
    if on then
        pcall(function() if delfile then delfile("ftd_persist_off.txt") end end)
        persist()
    else
        pcall(function() if writefile then writefile("ftd_persist_off.txt", "1") end end)
        pcall(function() local c = clear_teleport_queue or clearqueueonteleport if c then c() end end)
    end
end

local function notify(txt)
    if S._notify then S._notify(txt) return end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", { Title = "FTD", Text = tostring(txt), Duration = 3 })
    end)
end

local function fmtDur(s)
    s = math.max(0, math.floor(s))
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
    return string.format("%d:%02d", m, sec)
end
local function comma(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local k
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end
S._cnt = { on = false, start = 0, credits = 0, diamonds = 0, xp = 0, matches = 0, wins = 0, losses = 0, msgId = nil }
local function saveCounter()
    pcall(function() if writefile then writefile("ftd_counter.json", HttpService:JSONEncode(S._cnt)) end end)
end
local function loadCounter()
    pcall(function()
        if readfile and isfile and isfile("ftd_counter.json") then
            local t = HttpService:JSONDecode(readfile("ftd_counter.json"))
            if type(t) == "table" then for k, v in pairs(t) do S._cnt[k] = v end end
        end
    end)
    S.counter = S._cnt.on
end
local function webhookSend(payload, edit)
    local fn = (syn and syn.request) or (http and http.request) or http_request or request
    if not fn then return end
    task.spawn(function()
        local url, method
        if edit and S._cnt.msgId then
            url = WEBHOOK .. "/messages/" .. S._cnt.msgId
            method = "PATCH"
        else
            url = WEBHOOK .. "?wait=true"
            method = "POST"
        end
        local ok, resp = pcall(function()
            return fn({ Url = url, Method = method, Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload) })
        end)
        if ok and resp and method == "POST" then
            pcall(function()
                local body = resp.Body or resp.body
                local data = body and HttpService:JSONDecode(body)
                if data and data.id then S._cnt.msgId = tostring(data.id) saveCounter() end
            end)
        end
    end)
end
local function counterEmbed(stopped)
    local c = S._cnt
    local el = (c.start and c.start > 0) and (os.time() - c.start) or 0
    local fields = {
        { name = "Matches", value = string.format("%d  (%dW / %dL)", c.matches, c.wins, c.losses), inline = true },
        { name = "Elapsed", value = fmtDur(el), inline = true },
        { name = "Total gained", value = "Credits **" .. comma(c.credits) .. "**\nDiamonds **" .. comma(c.diamonds) .. "**\nXP **" .. comma(c.xp) .. "**", inline = false },
    }
    if el >= 120 then
        local hrs = el / 3600
        fields[#fields + 1] = { name = "Est. / hour", value = "Credits ~" .. comma(c.credits / hrs) .. "\nDiamonds ~" .. comma(c.diamonds / hrs), inline = true }
        fields[#fields + 1] = { name = "Est. / 12h", value = "Credits ~" .. comma(c.credits / hrs * 12) .. "\nDiamonds ~" .. comma(c.diamonds / hrs * 12), inline = true }
    else
        fields[#fields + 1] = { name = "Estimates", value = "calculating… (needs 2+ min)", inline = false }
    end
    return {
        embeds = { {
            title = (stopped and "⏹ FTD Session (stopped) — " or "📊 FTD Session (live) — ") .. LP.Name,
            color = stopped and 9807270 or 3447003,
            fields = fields,
            footer = { text = c.start > 0 and ("started " .. os.date("!%Y-%m-%d %H:%M UTC", c.start)) or "started" },
        } },
    }
end
local function counterSummary()
    local c = S._cnt
    local el = (c.start and c.start > 0) and (os.time() - c.start) or 0
    return string.format("Matches %d (%dW/%dL) | %s\nCredits +%s Diamonds +%s XP +%s",
        c.matches, c.wins, c.losses, fmtDur(el), comma(c.credits), comma(c.diamonds), comma(c.xp))
end
local function showCounter() notify(counterSummary()) end
local function counterToggle(v)
    if v then
        S._cnt = { on = true, start = os.time(), credits = 0, diamonds = 0, xp = 0, matches = 0, wins = 0, losses = 0, msgId = nil }
        saveCounter()
        webhookSend(counterEmbed(false), false)
        notify("counter started")
    else
        S._cnt.on = false
        webhookSend(counterEmbed(true), true)
        saveCounter()
        notify("counter stopped\n" .. counterSummary())
    end
end
loadCounter()

local function req(inst) if not inst then return nil end local ok, m = pcall(require, inst) if ok then return m end return nil end
local function findPath(root, segs) local n = root for _, s in ipairs(segs) do n = n and n:FindFirstChild(s) end return n end
local Data = req(findPath(RS, { "Shared", "Data" }))
local Util = req(findPath(RS, { "Shared", "Utility" }))

local function ev(name) return findPath(RS, { "Events", name }) end
local function credits()
    local ls = LP:FindFirstChild("leaderstats")
    local c = ls and ls:FindFirstChild("Credits")
    return c and c.Value or 0
end
local function curWave()
    local gd = RS:FindFirstChild("_GAMEDATA")
    local wv = gd and gd:FindFirstChild("Wave")
    return wv and wv.Value or 0
end
local function matchElapsed() return os.clock() - (S._clock0 or os.clock()) end
local function loadout()
    local out = {}
    local slots = findPath(LP, { "Data", "Slots" })
    if slots then
        for _, c in ipairs(slots:GetChildren()) do
            if tonumber(c.Name) and tostring(c.Value) ~= "" then out[c.Name] = tostring(c.Value) end
        end
    end
    return out
end
local function slotForTemplate(t)
    for slot, name in pairs(loadout()) do if name == t then return slot end end
    return nil
end
local function mapList()
    local out = {}
    if Data and type(Data.MAPS) == "table" then for k in pairs(Data.MAPS) do out[#out + 1] = tostring(k) end end
    if #out == 0 then out = { "The Bottom", "Frostbite Tower" } end
    return out
end
local function difficultyList()
    local out = {}
    if Data and type(Data.WAVES) == "table" then for k in pairs(Data.WAVES) do out[#out + 1] = tostring(k) end end
    if #out == 0 then out = { "easy", "mid", "hard" } end
    return out
end
local function burstFor(template)
    return (S.burstMap and S.burstMap[template]) or S.burstN
end

local WORMS = {
    { id = "BAIT_WORM", label = "Worm" },
    { id = "BAIT_ROYAL_WORM", label = "Royal" },
    { id = "BAIT_UNDERWORM", label = "Under" },
}
local function curOf(name)
    local ls = LP:FindFirstChild("leaderstats")
    local v = ls and ls:FindFirstChild(name)
    return (v and v.Value) or 0
end
local function buyBait(id, qty)
    if not qty or qty < 1 then return end
    pcall(function()
        local rf = findPath(RS, { "Events", "Trading", "AttemptPurchase" })
        if rf then rf:InvokeServer(id, qty) end
    end)
end
local function buyAll(id)
    local def = Data and Data.ITEMS and Data.ITEMS[id]
    if not def then return end
    local qty = math.floor(curOf(def.Currency) / (def.Price or 1))
    if qty > 0 then buyBait(id, math.min(qty, 100000)) end
end
local function autoBuyStep()
    local ab = findPath(LP, { "Data", "ActiveBait" })
    if not (ab and ab.Value ~= "") then return end
    local id = ab.Value
    local def = Data and Data.ITEMS and Data.ITEMS[id]
    if not def then return end
    local item = findPath(LP, { "Data", "Backpack" })
    item = item and item:FindFirstChild(id)
    local amt = (item and item:GetAttribute("amount")) or 0
    if amt < 50 then
        local n = math.min(math.floor(curOf(def.Currency) / (def.Price or 1)), 100)
        if n > 0 then buyBait(id, n) end
    end
end

local FODDER_RARITY = {
    ["Green (Basic)"] = "Basic",
    ["Blue (Rare)"] = "Rare",
    ["Purple (Epic)"] = "Epic",
    ["Red (Legendary)"] = "Legendary",
    ["Everything"] = "*",
}
local FEED_TARGET_KG = 100
local function towerKg(inst)
    if not Util then return 0 end
    local ok, kg = pcall(function() return (Util.getKgFromExp(inst:GetAttribute("kgExp"))) end)
    return ok and tonumber(kg) or 0
end
local function feedTarget()
    local sf = findPath(LP, { "Data", "Slots" })
    local slot = sf and sf:FindFirstChild(tostring(S.feedSlot))
    if not slot then return nil, nil end
    local id = tostring(slot.Value)
    local bp = findPath(LP, { "Data", "Backpack" })
    return bp and bp:FindFirstChild(id), id
end
local function feedFodder(targetId, cap)
    local out = {}
    local bp = findPath(LP, { "Data", "Backpack" })
    if not (bp and Data and Data.TOWERS) then return out end
    local want = FODDER_RARITY[S.fodderRarity] or "Basic"
    local eq = {}
    local sf = findPath(LP, { "Data", "Slots" })
    if sf then for _, c in ipairs(sf:GetChildren()) do eq[tostring(c.Value)] = true end end
    for _, c in ipairs(bp:GetChildren()) do
        if c:GetAttribute("kgExp") ~= nil then
            local def = Data.TOWERS[tostring(c.Value)]
            local rar = def and def.Rarity
            local trait = c:GetAttribute("trait")
            if rar and (want == "*" or rar == want) and c.Name ~= targetId and not eq[c.Name] and (trait == nil or trait == "") then
                out[#out + 1] = c.Name
                if cap and #out >= cap then break end
            end
        end
    end
    return out
end
local function previewFodder()
    local inst, id = feedTarget()
    notify("slot " .. tostring(S.feedSlot) .. ": Kg " .. tostring(inst and towerKg(inst) or "?") .. "\n" .. tostring(S.fodderRarity) .. " fodder = " .. #feedFodder(id or "__none__"))
end
local function feedCap() return tonumber(S.feedMaxKg) or FEED_TARGET_KG end
local function feedStep()
    local inst, id = feedTarget()
    if not (inst and id and Util) then notify("no unit in slot " .. tostring(S.feedSlot)) S.autoFeed = false return end
    local kg = towerKg(inst)
    if kg >= feedCap() then notify("slot " .. tostring(S.feedSlot) .. " reached Kg " .. kg) S.autoFeed = false return end
    local fodder = feedFodder(id, 50)
    if #fodder == 0 then notify("out of " .. tostring(S.fodderRarity) .. " fodder") S.autoFeed = false return end
    pcall(function() local rf = ev("AskFeed") if rf then rf:InvokeServer(id, fodder) end end)
    task.wait(0.15)
    local after = towerKg(inst)
    if after <= kg then
        S._feedStall = (S._feedStall or 0) + 1
        if S._feedStall >= 5 then notify("feed stalled at Kg " .. after) S.autoFeed = false end
    else
        S._feedStall = 0
        if math.floor(after / 10) > math.floor(kg / 10) then notify("feeding slot " .. tostring(S.feedSlot) .. ": Kg " .. after .. "/" .. feedCap()) end
    end
end
local function sellByRarity(rarity)
    local bp = findPath(LP, { "Data", "Backpack" })
    local rf = ev("AskSell")
    if not (bp and Data and Data.TOWERS and rf) then return 0 end
    local eq = {}
    local sf = findPath(LP, { "Data", "Slots" })
    if sf then for _, c in ipairs(sf:GetChildren()) do eq[tostring(c.Value)] = true end end
    local list = {}
    for _, c in ipairs(bp:GetChildren()) do
        if c:GetAttribute("kgExp") ~= nil then
            local def = Data.TOWERS[tostring(c.Value)]
            local trait = c:GetAttribute("trait")
            if def and def.Rarity == rarity and not eq[c.Name] and (trait == nil or trait == "") then
                list[#list + 1] = c.Name
            end
        end
    end
    local sold = 0
    while #list > 0 do
        local chunk = {}
        for _ = 1, math.min(100, #list) do chunk[#chunk + 1] = table.remove(list) end
        pcall(function() rf:InvokeServer(chunk) end)
        sold = sold + #chunk
        task.wait(0.2)
    end
    return sold
end

local function currentMap()
    local mn = mapName()
    if mn == "unknown" then return nil end
    return workspace:FindFirstChild(mn)
end
local function pathPoints()
    local pts = {}
    if not Util then return pts end
    local ok, paths = pcall(function() return Util.getMapSortedPaths() end)
    if ok and type(paths) == "table" then
        for _, path in pairs(paths) do
            if type(path) == "table" then for _, p in ipairs(path) do pts[#pts + 1] = p end end
        end
    end
    return pts
end
local function makeSpacePart(space, pos)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = true
    part.Transparency = 1
    part.Shape = Enum.PartType.Cylinder
    part.Size = Vector3.new(space.Y, space.Z, space.X)
    part.CFrame = CFrame.new(pos) * CFrame.new(0, space.Y / 2, 0) * CFrame.Angles(0, 0, 1.5707963267948966)
    part.Parent = workspace
    return part
end
local function collectSpots(towerName, checkFree, cap)
    local out = {}
    local map = currentMap()
    if not (map and Util) then return out end
    local placeables = map:FindFirstChild("Placeables")
    if not placeables then return out end
    local okS, space = pcall(function() return Util.getTowerSpace(towerName) end)
    if not okS or typeof(space) ~= "Vector3" then return out end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { placeables }
    for _, node in ipairs(pathPoints()) do
        for r = 4, 14, 3 do
            for a = 0, 300, 60 do
                local rad = math.rad(a)
                local cand = node + Vector3.new(math.cos(rad) * r, 0, math.sin(rad) * r)
                local hit = workspace:Raycast(cand + Vector3.new(0, 120, 0), Vector3.new(0, -260, 0), rp)
                if hit and hit.Instance and hit.Instance:IsDescendantOf(placeables) then
                    local pos = hit.Position
                    local free = true
                    if checkFree then
                        local part = makeSpacePart(space, pos)
                        pcall(function() free = not (Util.isSpaceCollidingWithAnything(part) or Util.isSpaceBoxCollidingWithOtherSpaces(part)) end)
                        part:Destroy()
                    end
                    if free then
                        out[#out + 1] = CFrame.new(pos)
                        if cap and #out >= cap then return out end
                    end
                end
            end
        end
    end
    return out
end

local function fireCreate(template, slot, cf)
    local ok = false
    pcall(function()
        local rf = ev("AskCreating")
        if rf then ok = rf:InvokeServer({ Template = template, Coordinates = cf, IsSpaceAvail = true, SlotName = slot }) end
    end)
    return ok
end
local function burstCreate(template, slot, cf, n)
    for _ = 1, (n or S.burstN) do
        task.spawn(function()
            pcall(function()
                local rf = ev("AskCreating")
                if rf then rf:InvokeServer({ Template = template, Coordinates = cf, IsSpaceAvail = true, SlotName = slot }) end
            end)
        end)
    end
end
local function fireUpgrade(id)
    pcall(function() local rf = ev("AskUpgrade") if rf then rf:InvokeServer(tonumber(id)) end end)
end
local function placedCount(towerName)
    if not Util then return 0 end
    local ok, list = pcall(function() return Util.getTowersByType(towerName, LP.Name) end)
    return (ok and type(list) == "table") and #list or 0
end
local function tryPlace()
    if not Data then return end
    for slot, towerName in pairs(loadout()) do
        local def = Data.TOWERS and Data.TOWERS[towerName]
        if def and def._type ~= "dummy" and def.Upgrades and def.Upgrades[1] then
            if placedCount(towerName) < (def._maxPlacements or 1) and credits() >= (def.Upgrades[1].Cost or 0) then
                local spots = collectSpots(towerName, true, 1)
                if spots[1] then
                    if S.burst then burstCreate(towerName, slot, spots[1], burstFor(towerName)) else fireCreate(towerName, slot, spots[1]) end
                end
            end
        end
    end
end
local function tryUpgrade()
    local tdir = workspace:FindFirstChild("Towers")
    if not (tdir and Data) then return end
    for _, tw in ipairs(tdir:GetChildren()) do
        if tw:GetAttribute("Owner") == LP.Name then
            local ty = tw:GetAttribute("Type")
            local up = tw:GetAttribute("Upgrade") or 1
            local def = ty and Data.TOWERS and Data.TOWERS[ty]
            if def and def.Upgrades then
                local cap = S.upgradeMap[ty] or #def.Upgrades
                local nxt = def.Upgrades[up + 1]
                if up < cap and nxt and credits() >= (nxt.Cost or 1e9) then fireUpgrade(tw.Name) end
            end
        end
    end
end

local function saveMacro()
    pcall(function() if writefile then writefile("ftd_macro_" .. mapName() .. ".json", HttpService:JSONEncode(S.macro)) end end)
end
local function loadMacro()
    S.macro = {}
    pcall(function()
        local f = "ftd_macro_" .. mapName() .. ".json"
        if readfile and isfile and isfile(f) then S.macro = HttpService:JSONDecode(readfile(f)) end
    end)
end
local function startRecord()
    S.macro = {}
    S._recCount = 0
    S._clock0 = os.clock()
    S.recording = true
end
local function stopRecord()
    S.recording = false
    saveMacro()
end

local function watchTowerAdded(tw)
    if S.recording then
        task.spawn(function()
            local tries = 0
            while not (tw:GetAttribute("Type") and tw:GetAttribute("slotName")) and tries < 120 do task.wait() tries = tries + 1 end
            if not S.recording then return end
            if tw:GetAttribute("Owner") ~= LP.Name then return end
            local ty = tw:GetAttribute("Type")
            local co = tw:GetAttribute("Coordinates")
            if not (ty and typeof(co) == "CFrame") then return end
            S._recCount = S._recCount + 1
            local idx = S._recCount
            local p = co.Position
            local slot = tw:GetAttribute("slotName")
            S.macro[#S.macro + 1] = { act = "place", template = ty, slot = slot and tostring(slot) or nil, x = p.X, y = p.Y, z = p.Z, t = matchElapsed(), cost = credits(), wave = curWave() }
            Cleanup:conn(tw:GetAttributeChangedSignal("Upgrade"):Connect(function()
                if S.recording and (tw:GetAttribute("Upgrade") or 1) >= 2 then
                    S.macro[#S.macro + 1] = { act = "upgrade", idx = idx, t = matchElapsed(), cost = credits(), wave = curWave() }
                end
            end))
        end)
    end
    if S.replay and S.running then S._playIds[#S._playIds + 1] = tw.Name end
end

local function resultsOpen()
    local gui = LP:FindFirstChild("PlayerGui")
    gui = gui and gui:FindFirstChild("Gui")
    local res = gui and gui:FindFirstChild("Results")
    return res and res.Visible
end

local function stepReplay()
    local mn = mapName()
    if mn == "unknown" then return end
    local w = curWave()
    if w < (S._lastWave or 0) then
        S._replayIdx = 1
        S._playIds = {}
        S._clock0 = os.clock()
    end
    S._lastWave = w
    if S._loadedMap ~= mn then
        loadMacro()
        S._loadedMap = mn
        S._replayIdx = 1
        S._playIds = {}
    end
    if not currentMap() then return end
    while S._replayIdx <= #S.macro do
        local ac = S.macro[S._replayIdx]
        if credits() < (ac.cost or 0) or curWave() < (ac.wave or 0) then break end
        if ac.act == "place" then
            local slot = ac.slot or slotForTemplate(ac.template)
            if slot then
                local cf = CFrame.new(ac.x, ac.y, ac.z)
                if S.burst then burstCreate(ac.template, slot, cf, burstFor(ac.template)) else fireCreate(ac.template, slot, cf) end
            end
            S._replayIdx = S._replayIdx + 1
        elseif ac.act == "upgrade" then
            local id = ac.idx and S._playIds[ac.idx]
            if id then fireUpgrade(id) S._replayIdx = S._replayIdx + 1 else break end
        else
            S._replayIdx = S._replayIdx + 1
        end
    end
end

local function burstAllSpots()
    local slot, tower = next(loadout())
    if not tower then return end
    local spots = collectSpots(tower, false, 60)
    for _, cf in ipairs(spots) do burstCreate(tower, slot, cf, 1) end
    notify("bursting " .. #spots .. " spots")
end

local function recordToggle(v)
    if v then startRecord() notify("recording " .. mapName())
    else stopRecord() notify("saved " .. #S.macro .. " actions") end
end
local function toggleRun()
    S.running = not S.running
    if S.running and S.replay then S._loadedMap = nil end
    notify(S.running and "running" or "stopped")
end
local function launchBattle()
    local cp = findPath(RS, { "Shared", "Packages", "Knit", "Services", "PartyService", "RF", "CreateParty" })
    local lc = findPath(RS, { "Shared", "Packages", "Knit", "Services", "PartyService", "RF", "LaunchParty" })
    if cp then pcall(function() cp:InvokeServer({ Map = S.launchMap, FriendsOnly = false }) end) end
    task.wait(0.6)
    if lc then pcall(function() lc:InvokeServer(LP.UserId) end) end
    notify("launching " .. S.launchMap)
end
local function equipRod()
    local char = LP.Character
    local sig = findPath(RS, { "Events", "Summoning", "_RodEquipSignal" })
    if char and sig then pcall(function() sig:FireServer(char, true) end) end
end

local function findReconnectBtn()
    local prompt = game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui")
    if not prompt then return nil end
    for _, d in ipairs(prompt:GetDescendants()) do
        if d:IsA("TextButton") and type(d.Text) == "string" then
            local tx = d.Text:lower()
            if tx:find("reconnect") or tx:find("rejoin") then return d end
        end
    end
    return nil
end
local function installAntiAfk()
    if S._afkInstalled then return end
    S._afkInstalled = true
    local VU = nil
    pcall(function() VU = game:GetService("VirtualUser") end)
    if not VU then return end
    Cleanup:conn(LP.Idled:Connect(function()
        if not S.antiAfk then return end
        pcall(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
    end))
end
local function installReconnect()
    if S._reconInstalled then return end
    S._reconInstalled = true
    task.spawn(function()
        while not Cleanup._dead do
            task.wait(2)
            if S.autoReconnect then
                pcall(function()
                    local btn = findReconnectBtn()
                    if btn and (not S._reconTime or tick() - S._reconTime > 10) then
                        S._reconTime = tick()
                        if getconnections then
                            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                        end
                    end
                end)
            end
        end
    end)
end

local function battleSpec()
    local units, seen = {}, {}
    for _, name in pairs(loadout()) do
        if not seen[name] then seen[name] = true units[#units + 1] = name end
    end
    local function maxUpg(name)
        local def = Data and Data.TOWERS and Data.TOWERS[name]
        return (def and def.Upgrades and #def.Upgrades) or 6
    end
    local upg = { { t = "toggle", key = "autoUpgrade", label = "Auto upgrade" } }
    for _, name in ipairs(units) do
        local mx = maxUpg(name)
        upg[#upg + 1] = { t = "slider", unit = name, target = "upgradeMap", fallback = mx, label = "Upg " .. name, min = 1, max = mx }
    end
    local exploit = {
        { t = "toggle", key = "burst", label = "Burst stack" },
        { t = "slider", key = "burstN", label = "Burst all", min = 1, max = 20 },
    }
    for _, name in ipairs(units) do
        exploit[#exploit + 1] = { t = "slider", unit = name, target = "burstMap", fallback = S.burstN, label = "Burst " .. name, min = 1, max = 20 }
    end
    exploit[#exploit + 1] = { t = "button", label = "Burst all spots", fn = burstAllSpots }
    return {
        { section = "Macro", items = {
            { t = "toggle", key = "recording", label = "Record", onChange = recordToggle },
            { t = "toggle", key = "replay", label = "Replay macro" },
            { t = "button", label = "Save macro", fn = saveMacro },
        } },
        { section = "Auto", items = {
            { t = "toggle", key = "autoPlace", label = "Auto place" },
            { t = "dropdown", key = "gameSpeed", label = "Speed", values = { "1", "2", "3" } },
            { t = "toggle", key = "autoSkip", label = "Auto skip" },
            { t = "toggle", key = "autoVote", label = "Auto vote" },
            { t = "dropdown", key = "difficulty", label = "Difficulty", values = difficultyList() },
            { t = "toggle", key = "autoReturn", label = "Auto lobby" },
            { t = "toggle", key = "autoReplay", label = "Auto replay" },
        } },
        { section = "Upgrades", items = upg },
        { section = "Exploit", items = exploit },
        { section = "Control", items = {
            { t = "button", label = "START / STOP", fn = toggleRun },
        } },
    }
end
local function hubSpec()
    local buy = { { t = "toggle", key = "autoBuy", label = "Auto buy bait" } }
    for _, wm in ipairs(WORMS) do
        buy[#buy + 1] = { t = "button", label = wm.label .. " 5x", fn = function() buyBait(wm.id, 5) end }
        buy[#buy + 1] = { t = "button", label = wm.label .. " 10x", fn = function() buyBait(wm.id, 10) end }
        buy[#buy + 1] = { t = "button", label = wm.label .. " all", fn = function() buyAll(wm.id) end }
    end
    return {
        { section = "Farm", items = {
            { t = "toggle", key = "autoFish", label = "Auto fish" },
            { t = "toggle", key = "autoClaim", label = "Auto claim" },
        } },
        { section = "Buy", items = buy },
        { section = "Feed", items = {
            { t = "dropdown", key = "feedSlot", label = "Feed slot", values = { "1", "2", "3", "4", "5" } },
            { t = "dropdown", key = "fodderRarity", label = "Fodder", values = { "Green (Basic)", "Blue (Rare)", "Purple (Epic)", "Red (Legendary)", "Everything" } },
            { t = "slider", key = "feedMaxKg", label = "Feed to Kg", min = 10, max = 180 },
            { t = "toggle", key = "autoFeed", label = "Auto feed" },
            { t = "button", label = "Preview fodder", fn = previewFodder },
        } },
        { section = "Sell", items = {
            { t = "dropdown", key = "sellRarity", label = "Sell rarity", values = { "Basic", "Rare", "Epic", "Mythic", "Legendary", "Extinct", "Supreme" } },
            { t = "button", label = "Sell all", fn = function() task.spawn(function() local n = sellByRarity(S.sellRarity) notify("sold " .. n .. " " .. tostring(S.sellRarity)) end) end },
        } },
        { section = "Launch", items = {
            { t = "dropdown", key = "launchMap", label = "Map", values = mapList() },
            { t = "toggle", key = "autoLaunch", label = "Auto launch" },
            { t = "button", label = "Launch battle", fn = launchBattle },
        } },
        { section = "Counter", items = {
            { t = "toggle", key = "counter", label = "Counter", onChange = counterToggle },
            { t = "button", label = "Show totals", fn = showCounter },
        } },
        { section = "System", items = {
            { t = "toggle", key = "antiAfk", label = "Anti AFK" },
            { t = "toggle", key = "autoReconnect", label = "Auto reconnect" },
            { t = "toggle", key = "webhookLog", label = "Webhook logs" },
            { t = "toggle", key = "persist", label = "Persist", onChange = setPersist },
        } },
        { section = "Control", items = {
            { t = "button", label = "START / STOP", fn = toggleRun },
        } },
    }
end

local function renderTab(Tab, spec)
    for _, sec in ipairs(spec) do
        pcall(function() Tab:Section({ Title = sec.section }) end)
        for _, it in ipairs(sec.items) do
            if it.t == "toggle" then
                pcall(function()
                    Tab:Toggle({ Title = it.label, Value = S[it.key], Callback = function(v)
                        S[it.key] = v saveCfg() if it.onChange then pcall(it.onChange, v) end
                    end })
                end)
            elseif it.t == "button" then
                pcall(function() Tab:Button({ Title = it.label, Callback = function() pcall(it.fn) end }) end)
            elseif it.t == "slider" then
                pcall(function()
                    local def = it.unit and ((S[it.target] and S[it.target][it.unit]) or it.fallback) or S[it.key]
                    Tab:Slider({ Title = it.label, Value = { Min = it.min, Max = it.max, Default = def }, Step = 1,
                        Callback = function(v)
                            local num = (type(v) == "table" and v.Value) or v
                            if it.unit then
                                if not S[it.target] then S[it.target] = {} end
                                S[it.target][it.unit] = num
                            else S[it.key] = num end
                            saveCfg()
                        end })
                end)
            elseif it.t == "dropdown" then
                pcall(function()
                    Tab:Dropdown({ Title = it.label, Values = it.values, Value = S[it.key],
                        Callback = function(v) S[it.key] = (type(v) == "table" and v[1]) or v saveCfg() end })
                end)
            end
        end
    end
end

local function buildWind(title, tabs)
    local ok, WindUI = pcall(function()
        return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua"))()
    end)
    if not ok or type(WindUI) ~= "table" then return false end
    local Window
    local ok2 = pcall(function()
        Window = WindUI:CreateWindow({ Title = title, Author = "macro", Folder = "FTDHub",
            Size = UDim2.fromOffset(480, 400), Theme = "Dark", HideSearchBar = true })
    end)
    if not ok2 or not Window then return false end
    S._notify = function(t) pcall(function() WindUI:Notify({ Title = "FTD", Content = tostring(t), Duration = 3 }) end) end
    local anyTab = false
    for _, td in ipairs(tabs) do
        local Tab
        pcall(function() Tab = Window:Tab({ Title = td.name }) end)
        if Tab then anyTab = true renderTab(Tab, td.spec) end
    end
    if not anyTab then return false end
    local function windRoot()
        if S._windGui and S._windGui.Parent then return S._windGui end
        local best, bestScore
        for _, cont in ipairs({ (gethui and gethui()) or false, game:GetService("CoreGui") }) do
            if cont then
                for _, g in ipairs(cont:GetChildren()) do
                    if g:IsA("ScreenGui") and g.Name ~= "FTDMobile" then
                        local ln = g.Name:lower()
                        local score = #g:GetDescendants() + ((ln:find("wind") or ln:find("ftd")) and 100000 or 0)
                        if not best or score > bestScore then best, bestScore = g, score end
                    end
                end
            end
        end
        S._windGui = best
        return best
    end
    local function toggleGui()
        local root = windRoot()
        if root then root.Enabled = not root.Enabled end
    end

    local mob = Cleanup:inst(Instance.new("ScreenGui"))
    mob.Name = "FTDMobile"
    mob.ResetOnSpawn = false
    mob.DisplayOrder = 9999
    pcall(function() mob.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui") end)
    local mbtn = Instance.new("TextButton")
    mbtn.Size = UDim2.fromOffset(44, 44)
    mbtn.Position = UDim2.fromOffset(14, 200)
    mbtn.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
    mbtn.Text = "FTD"
    mbtn.TextColor3 = Color3.fromRGB(235, 235, 245)
    mbtn.Font = Enum.Font.GothamBold
    mbtn.TextSize = 13
    mbtn.Active = true
    mbtn.Draggable = true
    mbtn.Parent = mob
    Instance.new("UICorner", mbtn).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", mbtn)
    stroke.Color = Color3.fromRGB(80, 90, 120)
    Cleanup:conn(mbtn.MouseButton1Click:Connect(toggleGui))

    Cleanup:conn(UIS.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == Enum.KeyCode.RightShift then toggleGui() end
    end))

    local function tuneChrome(root)
        local vpx = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X) or 1280
        local frame, area
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("Frame") or d:IsA("CanvasGroup") then
                local sz = d.AbsoluteSize
                if sz.X > 150 and sz.X < vpx - 20 then
                    local a = sz.X * sz.Y
                    if not area or a > area then frame, area = d, a end
                end
            end
        end
        if not frame then return end
        local topY = frame.AbsolutePosition.Y
        local rightX = frame.AbsolutePosition.X + frame.AbsoluteSize.X * 0.45
        local cluster = {}
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("TextButton") or d:IsA("ImageButton") then
                local sz, pos = d.AbsoluteSize, d.AbsolutePosition
                if sz.X < 60 and sz.Y < 60 and math.abs(pos.Y - topY) < 56 and pos.X >= rightX then
                    local nm = (d.Name .. " " .. (d:IsA("TextButton") and d.Text or "")):lower()
                    if nm:find("close") or d.Text == "×" or d.Text == "✕" then
                        if not d:GetAttribute("ftdClose") then
                            d:SetAttribute("ftdClose", true)
                            Cleanup:conn(d.MouseButton1Click:Connect(function() pcall(function() getgenv().FTD_UNLOAD() end) end))
                        end
                    elseif nm:find("minim") or d.Text == "—" or d.Text == "–" or d.Text == "_" or d.Text == "-" then
                        d.Visible = false
                    else
                        cluster[#cluster + 1] = d
                    end
                end
            end
        end
        if #cluster >= 3 then pcall(function() cluster[1].Visible = false end) end
    end

    task.spawn(function()
        for _ = 1, 10 do
            task.wait(0.4)
            local root = windRoot()
            if root then
                if not S._closeHooked then
                    S._closeHooked = true
                    Cleanup:conn(root.AncestryChanged:Connect(function(_, parent) if not parent then pcall(function() getgenv().FTD_UNLOAD() end) end end))
                    pcall(function() Cleanup:conn(root.Destroying:Connect(function() pcall(function() getgenv().FTD_UNLOAD() end) end)) end)
                end
                pcall(tuneChrome, root)
            end
        end
    end)
    return true
end

local function buildNative(title, tabs)
    local defs = {}
    for _, td in ipairs(tabs) do
        defs[#defs + 1] = { kind = "label", label = "== " .. td.name .. " ==" }
        for _, sec in ipairs(td.spec) do
            defs[#defs + 1] = { kind = "label", label = sec.section }
            for _, it in ipairs(sec.items) do
                if it.t == "toggle" then
                    defs[#defs + 1] = { kind = "toggle", key = it.key, label = it.label, onChange = it.onChange }
                elseif it.t == "button" then
                    defs[#defs + 1] = { kind = "button", label = it.label, fn = it.fn }
                end
            end
        end
    end
    local sg = Cleanup:inst(Instance.new("ScreenGui"))
    sg.Name = "FTDHub"
    sg.ResetOnSpawn = false
    pcall(function() sg.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui") end)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(214, 40 + #defs * 26)
    frame.Position = UDim2.fromOffset(24, 90)
    frame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local bar = Instance.new("TextLabel")
    bar.Size = UDim2.new(1, 0, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
    bar.BorderSizePixel = 0
    bar.Text = title
    bar.TextColor3 = Color3.fromRGB(235, 235, 245)
    bar.Font = Enum.Font.GothamBold
    bar.TextSize = 14
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)
    local y = 34
    for _, d in ipairs(defs) do
        if d.kind == "label" then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -12, 0, 20)
            lbl.Position = UDim2.fromOffset(6, y)
            lbl.BackgroundTransparency = 1
            lbl.Text = d.label
            lbl.TextColor3 = Color3.fromRGB(150, 170, 210)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 12
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = frame
            y = y + 22
        else
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -12, 0, 22)
            btn.Position = UDim2.fromOffset(6, y)
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 13
            btn.TextColor3 = Color3.fromRGB(230, 230, 235)
            btn.Parent = frame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            if d.kind == "toggle" then
                local function paint()
                    btn.BackgroundColor3 = S[d.key] and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(48, 50, 60)
                    btn.Text = (S[d.key] and "ON  " or "OFF  ") .. d.label
                end
                paint()
                Cleanup:conn(btn.MouseButton1Click:Connect(function()
                    S[d.key] = not S[d.key] paint() saveCfg()
                    if d.onChange then pcall(d.onChange, S[d.key]) end
                end))
            else
                btn.BackgroundColor3 = Color3.fromRGB(48, 60, 90)
                btn.Text = d.label
                Cleanup:conn(btn.MouseButton1Click:Connect(function() pcall(d.fn) end))
            end
            y = y + 26
        end
    end
end

local function buildAllTabs()
    return { { name = "Battle", spec = battleSpec() }, { name = "Hub", spec = hubSpec() } }
end
local function buildGui()
    local tabs = buildAllTabs()
    if not buildWind("FTD Hub", tabs) then buildNative("FTD Hub", tabs) end
end

local function gdVal(name, default)
    local g = RS:FindFirstChild("_GAMEDATA")
    local v = g and g:FindFirstChild(name)
    if v == nil then return default end
    return v.Value
end
local function matchRewards(won, wavesSurvived)
    local out = { Credits = 0, Diamonds = 0, Experience = 0 }
    if not (Data and Data.MAPS) then return out end
    local map = gdVal("Map", mapName())
    local diff = gdVal("Difficulty", S.difficulty)
    local md = Data.MAPS[map]
    local fixed = md and md.fixedRewards and md.fixedRewards[diff]
    if type(fixed) ~= "table" then return out end
    local mult = 1
    if not won then
        local total = (Data.WAVES and Data.WAVES[diff] and #Data.WAVES[diff]) or 1
        mult = math.min((wavesSurvived or 0) / math.max(total, 1), 0.75)
    end
    for _, r in ipairs(fixed) do
        if r.parent and out[r.parent] ~= nil then out[r.parent] = math.floor((r.val or 0) * mult) end
    end
    return out
end
local function httpPost(body)
    local fn = (syn and syn.request) or (http and http.request) or http_request or request
    if not fn then return end
    task.spawn(function() pcall(function()
        fn({ Url = WEBHOOK, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
    end) end)
end
local function sendMatchResult(won)
    local dur = os.clock() - (S._matchStart or os.clock())
    local r = matchRewards(won, S._maxWave)
    local map = gdVal("Map", mapName())
    local diff = gdVal("Difficulty", S.difficulty)
    local payload = {
        content = "@everyone",
        allowed_mentions = { parse = { "everyone" } },
        embeds = { {
            title = won and "🏆 Victory" or "💀 Defeat",
            color = won and 3066993 or 15158332,
            fields = {
                { name = "Player", value = LP.Name, inline = true },
                { name = "Map", value = tostring(map) .. " (" .. tostring(diff) .. ")", inline = true },
                { name = "Duration", value = fmtDur(dur), inline = true },
                { name = "Rewards", value = string.format("Credits **+%d**\nDiamonds **+%d**\nXP **+%d**", r.Credits, r.Diamonds, r.Experience), inline = false },
            },
            footer = { text = "FTD auto-farm" },
        } },
    }
    httpPost(HttpService:JSONEncode(payload))
end
local function trackMatch()
    local wv = curWave()
    if S._mtLast == nil then S._mtLast = wv end
    if wv < S._mtLast then
        S._matchStart = os.clock() S._matchLost = false S._maxWave = wv S._resultSent = false
    end
    S._mtLast = wv
    if not S._matchStart and wv >= 1 then S._matchStart = os.clock() end
    if wv > (S._maxWave or 0) then S._maxWave = wv end
    local bh = gdVal("BaseHealth")
    if type(bh) == "number" and bh <= 0 then S._matchLost = true end
    if resultsOpen() and not S._resultSent then
        S._resultSent = true
        local won = not S._matchLost
        pcall(function()
            if S._cnt and S._cnt.on then
                local r = matchRewards(won, S._maxWave)
                S._cnt.matches = S._cnt.matches + 1
                if won then S._cnt.wins = S._cnt.wins + 1 else S._cnt.losses = S._cnt.losses + 1 end
                S._cnt.credits = S._cnt.credits + r.Credits
                S._cnt.diamonds = S._cnt.diamonds + r.Diamonds
                S._cnt.xp = S._cnt.xp + r.Experience
                saveCounter()
                webhookSend(counterEmbed(false), true)
            end
            if S.webhookLog then sendMatchResult(won) end
        end)
    end
end

local function runBattle()
    persist()
    installAntiAfk()
    installReconnect()
    local tdir = workspace:WaitForChild("Towers", 10)
    if tdir then Cleanup:conn(tdir.ChildAdded:Connect(watchTowerAdded)) end
    local t0 = os.clock()
    while mapName() == "unknown" and os.clock() - t0 < 6 do task.wait(0.15) end
    loadCfg(mapName())
    buildGui()
    S.running = true
    task.spawn(function()
        while not Cleanup._dead do
            RunService.Heartbeat:Wait()
            if S.running then
                pcall(function()
                    trackMatch()
                    do
                        local target = tonumber(S.gameSpeed) or 2
                        local gd = RS:FindFirstChild("_GAMEDATA")
                        local gs = gd and gd:FindFirstChild("GameSpeed")
                        if gs and gs.Value ~= target then ev("AskGameSpeed"):InvokeServer(target) end
                    end
                    if S.autoVote then
                        local pv = findPath(RS, { "Events", "Votes", "PushVote" })
                        if pv then
                            if S._lastVote ~= S.difficulty then
                                pv:FireServer(S.difficulty) S._lastVote = S.difficulty S._voteN = 1
                            elseif (S._voteN or 0) < 4 then
                                pv:FireServer(S.difficulty) S._voteN = (S._voteN or 0) + 1
                            end
                        end
                    end
                    if S.autoSkip and not LP:GetAttribute("Autoskip") then
                        local pa = ev("PushAutoskip") if pa then pa:FireServer() end
                    end
                    if S.replay then stepReplay() end
                    if S.autoPlace and currentMap() then tryPlace() end
                    if S.autoUpgrade then tryUpgrade() end
                    if resultsOpen() then
                        local srw = ev("SendResultWill")
                        if srw then
                            if S.autoReplay then srw:FireServer("Replay")
                            elseif S.autoReturn then srw:FireServer("Lobby") end
                        end
                    end
                end)
            end
            task.wait(0.4)
        end
    end)
    notify("battle armed")
end

local function runHub()
    persist()
    installAntiAfk()
    installReconnect()
    buildGui()
    S.running = true
    task.spawn(function()
        while not Cleanup._dead do
            RunService.Heartbeat:Wait()
            if S.running then
                pcall(function()
                    if S.autoClaim then
                        local d = ev("AskDaily") if d then d:InvokeServer() end
                        local l = ev("AskLevelRedeem") if l then l:InvokeServer() end
                    end
                    if S.autoBuy then autoBuyStep() end
                    if S.autoLaunch then launchBattle() task.wait(5) end
                end)
            end
            task.wait(1.2)
        end
    end)
    task.spawn(function()
        while not Cleanup._dead do
            if S.running and S.autoFish then
                local bait = findPath(LP, { "Data", "ActiveBait" })
                local sum = findPath(RS, { "Events", "Summoning", "AskBaitSummon" })
                if bait and bait.Value ~= "" and sum then
                    equipRod()
                    pcall(function() sum:InvokeServer(1) end)
                else
                    task.wait(1)
                end
            else
                task.wait(1)
            end
        end
    end)
    task.spawn(function()
        while not Cleanup._dead do
            if S.running and S.autoFeed then
                pcall(feedStep)
                task.wait(0.1)
            else
                task.wait(1)
            end
        end
    end)
    notify("hub armed")
end

if game.PlaceId == BATTLE_PLACE then
    runBattle()
elseif game.PlaceId == HUB_PLACE then
    runHub()
end
