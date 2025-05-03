--
-- Mod: FS25_EnhancedVehicle_HUD
--
-- Author: Majo76
-- email: ls (at) majo76 (dot) de
-- @Date: 03.05.2025
-- @Version: 1.1.5.0

local myName = "FS25_EnhancedVehicle_HUD"

FS25_EnhancedVehicle_HUD = {}
local FS25_EnhancedVehicle_HUD_mt = Class(FS25_EnhancedVehicle_HUD, HUDDisplayElement)

FS25_EnhancedVehicle_HUD.SIZE = {
  TRACKBOX      = { 328, 50 },
  DIFFBOX       = {  24, 40 },
  PARKBOX       = {  20, 20 },
  MISCBOX       = { 232, 20 },
  DMGBOX        = { 200, 40 },
  ICONTRACK     = {  18, 18 },
  ICONDIFF      = {  24, 40 },
  ICONPARK      = {  24, 24 },
  MARGIN        = {   8,  8 },
  MARGINDMG     = {   5,  5 },
  MARGINFUEL    = {   5,  5 },
  MARGINELEMENT = {   5,  5 },
}

FS25_EnhancedVehicle_HUD.UV = {
  BGTRACK     =       {   0,  0, 300, 50 },
  BGDIFF      =       { 384,  0,  32, 64 },
  BGMISC      =       { 544,  0, 200, 20 },
  BGDMG       =       { 544, 20, 200, 44 },
  BGPARK      =       { 353,  0,  30, 32 },
  ICON_SNAP   =       {   0, 64,  64, 64 },
  ICON_TRACK  =       {  64, 64,  64, 64 },
  ICON_HL1    =       { 128, 64,  64, 64 },
  ICON_HL2    =       { 192, 64,  64, 64 },
  ICON_HL3    =       { 256, 64,  64, 64 },
  ICON_HLUP   =       { 320, 64,  64, 64 },
  ICON_HLDOWN =       { 384, 64,  64, 64 },
  ICON_DBG    =       { 416,  0,  32, 64 },
  ICON_DDM    =       { 448,  0,  32, 64 },
  ICON_DFRONT =       { 480,  0,  32, 64 },
  ICON_DBACK  =       { 512,  0,  32, 64 },
  ICON_PARK   =       { 352, 32,  32, 32 },
  BGBOX_TOPLEFT     = { 544, 64,   8,  8 },
  BGBOX_TOPRIGHT    = { 736, 64,   8,  8 },
  BGBOX_BOTTOMLEFT  = { 544, 86,   8,  8 },
  BGBOX_BOTTOMRIGHT = { 736, 86,   8,  8 },
  BGBOX_SCALE       = { 552, 64, 184, 30 },
  BGBOX_LEFT        = { 544, 64+8, 8, 10 },
  BGBOX_RIGHT       = { 736, 64+8, 8, 10 },
}

