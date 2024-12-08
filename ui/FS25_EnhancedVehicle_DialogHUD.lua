--
-- Mod: FS25_EnhancedVehicle_DialogHUD
--
-- Author: Majo76
-- email: ls (at) majo76 (dot) de
-- @Date: 08.12.2024
-- @Version: 1.2.0.0

local myName = "FS25_EnhancedVehicle_DialogHUD"

FS25_EnhancedVehicle_DialogHUD = {}
FS25_EnhancedVehicle_DialogHUD.INPUT_CONTEXT_NAME = "FS25_EnhancedVehicle_DialogHUD"

local FS25_EnhancedVehicle_DialogHUD_mt = Class(FS25_EnhancedVehicle_DialogHUD, HUDDisplayElement)

FS25_EnhancedVehicle_DialogHUD.SIZE = {
  DIALOGHUD = { 300, 122 },
}

FS25_EnhancedVehicle_DialogHUD.UV = {
  DIALOGHUD     =     {   0, 128, 300, 122 },
}

FS25_EnhancedVehicle_DialogHUD.POSITION = {
  DIALOGHUD   = { 0, 0 },
  SNAP2       = { 164, 41 },
  TRACK       = {  60, 13 },
  WORKWIDTH   = { 265, 13 },
  HLDISTANCE  = { 265, 40 },
  HLEOF       = { 312, 39 },
  ICON_SNAP   = {  60-10-18, 29 },
  ICON_TRACK  = {  60+10, 29 },
  ICON_HLMODE = { 265-24-18, 29 },
  ICON_HLDIR  = { 265+18, 29 },
  ICON_DIFF   = {   0, 0 },
  ICON_PARK   = {  -2,-2 },
  DMG         = { -15, 5 },
  FUEL        = {  15, 5 },
  MISC        = { 116, 5 },
  RPM         = { -55, -60 },
  TEMP        = {  58, -60 },
  ODO         = {   0, -40 },
}

FS25_EnhancedVehicle_DialogHUD.COLOR = {
  INACTIVE = {    0.7,     0.7,     0.7,    1 },
  ACTIVE   = { 60/255, 118/255,   0/255,    1 },
  BG       = {      0,       0,       0, 0.55 },
}

FS25_EnhancedVehicle_DialogHUD.TEXT_SIZE = {
  SNAP       = 20,
  TRACK      = 12,
  WORKWIDTH  = 12,
  HLDISTANCE = 12,
  HLEOF      = 9,
  DMG        = 12,
  FUEL       = 12,
  MISC       = 13,
  RPM        = 10,
  TEMP       = 10,
  ODO        = 9,
}

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:new(speedMeter, inputBinding, modDirectory)
  if debug > 1 then print("-> " .. myName .. ": new ") end

  local self = setmetatable({}, FS25_EnhancedVehicle_DialogHUD_mt)

  self.speedMeter        = speedMeter
  self.modDirectory      = modDirectory
  self.inputBinding      = inputBinding
  self.vehicle           = nil
  self.uiFilename        = Utils.getFilename("resources/HUD.dds", modDirectory)
  self.isCalculated      = false

  -- for icons
  self.icons = {}
  self.iconIsActive = { snap = nil, track = nil, hlmode = nil, hldir = nil }

  -- for text displays
  self.trackText            = {}

  --[[
  self.default_track_txt     = g_i18n:getText("hud_FS25_EnhancedVehicle_notrack")
  self.default_headland_txt  = g_i18n:getText("hud_FS25_EnhancedVehicle_noheadland")
  self.default_workwidth_txt = g_i18n:getText("hud_FS25_EnhancedVehicle_nowidth")
  self.default_dmg_txt       = g_i18n:getText("hud_FS25_EnhancedVehicle_header_dmg")
  self.default_fuel_txt      = g_i18n:getText("hud_FS25_EnhancedVehicle_header_fuel")
]]
  FS25_EnhancedVehicle_DialogHUD.COLOR.INACTIVE = { unpack(FS25_EnhancedVehicle.hud.colorInactive) }
  FS25_EnhancedVehicle_DialogHUD.COLOR.ACTIVE   = { unpack(FS25_EnhancedVehicle.hud.colorActive) }
  FS25_EnhancedVehicle_DialogHUD.COLOR.STANDBY  = { unpack(FS25_EnhancedVehicle.hud.colorStandby) }

  return self
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:delete()
  if debug > 1 then print("-> " .. myName .. ": delete ") end

  if self.HUDBox ~= nil then
    self.HUDBox:delete()
  end

