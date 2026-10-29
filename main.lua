--[[
    ═══════════════════════════════════════════════════════════════
    ⛏️ [Моя аниме-шахта / My Anime Mine] — Ultimate Autofarm Hub
    👑 Author: Ryomotik
    💎 UI: Fluent Amethyst / Dark Edition
    🎮 Place ID: 79389059854988
    ═══════════════════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Wait for GameState and Modules
local GameState = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameState"))
local MineConfig = require(ReplicatedStorage.Modules:WaitForChild("MineConfig"))
local MineInventory = require(ReplicatedStorage.Modules:WaitForChild("MineInventory"))
local String = require(ReplicatedStorage.Modules:WaitForChild("String"))

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
    warn("[MyAnimeMine]: Не удалось загрузить библиотеку интерфейса Fluent!")
    return
end

-- State Management
local State = {
    AutoFarm = false,
    FarmDelay = 0.05,
    AutoCollectChest = true,
    
    AutoSell = false,
    AutoSellInterval = 45,
    AutoSellInProgress = false,
    
    AutoEquipBest = true,
    AutoEquipInterval = 10,
    
    AutoUpgradeMiners = false,
    AutoUpgradeSkills = false,
    AutoBuyPickaxes = false,
    
    PlayerPlot = nil,
    Teleporting = false,
}

-- Notification Helper
local function notify(title, content, duration)
    pcall(function()
        Fluent:Notify({
            Title = title,
            Content = content,
            Duration = duration or 4
        })
    end)
end

-- Plot Resolver
local function getMyPlot()
    if State.PlayerPlot and State.PlayerPlot.Parent then
        return State.PlayerPlot
    end
    local mw = workspace:FindFirstChild("MineWorld")
    if not mw then return nil end
    local plots = mw:FindFirstChild("Plots")
    if not plots then return nil end
    
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            State.PlayerPlot = plot
            return plot
        end
    end
    return nil
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

        -- Step 1: Collect from chest
        GameState.SendEvent("MineTakeChest")
        task.wait(0.3)

        -- Step 2: Teleport to Shops
        teleportTo("Shops")
        task.wait(0.5)

        -- Step 3: Trigger SellPrompt
        local sellStand = workspace:FindFirstChild("SellStand")
        local prompt = sellStand and sellStand:FindFirstChild("SkeletonMiner", true) and sellStand.SkeletonMiner:FindFirstChild("SellPrompt", true)
        if prompt then
            fireproximityprompt(prompt)
            task.wait(0.5)
        end

        -- Step 4: Click Select All & Sell Button
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

        -- Step 5: Teleport back to Base
        teleportTo("Base")
        task.wait(0.5)
    end)
    
    State.AutoSellInProgress = false
end

-- Create Window
local Window = Fluent:CreateWindow({
    Title = "⛏️ My Anime Mine | Hub",
    SubTitle = "by Ryomotik",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Amethyst",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Farm = Window:AddTab({ Title = "Фарм", Icon = "pickaxe" }),
    Sell = Window:AddTab({ Title = "Продажа", Icon = "coins" }),
    Crew = Window:AddTab({ Title = "Петы & Кирки", Icon = "users" }),
    Upgrade = Window:AddTab({ Title = "Прокачка", Icon = "zap" }),
    Stats = Window:AddTab({ Title = "Инфо", Icon = "bar-chart-2" }),
    Settings = Window:AddTab({ Title = "Настройки", Icon = "settings" })
}

-- ─────────────────────────────────────────────────────────────
-- TAB: FARM (ФАРМ)
-- ─────────────────────────────────────────────────────────────
Tabs.Farm:AddSection("⛏️ Автоматическая добыча")

Tabs.Farm:AddToggle("AutoFarmToggle", {
    Title = "Авто-фарм руды (Кликер)",
    Description = "Автоматически и мгновенно разбивает все камни на вашем участке",
    Default = false,
    Callback = function(value)
        State.AutoFarm = value
        if value then
            notify("Автофарм", "Добыча активирована!", 2)
        else
            notify("Автофарм", "Добыча приостановлена.", 2)
        end
    end
})

Tabs.Farm:AddSlider("FarmSpeedSlider", {
    Title = "Задержка кликов",
    Description = "Меньше значение = быстрее разбивание камней",
    Default = 0.05,
    Min = 0.01,
    Max = 0.5,
    Rounding = 2,
    Callback = function(value)
        State.FarmDelay = value
    end
})

Tabs.Farm:AddToggle("AutoCollectChestToggle", {
    Title = "Авто-сбор из сундука участка",
    Description = "Забирает накопленную руду в инвентарь каждые 10 секунд",
    Default = true,
    Callback = function(value)
        State.AutoCollectChest = value
    end
})

Tabs.Farm:AddButton({
    Title = "Забрать всё из сундука (Take Chest)",
    Description = "Мгновенно опустошить сундук участка",
    Callback = function()
        GameState.SendEvent("MineTakeChest")
        notify("Сундук", "Все предметы перемещены в инвентарь!", 2)
    end
})

-- ─────────────────────────────────────────────────────────────
-- TAB: AUTO SELL (ПРОДАЖА)
-- ─────────────────────────────────────────────────────────────
Tabs.Sell:AddSection("💰 Автоматическая продажа")

Tabs.Sell:AddToggle("AutoSellToggle", {
    Title = "Авто-продажа (Телепорт в магазин)",
    Description = "Собирает руду, телепортируется к торговцу, продаёт всё и возвращается",
    Default = false,
    Callback = function(value)
        State.AutoSell = value
        if value then
            notify("Авто-продажа", "Запущена! Интервал: " .. State.AutoSellInterval .. " сек.", 3)
        end
    end
})

Tabs.Sell:AddSlider("SellIntervalSlider", {
    Title = "Интервал авто-продажи (сек)",
    Description = "Как часто летать в магазин для сбыта руды",
    Default = 45,
    Min = 15,
    Max = 180,
    Rounding = 0,
    Callback = function(value)
        State.AutoSellInterval = value
    end
})

Tabs.Sell:AddButton({
    Title = "Продать сейчас (Sell Now)",
    Description = "Мгновенный телепорт, быстрая продажа и возврат на базу",
    Callback = function()
        notify("Продажа", "Выполняем продажу...", 2)
        task.spawn(performFullSell)
    end
})

-- ─────────────────────────────────────────────────────────────
-- TAB: CREW & PETS (ПЕТЫ И КИРКИ)
-- ─────────────────────────────────────────────────────────────
Tabs.Crew:AddSection("🐾 Управление персонажами и экипировкой")

Tabs.Crew:AddToggle("AutoEquipBestToggle", {
    Title = "Авто-экипировка лучших петов",
    Description = "Периодически экипирует самых сильных персонажей для максимального урона",
    Default = true,
    Callback = function(value)
        State.AutoEquipBest = value
        if value then
            GameState.SendEvent("MineEquipBest")
            notify("Петы", "Лучшие персонажи экипированы!", 2)
        end
    end
})

Tabs.Crew:AddButton({
    Title = "Экипировать лучших петов сейчас",
    Description = "Отправляет запрос серверу на оптимизацию слотов",
    Callback = function()
        GameState.SendEvent("MineEquipBest")
        notify("Петы", "Сервер экипировал лучших персонажей!", 2)
    end
})

Tabs.Crew:AddButton({
    Title = "Экипировать лучшие кирки всем",
    Description = "Выдаёт самую мощную кирку каждому майнеру",
    Callback = function()
        pcall(function()
            local data = GameState.GetData2()
            local mg = data and data.MineGame
            local holders = mg and mg.Holders
            local tier = mg and mg.PickaxeTier or 1
            if holders then
                for hKey, _ in pairs(holders) do
                    GameState.SendEvent("MineEquipPickaxe", hKey, tier)
                end
                notify("Кирки", "Кирки экипированы всем майнерам!", 2)
            end
        end)
    end
})

-- ─────────────────────────────────────────────────────────────
-- TAB: UPGRADES (ПРОКАЧКА)
-- ─────────────────────────────────────────────────────────────
Tabs.Upgrade:AddSection("⚡ Автоматическая прокачка")

Tabs.Upgrade:AddToggle("AutoUpgradeMinersToggle", {
    Title = "Авто-прокачка майнеров (Damage, Speed, Mining)",
    Description = "Повышает уровень характеристик всех экипированных персонажей",
    Default = false,
    Callback = function(value)
        State.AutoUpgradeMiners = value
    end
})

Tabs.Upgrade:AddToggle("AutoUpgradeSkillsToggle", {
    Title = "Авто-прокачка дерева навыков (Skill Tree)",
    Description = "Изучает доступные навыки текущей зоны по мере накопления монет",
    Default = false,
    Callback = function(value)
        State.AutoUpgradeSkills = value
    end
})

Tabs.Upgrade:AddToggle("AutoBuyPickaxesToggle", {
    Title = "Авто-покупка лучших кирок (Pickaxe Shop)",
    Description = "Покупает кирку следующего уровня в магазине при наличии средств",
    Default = false,
    Callback = function(value)
        State.AutoBuyPickaxes = value
    end
})

-- ─────────────────────────────────────────────────────────────
-- TAB: STATS (ИНФОРМАЦИЯ)
-- ─────────────────────────────────────────────────────────────
Tabs.Stats:AddSection("📊 Телеметрия игрока")

local MoneyLabel = Tabs.Stats:AddParagraph({ Title = "💰 Баланс", Content = "Загрузка..." })
local GemsLabel = Tabs.Stats:AddParagraph({ Title = "💎 Гемы", Content = "Загрузка..." })
local ZoneLabel = Tabs.Stats:AddParagraph({ Title = "🗺️ Зона", Content = "Загрузка..." })
local PlotLabel = Tabs.Stats:AddParagraph({ Title = "🏡 Участок", Content = "Загрузка..." })

-- ─────────────────────────────────────────────────────────────
-- TAB: SETTINGS (НАСТРОЙКИ)
-- ─────────────────────────────────────────────────────────────
Tabs.Settings:AddSection("⚙️ Управление меню")

Tabs.Settings:AddKeybind("ToggleMenuKeybind", {
    Title = "Клавиша открытия/закрытия меню",
    Mode = "Toggle",
    Default = "LeftControl",
    Callback = function()
        -- Fluent handles minimize internally
    end
})

Tabs.Settings:AddSection("👑 Создатель")
Tabs.Settings:AddParagraph({
    Title = "Разработчик скрипта",
    Content = "Автор: Ryomotik\nСпециально для: Моя аниме-шахта (My Anime Mine)\nВерсия: v1.0 Ultimate Edition"
})

-- ─────────────────────────────────────────────────────────────
-- BACKGROUND WORKERS
-- ─────────────────────────────────────────────────────────────

-- 1. Auto-Farm Worker
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
                        pcall(fireclickdetector, click)
                    end
                end
            end
        end
        task.wait(State.FarmDelay)
    end
end)

-- 2. Auto-Collect Chest Worker
task.spawn(function()
    while true do
        if State.AutoCollectChest and not State.AutoSellInProgress then
            pcall(function()
                GameState.SendEvent("MineTakeChest")
            end)
        end
        task.wait(10)
    end
end)

-- 3. Auto-Sell Timer Worker
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

-- 4. Auto-Equip Best Worker
task.spawn(function()
    while true do
        if State.AutoEquipBest then
            pcall(function()
                GameState.SendEvent("MineEquipBest")
            end)
        end
        task.wait(State.AutoEquipInterval)
    end
end)

-- 5. Auto-Upgrade Miners Worker
task.spawn(function()
    while true do
        if State.AutoUpgradeMiners and not State.AutoSellInProgress then
            pcall(function()
                local data = GameState.GetData2()
                local mg = data and data.MineGame
                local holders = mg and mg.Holders
                if holders then
                    for hKey, _ in pairs(holders) do
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
        task.wait(4)
    end
end)

-- 6. Auto-Upgrade Skills Worker
task.spawn(function()
    while true do
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
        task.wait(6)
    end
end)

-- 7. Auto-Buy Pickaxes Worker
task.spawn(function()
    while true do
        if State.AutoBuyPickaxes and not State.AutoSellInProgress then
            pcall(function()
                local data = GameState.GetData2()
                local mg = data and data.MineGame
                local tier = mg and mg.PickaxeTier or 1
                GameState.SendEvent("MineBuyPickaxe", tier + 1)
            end)
        end
        task.wait(8)
    end
end)

-- 8. Live Telemetry Updater
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
        end)
        task.wait(2)
    end
end)

-- Select default tab and notify user
Window:SelectTab(1)
notify("⛏️ My Anime Mine Hub", "Скрипт успешно запущен! Нажмите LeftControl для скрытия.", 5)
