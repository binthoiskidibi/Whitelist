local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")


local API_URL = "https://4fb4ad48-15f1-4fc1-b136-6fe244fbdc36-00-11xzf7zv4wcky.sisko.replit.dev"
local maxRetries = 3
local retryDelay = 2

local function getHWID()
    return game:GetService("RbxAnalyticsService"):GetClientId()
end

local function verifyKey(key)
    local hwid = getHWID()
    local attempt = 0

    local requestFunc = (syn and syn.request) or (http and http.request) or request or http_request

    while attempt < maxRetries do 
        attempt = attempt + 1
        local success, result = pcall(function()
            local response = requestFunc({
                Url = API_URL .. "/api/verify",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({
                    key = key,
                    hwid = hwid
                })
            })
            
            if response.StatusCode == 200 then
                return HttpService:JSONDecode(response.Body)
            elseif response.StatusCode == 503 then
                error("Service unavailable")
            elseif response.StatusCode == 504 then
                error("Gateway timeout")
            else
                error("Server error: " .. response.StatusCode)
            end
        end)
        
        if success and result then
            if type(result) == "table" then
                return result.success, result.message or "Unknown error"
            end
        else
            print(" Attempt " .. attempt .. " failed: " .. tostring(result))
            if attempt < maxRetries then
                print(" Retrying in " .. retryDelay .. " seconds...")
                task.wait(retryDelay) 
            end
        end
    end 
    
    return false, "Connection timeout - Server not responding after 3 attempts"
end


local key = getgenv().CheckKey
if not key or key == "" then
    Players.LocalPlayer:Kick(" NO KEY PROVIDED\n\nPlease set your key:\ngetgenv().CheckKey = 'YOUR-KEY'")
    getgenv().KeySuccess = false
    return 
end

print(" Verifying key: " .. key)
print(" HWID: " .. getHWID())


local success, message = verifyKey(key)

if success then
    print(" Key verified successfully!")
    getgenv().KeySuccess = true

    return true
else
    print(" Key verification failed: " .. message)
    warn(" Reason: " .. message)
    

    local lowerMsg = message:lower()
    
    if lowerMsg:find("timeout") or lowerMsg:find("connection") or lowerMsg:find("server not responding") then
        warn(" Connection issue detected. Please try again.")
        warn(" If issue persists, contact support.")
    elseif lowerMsg:find("service unavailable") or lowerMsg:find("database not ready") then
        Players.LocalPlayer:Kick(" SERVICE TEMPORARILY UNAVAILABLE\n\nThe verification service is starting up.\n\nPlease wait 30 seconds and try again.")
    elseif lowerMsg:find("hwid mismatch") or lowerMsg:find("another device") or lowerMsg:find("registered to") then
        Players.LocalPlayer:Kick(" HWID VERIFICATION FAILED!\n\n" .. 
            "This key is registered to another device.\n\n" ..
            "To fix this:\n" ..
            "1. Join Discord server\n" ..
            "2. Use /resethwid command\n" ..
            "3. Try again\n\n" ..
            "Error: " .. message)
    elseif lowerMsg:find("not redeemed") then
        Players.LocalPlayer:Kick(" KEY NOT ACTIVATED!\n\n" ..
            "Please redeem this key first:\n" ..
            "1. Join Discord server\n" ..
            "2. Use /redeem <key> command\n" ..
            "3. Try again")
    elseif lowerMsg:find("blacklist") then
        Players.LocalPlayer:Kick(" KEY BLACKLISTED!\n\n" ..
            "This key has been banned.\n" ..
            "Contact support for more information.")
    elseif lowerMsg:find("expired") then
        Players.LocalPlayer:Kick(" KEY EXPIRED!\n\n" ..
            "Your key subscription has ended.\n" ..
            "Please purchase a new key.")
    elseif lowerMsg:find("invalid") or lowerMsg:find("does not exist") then
        Players.LocalPlayer:Kick(" INVALID KEY!\n\n" ..
            "The key you entered does not exist.\n" ..
            "Please check and try again.")
    else
        Players.LocalPlayer:Kick(" VERIFICATION FAILED!\n\n" ..
            "Reason: " .. message .. "\n\n" ..
            "Contact support if issue persists.")
    end
    
    return false
end

