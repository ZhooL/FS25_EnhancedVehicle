--
-- Mod: FS25_EnhancedVehicle_DialogSettings
--
-- Author: Majo76
-- email: ls (at) majo76 (dot) de
-- @Date: 01.12.2024
-- @Version: 1.2.0.0

local myName = "FS25_EnhancedVehicle_DialogSettings"

FS25_EnhancedVehicle_DialogSettings = {}
local FS25_EnhancedVehicle_DialogSettings_mt = Class(FS25_EnhancedVehicle_DialogSettings, ScreenElement)

local EV_elements_global = { 'snap', 'diff', 'hydraulic', 'parkingBrake', 'odoMeter' }
local EV_elements_HUD = { 'fuel', 'dmg', 'misc', 'rpm', 'temp', 'diff', 'track', 'park', 'odo' }

-- #############################################################################

function FS25_EnhancedVehicle_DialogSettings.new(target, custom_mt)
  if debug > 1 then print("-> " .. myName .. ": new ") end

  local self = DialogElement.new(target, custom_mt or FS25_EnhancedVehicle_DialogSettings_mt)

  self.vehicle = nil

  return self
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogSettings:delete()
  if debug > 1 then print("-> " .. myName .. ": delete ") end
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogSettings:setVehicle(vehicle)
  if debug > 1 then print("-> " .. myName .. ": setVehicle ") end

  self.vehicle = vehicle
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogSettings:onOpen()
  if debug > 1 then print("-> " .. myName .. ": onOpen ") end

  FS25_EnhancedVehicle_DialogSettings:superClass().onOpen(self)

  local modName = "FS25_EnhancedVehicle"

  -- title
  self.guiTitle:setText("Enhanced Vehicle ".. g_EnhancedVehicle.version .. " by Majo76")

  -- reset & reload config buttons
  self.resetConfigButton:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_resetConfigButton"))
  self.reloadConfigButton:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_reloadConfigButton"))

  -- section headers
  self.sectionGlobalFunctions:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_sectionGlobalFunctions"))
  self.sectionHUD:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_sectionHUD"))
  self.sectionSnapSettings:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_sectionSnapSettings"))
  self.sectionHeadlandSettings:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_sectionHeadlandSettings").." "..self.vehicle:getFullName())

  -- global elements
  for _, v in pairs(EV_elements_global) do
    v1 = v.."Title"
    v2 = v.."TT"
    v3 = v.."Setting"
    self[v1]:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_"..v1))
    self[v2]:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_"..v2))
    self[v3]:setTexts({
      g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_on"),
      g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_off")
    })
  end

  -- snap to angle
  self.snapSettingsAngleTitle:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_snapSettingsAngleTitle"))
  self.snapSettingsAngleTT:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_snapSettingsAngleTT"))

  -- visible tracks
  self.visibleTracksTitle:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_visibleTracksTitle"))
  self.visibleTracksTT:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_visibleTracksTT"))
  self.visibleTracksSetting:setTexts({ "1", "3", "5", "7", "9" })

  -- show lines
  self.showLinesTitle:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_showLinesTitle"))
  self.showLinesTT:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_showLinesTT"))
  self.showLinesSetting:setTexts({
    g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_showLinesOption1"),
    g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_showLinesOption2"),
    g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_showLinesOption3"),
    g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_showLinesOption4")
  })

  -- hide lines
  self.hideLinesTitle:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_hideLinesTitle"))
  self.hideLinesTT:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_hideLinesTT"))
  self.hideLinesSetting:setTexts({
    g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_on"),
    g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_off")
  })

  -- hide lines after
  self.hideLinesAfterTitle:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_hideLinesAfterTitle"))
  self.hideLinesAfterTT:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_hideLinesAfterTT"))
  self.hideLinesAfterSetting:setTexts({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" })

  -- headland mode
  self.headlandModeTitle:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandModeTitle"))
  self.headlandModeTT:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandModeTT"))
  self.headlandModeSetting:setTexts({
      g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandModeOption1"),
      g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandModeOption2"),
      g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandModeOption3")
    })
  -- headland distance
  self.headlandDistanceTitle:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandDistanceTitle"))
  self.headlandDistanceTT:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandDistanceTT"))
  local _dists = {}
  local _addtxt = ""
  if self.vehicle.vData.track.workWidth ~= nil then
    _addtxt = " ("..tostring(Round(self.vehicle.vData.track.workWidth, 1)).."m)"
  end
  table.insert(_dists, g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandDistanceOption1").._addtxt)
  for _, d in pairs(FS25_EnhancedVehicle.hl_distances) do
    if d >= 0 then
      table.insert(_dists, tostring(d).."m "..g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandDistanceOptionBefore"))
    else
      table.insert(_dists, tostring(math.abs(d)).."m "..g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandDistanceOptionAfter"))
    end
  end
  self.headlandDistanceSetting:setTexts(_dists)

  -- headland sound trigger distance
  self.headlandSoundTriggerDistanceTitle:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandSoundTriggerDistanceTitle"))
  self.headlandSoundTriggerDistanceTT:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_headlandSoundTriggerDistanceTT"))
  self.headlandSoundTriggerDistanceSetting:setTexts({ "5", "10", "15", "20" })

  -- HUD elements
  for _, v in pairs(EV_elements_HUD) do
    v1 = "HUD"..v.."Title"
    v2 = "HUD"..v.."TT"
    v3 = "HUD"..v.."Setting"
    self[v1]:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_"..v1))
    self[v2]:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_"..v2))
    self[v3]:setTexts({
      g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_on"),
      g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_off")
    })
  end

  -- HUD dmg display mode
  self.HUDdmgAmountLeftTitle:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_HUDdmgAmountLeftTitle"))
  self.HUDdmgAmountLeftTT:setText(g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_HUDdmgAmountLeftTT"))
  self.HUDdmgAmountLeftSetting:setTexts({
      g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_HUDdmgAmountLeftO1"),
      g_i18n.modEnvironments[modName]:getText("ui_FS25_EnhancedVehicle_HUDdmgAmountLeftO2")
    })

  self:updateValues()
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogSettings:updateValues()
  -- global elements
  for _, v in pairs(EV_elements_global) do
    v3 = v.."Setting"
    self[v3]:setState(lC:getConfigValue("global.functions", v.."IsEnabled") and 1 or 2)
  end

  -- HUD elements
  for _, v in pairs(EV_elements_HUD) do
    v3 = "HUD"..v.."Setting"
    self[v3]:setState(lC:getConfigValue("hud."..v, "enabled") and 1 or 2)
  end

  -- snap to angle
  self.snapSettingsAngleValue:setText(tostring(lC:getConfigValue("snap", "snapToAngle")))

  -- visible tracks
  local _state = (lC:getConfigValue("track", "numberOfTracks") + 1) / 2
  self.visibleTracksSetting:setState(_state)

  -- show lines
  self.showLinesSetting:setState(lC:getConfigValue("track", "showLines"))

  -- hide lines
  self.hideLinesSetting:setState(lC:getConfigValue("track", "hideLines") and 1 or 2)

  -- hide lines after
  self.hideLinesAfterSetting:setState(lC:getConfigValue("track", "hideLinesAfter"))

  -- headland mode
  self.headlandModeSetting:setState(self.vehicle.vData.track.headlandMode)

  -- headland distance
  local _state = 0
  if self.vehicle.vData.track.headlandDistance == 9999 then --self.vehicle.vData.track.workWidth then
    _state = 1
  end
  local _i = 2
  for _, d in pairs(FS25_EnhancedVehicle.hl_distances) do
    if self.vehicle.vData.track.headlandDistance == d then
      _state = _i
    end
    _i = _i + 1
  end
  self.headlandDistanceSetting:setState(_state)

  -- headland sound trigger distance
  self.headlandSoundTriggerDistanceSetting:setState(Between(Round(lC:getConfigValue("track", "headlandSoundTriggerDistance") / 5, 0), 1, 4))

  -- HUD dmg display mode
  self.HUDdmgAmountLeftSetting:setState(lC:getConfigValue("hud.dmg", "showAmountLeft") and 1 or 2)
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogSettings:onClickOk()
  if debug > 1 then print("-> " .. myName .. ": onClickOk ") end

  -- jump out if no vehicle is present
  if self.vehicle == nil then return end

  local state

  -- global functions
  for _, v in pairs(EV_elements_global) do
    v1 = v.."Setting"
    state = self[v1]:getState() == 1
    lC:setConfigValue("global.functions", v.."IsEnabled", state)
  end

  -- HUD
  for _, v in pairs(EV_elements_HUD) do
    v1 = "HUD"..v.."Setting"
    state = self[v1]:getState() == 1
    lC:setConfigValue("hud."..v, "enabled", state)
  end

  -- HUD dmg display
  state = self.HUDdmgAmountLeftSetting:getState() == 1
  lC:setConfigValue("hud.dmg", "showAmountLeft", state)

  -- snapto angle
  local n = tonumber(self.snapSettingsAngleValue:getText())
  if n ~= nil then
    if n <= 0 then n = 1 end
    if n > 90 then n = 90 end
  else
    n = 10
  end
  lC:setConfigValue("snap", "snapToAngle", n)

  -- visible tracks
  local _state = self.visibleTracksSetting:getState() * 2 - 1
  lC:setConfigValue("track", "numberOfTracks", _state)

  -- show lines
  state = Between(self.showLinesSetting:getState(), 1, 4)
  lC:setConfigValue("track", "showLines", state)

  -- hide lines
  state = self.hideLinesSetting:getState() == 1
  lC:setConfigValue("track", "hideLines", state)

  -- hide lines after
  state = self.hideLinesAfterSetting:getState()
  lC:setConfigValue("track", "hideLinesAfter", state)

  -- headland mode
  self.vehicle.vData.track.headlandMode = self.headlandModeSetting:getState()

  -- headland distance
  local _state = self.headlandDistanceSetting:getState()
  self.vehicle.vData.track.headlandDistance = 0
  if _state == 1 then
    self.vehicle.vData.track.headlandDistance = 9999
  end
  local _i = 2
  for _, d in pairs(FS25_EnhancedVehicle.hl_distances) do
    if _state == _i then
      self.vehicle.vData.track.headlandDistance = d
    end
    _i = _i + 1
  end

  -- headland sound trigger distance
  state = self.headlandSoundTriggerDistanceSetting:getState()
  lC:setConfigValue("track", "headlandSoundTriggerDistance", state * 5)

  -- write and update our config
  lC:writeConfig()
  FS25_EnhancedVehicle:activateConfig()

  -- update HUD
  FS25_EnhancedVehicle.ui_hud:storeScaledValues(true)

  -- close screen
  g_gui:closeDialogByName("FS25_EnhancedVehicle_DialogSettings")
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogSettings:onClickBack()
  if debug > 1 then print("-> " .. myName .. ": onClickBack ") end

  -- close screen
  g_gui:closeDialogByName("FS25_EnhancedVehicle_DialogSettings")
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogSettings:onClickResetConfig()
  if debug > 1 then print("-> " .. myName .. ": onClickResetConfig ") end

  FS25_EnhancedVehicle:resetConfig()
  lC:writeConfig()
  FS25_EnhancedVehicle:activateConfig()

  self:updateValues()
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogSettings:onClickReloadConfig(p1)
  if debug > 1 then print("-> " .. myName .. ": onClickReloadConfig ") end

  lC:readConfig()
  FS25_EnhancedVehicle:activateConfig()

  self:updateValues()
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogSettings:onTextChanged_SnapAngle(_, text)
  local n = tonumber(text)
  if n ~= nil then
    if n < 0 then n = 10 end
    if n > 90 then n = 90 end
  else
    n = ""
  end

  self.snapSettingsAngleValue:setText(tostring(n))
end
