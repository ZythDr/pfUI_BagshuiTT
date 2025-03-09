-- Simple standalone addon to anchor tooltips to Bagshui's bags frame
-- Makes tooltips appear at the top of Bagshui's bag frame when it's open

local BagshuiTT = CreateFrame("Frame", "pfUI_BagshuiTT")
BagshuiTT.isInitialized = false
BagshuiTT.cachedFrame = nil -- Store the last found frame
BagshuiTT.cacheTime = 0   -- When the cache was last updated

-- Debug function - rewritten for efficiency
local function debug(msg)
    if BagshuiTT.debugMode then 
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BagshuiTT]:|r " .. msg)
    end
end

-- Helper function to get Bagshui frame ONLY IF IT'S VISIBLE
-- Uses caching to minimize performance impact
function BagshuiTT:GetBagshuiFrame()
    -- Use cached frame if recent (within 0.1 second)
    -- This avoids multiple lookups during the same frame
    if self.cachedFrame and (GetTime() - self.cacheTime) < 0.1 then
        -- Ensure the cached frame is still valid and visible
        if self.cachedFrame.IsShown and self.cachedFrame:IsShown() then
            return self.cachedFrame
        end
    end
    
    local frame = nil
    
    -- Look for Bagshui frame through various possible paths
    -- First check the most commonly found paths for efficiency
    if Bagshui and Bagshui.components and Bagshui.components.Bags then
        if Bagshui.components.Bags.uiFrame then
            frame = Bagshui.components.Bags.uiFrame
        elseif Bagshui.components.Bags.window then
            frame = Bagshui.components.Bags.window
        end
    end
    
    -- Fall back to direct global lookup if needed
    if not frame and getglobal("BagshuiBagsFrame") then
        frame = getglobal("BagshuiBagsFrame")
    end
    
    -- Make sure the frame is valid and visible
    if frame and frame.IsShown and frame:IsShown() then
        -- Cache the successful result for better performance
        self.cachedFrame = frame
        self.cacheTime = GetTime()
        return frame
    end
    
    -- No visible frame found - clear the cache
    self.cachedFrame = nil
    return nil
end

-- Hook GameTooltip's SetPoint method to change tooltip positioning
-- This only affects tooltips when they are being created
function BagshuiTT:HookGameTooltipSetPoint()
    -- Store the original SetPoint function
    if not GameTooltip.original_SetPoint then
        GameTooltip.original_SetPoint = GameTooltip.SetPoint
    end
    
    -- Replace SetPoint with our own function
    GameTooltip.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
        -- Skip our code for item tooltips (most tooltips in the game)
        -- This improves performance for the majority of tooltips
        if self:GetAnchorType() ~= "ANCHOR_NONE" then
            return GameTooltip.original_SetPoint(self, point, relativeTo, relativePoint, x, y)
        end
        
        -- Check if Bagshui is visible ONLY when positioning a tooltip
        -- This on-demand check is CPU-friendly
        local bagshuiFrame = BagshuiTT:GetBagshuiFrame()
        if bagshuiFrame then
            -- Bagshui is visible, position tooltip at its top
            self:ClearAllPoints()
            return GameTooltip.original_SetPoint(self, "BOTTOMRIGHT", bagshuiFrame, "TOPRIGHT", 
                BagshuiTT:GetSetting("offsetX"), BagshuiTT:GetSetting("offsetY"))
        end
        
        -- Bagshui not visible, use original positioning
        return GameTooltip.original_SetPoint(self, point, relativeTo, relativePoint, x, y)
    end
    
    debug("Successfully hooked GameTooltip.SetPoint")
end

-- Settings management functions
function BagshuiTT:SetupConfig()
    -- Create config table if it doesn't exist
    if not pfUI_BagshuiTT_Config then
        pfUI_BagshuiTT_Config = {
            offsetX = 0,     -- Default horizontal offset 
            offsetY = 10     -- Default vertical offset
        }
    end
end

-- Get a setting with default fallback
function BagshuiTT:GetSetting(key)
    if not pfUI_BagshuiTT_Config then
        self:SetupConfig()
    end
    
    return pfUI_BagshuiTT_Config[key]
end

