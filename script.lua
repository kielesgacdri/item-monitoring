-- // Kise Monitoring Script - Final Version
local HttpService = game:GetService("HttpService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local SUPABASE_URL = "https://ixlfaqxeunlkilmzsbmu.supabase.co/rest/v1/"
local SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4bGZhcXhldW5sa2lsbXpzYm11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2MDQxNTgsImV4cCI6MjEwMTE4MDE1OH0.Pjp9yiCI6MEfWCmq1SLfDDPEK3aZOVTFwCB2nw-2sgs"

local headers = {
    ["apikey"] = SUPABASE_KEY,
    ["Authorization"] = "Bearer " .. SUPABASE_KEY,
    ["Content-Type"] = "application/json",
    ["Prefer"] = "resolution=merge-duplicates,return=minimal"
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

    -- 2. Sync Status Online (Heartbeat)
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

    -- 3. Sync Inventory & Fruit (Direct Delete + Insert)
    local itemsPayload = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:FindFirstChild("Inventory")
    local aggregatedItems = {}

    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            local rawName = item.Name
            local cleanName = rawName:gsub("^%s*(.-)%s*$", "%1")
            
            local category = "Seeds"
            local lowerName = cleanName:lower()
            
            if lowerName:find("shovel") or lowerName:find("sprinkler") or lowerName:find("watering can") or lowerName:find("wateringcan") or lowerName:find("trowel") or lowerName:find("pot") or lowerName:find("gear") or lowerName:find("crate") or lowerName:find("sign") or lowerName:find("chest") then
                category = "Gear"
            elseif lowerName:find("gnome") then
                category = "Gnomes"
            elseif lowerName:find("seed pack") or lowerName:find("seedpack") then
                category = "SeedPacks"
            elseif lowerName:find("egg") then
                category = "Eggs"
            end

            local isFruit = lowerName:find("kg") or cleanName:match("%[%s*%d+%.?%d*%s*kg%s*%]") or cleanName:match("%d+%.?%d*%s*kg")
            local finalItemName = cleanName
            if isFruit then
                category = "Fruit"
            end

            local amount = 1
            if item:GetAttribute("Amount") then
                amount = tonumber(item:GetAttribute("Amount")) or 1
            elseif item:GetAttribute("Count") then
                amount = tonumber(item:GetAttribute("Count")) or 1
            elseif item:GetAttribute("Stack") then
                amount = tonumber(item:GetAttribute("Stack")) or 1
            elseif item:GetAttribute("Quantity") then
                amount = tonumber(item:GetAttribute("Quantity")) or 1
            elseif item:FindFirstChild("Amount") then
                amount = tonumber(item.Amount.Value) or 1
            elseif item:FindFirstChild("Count") then
                amount = tonumber(item.Count.Value) or 1
            elseif item:FindFirstChild("Stack") then
                amount = tonumber(item.Stack.Value) or 1
            elseif item:FindFirstChild("Value") then
                amount = tonumber(item.Value) or 1
            else
                local foundNum = cleanName:match("%((%d+)%)") or cleanName:match("x(%d+)")
                if foundNum then
                    amount = tonumber(foundNum) or 1
                end
            end

            amount = math.floor(tonumber(amount) or 1)

            local key = finalItemName
            if aggregatedItems[key] then
                aggregatedItems[key].amount = aggregatedItems[key].amount + amount
            else
                aggregatedItems[key] = {
                    username = tostring(username),
                    item_name = tostring(finalItemName),
                    category = tostring(category),
                    amount = amount
                }
            end
        end
    end

    for _, itemData in pairs(aggregatedItems) do
        table.insert(itemsPayload, itemData)
    end

    -- STEP A: Hapus data inventory lama khusus username ini di Supabase
    pcall(function()
        httpRequest({
            Url = SUPABASE_URL .. "Item_monitoring?username=eq." .. username,
            Method = "DELETE",
            Headers = {
                ["apikey"] = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                ["Content-Type"] = "application/json"
            }
        })
    end)

    task.wait(0.5)

    -- STEP B: Masukkan data inventory baru yang valid saat ini
    if #itemsPayload > 0 then
        pcall(function()
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

    print("[SYNC SUCCESS] Data & Status Online (" .. username .. ") berhasil diperbarui!")
end

task.spawn(function()
    task.wait(math.random(2, 5))
    scanAndSync()

    while true do
        task.wait(20 + math.random(1, 10))
        scanAndSync()
    end
end)