--[[
  if self.diffBox ~= nil then
    self.diffBox:delete()
  end

  if self.miscBox ~= nil then
    self.miscBox:delete()
  end

  for _, element in pairs(self.bgBoxElements) do
    if self.dmgBox[element] ~= nil then
      self.dmgBox[element]:delete()
    end
    if self.fuelBox[element] ~= nil then
      self.fuelBox[element]:delete()
    end
  end

  if self.parkBox ~= nil then
    self.parkBox:delete()
  end
]]
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:load()
  if debug > 1 then print("-> " .. myName .. ": load ") end

  self:createElements()
  self:setVehicle(nil)
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:createElements()
  if debug > 1 then print("-> " .. myName .. ": createElements ") end

--  print(DebugUtil.printTableRecursively(self, 0, 0, 2))

  -- create our HUD box
  self:createHUDBox()
--[[

  -- create our diff box
  self:createDiffBox()

  -- create our park box
  self:createParkBox()

  -- create our misc box
  self:createMiscBox()

  -- create our damage box
  self:createDamageBox()

  -- create our fuel box
  self:createFuelBox()

  self.marginWidth, self.marginHeight = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.MARGIN)
  _, self.marginElement               = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.MARGINELEMENT)
]]
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:createHUDBox()
  if debug > 1 then print("-> " .. myName .. ": createHUDBox") end

  -- prepare
--  local iconWidth, iconHeight = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.ICONTRACK)
  local boxWidth, boxHeight = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_DialogHUD.SIZE.DIALOGHUD)
  local x = 0
  local y = 0

  -- add background overlay box
  local boxOverlay = Overlay.new(self.uiFilename, x, y, boxWidth, boxHeight)
  boxOverlay.isVisible = true
  self.HUDBox = HUDElement.new(boxOverlay)
  self.HUDBox:setUVs(GuiUtils.getUVs(FS25_EnhancedVehicle_DialogHUD.UV.DIALOGHUD))
  self.HUDBox:setColor(unpack({1,1,1,1}))
--[[
  -- add snap icon
  local iconPosX, iconPosY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.ICON_SNAP)
  self.icons.snap = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_SNAP)
  self.icons.snap:setVisible(true)
  self.icons.snap:setColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.INACTIVE))
  self.trackBox:addChild(self.icons.snap)

  -- add track icon
  local iconPosX, iconPosY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.ICON_TRACK)
  self.icons.track = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_TRACK)
  self.icons.track:setVisible(true)
  self.icons.track:setColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.INACTIVE))
  self.trackBox:addChild(self.icons.track)

  -- add headland mode icons
  local iconPosX, iconPosY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.ICON_HLMODE)
  self.icons.hl1 = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_HL1)
  self.icons.hl1:setVisible(false)
  self.trackBox:addChild(self.icons.hl1)
  self.icons.hl2 = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_HL2)
  self.icons.hl2:setVisible(false)
  self.trackBox:addChild(self.icons.hl2)
  self.icons.hl3 = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_HL3)
  self.icons.hl3:setVisible(false)
  self.trackBox:addChild(self.icons.hl3)

  -- add headland direction icons
  local iconPosX, iconPosY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.ICON_HLDIR)
  self.icons.hlup = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_HLUP)
  self.icons.hlup:setVisible(false)
  self.icons.hlup:setColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.INACTIVE))
  self.trackBox:addChild(self.icons.hlup)
  self.icons.hldown = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_HLDOWN)
  self.icons.hldown:setVisible(false)
  self.icons.hldown:setColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.INACTIVE))
  self.trackBox:addChild(self.icons.hldown)
]]
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:createIcon(baseX, baseY, width, height, uvs)
  if debug > 2 then print("-> " .. myName .. ": createIcon ") end

  local iconOverlay = Overlay.new(self.uiFilename, baseX, baseY, width, height)
  iconOverlay:setUVs(GuiUtils.getUVs(uvs))
  local element = HUDElement.new(iconOverlay)

  element:setVisible(false)

  return element
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:storeScaledValues()
  if debug > 1 then print("-> " .. myName .. ": storeScaledValues ") end

