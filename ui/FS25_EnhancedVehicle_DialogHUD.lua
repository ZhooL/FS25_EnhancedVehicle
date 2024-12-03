--
-- Mod: FS25_EnhancedVehicle_DialogHUD
--
-- Author: Majo76
-- email: ls (at) majo76 (dot) de
-- @Date: 01.12.2024
-- @Version: 1.2.0.0

local myName = "FS25_EnhancedVehicle_DialogHUD"

FS25_EnhancedVehicle_DialogHUD = {}
local FS25_EnhancedVehicle_DialogHUD_mt = Class(FS25_EnhancedVehicle_DialogHUD, ScreenElement)

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD.new(target, custom_mt)
  if debug > 1 then print("-> " .. myName .. ": new ") end

  local self = DialogElement.new(target, custom_mt or FS25_EnhancedVehicle_DialogHUD_mt)

  self.vehicle = nil

  return self
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:delete()
  if debug > 1 then print("-> " .. myName .. ": delete ") end
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:setVehicle(vehicle)
  if debug > 1 then print("-> " .. myName .. ": setVehicle ") end

  self.vehicle = vehicle
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:onOpen()
  if debug > 1 then print("-> " .. myName .. ": onOpen ") end

  FS25_EnhancedVehicle_DialogHUD:superClass().onOpen(self)

  self:updateValues()

  g_currentMission.hud:setIsVisible(true)
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:onDraw()
  g_currentMission.hud:setIsVisible(true)
  FS25_EnhancedVehicle.onDraw(self.vehicle, true)
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:updateValues()
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:onClickOk()
  if debug > 1 then print("-> " .. myName .. ": onClickOk ") end

  -- jump out if no vehicle is present
  if self.vehicle == nil then return end

  -- close screen
  g_gui:closeDialogByName("FS25_EnhancedVehicle_DialogHUD")
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:onClickBack()
  if debug > 1 then print("-> " .. myName .. ": onClickBack ") end

  -- close screen
  g_gui:closeDialogByName("FS25_EnhancedVehicle_DialogHUD")
end

function FS25_EnhancedVehicle_DialogHUD:onClickTrackMoveLeft()
  print("left")
  FS25_EnhancedVehicle.onActionCall(self.vehicle, "FS25_EnhancedVehicle_SNAP_TRACKP", -1, 0, 0, 0)
end

function FS25_EnhancedVehicle_DialogHUD:onClickTrackMoveRight()
  print("right")
  FS25_EnhancedVehicle.onActionCall(self.vehicle, "FS25_EnhancedVehicle_SNAP_TRACKP", 1, 0, 0, 0)
end