FS25_EnhancedVehicle_HUD.POSITION = {
  SNAP1       = { 164, 14 },
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

FS25_EnhancedVehicle_HUD.COLOR = {
  INACTIVE = {    0.7,     0.7,     0.7,    1 },
  ACTIVE   = { 60/255, 118/255,   0/255,    1 },
  BG       = {      0,       0,       0, 0.55 },
}

FS25_EnhancedVehicle_HUD.TEXT_SIZE = {
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

local dmg_txt

-- #############################################################################

function FS25_EnhancedVehicle_HUD:new(speedMeter, gameInfoDisplay, modDirectory)
  if debug > 1 then print("-> " .. myName .. ": new ") end

  local self = setmetatable({}, FS25_EnhancedVehicle_HUD_mt)

  self.speedMeter        = speedMeter
  self.gameInfoDisplay   = gameInfoDisplay
  self.modDirectory      = modDirectory
  self.vehicle           = nil
  self.uiFilename        = Utils.getFilename("resources/HUD.dds", modDirectory)
  self.isCalculated      = false

  -- for icons
  self.icons = {}
  self.iconIsActive = { snap = nil, track = nil, hlmode = nil, hldir = nil }

  -- for text displays
  self.snapText1            = {}
  self.snapText2            = {}
  self.trackText            = {}
  self.headlandText         = {}
  self.headlandEOFText      = {}
  self.workWidthText        = {}
  self.headlandDistanceText = {}
  self.dmgText              = {}
  self.fuelText             = {}
  self.miscText             = {}
  self.rpmText              = {}
  self.tempText             = {}
  self.odoText              = {}

  self.default_track_txt     = g_i18n:getText("hud_FS25_EnhancedVehicle_notrack")
  self.default_headland_txt  = g_i18n:getText("hud_FS25_EnhancedVehicle_noheadland")
  self.default_workwidth_txt = g_i18n:getText("hud_FS25_EnhancedVehicle_nowidth")
  self.default_dmg_txt       = g_i18n:getText("hud_FS25_EnhancedVehicle_header_dmg")
  self.default_fuel_txt      = g_i18n:getText("hud_FS25_EnhancedVehicle_header_fuel")

  FS25_EnhancedVehicle_HUD.COLOR.INACTIVE = { unpack(FS25_EnhancedVehicle.hud.colorInactive) }
  FS25_EnhancedVehicle_HUD.COLOR.ACTIVE   = { unpack(FS25_EnhancedVehicle.hud.colorActive) }
  FS25_EnhancedVehicle_HUD.COLOR.STANDBY  = { unpack(FS25_EnhancedVehicle.hud.colorStandby) }

  self.bgBoxElements = { "topleft", "topright", "bottomleft", "bottomright", "scale", "left", "right" }

  -- for tracking how many progress bars are visible
  FS25_EnhancedVehicle_HUD.numberProgessBars = 0

  -- hook into some original HUD functions
  g_currentMission.hud.sideNotifications.markProgressBarForDrawing = Utils.appendedFunction(g_currentMission.hud.sideNotifications.markProgressBarForDrawing, FS25_EnhancedVehicle_HUD.markProgressBarForDrawing)

  return self
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:delete()
  if debug > 1 then print("-> " .. myName .. ": delete ") end

  if self.trackBox ~= nil then
    self.trackBox:delete()
  end

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
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:load()
  if debug > 1 then print("-> " .. myName .. ": load ") end

  self:createElements()
  self:setVehicle(nil)
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:createElements()
  if debug > 1 then print("-> " .. myName .. ": createElements ") end

--  print(DebugUtil.printTableRecursively(self, 0, 0, 2))

  -- create our track box
  self:createTrackBox()

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
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:createTrackBox()
  if debug > 1 then print("-> " .. myName .. ": createTrackBox") end

  -- prepare
  local iconWidth, iconHeight = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.ICONTRACK)
  local boxWidth, boxHeight = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.TRACKBOX)
  local x = 0
  local y = 0

  -- add background overlay box
  local boxOverlay = Overlay.new(self.uiFilename, x, y, boxWidth, boxHeight)
  boxOverlay.isVisible = true
  self.trackBox = HUDElement.new(boxOverlay)
  self.trackBox:setUVs(GuiUtils.getUVs(FS25_EnhancedVehicle_HUD.UV.BGTRACK))
  self.trackBox:setColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.BG))

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
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:createDiffBox()
  if debug > 1 then print("-> " .. myName .. ": createDiffBox ") end

  -- prepare
  local iconWidth, iconHeight = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.ICONDIFF)
  local boxWidth, boxHeight = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.DIFFBOX)
  local x = 0
  local y = 0

  -- add background overlay box
  local boxOverlay = Overlay.new(self.uiFilename, x, y, boxWidth, boxHeight)
  local boxElement = HUDElement.new(boxOverlay)
  self.diffBox = boxElement
  self.diffBox:setUVs(GuiUtils.getUVs(FS25_EnhancedVehicle_HUD.UV.BGDIFF))
  self.diffBox:setColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.BG))
  self.diffBox:setVisible(false)

  -- add diff icons
  local iconPosX, iconPosY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.ICON_DIFF)
  self.icons.diff_bg = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_DBG)
  self.icons.diff_bg:setVisible(true)
  self.icons.diff_bg:setColor(0, 0, 0, 1)
  self.diffBox:addChild(self.icons.diff_bg)
  self.icons.diff_dm = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_DDM)
  self.icons.diff_dm:setVisible(true)
  self.diffBox:addChild(self.icons.diff_dm)
  self.icons.diff_front = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_DFRONT)
  self.icons.diff_front:setVisible(true)
  self.diffBox:addChild(self.icons.diff_front)
  self.icons.diff_back = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_DBACK)
  self.icons.diff_back:setVisible(true)
  self.diffBox:addChild(self.icons.diff_back)
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:createParkBox()
  if debug > 1 then print("-> " .. myName .. ": createParkBox ") end

  -- prepare
  local iconWidth, iconHeight = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.ICONPARK)
  local boxWidth, boxHeight = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.PARKBOX)
  local x = 0
  local y = 0

  -- add background overlay box
  local boxOverlay = Overlay.new(self.uiFilename, x, y, boxWidth, boxHeight)
  local boxElement = HUDElement.new(boxOverlay)
  self.parkBox = boxElement
  self.parkBox:setUVs(GuiUtils.getUVs(FS25_EnhancedVehicle_HUD.UV.BGPARK))
  self.parkBox:setColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.BG))
  self.parkBox:setVisible(false)

  -- add park icon
  local iconPosX, iconPosY = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.POSITION.ICON_PARK)
  self.icons.park = self:createIcon(x + iconPosX, y + iconPosY, iconWidth, iconHeight, FS25_EnhancedVehicle_HUD.UV.ICON_PARK)
  self.icons.park:setVisible(true)
  self.parkBox:addChild(self.icons.park)
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:createMiscBox()
  if debug > 1 then print("-> " .. myName .. ": createMiscBox ") end

  -- prepare
  local boxWidth, boxHeight = self.speedMeter:scalePixelToScreenVector(FS25_EnhancedVehicle_HUD.SIZE.MISCBOX)

  -- add background overlay box
  local boxOverlay = Overlay.new(self.uiFilename, 0, 0, boxWidth, boxHeight)
  local boxElement = HUDElement.new(boxOverlay)
  self.miscBox = boxElement
  self.miscBox:setUVs(GuiUtils.getUVs(FS25_EnhancedVehicle_HUD.UV.BGMISC))
  self.miscBox:setColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.BG))
  self.miscBox:setVisible(false)
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:createDamageBox()
  if debug > 1 then print("-> " .. myName .. ": createDamageBox ") end

  -- create single elements of box
  self.dmgBox = {}
  for _, element in pairs(self.bgBoxElements) do
    local boxOverlay = Overlay.new(self.uiFilename, 0, 0, 1, 1)
    local boxElement = HUDElement.new(boxOverlay)
    self.dmgBox[element] = boxElement
    self.dmgBox[element]:setUVs(GuiUtils.getUVs(FS25_EnhancedVehicle_HUD.UV["BGBOX_"..string.upper(element)]))
    self.dmgBox[element]:setColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.BG))
    self.dmgBox[element]:setVisible(false)
  end