--[[  
  -- overwrite from config file
  FS25_EnhancedVehicle_HUD.TEXT_SIZE.DMG  = FS25_EnhancedVehicle.hud.dmg.fontSize
  FS25_EnhancedVehicle_HUD.TEXT_SIZE.FUEL = FS25_EnhancedVehicle.hud.fuel.fontSize
  FS25_EnhancedVehicle_HUD.COLOR.INACTIVE = { unpack(FS25_EnhancedVehicle.hud.colorInactive) }
  FS25_EnhancedVehicle_HUD.COLOR.ACTIVE   = { unpack(FS25_EnhancedVehicle.hud.colorActive) }
  FS25_EnhancedVehicle_HUD.COLOR.STANDBY  = { unpack(FS25_EnhancedVehicle.hud.colorStandby) }

  -- prepare
  local baseX = self.speedMeter.speedBg.x + self.speedMeter.speedBg.width / 2
  local baseY = self.speedMeter.speedBg.y + self.speedMeter.speedBg.height / 2

  if self.trackBox ~= nil then
    -- some globals
    local boxWidth, boxHeight = self.trackBox:getWidth(), self.trackBox:getHeight()
    local boxPosX = self.speedMeter.speedBg.x -- left border of gauge
    local boxPosY = self.speedMeter.speedBg.y + self.speedMeter.speedBg.height + self.marginElement -- move above gauge and some spacing
    local boxPosY2 = boxPosY

    -- global move of box
    local offX, offY = self.speedMeter:scalePixelToScreenVector({ FS25_EnhancedVehicle.hud.track.offsetX, FS25_EnhancedVehicle.hud.track.offsetY })
    boxPosX = boxPosX + offX
    boxPosY = boxPosY + offY

    self.trackBox:setPosition(boxPosX, boxPosY)

    -- move FS25 fill levels display above our display element
    g_currentMission.hud.fillLevelsDisplay.offsetY = 0
    if FS25_EnhancedVehicle.functionSnapIsEnabled and FS25_EnhancedVehicle.hud.track.enabled and FS25_EnhancedVehicle.hud.track.offsetX == 0 and FS25_EnhancedVehicle.hud.track.offsetY == 0 then
      g_currentMission.hud.fillLevelsDisplay.y = boxPosY + self.trackBox:getHeight() + self.marginElement
    else
      g_currentMission.hud.fillLevelsDisplay.y = boxPosY2 + self.marginElement / 2
    end

    -- snap text
    local textX, textY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.SNAP1)
    self.snapText1.posX = boxPosX + textX
    self.snapText1.posY = boxPosY + textY
    self.snapText1.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.SNAP)

    -- additional snap text
    local textX, textY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.SNAP2)
    self.snapText2.posX = boxPosX + textX
    self.snapText2.posY = boxPosY + textY
    self.snapText2.size = self.snapText1.size

    -- track text
    local textX, textY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.TRACK)
    self.trackText.posX = boxPosX + textX
    self.trackText.posY = boxPosY + textY
    self.trackText.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.TRACK)

    -- workwidth text
    local textX, textY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.WORKWIDTH)
    self.workWidthText.posX = boxPosX + textX
    self.workWidthText.posY = boxPosY + textY
    self.workWidthText.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.WORKWIDTH)

    -- headland distance text
    local textX, textY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.HLDISTANCE)
    self.headlandDistanceText.posX = boxPosX + textX
    self.headlandDistanceText.posY = boxPosY + textY
    self.headlandDistanceText.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.HLDISTANCE)

    -- headland eof text
    local textX, textY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.HLEOF)
    self.headlandEOFText.posX = boxPosX + textX
    self.headlandEOFText.posY = boxPosY + textY
    self.headlandEOFText.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.HLEOF)
  end

  if self.diffBox ~= nil then
    local x = self.speedMeter.speedBg.x -- left border of gauge
    local y = self.speedMeter.speedBg.y + self.speedMeter.speedBg.height - self.diffBox:getHeight() -- move to gauge top border

    -- global move
    local offX, offY = self.speedMeter:scalePixelToScreenVector({ FS25_EnhancedVehicle.hud.diff.offsetX, FS25_EnhancedVehicle.hud.diff.offsetY })
    x = x + offX
    y = y + offY

    self.diffBox:setPosition(x, y)
  end

  self.dmgText.textMarginWidth, self.dmgText.textMarginHeight = self.gameInfoDisplay:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.MARGINDMG)
  self.dmgText.boxMarginWidth, self.dmgText.boxMarginHeight = self.gameInfoDisplay:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.MARGIN)
  if self.dmgBox ~= nil then
    local baseX, baseY = self.gameInfoDisplay:getPosition()
    self.dmgText.posX = baseX
    self.dmgText.posY = baseY - self.gameInfoDisplay.infoBgScale.height - self.marginElement  -- move just below bottom of gameinfodisplay
    self.dmgText.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.DMG)
    -- set fixed dimensions
    self.dmgBox.topleft:setDimension(    self.dmgText.boxMarginWidth, self.dmgText.boxMarginHeight)
    self.dmgBox.topright:setDimension(   self.dmgText.boxMarginWidth, self.dmgText.boxMarginHeight)
    self.dmgBox.bottomleft:setDimension( self.dmgText.boxMarginWidth, self.dmgText.boxMarginHeight)
    self.dmgBox.bottomright:setDimension(self.dmgText.boxMarginWidth, self.dmgText.boxMarginHeight)
  end

  self.fuelText.textMarginWidth, self.fuelText.textMarginHeight = self.gameInfoDisplay:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.MARGINFUEL)
  self.fuelText.boxMarginWidth, self.fuelText.boxMarginHeight = self.gameInfoDisplay:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.MARGIN)
  if self.fuelBox ~= nil then
    local baseX, baseY = self.gameInfoDisplay:getPosition()
    self.fuelText.posX = baseX
    self.fuelText.posY = baseY - self.gameInfoDisplay.infoBgScale.height - self.marginElement  -- move just below bottom of gameinfodisplay
    self.fuelText.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.FUEL)
    -- set fixed dimensions
    self.fuelBox.topleft:setDimension(    self.fuelText.boxMarginWidth, self.fuelText.boxMarginHeight)
    self.fuelBox.topright:setDimension(   self.fuelText.boxMarginWidth, self.fuelText.boxMarginHeight)
    self.fuelBox.bottomleft:setDimension( self.fuelText.boxMarginWidth, self.fuelText.boxMarginHeight)
    self.fuelBox.bottomright:setDimension(self.fuelText.boxMarginWidth, self.fuelText.boxMarginHeight)
  end

  if self.miscBox ~= nil then
    -- some globals
    local boxWidth, boxHeight = self.miscBox:getWidth(), self.miscBox:getHeight()
    local boxPosX = self.speedMeter.speedBg.x
    local boxPosY = self.speedMeter.speedBg.y - boxHeight - self.marginElement

    -- global move
    local offX, offY = self.speedMeter:scalePixelToScreenVector({ FS25_EnhancedVehicle.hud.misc.offsetX, FS25_EnhancedVehicle.hud.misc.offsetY })
    boxPosX = boxPosX + offX
    boxPosY = boxPosY + offY

    self.miscBox:setPosition(boxPosX, boxPosY)

    -- misc text
    local textX, textY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.MISC)
    self.miscText.posX = boxPosX + textX
    self.miscText.posY = boxPosY + textY
    self.miscText.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.MISC)
  end

  -- park box
  if self.parkBox ~= nil then
    -- some globals
    local boxPosX = self.speedMeter.speedBg.x + self.diffBox:getWidth() + self.marginElement / 2
    local boxPosY = self.speedMeter.speedBg.y + self.speedMeter.speedBg.height - self.parkBox:getHeight()

    -- global move
    local offX, offY = self.speedMeter:scalePixelToScreenVector({ FS25_EnhancedVehicle.hud.park.offsetX, FS25_EnhancedVehicle.hud.park.offsetY })
    boxPosX = boxPosX + offX
    boxPosY = boxPosY + offY

    self.parkBox:setPosition(boxPosX, boxPosY)
  end

  -- rpm & temp & odo
  local textX, textY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.RPM)
  self.rpmText.posX = baseX + textX
  self.rpmText.posY = baseY + textY
  self.rpmText.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.RPM)

  local textX, textY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.TEMP)
  self.tempText.posX = baseX + textX
  self.tempText.posY = baseY + textY
  self.tempText.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.TEMP)

  local textX, textY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.ODO)
  self.odoText.posX = baseX + textX
  self.odoText.posY = baseY + textY
  self.odoText.size = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.ODO)
  self.odoText.size2 = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle_HUD.TEXT_SIZE.ODO - 1)
]]
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:setVehicle(vehicle)
  if debug > 2 then print("-> " .. myName .. ": setVehicle ") end

  self.vehicle = vehicle

  if self.HUDBox ~= nil then
    self.HUDBox:setVisible(vehicle ~= nil)
  end
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:hideSomething(vehicle)
  if debug > 2 then print("-> " .. myName .. ": hideSomething ") end

  if vehicle.isClient then
    self.HUDBox:setVisible(false)
  end
