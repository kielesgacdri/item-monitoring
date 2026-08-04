-- // Kise Monitoring Script - Ultimate Stable Version
local HttpService = game:GetService("HttpService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local SUPABASE_URL = "https://ixlfaqxeunlkilmzsbmu.supabase.co/rest/v1/"
local SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4bGZhcXhldW5sa2lsbXpzYm11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2MDQxNTgsImV4cCI6MjEwMTE4MDE1OH0.Pjp9yiCI6MEfWCmq1SLfDDPEK3aZOVTFwCB2nw-2sgs"

local headers = {
    ["apikey"] = SUPABASE_KEY,
    ["Authorization"] = "Bearer " .. SUPABASE_KEY,
    ["Content-Type"] = "application/json",
    ["Prefer"] = "resolution=merge-duplicates"
}

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local function getRealSheckles()
    if LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Sheckles") then
        return tonumber(LocalPlayer.leaderstats.Sheckles.Value) or 0
    elseif LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Sheckles") then
        return tonumber(LocalPlayer.Data.Sheckles.Value) or 0
    end
    return 0
end

local function scanAndSync()
    if not httpRequest then return end
    if not LocalPlayer or not LocalPlayer.Name then return end

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    if not LocalPlayer:FindFirstChild("Backpack") then return end

    local username = LocalPlayer.Name
    local realSheckles = getRealSheckles()

    -- 1. Sync Sheckles
    pcall(function()
        httpRequest({
            Url = SUPABASE_URL .. "User_sheckles?on_conflict=username",
            Method = "POST",
            Headers = headers,
            Body = HttpService:JSONEncode({
                username = username,
                sheckles = realSheckles
            })
        })
    end)

    -- 2. Sync Status Online
    pcall(function()
        httpRequest({
            Url = SUPABASE_URL .. "User_status?on_conflict=username",
            Method = "POST",
            Headers = headers,
            Body = HttpService:JSONEncode({
                username = username,
                last_seen = os.date("!%Y-%m-%dT%H:%M:%SZ")
            })
        })
    end)

    -- 3. INVENTORY SYNC (Aman dari Error 400)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local aggregatedItems = {}

    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            local rawName = item.Name
            local cleanName = rawName:gsub("^%s*(.-)%s*$", "%1")
            
            local category = "Seeds"
            local lowerName = cleanName:lower()
            
            if lowerName:find("shovel") or lowerName:find("sprinkler") or lowerName:find("watering can") or lowerName:find("gear") or lowerName:find("crate") or lowerName:find("chest") then
                category = "Gear"
            elseif lowerName:find("gnome") then
                category = "Gnomes"
            elseif lowerName:find("seed pack") then
                category = "SeedPacks"
            elseif lowerName:find("egg") then
                category = "Eggs"
            end

            local isFruit = lowerName:find("kg") or cleanName:match("%[%s*%d+%.?%d*%s*kg%s*%]")
            if isFruit then category = "Fruit" end

            local amount = 1
            if item:GetAttribute("Amount") then
                amount = tonumber(item:GetAttribute("Amount")) or 1
            elseif item:FindFirstChild("Amount") then
                amount = tonumber(item.Amount.Value) or 1
            else
                local foundNum = cleanName:match("%((%d+)%)") or cleanName:match("x(%d+)")
                if foundNum then amount = tonumber(foundNum) or 1 end
            end

            local key = username .. "_" .. cleanName
            if aggregatedItems[key] then
                aggregatedItems[key].amount = aggregatedItems[key].amount + amount
            else
                aggregatedItems[key] = {
                    username = tostring(username),
                    item_name = tostring(cleanName),
                    category = tostring(category),
                    amount = math.floor(amount)
                }
            end
        end
    end

    local itemsPayload = {}
    for _, itemData in pairs(aggregatedItems) do
        table.insert(itemsPayload, itemData)
    end

    if #itemsPayload > 0 then
        pcall(function()
            -- Hapus data lama milik user ini
            httpRequest({
                Url = SUPABASE_URL .. "Item_monitoring?username=eq." .. HttpService:UrlEncode(username),
                Method = "DELETE",
                Headers = headers
            })
            
            task.wait(0.5)

            -- Kirim data baru dengan header upsert/merge
            httpRequest({
                Url = SUPABASE_URL .. "Item_monitoring",
                Method = "POST",
                Headers = {
                    ["apikey"] = SUPABASE_KEY,
                    ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                    ["Content-Type"] = "application/json",
                    ["Prefer"] = "return=minimal"
                },
                Body = HttpService:JSONEncode(itemsPayload)
            })
        end)
    end
end

task.spawn(function()
    repeat task.wait(1) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer:FindFirstChild("Backpack")
    task.wait(3)

    scanAndSync()

    while true do
        task.wait(20)
        scanAndSync()
    end
end)
