--[[
    ═══════════════════════════════════════════════════════════════
    ⛏️ [Моя аниме-шахта / My Anime Mine] — Ultimate Autofarm Hub v2.0
    👑 Author: Ryomotik
    💎 UI: Fluent Amethyst Edition
    🎮 Place ID: 79389059854988
    ═══════════════════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Game Modules
local GameState = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameState"))
local MineConfig = require(ReplicatedStorage.Modules:WaitForChild("MineConfig"))
local MineInventory = require(ReplicatedStorage.Modules:WaitForChild("MineInventory"))
local String = require(ReplicatedStorage.Modules:WaitForChild("String"))
local Items = require(ReplicatedStorage.Modules:WaitForChild("Items"))

-- Load Fluent Interface Suite
local Fluent = nil
local fluentSuccess, _ = pcall(function()
    Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/ryomotik/MyAnimeMine-Autofarm/main/fluent.lua", true))()
end)

if not Fluent or not fluentSuccess then
    pcall(function()
        Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua", true))()
    end)
end

if not Fluent then
    warn("[MyAnimeMine]: Не удалось загрузить интерфейс Fluent!")
    return
end

-- Script State
local State = {
    -- Auto-Farm (Plot)
    AutoFarm = false,
    FarmSpeed = 15,          -- Clicks per cycle
    FarmDelay = 0.05,
    PlaySwingAnimation = true,
    
    -- Auto-Clicker (Cursor / Mouse)
    AutoClicker = false,
    ClickerCPS = 25,
    ClickerKey = Enum.KeyCode.V,
    
    -- Chest & Pets
    AutoCollectChest = true,
    AutoEquipBest = true,
    EquipInterval = 5,
    
    -- Auto-Sell
    AutoSell = false,
    AutoSellInterval = 45,
    AutoSellInProgress = false,
    
    -- Upgrades
    AutoUpgradeMiners = false,
    AutoUpgradeSkills = false,
    AutoBuyPickaxes = false,
    
    -- Internal
    PlayerPlot = nil,
    SwingTrack = nil,
}

-- Notification Helper
local function notify(title, content, duration)
    pcall(function()
        Fluent:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3
        })
    end)
end

-- Dynamic & Bulletproof Plot Resolver
local function getMyPlot()
    if State.PlayerPlot and State.PlayerPlot.Parent and State.PlayerPlot:FindFirstChild("Nodes") then
        return State.PlayerPlot
    end
    
    local mw = workspace:FindFirstChild("MineWorld")
    local plots = mw and mw:FindFirstChild("Plots")
    if not plots then return nil end
    local myId = LocalPlayer.UserId
    
    -- 1. Check OwnerUserId attribute
    for _, p in ipairs(plots:GetChildren()) do
        if p:GetAttribute("OwnerUserId") == myId and p:FindFirstChild("Nodes") then
            State.PlayerPlot = p
            return p
        end
    end
    
    -- 2. Check Name or Owner ObjectValue
    for _, p in ipairs(plots:GetChildren()) do
        if p.Name:find(LocalPlayer.Name) or (p:FindFirstChild("Owner") and p.Owner.Value == LocalPlayer) then
            if p:FindFirstChild("Nodes") then
                State.PlayerPlot = p
                return p
            end
        end
    end
    
    -- 3. Fallback: Find plot closest to player character
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local closest, minDist = nil, 300
        for _, p in ipairs(plots:GetChildren()) do
            local base = p:FindFirstChild("Base") or p:FindFirstChild("MineFloor") or p:FindFirstChild("Chest")
            if base and p:FindFirstChild("Nodes") then
                local dist = (base.Position - root.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = p
                end
            end
        end
        if closest then
            State.PlayerPlot = closest
            return closest
        end
    end
    
    return nil
end

-- Swing Animation Helper
local function triggerSwingAnim()
    if not State.PlaySwingAnimation then return end
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        
        if not State.SwingTrack or not State.SwingTrack.IsPlaying then
            local anim = ReplicatedStorage.Animations:FindFirstChild("MineStrikeR15") 
                      or ReplicatedStorage.Animations:FindFirstChild("MineStrike")
                      or ReplicatedStorage.Animations:FindFirstChild("PickaxeNew")
            if anim then
                State.SwingTrack = hum:LoadAnimation(anim)
                State.SwingTrack.Priority = Enum.AnimationPriority.Action
                State.SwingTrack:Play()
            end
        end
    end)