-- Save a setting
function BagshuiTT:SaveSetting(key, value)
    if not pfUI_BagshuiTT_Config then
        self:SetupConfig()
    end
    
    pfUI_BagshuiTT_Config[key] = value
end

-- Add slash commands to adjust positioning offsets
function BagshuiTT:InitializeSlashCommands()
    SLASH_BAGSHUITT1 = "/btt"
    SlashCmdList["BAGSHUITT"] = function(msg)
        -- Parse the command using Lua 5.0 compatible methods
        local params = {}
        for param in string.gfind(msg, "%S+") do
            table.insert(params, param)
        end
        
        local cmd = string.lower(params[1] or "")
        local arg1 = params[2]
        local arg2 = params[3]
        
        if cmd == "offset" then
            -- Set offsets - format: /btt offset x y
            local x = tonumber(arg1)
            local y = tonumber(arg2)
            
            if x and y then
                -- Set and save new offsets
                BagshuiTT:SaveSetting("offsetX", x)
                BagshuiTT:SaveSetting("offsetY", y)
                -- Clear the cache to ensure next tooltip uses new offset
                BagshuiTT.cachedFrame = nil
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BagshuiTT]:|r Offset set to X: " .. x .. ", Y: " .. y)
            else
                -- Show current offsets
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BagshuiTT]:|r Current offset - X: " .. 
                    BagshuiTT:GetSetting("offsetX") .. ", Y: " .. BagshuiTT:GetSetting("offsetY"))
            end
        elseif cmd == "debug" then
            -- Toggle debug mode
            BagshuiTT.debugMode = not BagshuiTT.debugMode
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BagshuiTT]:|r Debug mode " .. (BagshuiTT.debugMode and "enabled" or "disabled"))
        else
            -- Show help
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BagshuiTT]:|r Commands:")
            DEFAULT_CHAT_FRAME:AddMessage("  /btt offset x y - Set tooltip position offset")
            DEFAULT_CHAT_FRAME:AddMessage("  /btt debug - Toggle debug mode")
        end
    end
end

-- Initialize addon
function BagshuiTT:Initialize()
    if self.isInitialized then return end
    
    -- Setup saved configuration
    self:SetupConfig()
    
    -- Set up slash commands
    self:InitializeSlashCommands()
    
    -- Hook GameTooltip's SetPoint method for future tooltips
    self:HookGameTooltipSetPoint()
    
    self.isInitialized = true
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BagshuiTT]:|r Addon loaded. Type /btt for commands.")
end

-- Register for events needed for initialization
BagshuiTT:RegisterEvent("ADDON_LOADED")
BagshuiTT:RegisterEvent("PLAYER_LOGIN")
BagshuiTT:RegisterEvent("VARIABLES_LOADED")

-- WoW 1.12.1 style event handling
-- This ensures the addon initializes properly even if Bagshui loads after us
BagshuiTT:SetScript("OnEvent", function()
    -- Load saved variables as soon as they're available
    if event == "VARIABLES_LOADED" then
        BagshuiTT:SetupConfig()
    end
    
    -- Try to initialize if Bagshui is already loaded
    if Bagshui and not BagshuiTT.isInitialized then
        BagshuiTT:Initialize()
    elseif event == "PLAYER_LOGIN" and not BagshuiTT.isInitialized then
        -- Periodic check for Bagshui if we still haven't initialized
        local checkFrame = CreateFrame("Frame")
        local checkTime = 0
        local checkInterval = 30  -- Check every 30 frames (about 1 second)
        local nextCheck = checkInterval
        
        checkFrame:SetScript("OnUpdate", function()
            checkTime = checkTime + 1
            
            -- Stop checking once we're initialized
            if BagshuiTT.isInitialized then
                checkFrame:SetScript("OnUpdate", nil)
                return
            end
            
            -- Time out after about 5 seconds
            if checkTime > 100 then 
                BagshuiTT:Initialize()  -- Try anyway
                checkFrame:SetScript("OnUpdate", nil)
            elseif checkTime >= nextCheck then 
                -- Check periodically for Bagshui
                nextCheck = checkTime + checkInterval
                if Bagshui then
                    BagshuiTT:Initialize()
                    checkFrame:SetScript("OnUpdate", nil)
                end
            end
        end)
    end
end)