--[[
    ═══════════════════════════════════════════════════════════════
    ⛏️ [Моя аниме-шахта / My Anime Mine] — Universal GitHub Loader
    👑 Author: Ryomotik
    💎 Version: v1.0 Ultimate Edition
    ═══════════════════════════════════════════════════════════════
]]

local rawUrl = "https://raw.githubusercontent.com/ryomotik/MyAnimeMine-Autofarm/main/main.lua?v=" .. tostring(os.time())

local success, result = pcall(function()
    return game:HttpGet(rawUrl, true)
end)

if not success or not result or #result < 500 then
    pcall(function()
        result = game:HttpGet("https://raw.githubusercontent.com/ryomotik/MyAnimeMine-Autofarm/main/main.lua", true)
    end)
end

if result and #result > 500 then
    local fn, err = loadstring(result)
    if fn then
        fn()
    else
        warn("[MyAnimeMine Loader Error]: Ошибка компиляции main.lua:", tostring(err))
    end
else
    warn("[MyAnimeMine Loader Error]: Не удалось загрузить скрипт с GitHub. Проверьте подключение к сети.")
end