end

-- Routine: Take from Chest & Equip Best Dropped Characters
local function performCollectAndEquipBest()
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local mineGui = pg and pg:FindFirstChild("MineGui")
        
        -- Step 1: Take ALL dropped items and anime characters from plot chest
        GameState.SendEvent("MineTakeChest")
        if mineGui then
            local cf = mineGui:FindFirstChild("ChestFrame")
            if cf and cf:FindFirstChild("Content") then
                local takeBtn = cf.Content.Actions:FindFirstChild("TakeButton")
                if takeBtn then
                    firesignal(takeBtn.MouseButton1Click)
                end
            end
        end
        task.wait(0.25)
        
        -- Step 2: Equip Best anime characters from inventory into all slots
        GameState.SendEvent("MineEquipBest")
        if mineGui then
            local inv = mineGui:FindFirstChild("InventoryFrame")
            if inv and inv:FindFirstChild("Content") then
                local eqBtn = inv.Content.Actions:FindFirstChild("EquipBestButton")
                if eqBtn then
                    firesignal(eqBtn.MouseButton1Click)
                end
            end
        end
        task.wait(0.2)
        
        -- Step 3: Equip highest pickaxe to all miners
        local data = GameState.GetData2()
        local mg = data and data.MineGame
        local tier = mg and mg.PickaxeTier or 1
        local holders = mg and mg.Holders
        if holders then
            for hKey in pairs(holders) do
                GameState.SendEvent("MineEquipPickaxe", hKey, tier)
            end
        end
    end)
end

-- Teleport Helper
local function getTeleportButton()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local mineGui = pg and pg:FindFirstChild("MineGui")
    return mineGui and mineGui:FindFirstChild("TeleportButton")
end

local function teleportTo(destination) -- "Shops" or "Base"
    local btn = getTeleportButton()
    if not btn then return false end
    local label = btn:FindFirstChildWhichIsA("TextLabel", true)
    if label and label.Text == destination then
        firesignal(btn.MouseButton1Click)
        task.wait(0.8)
        return true
    end
    return false
end

-- Full Auto-Sell Routine
local function performFullSell()
    if State.AutoSellInProgress then return end
    State.AutoSellInProgress = true
    
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local mineGui = pg and pg:FindFirstChild("MineGui")
        if not mineGui then 
            State.AutoSellInProgress = false
            return 
        end

        -- 1. Collect chest
        GameState.SendEvent("MineTakeChest")
        task.wait(0.3)

        -- 2. Teleport to Shops
        teleportTo("Shops")
        task.wait(0.5)

        -- 3. Open SellStand Prompt
        local sellStand = workspace:FindFirstChild("SellStand")
        local prompt = sellStand and sellStand:FindFirstChild("SkeletonMiner", true) and sellStand.SkeletonMiner:FindFirstChild("SellPrompt", true)
        if prompt then
            fireproximityprompt(prompt)
            task.wait(0.5)
        end

        -- 4. Click Select All & Sell
        local sellFrame = mineGui:FindFirstChild("SellFrame")
        if sellFrame and sellFrame.Visible then
            local content = sellFrame:FindFirstChild("Content")
            if content then
                local selectAll = content:FindFirstChild("SelectAllButton")
                local sellBtn = content:FindFirstChild("SellButton")
                if selectAll and sellBtn then
                    firesignal(selectAll.MouseButton1Click)
                    task.wait(0.2)
                    firesignal(sellBtn.MouseButton1Click)
                    task.wait(0.4)
                end
            end
        end

        -- 5. Teleport back to Base
        teleportTo("Base")
        task.wait(0.5)
    end)
    
    State.AutoSellInProgress = false
end

