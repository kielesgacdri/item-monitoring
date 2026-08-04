-- // Kise Monitoring Script - Full Final Real-time Version
local HttpService = game:GetService("HttpService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local SUPABASE_URL = "https://ixlfaqxeunlkilmzsbmu.supabase.co/rest/v1/"
local SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4bGZhcXhldW5sa2lsbXpzYm11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2MDQxNTgsImV4cCI6MjEwMTE4MDE1OH0.Pjp9yiCI6MEfWCmq1SLfDDPEK3aZOVTFwCB2nw-2sgs"

local headers = {
    ["apikey"] = SUPABASE_KEY,
    ["Authorization"] = "Bearer " .. SUPABASE_KEY,
    ["Content-Type"] = "application/json"
}

local httpRequest = syn and syn.request or http_request or request

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

    local username = LocalPlayer.Name
    local realSheckles = getRealSheckles()

    -- 1. Sync Sheckles (Upsert)
    pcall(function()
        httpRequest({
            Url = SUPABASE_URL .. "User_sheckles?on_conflict=username",
            Method = "POST",
            Headers = {
                ["apikey"] = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                ["Content-Type"] = "application/json",
                ["Prefer"] = "resolution=merge-duplicates"
            },
            Body = HttpService:JSONEncode({
                username = username,
                sheckles = realSheckles
            })
        })
    end)

    -- 2. Sync Status Online (Heartbeat waktu saat ini)
    pcall(function()
        httpRequest({
            Url = SUPABASE_URL .. "User_status?on_conflict=username",
            Method = "POST",
            Headers = {
                ["apikey"] = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                ["Content-Type"] = "application/json",
                ["Prefer"] = "resolution=merge-duplicates"
            },
            Body = HttpService:JSONEncode({
                username = username,
                last_seen = os.date("!%Y-%m-%dT%H:%M:%SZ")
            })
        })
    end)

    -- 3. INVENTORY: Hapus data lama user ini, lalu masukkan yang baru (Full Refresh)
    pcall(function()
        httpRequest({
            Url = SUPABASE_URL .. "Item_monitoring?username=eq." .. username,
            Method = "DELETE",
            Headers = headers
        })
    end)

    local itemsPayload = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:FindFirstChild("Inventory")
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

            local key = cleanName
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

    for _, itemData in pairs(aggregatedItems) do
        table.insert(itemsPayload, itemData)
    end

    if #itemsPayload > 0 then
        pcall(function()
            httpRequest({
                Url = SUPABASE_URL .. "Item_monitoring",
                Method = "POST",
                Headers = headers,
                Body = HttpService:JSONEncode(itemsPayload)
            })
        end)
    end
end

task.spawn(function()
    task.wait(math.random(1, 2))
    scanAndSync()

    while true do
        task.wait(4) -- Update cepat tiap 4 detik
        scanAndSync()
    end
end)