end

-- #############################################################################

function FS25_EnhancedVehicle_DialogHUD:drawHUD()
  if debug > 2 then print("-> " .. myName .. ": drawHUD ") end

  -- jump out if we're not ready
  if self.vehicle == nil or not self.speedMeter.isVehicleDrawSafe or g_dedicatedServerInfo ~= nil then return end

  -- jump out if this vehicle does not have the EV spec (e.g. trains)
  if self.vehicle["spec_FS25_EnhancedVehicle.EnhancedVehicle"] == nil then return end

  -- as soon as the game gauge appeared -> update our positions only once
  if self.isCalculated == false then
    self:storeScaledValues()
    self.isCalculated = true
  end

  self.HUDBox:setVisible(true)
  local _w, _h = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_DialogHUD.SIZE.DIALOGHUD)
  self.HUDBox:setPosition(0.5 - _w / 2, 0.15)
--  self.HUDBox:setDimension(_w, _h)
  self.HUDBox.overlay:render()

  -- reset text stuff to "defaults"
  setTextColor(1,1,1,1)
  setTextAlignment(RenderText.ALIGN_LEFT)
  setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
  setTextBold(false)
end

function FS25_EnhancedVehicle_DialogHUD:toggleMouseCursor()
  local isActive = not self.inputBinding:getShowMouseCursor()
  if not self.isCustomInputActive and self.inputBinding:getShowMouseCursor() then
      self.inputBinding:setShowMouseCursor(false)-- always reset
      isActive = false
  end

  self.inputBinding:setShowMouseCursor(isActive)

  if not self.isCustomInputActive and isActive then
      self.inputBinding:setContext(FS25_EnhancedVehicle_DialogHUD.INPUT_CONTEXT_NAME, true, false)

      local _, eventId = self.inputBinding:registerActionEvent(InputAction.PS_TOGGLE_MOUSE_CURSOR, self, self.toggleMouseCursor, false, true, false, true)
      self.inputBinding:setActionEventTextVisibility(eventId, false)

      self.isCustomInputActive = true
  elseif self.isCustomInputActive and not isActive then
      self.inputBinding:removeActionEventsByTarget(self)
      self.inputBinding:revertContext(true) -- revert and clear message context
      self.isCustomInputActive = false
  end

  --Make compatible with IC.
--  if self.vehicle ~= nil then
--      self.vehicle.isMouseActive = isActive
--      local rootVehicle = self.vehicle:getRootVehicle()
--      rootVehicle.isMouseActive = isActive
--  end
end