-- ─────────────────────────────────────────────────────────────
-- CREATE FLUENT UI WINDOW
-- ─────────────────────────────────────────────────────────────
local Window = Fluent:CreateWindow({
    Title = "⛏️ My Anime Mine | Hub v2.0",
    SubTitle = "by Ryomotik",
    TabWidth = 160,
    Size = UDim2.fromOffset(590, 480),
    Acrylic = true,
    Theme = "Amethyst",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Farm = Window:AddTab({ Title = "Фарм", Icon = "pickaxe" }),
    Clicker = Window:AddTab({ Title = "Автокликер", Icon = "mouse-pointer" }),
    Pets = Window:AddTab({ Title = "Петы & Кирки", Icon = "users" }),
    Sell = Window:AddTab({ Title = "Продажа", Icon = "coins" }),
    Upgrade = Window:AddTab({ Title = "Прокачка", Icon = "zap" }),
    Stats = Window:AddTab({ Title = "Инфо", Icon = "bar-chart-2" }),
    Settings = Window:AddTab({ Title = "Настройки", Icon = "settings" })
}

-- ─────────────────────────────────────────────────────────────
-- TAB 1: AUTO FARM (ТУРБО-АВТОФАРМ УЧАСТКА)
-- ─────────────────────────────────────────────────────────────
Tabs.Farm:AddSection("⚡ Турбо-Автофарм Участка")

Tabs.Farm:AddToggle("AutoFarmToggle", {
    Title = "Турбо-Автофарм (Все камни на участке)",
    Description = "Автоматически и непрерывно разбивает все спавнящиеся камни на вашем участке",
    Default = false,
    Callback = function(val)
        State.AutoFarm = val
        if val then
            notify("Автофарм", "Турбо-добыча активирована!", 2)
        else
            notify("Автофарм", "Добыча остановлена.", 2)
        end
    end
})

Tabs.Farm:AddSlider("FarmSpeedSlider", {
    Title = "Ударов за такт (Интенсивность)",
    Description = "Сколько раз кликать по жиле за каждый цикл (рекомендуется 5-15)",
    Default = 10,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Callback = function(val)
        State.FarmSpeed = val
    end
})

Tabs.Farm:AddSlider("FarmDelaySlider", {
    Title = "Задержка цикла автофарма (сек)",
    Description = "Пауза между циклами обхода рудных жил",
    Default = 0.05,
    Min = 0.01,
    Max = 0.3,
    Rounding = 2,
    Callback = function(val)
        State.FarmDelay = val
    end
})

Tabs.Farm:AddToggle("SwingAnimToggle", {
    Title = "Анимация взмаха кирки",
    Description = "Персонаж визуально машет киркой при автофарме и автоклике",
    Default = true,
    Callback = function(val)
        State.PlaySwingAnimation = val
    end
})

-- ─────────────────────────────────────────────────────────────
-- TAB 2: AUTOCLICKER (ПОЛНОЦЕННЫЙ АВТОКЛИКЕР МЫШИ)
-- ─────────────────────────────────────────────────────────────
Tabs.Clicker:AddSection("🖱️ Автокликер Курсора / Мыши")

Tabs.Clicker:AddToggle("AutoClickerToggle", {
    Title = "Включить Автокликер",
    Description = "Быстро кликает по камню под прицелом/курсором или спамит ЛКМ",
    Default = false,
    Callback = function(val)
        State.AutoClicker = val
        if val then
            notify("Автокликер", "Автокликер включён! Нажмите клавишу для переключения.", 2)
        else
            notify("Автокликер", "Автокликер выключен.", 2)
        end
    end
})

Tabs.Clicker:AddSlider("ClickerCPSSlider", {
    Title = "Кликов в секунду (CPS)",
    Description = "Скорость работы автокликера",
    Default = 25,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Callback = function(val)
        State.ClickerCPS = val
    end
})

Tabs.Clicker:AddKeybind("ClickerKeybind", {
    Title = "Горячая клавиша автокликера (Вкл/Выкл)",
    Mode = "Toggle",
    Default = "V",
    Callback = function(val)
        State.AutoClicker = not State.AutoClicker
        notify("Автокликер", "Статус: " .. (State.AutoClicker and "ВКЛЮЧЁН" or "ВЫКЛЮЧЕН"), 1.5)
    end
})

-- ─────────────────────────────────────────────────────────────
-- TAB 3: PETS & CREW (ПЕТЫ И КИРКИ)
-- ─────────────────────────────────────────────────────────────
Tabs.Pets:AddSection("🐾 Авто-сбор и экипировка сильнейших петов")

Tabs.Pets:AddToggle("AutoEquipBestToggle", {
    Title = "Авто-сбор и экипировка топ петов",
    Description = "Каждые 5 сек забирает сундук и надевает самых сильных выпавших аниме-персов",
    Default = true,
    Callback = function(val)
        State.AutoEquipBest = val
        if val then
            performCollectAndEquipBest()
            notify("Петы", "Авто-экипировка лучших петов включена!", 2)
        end
    end
})

Tabs.Pets:AddButton({
    Title = "⚡ Забрать сундук и одеть ТОП петов сейчас",
    Description = "Мгновенно достаёт всех выпавших петов из сундука и ставит их в слоты",
    Callback = function()
        performCollectAndEquipBest()
        notify("Петы", "Сундук опустошён, лучшие персонажи экипированы!", 2.5)
    end
})

Tabs.Pets:AddSection("📋 Текущая команда в слотах (Holders)")
local SlotListParagraph = Tabs.Pets:AddParagraph({ 
    Title = "Экипированные майнеры", 
    Content = "Загрузка..." 
})

-- ─────────────────────────────────────────────────────────────
-- TAB 4: AUTO SELL (ПРОДАЖА)
-- ─────────────────────────────────────────────────────────────
Tabs.Sell:AddSection("💰 Автоматическая продажа")

Tabs.Sell:AddToggle("AutoSellToggle", {
    Title = "Авто-продажа (Телепорт в магазин)",
    Description = "Забирает руду, летит к торговцу, жмёт «Выбрать всё» и «Продать», затем возвращается",
    Default = false,
    Callback = function(val)
        State.AutoSell = val
        if val then
            notify("Продажа", "Авто-продажа запущена (каждые " .. State.AutoSellInterval .. " сек)", 3)
        end
    end
})

Tabs.Sell:AddSlider("SellIntervalSlider", {
    Title = "Интервал продажи (сек)",
    Description = "Как часто летать в магазин для сбыта накопленной руды",
    Default = 45,
    Min = 15,
    Max = 180,
    Rounding = 0,
    Callback = function(val)
        State.AutoSellInterval = val
    end
})

Tabs.Sell:AddButton({
    Title = "Продать прямо сейчас (Sell Now)",
    Description = "Моментальный телепорт, быстрая продажа и возврат на участок",
    Callback = function()
        notify("Продажа", "Выполняем продажу...", 2)
        task.spawn(performFullSell)
    end
})

-- ─────────────────────────────────────────────────────────────
-- TAB 5: UPGRADES (ПРОКАЧКА)
-- ─────────────────────────────────────────────────────────────
Tabs.Upgrade:AddSection("⚡ Автоматическая прокачка")

Tabs.Upgrade:AddToggle("AutoUpgradeMinersToggle", {
    Title = "Авто-прокачка майнеров (Damage, Speed, Mining)",
    Description = "Повышает уровни характеристик всех экипированных персонажей",
    Default = false,
    Callback = function(val)
        State.AutoUpgradeMiners = val
    end
})

Tabs.Upgrade:AddToggle("AutoUpgradeSkillsToggle", {
    Title = "Авто-прокачка дерева навыков (Skill Tree)",
    Description = "Изучает доступные навыки текущей зоны по мере накопления монет",
    Default = false,
    Callback = function(val)
        State.AutoUpgradeSkills = val
    end
})

Tabs.Upgrade:AddToggle("AutoBuyPickaxesToggle", {
    Title = "Авто-покупка лучших кирок (Pickaxe Shop)",
    Description = "Покупает кирку следующего уровня в магазине при наличии средств",
    Default = false,
    Callback = function(val)
        State.AutoBuyPickaxes = val
    end
})

-- ─────────────────────────────────────────────────────────────
-- TAB 6: STATS & INFO (ИНФОРМАЦИЯ)
-- ─────────────────────────────────────────────────────────────
Tabs.Stats:AddSection("📊 Телеметрия")

local MoneyLabel = Tabs.Stats:AddParagraph({ Title = "💰 Баланс", Content = "Загрузка..." })
local GemsLabel = Tabs.Stats:AddParagraph({ Title = "💎 Гемы", Content = "Загрузка..." })
local ZoneLabel = Tabs.Stats:AddParagraph({ Title = "🗺️ Зона", Content = "Загрузка..." })
local PlotLabel = Tabs.Stats:AddParagraph({ Title = "🏡 Участок", Content = "Загрузка..." })

-- ─────────────────────────────────────────────────────────────
-- TAB 7: SETTINGS (НАСТРОЙКИ)
-- ─────────────────────────────────────────────────────────────
Tabs.Settings:AddSection("⚙️ Меню")

Tabs.Settings:AddKeybind("ToggleMenuKeybind", {
    Title = "Скрыть/Показать интерфейс",
    Mode = "Toggle",
    Default = "LeftControl",
    Callback = function() end
})

Tabs.Settings:AddSection("👑 Создатель")
Tabs.Settings:AddParagraph({
    Title = "Разработчик скрипта",
    Content = "Автор: Ryomotik\nСпециально для: «⛏️ Моя аниме-шахта» (My Anime Mine)\nВерсия: v2.0 Turbo Edition"
})

-- ─────────────────────────────────────────────────────────────
-- BACKGROUND WORKERS
-- ─────────────────────────────────────────────────────────────

-- 1. Turbo Auto-Farm Worker (All Nodes on Plot)
task.spawn(function()
    while true do
        if State.AutoFarm and not State.AutoSellInProgress then
            local plot = getMyPlot()
            if plot and plot:FindFirstChild("Nodes") then
                local nodes = plot.Nodes:GetChildren()
                for _, node in ipairs(nodes) do
                    if not State.AutoFarm or State.AutoSellInProgress then break end
                    local click = node:FindFirstChild("NodeClick")
                    if click and click:IsA("ClickDetector") then
                        for _ = 1, State.FarmSpeed do
                            pcall(fireclickdetector, click)
                        end
                        triggerSwingAnim()
                    end
                end
            end
        end
        task.wait(State.FarmDelay)
    end
end)

-- 2. Cursor Auto-Clicker Worker (Target / Mouse)
task.spawn(function()
    while true do
        if State.AutoClicker and not State.AutoSellInProgress then
            local target = Mouse.Target
            local node = target and target:FindFirstAncestorWhichIsA("Model")
            local click = node and node:FindFirstChild("NodeClick")
            
            if click and click:IsA("ClickDetector") then
                pcall(fireclickdetector, click)
                triggerSwingAnim()
            else
                pcall(mouse1click)
                triggerSwingAnim()
            end
        end
        local delay = 1 / math.clamp(State.ClickerCPS, 1, 50)
        task.wait(delay)
    end
end)

-- 3. Auto-Collect Chest & Equip Best Dropped Pets Worker
task.spawn(function()
    while true do
        task.wait(State.EquipInterval)
        if (State.AutoEquipBest or State.AutoCollectChest) and not State.AutoSellInProgress then
            performCollectAndEquipBest()
        end
    end
end)

-- 4. Auto-Sell Timer Worker
task.spawn(function()
    local lastSellTime = os.clock()
    while true do
        task.wait(1)
        if State.AutoSell and not State.AutoSellInProgress then
            if os.clock() - lastSellTime >= State.AutoSellInterval then
                lastSellTime = os.clock()
                performFullSell()
            end
        end
    end
end)

-- 5. Auto-Upgrade Miners Worker
task.spawn(function()
    while true do
        task.wait(4)
        if State.AutoUpgradeMiners and not State.AutoSellInProgress then
            pcall(function()
                local data = GameState.GetData2()
                local mg = data and data.MineGame
                local holders = mg and mg.Holders
                if holders then
                    for hKey in pairs(holders) do
                        if not State.AutoUpgradeMiners then break end
                        GameState.SendEvent("MineUpgradeCharacter", hKey, "Damage")
                        task.wait(0.04)
                        GameState.SendEvent("MineUpgradeCharacter", hKey, "Speed")
                        task.wait(0.04)
                        GameState.SendEvent("MineUpgradeCharacter", hKey, "MineSpeed")
                        task.wait(0.04)
                    end
                end
            end)
        end
    end
end)

-- 6. Auto-Upgrade Skills Worker
task.spawn(function()
    while true do
        task.wait(6)
        if State.AutoUpgradeSkills and not State.AutoSellInProgress then
            pcall(function()
                local data = GameState.GetData2()
                local mg = data and data.MineGame
                local curZone = "Z" .. tostring(mg and mg.CurrentZone or 1)
                local zNodes = MineConfig.ZoneSkillNodes and MineConfig.ZoneSkillNodes[curZone]
                if zNodes then
                    for _, node in ipairs(zNodes) do
                        if not State.AutoUpgradeSkills then break end
                        GameState.SendEvent("MineBuySkill", node.Id)
                        task.wait(0.05)
                    end
                end
            end)
        end
    end
end)

-- 7. Auto-Buy Pickaxes Worker
task.spawn(function()
    while true do
        task.wait(8)
        if State.AutoBuyPickaxes and not State.AutoSellInProgress then
            pcall(function()
                local data = GameState.GetData2()
                local mg = data and data.MineGame
                local tier = mg and mg.PickaxeTier or 1
                GameState.SendEvent("MineBuyPickaxe", tier + 1)
            end)
        end
    end
end)

-- 8. Live Telemetry & Slot Display Updater
task.spawn(function()
    while true do
        pcall(function()
            local data = GameState.GetData2()
            local mg = data and data.MineGame
            local money = data and data.Money or 0
            local gems = mg and mg.Gems or 0
            local zone = mg and mg.CurrentZone or 1
            local plot = getMyPlot()
            
            local fmtMoney = (String and String.ToMoney and pcall(String.ToMoney, String, money)) and String:ToMoney(money) or tostring(math.floor(money))
            MoneyLabel:SetDesc("$" .. fmtMoney)
            GemsLabel:SetDesc(tostring(gems) .. " 💎")
            ZoneLabel:SetDesc("Зона " .. tostring(zone))
            PlotLabel:SetDesc(plot and plot.Name or "Поиск...")
            
            -- Update Slot Display in Pets Tab
            local slotLines = {}
            local holders = mg and mg.Holders
            if holders then
                local keys = {}
                for k in pairs(holders) do table.insert(keys, k) end
                table.sort(keys)
                for _, k in ipairs(keys) do
                    local h = holders[k]
                    local itemData = Items.GetItemData(h.CharName)
                    local baseDmg = itemData and MineConfig.GetCharacterDamage(itemData) or 0
                    local mult = MineConfig.GetCharacterLevelMultiplier(h.CharLevel or 1)
                    local totalDmg = math.floor(baseDmg * mult)
                    local fmtDmg = (String and String.ToMoney and pcall(String.ToMoney, String, totalDmg)) and String:ToMoney(totalDmg) or tostring(totalDmg)
                    table.insert(slotLines, string.format("• [%s] %s | Lvl: %d | DMG: %s", k, h.CharName, h.CharLevel or 1, fmtDmg))
                end
            end
            if #slotLines > 0 then
                SlotListParagraph:SetDesc(table.concat(slotLines, "\n"))
            else
                SlotListParagraph:SetDesc("Нет активных слотов")
            end
        end)
        task.wait(2)
    end
end)

-- Default tab selection and ready notification
Window:SelectTab(1)
notify("⛏️ My Anime Mine Hub v2.0", "Готово! Автокликер [V] и авто-экипировка настроены.", 5)
