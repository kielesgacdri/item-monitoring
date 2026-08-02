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

    -- 3. Sync Inventory
    local itemsPayload = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:FindFirstChild("Inventory")
    local aggregatedItems = {}

    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            local itemName = item.Name
            local category = "Seed"
            local lowerName = itemName:lower()
            
            if lowerName:find("sprinkler") or lowerName:find("can") or lowerName:find("trowel") or lowerName:find("pot") or lowerName:find("gear") or lowerName:find("crate") or lowerName:find("sign") or lowerName:find("chest") then
                category = "Gear"
            end

            local amount = 1
            if item:FindFirstChild("Amount") then
                amount = tonumber(item.Amount.Value) or 1
            elseif item:FindFirstChild("Count") then
                amount = tonumber(item.Count.Value) or 1
            elseif item:FindFirstChild("Value") then
                amount = tonumber(item.Value) or 1
            elseif item:FindFirstChild("Stack") then
                amount = tonumber(item.Stack.Value) or 1
            elseif item:GetAttribute("Amount") then
                amount = tonumber(item:GetAttribute("Amount")) or 1
            elseif item:GetAttribute("Count") then
                amount = tonumber(item:GetAttribute("Count")) or 1
            end

            local key = category .. "_" .. itemName
            if aggregatedItems[key] then
                aggregatedItems[key].amount = aggregatedItems[key].amount + amount
            else
                aggregatedItems[key] = {
                    username = username,
                    category = category,
                    item_name = itemName,
                    amount = amount
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
                Url = SUPABASE_URL .. "Item_monitoring?on_conflict=username,category,item_name",
                Method = "POST",
                Headers = headers,
                Body = HttpService:JSONEncode(itemsPayload)
            })
        end)
    end

    print("[SYNC] Data & Status Online (" .. username .. ") berhasil diperbarui!")
end

task.spawn(function()
    while true do
        scanAndSync()
        task.wait(15)
    end
end)