end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:createFuelBox()
  if debug > 1 then print("-> " .. myName .. ": createFuelBox ") end

  -- create single elements of box
  self.fuelBox = {}
  for _, element in pairs(self.bgBoxElements) do
    local boxOverlay = Overlay.new(self.uiFilename, 0, 0, 1, 1)
    local boxElement = HUDElement.new(boxOverlay)
    self.fuelBox[element] = boxElement
    self.fuelBox[element]:setUVs(GuiUtils.getUVs(FS25_EnhancedVehicle_HUD.UV["BGBOX_"..string.upper(element)]))
    self.fuelBox[element]:setColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.BG))
    self.fuelBox[element]:setVisible(false)
  end
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:createIcon(baseX, baseY, width, height, uvs)
  if debug > 2 then print("-> " .. myName .. ": createIcon ") end

  local iconOverlay = Overlay.new(self.uiFilename, baseX, baseY, width, height)
  iconOverlay:setUVs(GuiUtils.getUVs(uvs))
  local element = HUDElement.new(iconOverlay)

  element:setVisible(false)

  return element
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:storeScaledValues()
  if debug > 1 then print("-> " .. myName .. ": storeScaledValues ") end

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
      if (FS25_EnhancedVehicle.hud.track.moveFillLevelsDisplayDeltaY ~= 0) then
        local offY = self.speedMeter:scalePixelToScreenHeight(FS25_EnhancedVehicle.hud.track.moveFillLevelsDisplayDeltaY)
        g_currentMission.hud.fillLevelsDisplay.y = g_currentMission.hud.fillLevelsDisplay.y + offY
      end
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
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:setVehicle(vehicle)
  if debug > 2 then print("-> " .. myName .. ": setVehicle ") end

  self.vehicle = vehicle

  if self.trackBox ~= nil then
    self.trackBox:setVisible(vehicle ~= nil)
  end
  if self.diffBox ~= nil then
    self.diffBox:setVisible(vehicle ~= nil)
  end
  if self.miscBox ~= nil then
    self.miscBox:setVisible(vehicle ~= nil)
  end
  if self.dmgBox ~= nil then
    for _, element in pairs(self.bgBoxElements) do
      self.dmgBox[element]:setVisible(vehicle ~= nil)
    end
  end
  if self.fuelBox ~= nil then
    for _, element in pairs(self.bgBoxElements) do
      self.fuelBox[element]:setVisible(vehicle ~= nil)
    end
  end
  if self.parkBox ~= nil then
    self.parkBox:setVisible(vehicle ~= nil)
  end
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:hideSomething(vehicle)
  if debug > 2 then print("-> " .. myName .. ": hideSomething ") end

  if vehicle.isClient then
    self.trackBox:setVisible(false)
    self.diffBox:setVisible(false)
    self.miscBox:setVisible(false)
    for _, element in pairs(self.bgBoxElements) do
      self.dmgBox[element]:setVisible(false)
      self.fuelBox[element]:setVisible(false)
    end
    self.parkBox:setVisible(false)
  end
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:drawHUD()
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

  -- should an element be visible at all?
  if not FS25_EnhancedVehicle.functionSnapIsEnabled then
    self.trackBox:setVisible(false)
  else
    self.trackBox:setVisible(FS25_EnhancedVehicle.hud.track.enabled == true)
    self.trackBox.overlay:render()
  end

  if not FS25_EnhancedVehicle.functionDiffIsEnabled then
    self.diffBox:setVisible(false)
  else
    self.diffBox:setVisible(FS25_EnhancedVehicle.hud.diff.enabled == true)
    self.diffBox.overlay:render()
  end

  if not FS25_EnhancedVehicle.functionParkingBrakeIsEnabled then
    self.parkBox:setVisible(false)
  else
    self.parkBox:setVisible(FS25_EnhancedVehicle.hud.park.enabled == true)
    self.parkBox.overlay:render()
  end

  for _, element in pairs(self.bgBoxElements) do
    self.dmgBox[element]:setVisible(FS25_EnhancedVehicle.hud.dmg.enabled == true)
    self.dmgBox[element].overlay:render()
    self.fuelBox[element]:setVisible(FS25_EnhancedVehicle.hud.fuel.enabled == true)
    self.fuelBox[element].overlay:render()
  end

  self.miscBox:setVisible(FS25_EnhancedVehicle.hud.misc.enabled == true)
  self.miscBox.overlay:render()

  -- draw our track HUD
  if self.trackBox:getVisible() then
    -- snap icon
    local color = FS25_EnhancedVehicle_HUD.COLOR.INACTIVE
    if self.vehicle.vData.is[5] then
      color = FS25_EnhancedVehicle_HUD.COLOR.ACTIVE
    elseif self.vehicle.vData.opMode == 1 then
      color = FS25_EnhancedVehicle_HUD.COLOR.STANDBY
    end
    self.icons.snap:setColor(unpack(color))
    self.icons.snap.overlay:render()

    -- track icon
    local color = FS25_EnhancedVehicle_HUD.COLOR.INACTIVE
    if self.vehicle.vData.is[6] then
      color = FS25_EnhancedVehicle_HUD.COLOR.ACTIVE
    elseif self.vehicle.vData.opMode == 2 then
      color = FS25_EnhancedVehicle_HUD.COLOR.STANDBY
    end
    self.icons.track:setColor(unpack(color))
    self.icons.track.overlay:render()

    -- without usable track data -> hide icons
    if not self.vehicle.vData.track.isCalculated then
      self.icons.hl1:setVisible(false)
      self.icons.hl2:setVisible(false)
      self.icons.hl3:setVisible(false)
      self.icons.hlup:setVisible(false)
      self.icons.hldown:setVisible(false)
    else
      -- headland mode icon
      local _b1, _b2, _b3 = false, false, false
      if self.vehicle.vData.track.headlandMode == 1 then
        _b1 = true
      elseif self.vehicle.vData.track.headlandMode == 2 then
        _b2 = true
      elseif self.vehicle.vData.track.headlandMode == 3 then
        _b3 = true
      end
      self.icons.hl1:setVisible(_b1)
      self.icons.hl2:setVisible(_b2)
      self.icons.hl3:setVisible(_b3)
      self.icons.hl1.overlay:render()
      self.icons.hl2.overlay:render()
      self.icons.hl3.overlay:render()

      -- headland distance icon
      local distance = self.vehicle.vData.track.headlandDistance
      if distance == 9999 and self.vehicle.vData.track.workWidth ~= nil then
        distance = self.vehicle.vData.track.workWidth
      end
      if distance >= 0 then
        self.icons.hlup:setVisible(true)
        self.icons.hldown:setVisible(false)
      else
        self.icons.hlup:setVisible(false)
        self.icons.hldown:setVisible(true)
      end
      self.icons.hlup.overlay:render()
      self.icons.hldown.overlay:render()
    end

    -- snap degree display
    if self.vehicle.vData.rot ~= nil then
      setTextAlignment(RenderText.ALIGN_CENTER)
      setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
      setTextBold(true)

      local degree_vrot = NormalizeAngle(180 + self.vehicle.vData.rot)
      local snap_txt = string.format("%.1f°", degree_vrot)
      local snap_txt2 = nil

      if self.vehicle.vData.is[5] then
        local degree = NormalizeAngle(180 + self.vehicle.vData.is[4])

        local function getQuarterSymbol(angle)
          local fraction = angle % 1
          if fraction < 0.125 or fraction >= 0.875 then return "" end
          if fraction < 0.375 then return "¼" end
          if fraction < 0.625 then return "½" end
          return "¾"
        end

        snap_txt2 = snap_txt
        snap_txt = string.format("%d%s°", degree, getQuarterSymbol(degree))
      end

      local color = self.vehicle.vData.is[5] and FS25_EnhancedVehicle_HUD.COLOR.ACTIVE or FS25_EnhancedVehicle_HUD.COLOR.INACTIVE
      setTextColor(unpack(color))
      renderText(self.snapText1.posX, self.snapText1.posY, self.snapText1.size, snap_txt)

      if snap_txt2 then
        setTextColor(1,1,1,1)
        renderText(self.snapText2.posX, self.snapText2.posY, self.snapText2.size, snap_txt2)
      end
    end

    -- track display
    -- prepare text
    local track_txt     = self.default_track_txt
    local headland_txt  = self.default_headland_txt
    local headland_txt2 = ""
    local workwidth_txt = self.default_workwidth_txt

    if self.vehicle.vData.track.isCalculated then
      local _prefix = "+"
      if self.vehicle.vData.track.deltaTrack == 0 then _prefix = "+/-" end
      if self.vehicle.vData.track.deltaTrack < 0 then _prefix = "" end
      local _curTrack = Round(self.vehicle.vData.track.originalTrackLR, 0)
      track_txt = string.format("#%i → %s%i → %i", _curTrack, _prefix, self.vehicle.vData.track.deltaTrack, (_curTrack + self.vehicle.vData.track.deltaTrack))
      workwidth_txt = string.format("|← %.1fm →|", Round(self.vehicle.vData.track.workWidth, 1))
      local _tmp = self.vehicle.vData.track.headlandDistance
      if _tmp == 9999 then _tmp = Round(self.vehicle.vData.track.workWidth, 1) end
      headland_txt = string.format("%.1fm", math.abs(_tmp))
      headland_txt2 = self.vehicle.vData.track.eofDistance ~= -1 and string.format("%.1f", self.vehicle.vData.track.eofDistance) or "err"
    end
    if self.vehicle.vData.opMode == 1 and self.vehicle.vData.impl.isCalculated and self.vehicle.vData.impl.workWidth > 0 then
      workwidth_txt = string.format("|← %.1fm →|", Round(self.vehicle.vData.impl.workWidth, 1))
    end

    -- render text
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)

    local color = (self.vehicle.vData.is[5] and self.vehicle.vData.is[6]) and FS25_EnhancedVehicle_HUD.COLOR.ACTIVE or FS25_EnhancedVehicle_HUD.COLOR.INACTIVE
    self.icons.hl1:setColor(unpack(color))
    self.icons.hl2:setColor(unpack(color))
    self.icons.hl3:setColor(unpack(color))

    -- track number
    setTextColor(unpack(color))
    renderText(self.trackText.posX, self.trackText.posY, self.trackText.size, track_txt)

    -- working width
    setTextColor(unpack(FS25_EnhancedVehicle_HUD.COLOR.INACTIVE))
    renderText(self.workWidthText.posX, self.workWidthText.posY, self.workWidthText.size, workwidth_txt)

    -- headland distance
    renderText(self.headlandDistanceText.posX, self.headlandDistanceText.posY, self.headlandDistanceText.size, headland_txt)

    if self.vehicle.vData.track.headlandMode >= 2 then
      if self.vehicle.vData.track.eofDistance > 30 then
        color = FS25_EnhancedVehicle_HUD.COLOR.ACTIVE
      elseif self.vehicle.vData.track.eofDistance > 10 then
        color = FS25_EnhancedVehicle_HUD.COLOR.STANDBY
      elseif self.vehicle.vData.track.eofDistance >= 0 then
        color = { 1, 0, 0, 1 }
      else
        color = FS25_EnhancedVehicle_HUD.COLOR.INACTIVE
      end
      setTextColor(unpack(color))
    end
    renderText(self.headlandEOFText.posX, self.headlandEOFText.posY, self.headlandEOFText.size, headland_txt2)
  end -- <- end of draw track box

  -- draw our diff HUD
  if self.diffBox:getVisible() then
    if self.vehicle.spec_motorized ~= nil and FS25_EnhancedVehicle.hud.diff.enabled then
      -- prepare
      local _txt = {}
      _txt.color = { "fs25green", "fs25green", "gray" }
      if self.vehicle.vData ~= nil then
        if self.vehicle.vData.is[1] then
          _txt.color[1] = "red"
        end
        if self.vehicle.vData.is[2] then
          _txt.color[2] = "red"
        end
        if self.vehicle.vData.is[3] == 0 then
          _txt.color[3] = "gray"
        end
        if self.vehicle.vData.is[3] == 1 then
          _txt.color[3] = "yellow"
        end
        if self.vehicle.vData.is[3] == 2 then
          _txt.color[3] = "gray"
        end
      end

      self.icons.diff_front:setColor(unpack(FS25_EnhancedVehicle.color[_txt.color[1]]))
      self.icons.diff_back:setColor(unpack(FS25_EnhancedVehicle.color[_txt.color[2]]))
      self.icons.diff_dm:setColor(unpack(FS25_EnhancedVehicle.color[_txt.color[3]]))
      self.icons.diff_bg.overlay:render()
      self.icons.diff_front.overlay:render()
      self.icons.diff_back.overlay:render()
      self.icons.diff_dm.overlay:render()
    end
  end

  -- draw our park HUD
  if self.parkBox:getVisible() then
    -- park icon
    local color = {}
    if self.vehicle.vData.is[13] then
      color = { unpack(FS25_EnhancedVehicle.color.red) }
    else
      color = { unpack(FS25_EnhancedVehicle_HUD.COLOR.ACTIVE) }
    end
    self.icons.park:setColor(unpack(color))
    self.icons.park.overlay:render()
  end

  local deltaY = 0
  if g_currentMission.hud.sideNotifications ~= nil and FS25_EnhancedVehicle.hud.dmg.offsetX == 0 and FS25_EnhancedVehicle.hud.dmg.offsetY == 0 and FS25_EnhancedVehicle.hud.fuel.offsetX == 0 and FS25_EnhancedVehicle.hud.fuel.offsetY == 0 then
    -- move our elements down if game displays side notifications
    if #g_currentMission.hud.sideNotifications.notificationQueue > 0 then
      deltaY = deltaY + (g_currentMission.hud.sideNotifications.bgScale.height + g_currentMission.hud.sideNotifications.notificationOffsetY) * #g_currentMission.hud.sideNotifications.notificationQueue
      deltaY = deltaY + g_currentMission.hud.sideNotifications.notificationOffsetY
    end
    -- move our elements down if game displays progress bars
    if FS25_EnhancedVehicle_HUD.numberProgessBars > 0 then
      deltaY = deltaY + (g_currentMission.hud.sideNotifications.progressBarBgTop.height +
                         g_currentMission.hud.sideNotifications.progressBarBgScale.height +
                         g_currentMission.hud.sideNotifications.progressBarBgBottom.height +
                         g_currentMission.hud.sideNotifications.progressBarSectionOffsetY) * FS25_EnhancedVehicle_HUD.numberProgessBars
      deltaY = deltaY + self.marginElement
      FS25_EnhancedVehicle_HUD.numberProgessBars = 0
    end
  end

  -- damage display
  if self.vehicle.spec_wearable ~= nil and FS25_EnhancedVehicle.hud.dmg.enabled then
    -- prepare text
    dmg_txt = { }

    -- add own vehicle dmg
    if self.vehicle.spec_wearable ~= nil then
      if not FS25_EnhancedVehicle.hud.dmg.showAmountLeft then
        table.insert(dmg_txt, { string.format("%s: %.1f%% | %.1f%%", self.vehicle.typeDesc, (self.vehicle.spec_wearable:getDamageAmount() * 100), (self.vehicle.spec_wearable:getWearTotalAmount() * 100)), 1 })
      else
        table.insert(dmg_txt, { string.format("%s: %.1f%% | %.1f%%", self.vehicle.typeDesc, (100 - (self.vehicle.spec_wearable:getDamageAmount() * 100)), (100 - (self.vehicle.spec_wearable:getWearTotalAmount() * 100))), 1 })
      end
    end

    if self.vehicle.spec_attacherJoints ~= nil then
      getDmg(self.vehicle.spec_attacherJoints)
    end

    -- prepare rendering
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(false)

    -- calculate width & height of text
    local _w, _h = 0, 0
    table.insert(dmg_txt, 1, { self.default_dmg_txt, 0 })
    for _, txt in pairs(dmg_txt) do
      setTextBold(false)
      if txt[2] == 0 then
        _h = _h + self.dmgText.textMarginHeight
        setTextBold(true)
      end
      _h = _h + self.dmgText.size
      local tmp = getTextWidth(self.dmgText.size, txt[1])
      if tmp > _w then _w = tmp end
    end

    -- calculate position of text
    local x = self.dmgText.posX
    local y = self.dmgText.posY - deltaY
    if FS25_EnhancedVehicle.hud.dmg.offsetX ~= 0 or FS25_EnhancedVehicle.hud.dmg.offsetY ~= 0 then
      local offX, offY = self.speedMeter:scalePixelToScreenVector({ FS25_EnhancedVehicle.hud.dmg.offsetX, FS25_EnhancedVehicle.hud.dmg.offsetY })
      x = x + offX
      y = y + offY
    else
      -- move further down for more elements
      deltaY = deltaY + _h + self.dmgText.textMarginHeight * 2 + self.marginElement
    end

    local textMarginWidth  = self.dmgText.textMarginWidth
    local textMarginHeight = self.dmgText.textMarginHeight
    local boxMarginWidth   = self.dmgText.boxMarginWidth
    local boxMarginHeight  = self.dmgText.boxMarginHeight

    local leftX   = x - _w - textMarginWidth * 2
    local rightX  = x - boxMarginWidth
    local topY    = y - boxMarginHeight
    local bottomY = y - _h - textMarginHeight * 2

    -- Set positions
    self.dmgBox.topleft:setPosition(leftX, topY)
    self.dmgBox.topright:setPosition(rightX, topY)
    self.dmgBox.bottomleft:setPosition(leftX, bottomY)
    self.dmgBox.bottomright:setPosition(rightX, bottomY)
    self.dmgBox.left:setPosition(leftX, bottomY + boxMarginHeight)
    self.dmgBox.right:setPosition(rightX, bottomY + boxMarginHeight)
    self.dmgBox.scale:setPosition(leftX + boxMarginWidth, bottomY)

    -- Set dimensions
    local sideHeight = _h + textMarginHeight * 2 - boxMarginHeight * 2
    self.dmgBox.left:setDimension(boxMarginWidth, sideHeight)
    self.dmgBox.right:setDimension(boxMarginWidth, sideHeight)
    self.dmgBox.scale:setDimension(_w - (boxMarginWidth - textMarginWidth) * 2, _h + textMarginHeight * 2)

    for _, txt in pairs(dmg_txt) do
      if txt[2] == 0 then
        setTextColor(unpack(FS25_EnhancedVehicle.color.lgray))
        setTextBold(true)
      elseif txt[2] == 2 then
        setTextColor(1,1,1,1)
      else
        setTextColor(unpack(FS25_EnhancedVehicle.color.dmg))
      end
      renderText(x - self.dmgText.textMarginWidth, y - self.dmgText.textMarginHeight / 2, self.dmgText.size, txt[1])
      if txt[2] == 0 then
        setTextBold(false)
        y = y - self.dmgText.textMarginHeight
      end
      y = y - self.dmgText.size
    end
  end -- <- end of render damage

  -- fuel display
  if self.vehicle.spec_fillUnit ~= nil and FS25_EnhancedVehicle.hud.fuel.enabled then
    -- get values
    local fuel_diesel_current   = -1
    local fuel_adblue_current   = -1
    local fuel_electric_current = -1
    local fuel_methane_current  = -1
    local fuel_diesel_max   = -1
    local fuel_adblue_max   = -1
    local fuel_electric_max = -1
    local fuel_methane_max  = -1

    for _, fillUnit in ipairs(self.vehicle.spec_fillUnit.fillUnits) do
      if fillUnit.fillType == FillType.DIESEL then -- Diesel
        fuel_diesel_max = fillUnit.capacity
        fuel_diesel_current = fillUnit.fillLevel
      end
      if fillUnit.fillType == FillType.DEF then -- AdBlue
        fuel_adblue_max = fillUnit.capacity
        fuel_adblue_current = fillUnit.fillLevel
      end
      if fillUnit.fillType == FillType.ELECTRICCHARGE then -- Electric
        fuel_electric_max = fillUnit.capacity
        fuel_electric_current = fillUnit.fillLevel
      end
      if fillUnit.fillType == FillType.METHANE then -- Methan
        fuel_methane_max = fillUnit.capacity
        fuel_methane_current = fillUnit.fillLevel
      end
    end

    -- prepare text
    local fuel_txt = { }
    if fuel_diesel_current >= 0 then
      table.insert(fuel_txt, { string.format("%.1f l/%.1f l", fuel_diesel_current, fuel_diesel_max), 1 })
    end
    if fuel_adblue_current >= 0 then
      table.insert(fuel_txt, { string.format("%.1f l/%.1f l", fuel_adblue_current, fuel_adblue_max), 2 })
    end
    if fuel_electric_current >= 0 then
      table.insert(fuel_txt, { string.format("%.1f kWh/%.1f kWh", fuel_electric_current, fuel_electric_max), 3 })
    end
    if fuel_methane_current >= 0 then
      table.insert(fuel_txt, { string.format("%.1f l/%.1f l", fuel_methane_current, fuel_methane_max), 4 })
    end
    if (self.vehicle:getIsMotorStarted() or self.vehicle:getIsMotorInNeutral()) and self.vehicle.isServer then
      if fuel_electric_current >= 0 then
        table.insert(fuel_txt, { string.format("%.1f kW/h", self.vehicle.spec_motorized.lastFuelUsage), 5 })
      else
        table.insert(fuel_txt, { string.format("%.1f l/h", self.vehicle.spec_motorized.lastFuelUsage), 5 })
      end
    end

    -- prepare rendering
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(false)

    -- calculate width & height of text
    local _w, _h = 0, 0
    table.insert(fuel_txt, 1, { self.default_fuel_txt, 0 })
    for _, txt in pairs(fuel_txt) do
      setTextBold(false)
      if txt[2] == 0 then
        setTextBold(true)
        _h = _h + self.fuelText.textMarginHeight
      end
      _h = _h + self.fuelText.size
      local tmp = getTextWidth(self.fuelText.size, txt[1])
      if tmp > _w then _w = tmp end
    end

    -- calculate position of text
    local x = self.fuelText.posX
    local y = self.fuelText.posY - deltaY
    if FS25_EnhancedVehicle.hud.fuel.offsetX ~= 0 or FS25_EnhancedVehicle.hud.fuel.offsetY ~= 0 then
      local offX, offY = self.speedMeter:scalePixelToScreenVector({ FS25_EnhancedVehicle.hud.fuel.offsetX, FS25_EnhancedVehicle.hud.fuel.offsetY })
      x = x + offX
      y = y + offY
    end

    self.fuelBox.topleft:setPosition(     x - _w - self.fuelText.textMarginWidth * 2, y - self.fuelText.boxMarginHeight)
    self.fuelBox.topright:setPosition(    x - self.fuelText.boxMarginWidth,           y - self.fuelText.boxMarginHeight)
    self.fuelBox.bottomleft:setPosition(  x - _w - self.fuelText.textMarginWidth * 2, y - _h - self.fuelText.textMarginHeight * 2)
    self.fuelBox.bottomright:setPosition( x - self.fuelText.boxMarginWidth,           y - _h - self.fuelText.textMarginHeight * 2)
    self.fuelBox.left:setPosition(        x - _w - self.fuelText.textMarginWidth * 2, y - _h - self.fuelText.textMarginHeight * 2 + self.fuelText.boxMarginHeight)
    self.fuelBox.right:setPosition(       x - self.fuelText.boxMarginWidth,           y - _h - self.fuelText.textMarginHeight * 2 + self.fuelText.boxMarginHeight)
    self.fuelBox.scale:setPosition(       x - _w - self.fuelText.textMarginWidth * 2 + self.fuelText.boxMarginWidth, y - _h - self.fuelText.textMarginHeight * 2)

    self.fuelBox.left:setDimension(  self.fuelText.boxMarginWidth, _h + self.fuelText.textMarginHeight * 2 - self.fuelText.boxMarginHeight * 2)
    self.fuelBox.right:setDimension( self.fuelText.boxMarginWidth, _h + self.fuelText.textMarginHeight * 2 - self.fuelText.boxMarginHeight * 2)
    self.fuelBox.scale:setDimension( _w - (self.fuelText.boxMarginWidth - self.fuelText.textMarginWidth) * 2, _h + self.fuelText.textMarginHeight * 2)

    for _, txt in pairs(fuel_txt) do
      if txt[2] == 0 then
        setTextColor(unpack(FS25_EnhancedVehicle.color.lgray))
        setTextBold(true)
      elseif txt[2] == 1 then
        setTextColor(unpack(FS25_EnhancedVehicle.color.fuel))
      elseif txt[2] == 2 then
        setTextColor(unpack(FS25_EnhancedVehicle.color.adblue))
      elseif txt[2] == 3 then
        setTextColor(unpack(FS25_EnhancedVehicle.color.electric))
      elseif txt[2] == 4 then
        setTextColor(unpack(FS25_EnhancedVehicle.color.methane))
      else
        setTextColor(1,1,1,1)
      end
      renderText(x - self.fuelText.textMarginWidth, y - self.fuelText.textMarginHeight / 2, self.fuelText.size, txt[1])
      if txt[2] == 0 then
        setTextBold(false)
        y = y - self.fuelText.textMarginHeight
      end
      y = y - self.fuelText.size
    end
  end -- <- end of render fuel

  -- misc display
  if self.vehicle.spec_motorized ~= nil and FS25_EnhancedVehicle.hud.misc.enabled then
    -- prepare text
    local misc_txt = string.format("%.1f", self.vehicle:getTotalMass(true)) .. "t (total: " .. string.format("%.1f", self.vehicle:getTotalMass()) .. " t)"

    -- render text
    setTextColor(1,1,1,1)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BOTTOM)
    setTextBold(false)
    renderText(self.miscText.posX, self.miscText.posY, self.miscText.size, misc_txt)
  end

  -- rpm display
  if self.vehicle.spec_motorized ~= nil and FS25_EnhancedVehicle.hud.rpm.enabled then
    -- prepare text
    local rpm_txt1 = "--"
    local rpm_txt2 = "\nrpm"
    if (self.vehicle:getIsMotorStarted() or self.vehicle:getIsMotorInNeutral()) then
      rpm_txt1 = string.format("%i", self.vehicle.spec_motorized:getMotorRpmReal())
    end

    -- render text
    setTextColor(1,1,1,1)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    renderText(self.rpmText.posX, self.rpmText.posY, self.rpmText.size, rpm_txt1)
    setTextColor(unpack(FS25_EnhancedVehicle.color.fs25green))
    renderText(self.rpmText.posX, self.rpmText.posY, self.rpmText.size, rpm_txt2)
  end

  -- temperature display
  if self.vehicle.spec_motorized ~= nil and FS25_EnhancedVehicle.hud.temp.enabled and self.vehicle.isServer then
    -- prepare text
    local _useF = g_gameSettings:getValue(GameSettings.SETTING.USE_FAHRENHEIT)
    local _s = "C"
    if _useF then _s = "F" end

    local temp_txt1 = "--"
    local temp_txt2 = "\n°" .. _s
    if (self.vehicle:getIsMotorStarted() or self.vehicle:getIsMotorInNeutral()) then
      local _value = self.vehicle.spec_motorized.motorTemperature.value

      if _useF then _value = _value * 1.8 + 32 end
      temp_txt1 = string.format("%i", _value)
    end

    -- render text
    setTextColor(1,1,1,1)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    renderText(self.tempText.posX, self.tempText.posY, self.tempText.size, temp_txt1)
    setTextColor(unpack(FS25_EnhancedVehicle.color.fs25green))
    renderText(self.tempText.posX, self.tempText.posY, self.tempText.size, temp_txt2)
  end

  -- odoMeter display
  if FS25_EnhancedVehicle.functionOdoMeterIsEnabled and FS25_EnhancedVehicle.hud.odo.enabled and self.vehicle.spec_motorized ~= nil then
    -- render text
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextBold(true)
    local color = FS25_EnhancedVehicle_HUD.COLOR.ACTIVE
    setTextColor(unpack(color))

    local odoDistanceInKM = (self.vehicle.vData.is[14] / 1000) % 999999.99
    local odoDistance = g_i18n:getDistance(odoDistanceInKM)
    local tripDistanceInKM = (self.vehicle.vData.is[15] / 1000) % 999999.99
    local tripDistance = g_i18n:getDistance(tripDistanceInKM)

    local _mode = "ODO"
    local _txt = string.format("  %09.02f", odoDistance)
    if self.vehicle.vData.is[16] > 0 then
      _mode = "Trip"
      _txt = string.format("  %09.02f", tripDistance)
    end
    local unit = g_i18n:getMeasuringUnit()

    local _txt2 = string.format("%s                            %s", _mode, unit)
    renderText(self.odoText.posX, self.odoText.posY, self.odoText.size2, _txt2)
    setTextColor(1,1,1,1)
    renderText(self.odoText.posX, self.odoText.posY, self.odoText.size, _txt)
  end

  -- reset text stuff to "defaults"
  setTextColor(1,1,1,1)
  setTextAlignment(RenderText.ALIGN_LEFT)
  setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
  setTextBold(false)
end

-- #############################################################################

function getDmg(start)
  if start.spec_attacherJoints.attachedImplements ~= nil then
    for _, implement in pairs(start.spec_attacherJoints.attachedImplements) do
      local tA = 0
      local tL = 0
      if implement.object.spec_wearable ~= nil then
        tA = implement.object.spec_wearable:getDamageAmount()
        tL = implement.object.spec_wearable:getWearTotalAmount()
      end

      if FS25_EnhancedVehicle.hud.dmg.showAmountLeft then
        table.insert(dmg_txt, { string.format("%s: %.1f%% | %.1f%%", implement.object.typeDesc, (100 - (tA * 100)), (100 - (tL * 100))), 2 })
      else
        table.insert(dmg_txt, { string.format("%s: %.1f%% | %.1f%%", implement.object.typeDesc, (tA * 100), (tL * 100)), 2 })
      end

      if implement.object.spec_attacherJoints ~= nil then
        getDmg(implement.object)
      end
    end
  end
end

-- #############################################################################

function FS25_EnhancedVehicle_HUD:markProgressBarForDrawing(v1)
  FS25_EnhancedVehicle_HUD.numberProgessBars = FS25_EnhancedVehicle_HUD.numberProgessBars + 1
end
