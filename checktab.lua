-- ============================================================
--  NAAHUB — SLOT SYSTEM
--  Giới hạn tối đa 20 tab chạy đồng thời
--  Firebase: naahub-default-rtdb.asia-southeast1
-- ============================================================

local FIREBASE_URL = "https://naahub-default-rtdb.asia-southeast1.firebasedatabase.app"
local MAX_SLOTS    = 20
local Http         = game:GetService("HttpService")
local Players      = game:GetService("Players")
local LocalPlayer  = Players.LocalPlayer

-- ID độc nhất cho mỗi tab (userId + thời gian execute)
local mySlotID = tostring(LocalPlayer.UserId) .. "_" .. tostring(math.floor(tick()))

-- ============================================================
--  HÀM NỘI BỘ
-- ============================================================

local function firebaseGet(path)
    local ok, res = pcall(function()
        return request({
            Url    = FIREBASE_URL .. path .. ".json",
            Method = "GET"
        })
    end)
    if not ok or not res or res.StatusCode ~= 200 then return nil end
    local body = res.Body
    if body == "null" then return {} end
    local decoded = pcall(function() return Http:JSONDecode(body) end)
    return Http:JSONDecode(body)
end

local function firebasePut(path, data)
    pcall(function()
        request({
            Url     = FIREBASE_URL .. path .. ".json",
            Method  = "PUT",
            Body    = Http:JSONEncode(data),
            Headers = { ["Content-Type"] = "application/json" }
        })
    end)
end

local function firebaseDelete(path)
    pcall(function()
        request({
            Url    = FIREBASE_URL .. path .. ".json",
            Method = "DELETE"
        })
    end)
end

-- ============================================================
--  DỌN SLOT CŨ (slot bị treo > 30 phút do crash không xóa)
-- ============================================================
local function cleanStaleSlots(slots)
    local now = os.time()
    for slotID, data in pairs(slots) do
        if type(data) == "table" and data.time then
            -- Nếu slot tồn tại quá 30 phút → coi như đã thoát
            if (now - data.time) > 1800 then
                firebaseDelete("/slots/" .. slotID)
                slots[slotID] = nil
            end
        end
    end
    return slots
end

-- ============================================================
--  ĐĂNG KÝ SLOT
-- ============================================================
local function registerSlot()
    local slots = firebaseGet("/slots") or {}

    -- Dọn slot cũ trước
    slots = cleanStaleSlots(slots)

    -- Đếm slot đang active
    local count = 0
    for _ in pairs(slots) do count = count + 1 end

    -- Kiểm tra giới hạn
    if count >= MAX_SLOTS then
        return false, count
    end

    -- Đăng ký slot mới
    firebasePut("/slots/" .. mySlotID, {
        user   = LocalPlayer.Name,
        userID = LocalPlayer.UserId,
        time   = os.time()
    })

    return true, count + 1
end

-- ============================================================
--  GIẢI PHÓNG SLOT KHI THOÁT
-- ============================================================
local function releaseSlot()
    firebaseDelete("/slots/" .. mySlotID)
end

-- Tự xóa khi player rời game
game:GetService("Players").LocalPlayer.AncestryChanged:Connect(function()
    releaseSlot()
end)

-- Backup: xóa khi game close (không phải lúc nào cũng chạy được)
game:BindToClose(function()
    releaseSlot()
end)

-- Heartbeat cập nhật time mỗi 5 phút để slot không bị dọn nhầm
task.spawn(function()
    while task.wait(300) do
        firebasePut("/slots/" .. mySlotID .. "/time", os.time())
    end
end)

-- ============================================================
--  CHẠY KIỂM TRA — GỌI HÀM NÀY ĐẦU SCRIPT
-- ============================================================
local function CheckSlot()
    local ok, currentCount = registerSlot()

    if not ok then
        -- Hiện thông báo lỗi (dùng được với hoặc không có NaaUI)
        local msg = "❌ NaaHub đã đạt giới hạn " .. MAX_SLOTS .. " tab!\n"
                 .. "Hiện tại: " .. currentCount .. "/" .. MAX_SLOTS .. "\n"
                 .. "Vui lòng thử lại sau khi có tab khác đóng."

        -- Nếu có NaaUI thì dùng Notify
        if NaaUI and NaaUI.Notify then
            NaaUI.Notify("Giới Hạn Tab", msg, 10)
        else
            warn(msg)
        end

        error(msg)
        return false
    end

    print("✅ [NaaHub] Slot đã đăng ký | Tab đang active: " .. currentCount .. "/" .. MAX_SLOTS)
    return true
end

return {
    Check   = CheckSlot,    -- gọi đầu script để kiểm tra
    Release = releaseSlot,  -- gọi thủ công nếu cần
    SlotID  = mySlotID,     -- ID của tab này
}
