--
-- Mod: FS25_EnhancedVehicle
--
-- Author: Majo76
-- email: ls (at) majo76 (dot) de
-- @Date: 06.06.2025
-- @Version: 1.1.6.0

--[[
CHANGELOG

2025-xx-xx - V1.1.6.0
* fix config setting "showKeysInHelpMenu" was not working at all
+ key bindings and help menu will no longer be set if functionality (e.g. park brake) is disabled in the global settings (Attn: need to re-enter vehicle to activate change)
+ added translation: uk (thanks to ilia235 on Discord)

2025-05-03 - V1.1.5.0
* some code/performance optimizations here and there and fix for bug #59 (thanks to DeckerMMIV)
+ ability to rotate in 0.25 degrees, instead of 90 degrees (thanks to DeckerMMIV)
+ display value of compass direction aligned to be the same as the base-game's mini-map (thanks to DeckerMMIV)
+ made rotation input-action repeatable similar to when setting width/offset of track (thanks to DeckerMMIV)
+ reordered the "showLines" sequence: hidden -> yellow -> yellow & red -> red -> hidden (thanks to DeckerMMIV)

2024-12-08 - V1.1.4.0
+ added XML config option "moveFillLevelsDisplayDeltaY" to move the inGame FillLevelsDisplay by x pixels
+ added translation: nl
* minor code optimizations

2024-12-07 - V1.1.3.1
* forgot to update the modDesc version *doh*

2024-12-07 - V1.1.3.0
* HUD elements dmg and fuel can now be moved correctly by changing offsetX/Y in XML config
+ added translation: da, cz, es, hu

2024-12-02 - V1.1.2.2
+ several bugfixes, code optimizations and translations additions/updates
- revert NormalizeAngle code change

2024-11-30 - V1.1.1.0
+ added new feature: front/rear hydraulic unfold/fold on keypress
+ added translations: ru, cs, pl

2024-11-26 - V1.1.0.0
+ the configuration menu is back. yay!
* (finally) fixed too many EV key bindings are shown in help menu

2024-11-24 - V1.0.1.0
+ added odometer / tripmeter (driven kilometer display) based on Giants modding tutorial
- disabled configuration menu (for now)

2024-11-12 - V1.0.0.0
+ initial release for FS25
- removed support for different fuel/dmg positions

license: https://creativecommons.org/licenses/by-nc-sa/4.0/
]]--

local myName = "FS25_EnhancedVehicle"

FS25_EnhancedVehicle = {}
local FS25_EnhancedVehicle_mt = Class(FS25_EnhancedVehicle)

local joints_front
local joints_back
local implements_front
local implements_back
local listOfObjects

-- #############################################################################

function FS25_EnhancedVehicle:new(mission, modDirectory, modName, i18n, gui, inputManager, messageCenter)
  if debug > 1 then print("-> " .. myName .. ": new ") end

  local self = {}

  setmetatable(self, FS25_EnhancedVehicle_mt)

  self.mission       = mission
  self.modDirectory  = modDirectory
  self.modName       = modName
  self.i18n          = i18n
  self.gui           = gui
  self.inputManager  = inputManager
  self.messageCenter = messageCenter

  local modDesc = loadXMLFile("modDesc", modDirectory .. "modDesc.xml");
  self.version = getXMLString(modDesc, "modDesc.version");

  -- some global stuff - DONT touch
  FS25_EnhancedVehicle.hud = {}
  FS25_EnhancedVehicle.fS = g_currentMission.hud.speedMeter:scalePixelToScreenHeight(12)
  FS25_EnhancedVehicle.sections = { 'fuel', 'dmg', 'misc', 'rpm', 'temp', 'diff', 'track', 'park', 'odo' }
  FS25_EnhancedVehicle.actions = {}
  FS25_EnhancedVehicle.actions.global =    { 'FS25_EnhancedVehicle_MENU' }
  FS25_EnhancedVehicle.actions.park =      { 'FS25_EnhancedVehicle_PARK' }
  FS25_EnhancedVehicle.actions.odo =       { 'FS25_EnhancedVehicle_ODO_MODE' }
  FS25_EnhancedVehicle.actions.snap =      { 'FS25_EnhancedVehicle_SNAP_ONOFF',
                                             'FS25_EnhancedVehicle_SNAP_REVERSE',
                                             'FS25_EnhancedVehicle_SNAP_OPMODE',
                                             'FS25_EnhancedVehicle_SNAP_CALC_WW',
                                             'FS25_EnhancedVehicle_SNAP_GRID_RESET',
                                             'FS25_EnhancedVehicle_SNAP_LINES_MODE',
                                             'FS25_EnhancedVehicle_SNAP_TRACK',
                                             'FS25_EnhancedVehicle_SNAP_TRACKP',
                                             'FS25_EnhancedVehicle_SNAP_TRACKW',
                                             'FS25_EnhancedVehicle_SNAP_TRACKO',
                                             'FS25_EnhancedVehicle_SNAP_TRACKJ',
                                             'FS25_EnhancedVehicle_SNAP_HL_MODE',
                                             'FS25_EnhancedVehicle_SNAP_HL_DIST',
                                             'FS25_EnhancedVehicle_SNAP_ANGLE1',
                                             'FS25_EnhancedVehicle_SNAP_ANGLE2',
                                             'FS25_EnhancedVehicle_SNAP_ANGLE3',
                                             'AXIS_MOVE_SIDE_VEHICLE',
                                             'AXIS_ACCELERATE_VEHICLE',
                                             'AXIS_BRAKE_VEHICLE' }
  FS25_EnhancedVehicle.actions.diff  =     { 'FS25_EnhancedVehicle_FD',
                                             'FS25_EnhancedVehicle_RD',
                                             'FS25_EnhancedVehicle_BD',
                                             'FS25_EnhancedVehicle_DM' }
  FS25_EnhancedVehicle.actions.hydraulic = { 'FS25_EnhancedVehicle_AJ_REAR_UPDOWN',
                                             'FS25_EnhancedVehicle_AJ_REAR_ONOFF',
                                             'FS25_EnhancedVehicle_AJ_REAR_FOLD',
                                             'FS25_EnhancedVehicle_AJ_FRONT_UPDOWN',
                                             'FS25_EnhancedVehicle_AJ_FRONT_ONOFF',
                                             'FS25_EnhancedVehicle_AJ_FRONT_FOLD' }

  -- for key press delay
  FS25_EnhancedVehicle.startActionTime = 0
  FS25_EnhancedVehicle.nextActionTime  = 0
  FS25_EnhancedVehicle.deltaActionTime = 500
  FS25_EnhancedVehicle.minActionTime   = 31.25

  -- some colors
  FS25_EnhancedVehicle.color = {
    black     = {       0,       0,       0, 1 },
    white     = {       1,       1,       1, 1 },
    red       = { 255/255,   0/255,   0/255, 1 },
    darkred   = { 128/255,   0/255,   0/255, 1 },
    green     = {   0/255, 255/255,   0/255, 1 },
    blue      = {   0/255,   0/255, 255/255, 1 },
    yellow    = { 255/255, 255/255,   0/255, 1 },
    gray      = { 128/255, 128/255, 128/255, 1 },
    lgray     = { 178/255, 178/255, 178/255, 1 },
    dmg       = { 255/255, 174/255,   0/255, 1 },
    fuel      = { 178/255, 214/255,  22/255, 1 },
    adblue    = {  48/255,  78/255, 249/255, 1 },
    electric  = { 255/255, 255/255,   0/255, 1 },
    methane   = {   0/255, 198/255, 255/255, 1 },
    ls22blue  = {   0/255, 198/255, 253/255, 1 },
    fs25green = {  60/255, 118/255,   0/255, 1 },
  }

  FS25_EnhancedVehicle.hl_distances = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20, -1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -12, -14, -16, -18, -20 }

  -- load sound effects
  if g_dedicatedServerInfo == nil then
    local file, id
    FS25_EnhancedVehicle.sounds = {}
    for _, id in ipairs({"diff_lock", "brakeOn", "brakeOff", "snap_on", "snap_off", "hl_approach"}) do
      FS25_EnhancedVehicle.sounds[id] = createSample(id)
      file = self.modDirectory.."resources/"..id..".ogg"
      loadSample(FS25_EnhancedVehicle.sounds[id], file, false)
    end
  end

  return self
end

-- #############################################################################

function FS25_EnhancedVehicle:delete()
  if debug > 1 then print("-> " .. myName .. ": delete ") end

  -- delete our UI
  FS25_EnhancedVehicle.ui_menu:delete()

  -- delete our HUD
  FS25_EnhancedVehicle.ui_hud:delete()
end

-- #############################################################################

function FS25_EnhancedVehicle:onMissionLoaded(mission)
  if debug > 1 then print("-> " .. myName .. ": onMissionLoaded ") end

  -- create configuration dialog
  FS25_EnhancedVehicle.ui_menu = FS25_EnhancedVehicle_UI.new()
  g_gui:loadGui(self.modDirectory.."ui/FS25_EnhancedVehicle_UI.xml", "FS25_EnhancedVehicle_UI", FS25_EnhancedVehicle.ui_menu)

  -- create HUD
  FS25_EnhancedVehicle.ui_hud = FS25_EnhancedVehicle_HUD:new(mission.hud.speedMeter, mission.hud.gameInfoDisplay, self.modDirectory)
  FS25_EnhancedVehicle.ui_hud:load()

  -- hook into function, which is called only if the HUD is really visible for a vehicle
  mission.hud.drawControlledEntityHUD = Utils.appendedFunction(mission.hud.drawControlledEntityHUD,
    function(self)
      if self.isVisible then
        FS25_EnhancedVehicle.ui_hud:drawHUD()
      end
    end)

  -- hook into function, which sets the vehicle for HUD display
  mission.hud.setControlledVehicle = Utils.appendedFunction(mission.hud.setControlledVehicle,
    function(self, vehicle)
      FS25_EnhancedVehicle.ui_hud:setVehicle(vehicle)
    end)
end

-- #############################################################################

function FS25_EnhancedVehicle:loadMap()
  print("--> loaded FS25_EnhancedVehicle version " .. self.version .. " (by Majo76) <--");

  -- first set our current and default config to default values
  FS25_EnhancedVehicle:resetConfig()
  -- then read values from disk and "overwrite" current config
  lC:readConfig()
  -- then write current config (which is now a merge between default values and from disk)
  lC:writeConfig()
  -- and finally activate current config
  FS25_EnhancedVehicle:activateConfig()
end

-- #############################################################################

function FS25_EnhancedVehicle:unloadMap()
  print("--> unloaded FS25_EnhancedVehicle version " .. self.version .. " (by Majo76) <--");
end

-- #############################################################################

function FS25_EnhancedVehicle.installSpecializations(vehicleTypeManager, specializationManager, modDirectory, modName)
  if debug > 1 then print("-> " .. myName .. ": installSpecializations ") end

  specializationManager:addSpecialization("EnhancedVehicle", "FS25_EnhancedVehicle", Utils.getFilename("FS25_EnhancedVehicle.lua", modDirectory), nil)

  if specializationManager:getSpecializationByName("EnhancedVehicle") == nil then
    print("ERROR: unable to add specialization 'FS25_EnhancedVehicle'")
  else
    for typeName, typeDef in pairs(vehicleTypeManager.types) do
      if SpecializationUtil.hasSpecialization(Drivable,  typeDef.specializations) and
         SpecializationUtil.hasSpecialization(Enterable, typeDef.specializations) and
         SpecializationUtil.hasSpecialization(Motorized, typeDef.specializations) and
         not SpecializationUtil.hasSpecialization(Locomotive,     typeDef.specializations) and
         not SpecializationUtil.hasSpecialization(ConveyorBelt,   typeDef.specializations) and
         not SpecializationUtil.hasSpecialization(AIConveyorBelt, typeDef.specializations)
      then
        if debug > 1 then print("--> attached specialization 'EnhancedVehicle' to vehicleType '" .. tostring(typeName) .. "'") end
        vehicleTypeManager:addSpecialization(typeName, modName..".EnhancedVehicle")
      end
    end
  end
end

-- #############################################################################

function FS25_EnhancedVehicle.prerequisitesPresent(specializations)
  if debug > 1 then print("-> " .. myName .. ": prerequisites ") end

  return true
end

-- #############################################################################

function FS25_EnhancedVehicle.registerEventListeners(vehicleType)
  if debug > 1 then print("-> " .. myName .. ": registerEventListeners ") end

  for _,n in pairs( { "onLoad", "onPostLoad", "saveToXMLFile", "onUpdate", "onDraw", "onReadStream", "onWriteStream", "onReadUpdateStream", "onWriteUpdateStream", "onRegisterActionEvents", "onEnterVehicle", "onLeaveVehicle", "onPostAttachImplement", "onPostDetachImplement" } ) do
    SpecializationUtil.registerEventListener(vehicleType, n, FS25_EnhancedVehicle)
  end
end

-- #############################################################################
-- ### function for others mods to enable/disable EnhancedVehicle functions
-- ###   name: differential, hydraulic, snap, park, odometer
-- ###  state: true or false

function FS25_EnhancedVehicle:functionEnable(name, state)
  if name == "differential" then
    lC:setConfigValue("global.functions", "diffIsEnabled", state)
    FS25_EnhancedVehicle.functionDiffIsEnabled = state
  end
  if name == "hydraulic" then
    lC:setConfigValue("global.functions", "hydraulicIsEnabled", state)
    FS25_EnhancedVehicle.functionHydraulicIsEnabled = state
  end
  if name == "snap" then
    lC:setConfigValue("global.functions", "snapIsEnabled", state)
    FS25_EnhancedVehicle.functionSnapIsEnabled = state
  end
  if name == "park" then
    lC:setConfigValue("global.functions", "parkingBrakeIsEnabled", state)
    FS25_EnhancedVehicle.functionParkingBrakeIsEnabled = state
  end
  if name == "odometer" then
    lC:setConfigValue("global.functions", "odoMeterIsEnabled", state)
    FS25_EnhancedVehicle.functionOdoMeterIsEnabled = state
  end
end

-- #############################################################################
-- ### function for others mods to get EnhancedVehicle functions status
-- ###   name: differential, hydraulic, snap, park, odometer
-- ###  returns true or false

function FS25_EnhancedVehicle:functionStatus(name)
  if name == "differential" then
    return(lC:getConfigValue("global.functions", "diffIsEnabled"))
  end
  if name == "hydraulic" then
    return(lC:getConfigValue("global.functions", "hydraulicIsEnabled"))
  end
  if name == "snap" then
    return(lC:getConfigValue("global.functions", "snapIsEnabled"))
  end
  if name == "park" then
    return(lC:getConfigValue("global.functions", "parkingBrakeIsEnabled"))
  end
  if name == "odometer" then
    return(lC:getConfigValue("global.functions", "odoMeterIsEnabled"))
  end

  return(nil)
end

-- #############################################################################

function FS25_EnhancedVehicle:activateConfig()
  -- here we will "move" our config from the libConfig internal storage to the variables we actually use

  -- functions
  FS25_EnhancedVehicle.functionDiffIsEnabled         = lC:getConfigValue("global.functions", "diffIsEnabled")
  FS25_EnhancedVehicle.functionHydraulicIsEnabled    = lC:getConfigValue("global.functions", "hydraulicIsEnabled")
  FS25_EnhancedVehicle.functionSnapIsEnabled         = lC:getConfigValue("global.functions", "snapIsEnabled")
  FS25_EnhancedVehicle.functionParkingBrakeIsEnabled = lC:getConfigValue("global.functions", "parkingBrakeIsEnabled")
  FS25_EnhancedVehicle.functionOdoMeterIsEnabled     = lC:getConfigValue("global.functions", "odoMeterIsEnabled")

  -- globals
  FS25_EnhancedVehicle.showKeysInHelpMenu  = lC:getConfigValue("global.misc", "showKeysInHelpMenu")
  FS25_EnhancedVehicle.soundIsOn           = lC:getConfigValue("global.misc", "soundIsOn")

  -- snap
  FS25_EnhancedVehicle.snap = {}
  FS25_EnhancedVehicle.snap.snapToAngle = lC:getConfigValue("snap", "snapToAngle")
  FS25_EnhancedVehicle.snap.attachmentSpikeHeight = lC:getConfigValue("snap", "attachmentSpikeHeight")
  FS25_EnhancedVehicle.snap.trackSpikeHeight      = lC:getConfigValue("snap", "trackSpikeHeight")
  FS25_EnhancedVehicle.snap.distanceAboveGroundVehicleMiddleLine  = lC:getConfigValue("snap", "distanceAboveGroundVehicleMiddleLine")
  FS25_EnhancedVehicle.snap.distanceAboveGroundVehicleSideLine    = lC:getConfigValue("snap", "distanceAboveGroundVehicleSideLine")
  FS25_EnhancedVehicle.snap.distanceAboveGroundAttachmentSideLine = lC:getConfigValue("snap", "distanceAboveGroundAttachmentSideLine")

  FS25_EnhancedVehicle.snap.colorVehicleMiddleLine  = { lC:getConfigValue("snap.colorVehicleMiddleLine",  "red"), lC:getConfigValue("snap.colorVehicleMiddleLine",  "green"), lC:getConfigValue("snap.colorVehicleMiddleLine",  "blue") }
  FS25_EnhancedVehicle.snap.colorVehicleSideLine    = { lC:getConfigValue("snap.colorVehicleSideLine",    "red"), lC:getConfigValue("snap.colorVehicleSideLine",    "green"), lC:getConfigValue("snap.colorVehicleSideLine",    "blue") }
  FS25_EnhancedVehicle.snap.colorAttachmentSideLine = { lC:getConfigValue("snap.colorAttachmentSideLine", "red"), lC:getConfigValue("snap.colorAttachmentSideLine", "green"), lC:getConfigValue("snap.colorAttachmentSideLine", "blue") }

  -- track
  FS25_EnhancedVehicle.track = {}
  FS25_EnhancedVehicle.track.distanceAboveGround = lC:getConfigValue("track", "distanceAboveGround")
  FS25_EnhancedVehicle.track.numberOfTracks      = lC:getConfigValue("track", "numberOfTracks")
  FS25_EnhancedVehicle.track.showLines           = lC:getConfigValue("track", "showLines")
  FS25_EnhancedVehicle.track.hideLines           = lC:getConfigValue("track", "hideLines")
  FS25_EnhancedVehicle.track.hideLinesAfter      = lC:getConfigValue("track", "hideLinesAfter")
  FS25_EnhancedVehicle.track.hideLinesAfterValue = 0
  FS25_EnhancedVehicle.track.color = { lC:getConfigValue("track.color", "red"), lC:getConfigValue("track.color", "green"), lC:getConfigValue("track.color", "blue") }
  FS25_EnhancedVehicle.track.headlandSoundTriggerDistance = lC:getConfigValue("track", "headlandSoundTriggerDistance")

  -- HUD stuff
  for _, section in pairs(FS25_EnhancedVehicle.sections) do
    FS25_EnhancedVehicle.hud[section] = {}
    FS25_EnhancedVehicle.hud[section].enabled  = lC:getConfigValue("hud."..section, "enabled")
    FS25_EnhancedVehicle.hud[section].fontSize = lC:getConfigValue("hud."..section, "fontSize")
    FS25_EnhancedVehicle.hud[section].offsetX  = lC:getConfigValue("hud."..section, "offsetX")
    FS25_EnhancedVehicle.hud[section].offsetY  = lC:getConfigValue("hud."..section, "offsetY")
  end
  FS25_EnhancedVehicle.hud.dmg.showAmountLeft                = lC:getConfigValue("hud.dmg",   "showAmountLeft")
  FS25_EnhancedVehicle.hud.track.moveFillLevelsDisplayDeltaY = lC:getConfigValue("hud.track", "moveFillLevelsDisplayDeltaY")

  FS25_EnhancedVehicle.hud.colorActive   = { lC:getConfigValue("hud.colorActive",   "red"), lC:getConfigValue("hud.colorActive",   "green"), lC:getConfigValue("hud.colorActive",   "blue"), 1 }
  FS25_EnhancedVehicle.hud.colorInactive = { lC:getConfigValue("hud.colorInactive", "red"), lC:getConfigValue("hud.colorInactive", "green"), lC:getConfigValue("hud.colorInactive", "blue"), 1 }
  FS25_EnhancedVehicle.hud.colorStandby  = { lC:getConfigValue("hud.colorStandby",  "red"), lC:getConfigValue("hud.colorStandby",  "green"), lC:getConfigValue("hud.colorStandby",  "blue"), 1 }

  FS25_EnhancedVehicle.sfx_volume = {}
  FS25_EnhancedVehicle.sfx_volume.track       = lC:getConfigValue("sfx.track",       "volume")
  FS25_EnhancedVehicle.sfx_volume.brake       = lC:getConfigValue("sfx.brake",       "volume")
  FS25_EnhancedVehicle.sfx_volume.diff        = lC:getConfigValue("sfx.diff",        "volume")
  FS25_EnhancedVehicle.sfx_volume.hl_approach = lC:getConfigValue("sfx.hl_approach", "volume")
end

-- #############################################################################

function FS25_EnhancedVehicle:resetConfig(disable)
  if debug > 0 then print("-> " .. myName .. ": resetConfig ") end
  disable = false or disable

  -- start fresh
  lC:clearConfig()

  -- functions
  lC:addConfigValue("global.functions", "diffIsEnabled",         "bool", true)
  lC:addConfigValue("global.functions", "hydraulicIsEnabled",    "bool", true)
  lC:addConfigValue("global.functions", "snapIsEnabled",         "bool", true)
  lC:addConfigValue("global.functions", "parkingBrakeIsEnabled", "bool", true)
  lC:addConfigValue("global.functions", "odoMeterIsEnabled",     "bool", true)

  -- globals
  lC:addConfigValue("global.misc", "showKeysInHelpMenu", "bool",   true)
  lC:addConfigValue("global.misc", "soundIsOn", "bool",            true)

  -- snap
  lC:addConfigValue("snap", "snapToAngle", "float", 10.0)
  lC:addConfigValue("snap", "attachmentSpikeHeight", "float", 0.75)
  lC:addConfigValue("snap", "trackSpikeHeight",      "float", 0)
  lC:addConfigValue("snap", "distanceAboveGroundVehicleMiddleLine",  "float", 0.3)
  lC:addConfigValue("snap", "distanceAboveGroundVehicleSideLine",    "float", 0.25)
  lC:addConfigValue("snap", "distanceAboveGroundAttachmentSideLine", "float", 0.20)
  lC:addConfigValue("snap.colorVehicleMiddleLine", "red",    "float", 76/255)
  lC:addConfigValue("snap.colorVehicleMiddleLine", "green",  "float", 76/255)
  lC:addConfigValue("snap.colorVehicleMiddleLine", "blue",   "float", 76/255)
  lC:addConfigValue("snap.colorVehicleSideLine", "red",      "float", 255/255)
  lC:addConfigValue("snap.colorVehicleSideLine", "green",    "float", 0/255)
  lC:addConfigValue("snap.colorVehicleSideLine", "blue",     "float", 0/255)
  lC:addConfigValue("snap.colorAttachmentSideLine", "red",   "float", 100/255)
  lC:addConfigValue("snap.colorAttachmentSideLine", "green", "float", 0/255)
  lC:addConfigValue("snap.colorAttachmentSideLine", "blue",  "float", 0/255)

  -- track
  lC:addConfigValue("track",       "distanceAboveGround",          "float", 0.15)
  lC:addConfigValue("track",       "numberOfTracks",               "int",   5)
  lC:addConfigValue("track",       "showLines",                    "int",   2)
  lC:addConfigValue("track",       "hideLines",                    "bool",  false)
  lC:addConfigValue("track",       "hideLinesAfter",               "int",   5)
  lC:addConfigValue("track.color", "red",                          "float", 255/255)
  lC:addConfigValue("track.color", "green",                        "float", 150/255)
  lC:addConfigValue("track.color", "blue",                         "float", 0/255)
  lC:addConfigValue("track",       "headlandSoundTriggerDistance", "int",   10)

  -- fuel
  lC:addConfigValue("hud.fuel", "enabled",  "bool", true)
  lC:addConfigValue("hud.fuel", "fontSize", "int",  12)
  lC:addConfigValue("hud.fuel", "offsetX",  "int",  0)
  lC:addConfigValue("hud.fuel", "offsetY",  "int",  0)

  -- dmg
  lC:addConfigValue("hud.dmg", "enabled",        "bool", true)
  lC:addConfigValue("hud.dmg", "fontSize",       "int",  12)
  lC:addConfigValue("hud.dmg", "showAmountLeft", "bool", false)
  lC:addConfigValue("hud.dmg", "offsetX",        "int",  0)
  lC:addConfigValue("hud.dmg", "offsetY",        "int",  0)

  -- track
  lC:addConfigValue("hud.track", "enabled",                     "bool", true)
  lC:addConfigValue("hud.track", "offsetX",                     "int",  0)
  lC:addConfigValue("hud.track", "offsetY",                     "int",  0)
  lC:addConfigValue("hud.track", "moveFillLevelsDisplayDeltaY", "int",  0)

  -- misc
  lC:addConfigValue("hud.misc", "enabled", "bool", true)
  lC:addConfigValue("hud.misc", "offsetX", "int",  0)
  lC:addConfigValue("hud.misc", "offsetY", "int",  0)

  -- rpm
  lC:addConfigValue("hud.rpm", "enabled", "bool", true)

  -- temp
  lC:addConfigValue("hud.temp", "enabled", "bool", true)

  -- odoMeter
  lC:addConfigValue("hud.odo", "enabled", "bool", true)

  -- diff
  lC:addConfigValue("hud.diff", "enabled", "bool", true)
  lC:addConfigValue("hud.diff", "offsetX", "int",  0)
  lC:addConfigValue("hud.diff", "offsetY", "int",  0)

  -- park
  lC:addConfigValue("hud.park", "enabled", "bool", true)
  lC:addConfigValue("hud.park", "offsetX", "int",  0)
  lC:addConfigValue("hud.park", "offsetY", "int",  0)

  -- HUD more colors
  lC:addConfigValue("hud.colorActive",   "red",   "float",  60/255)
  lC:addConfigValue("hud.colorActive",   "green", "float", 118/255)
  lC:addConfigValue("hud.colorActive",   "blue",  "float",   0/255)
  lC:addConfigValue("hud.colorInactive", "red",   "float", 180/255)
  lC:addConfigValue("hud.colorInactive", "green", "float", 180/255)
  lC:addConfigValue("hud.colorInactive", "blue",  "float", 180/255)
  lC:addConfigValue("hud.colorStandby",  "red",   "float", 255/255)
  lC:addConfigValue("hud.colorStandby",  "green", "float", 174/255)
  lC:addConfigValue("hud.colorStandby",  "blue",  "float",   0/255)

  -- sound volumes
  lC:addConfigValue("sfx.track",       "volume", "float", 0.10)
  lC:addConfigValue("sfx.brake",       "volume", "float", 0.10)
  lC:addConfigValue("sfx.diff",        "volume", "float", 0.50)
  lC:addConfigValue("sfx.hl_approach", "volume", "float", 0.10)
end

-- #############################################################################

function FS25_EnhancedVehicle:onLoad(savegame)
  if debug > 1 then print("-> " .. myName .. ": onLoad" .. mySelf(self)) end

  -- export functions for other mods
  self.functionEnable = FS25_EnhancedVehicle.functionEnable
  self.functionStatus = FS25_EnhancedVehicle.functionStatus
end

-- #############################################################################

function FS25_EnhancedVehicle:onPostLoad(savegame)
  if debug > 1 then print("-> " .. myName .. ": onPostLoad" .. mySelf(self)) end

  -- vData
  --   1 - frontDiffIsOn
  --   2 - backDiffIsOn
  --   3 - drive mode
  --   4 - snapAngle
  --   5 - snap.enable
  --   6 - snap on track
  --   7 - track px
  --   8 - track pz
  --   9 - track dX
  --  10 - track dZ
  --  11 - track snapx
  --  12 - track snapz
  --  13 - parking brake on
  --  14 - odo meter
  --  15 - trip meter
  --  16 - odo mode

  -- initialize vehicle data with defaults
  self.vData = {}
  self.vData.is   = {   nil,   nil, nil, nil,   nil,   nil, nil, nil, nil, nil, nil, nil, nil,   nil, nil, nil }
  self.vData.want = { false, false,   1, 0.0, false, false,   0,   0,   0,   0,   0,   0, false, 0.0, 0.0, 0 }
  self.vData.torqueRatio   = { 0.5, 0.5, 0.5 }
  self.vData.maxSpeedRatio = { 1.0, 1.0, 1.0 }
  self.vData.rot = 0.0
  self.vData.axisSidePrev = 0.0
  self.vData.opMode = 0
  self.vData.triggerCalculate = false
  self.vData.impl  = { isCalculated = false }
  self.vData.track = { isCalculated = false, deltaTrack = 1, headlandMode = 1, headlandDistance = 9999, isOnField = 0, eofDistance = -1, eofNext = 0 }
  self.vData.dirtyFlag = self:getNextDirtyFlag()
  self.vData.networkThreshold = 10 -- send odo/tripMeter updates every 10 meters
  self.vData.odoDistanceSent  = 0  -- last odo value sent
  self.vData.tripDistanceSent = 0  -- last trip value sent

  -- (server) set some defaults
  if self.isServer then
    for _, differential in ipairs(self.spec_motorized.differentials) do
      if differential.diffIndex1 == 1 then -- front
        self.vData.torqueRatio[1]   = differential.torqueRatio
        self.vData.maxSpeedRatio[1] = differential.maxSpeedRatio
      end
      if differential.diffIndex1 == 3 then -- back
        self.vData.torqueRatio[2]   = differential.torqueRatio
        self.vData.maxSpeedRatio[2] = differential.maxSpeedRatio
      end
      if differential.diffIndex1 == 0 and differential.diffIndex1IsWheel == false then -- front_to_back
        self.vData.torqueRatio[3]   = differential.torqueRatio
        self.vData.maxSpeedRatio[3] = differential.maxSpeedRatio
      end
    end
  end

  -- load vehicle status from savegame
  if savegame ~= nil then
    local xmlFile = savegame.xmlFile
    local key     = savegame.key ..".FS25_EnhancedVehicle.EnhancedVehicle"

    local _data
    for _, _data in pairs( { {1, 'frontDiffIsOn'}, {2, 'backDiffIsOn'}, {3, 'driveMode'}, {13, 'parkingBrakeIsOn'}, {14, 'odoMeter'}, {15, 'tripMeter'}, {16, 'odoMode'} }) do
      local idx = _data[1]
      local _v
      if idx == 3 or idx == 16 then
        _v = getXMLInt(xmlFile.handle, key.."#".. _data[2])
      elseif (idx == 14 or idx == 15) then
        _v = getXMLFloat(xmlFile.handle, key.."#".. _data[2])
      else
        _v = getXMLBool(xmlFile.handle, key.."#".. _data[2])
      end
      if _v ~= nil then
        if (idx == 3 or idx == 14 or idx == 15 or idx == 16) then
          self.vData.want[idx] = _v
          if debug > 1 then print("--> found ".._data[2].."=".._v.." in savegame" .. mySelf(self)) end
        else
          if _v then
            self.vData.want[idx] = true
            if debug > 1 then print("--> found ".._data[2].."=true in savegame" .. mySelf(self)) end
          else
            self.vData.want[idx] = false
            if debug > 1 then print("--> found ".._data[2].."=false in savegame" .. mySelf(self)) end
          end
        end
      end
    end
  end

  -- update vehicle parameters
  if self.isServer then
    FS25_EnhancedVehicle:updatevData(self)
  elseif self.isClient then
    self.vData.is = { unpack(self.vData.want) }
  end

  if debug > 0 then print("--> setup of vData done" .. mySelf(self)) end
end

-- #############################################################################

function FS25_EnhancedVehicle:saveToXMLFile(xmlFile, key)
  if debug > 1 then print("-> " .. myName .. ": saveToXMLFile" .. mySelf(self)) end

  if self.vData.is[1] ~= nil then  setXMLBool(xmlFile.handle,  key.."#frontDiffIsOn",    self.vData.is[1])  else print("-> EV: saveToXMLFile warning [1]")  end
  if self.vData.is[2] ~= nil then  setXMLBool(xmlFile.handle,  key.."#backDiffIsOn",     self.vData.is[2])  else print("-> EV: saveToXMLFile warning [2]")  end
  if self.vData.is[3] ~= nil then  setXMLInt(xmlFile.handle,   key.."#driveMode",        self.vData.is[3])  else print("-> EV: saveToXMLFile warning [3]")  end
  if self.vData.is[13] ~= nil then setXMLBool(xmlFile.handle,  key.."#parkingBrakeIsOn", self.vData.is[13]) else print("-> EV: saveToXMLFile warning [13]") end
  if self.vData.is[14] ~= nil then setXMLFloat(xmlFile.handle, key.."#odoMeter",         self.vData.is[14]) else print("-> EV: saveToXMLFile warning [14]") end
  if self.vData.is[15] ~= nil then setXMLFloat(xmlFile.handle, key.."#tripMeter",        self.vData.is[15]) else print("-> EV: saveToXMLFile warning [15]") end
  if self.vData.is[16] ~= nil then setXMLInt(xmlFile.handle,   key.."#odoMode",          self.vData.is[16]) else print("-> EV: saveToXMLFile warning [16]") end
end

-- #############################################################################

function FS25_EnhancedVehicle:onReadStream(streamId, connection)
  if debug > 1 then print("-> " .. myName .. ": onReadStream - " .. streamId .. mySelf(self)) end

  -- receive initial data from server
  self.vData.is[1] =  streamReadBool(streamId)    -- front diff
  self.vData.is[2] =  streamReadBool(streamId)    -- back diff
  self.vData.is[3] =  streamReadInt8(streamId)    -- drive mode
  self.vData.is[4] =  streamReadFloat32(streamId) -- snap angle
  self.vData.is[5] =  streamReadBool(streamId)    -- snap.enable
  self.vData.is[6] =  streamReadBool(streamId)    -- snap on track
  self.vData.is[7] =  streamReadFloat32(streamId) -- snap track px
  self.vData.is[8] =  streamReadFloat32(streamId) -- snap track pz
  self.vData.is[9] =  streamReadFloat32(streamId) -- snap track dX
  self.vData.is[10] = streamReadFloat32(streamId) -- snap track dZ
  self.vData.is[11] = streamReadFloat32(streamId) -- snap track snap x
  self.vData.is[12] = streamReadFloat32(streamId) -- snap track snap z
  self.vData.is[13] = streamReadBool(streamId)    -- parking brake on
  self.vData.is[14] = streamReadFloat32(streamId) -- odoMeter
  self.vData.is[15] = streamReadFloat32(streamId) -- tripMeter
  self.vData.is[16] = streamReadInt8(streamId)    -- odo mode

  if self.isClient then
    self.vData.want = { unpack(self.vData.is) }
  end

--  if debug then print(DebugUtil.printTableRecursively(self.vData, 0, 0, 2)) end
end

-- #############################################################################

function FS25_EnhancedVehicle:onWriteStream(streamId, connection)
  if debug > 1 then print("-> " .. myName .. ": onWriteStream - " .. streamId .. mySelf(self)) end

  -- send initial data to client
  streamWriteBool(streamId,    self.vData.is[1])
  streamWriteBool(streamId,    self.vData.is[2])
  streamWriteInt8(streamId,    self.vData.is[3])
  streamWriteFloat32(streamId, self.vData.is[4])
  streamWriteBool(streamId,    self.vData.is[5])
  streamWriteBool(streamId,    self.vData.is[6])
  streamWriteFloat32(streamId, self.vData.is[7])
  streamWriteFloat32(streamId, self.vData.is[8])
  streamWriteFloat32(streamId, self.vData.is[9])
  streamWriteFloat32(streamId, self.vData.is[10])
  streamWriteFloat32(streamId, self.vData.is[11])
  streamWriteFloat32(streamId, self.vData.is[12])
  streamWriteBool(streamId,    self.vData.is[13])
  streamWriteFloat32(streamId, self.vData.is[14])
  streamWriteFloat32(streamId, self.vData.is[15])
  streamWriteInt8(streamId,    self.vData.is[16])
end

-- #############################################################################

function FS25_EnhancedVehicle:onReadUpdateStream(streamId, timestamp, connection)
  if debug > 2 then print("-> " .. myName .. ": onReadUpdateStream - " .. streamId .. mySelf(self)) end

  -- only receive our odo/tripMeter updates
  if connection:getIsServer() then
    if streamReadBool(streamId) then
      self.vData.want[14] = streamReadFloat32(streamId)
      self.vData.want[15] = streamReadFloat32(streamId)
    end
  end

  if self.isClient then
    self.vData.is[14] = self.vData.want[14]
    self.vData.is[15] = self.vData.want[15]
  end
end

-- #############################################################################

function FS25_EnhancedVehicle:onWriteUpdateStream(streamId, connection, dirtyMask)
  if debug > 2 then print("-> " .. myName .. ": onWriteUpdateStream - " .. streamId .. " / " .. dirtyMask .. mySelf(self)) end

  if not connection:getIsServer() then
    -- only sent our odo/tripMeter values
    if streamWriteBool(streamId, bitAND(dirtyMask, self.vData.dirtyFlag) ~= 0) then
      streamWriteFloat32(streamId, self.vData.want[14])
      streamWriteFloat32(streamId, self.vData.want[15])
    end
  end
end

-- #############################################################################

function FS25_EnhancedVehicle:onUpdate(dt)
  if debug > 2 then print("-> " .. myName .. ": onUpdate " .. dt .. ", S: " .. tostring(self.isServer) .. ", C: " .. tostring(self.isClient) .. mySelf(self)) end

  -- (client)
  if FS25_EnhancedVehicle.functionSnapIsEnabled and self.isClient then
    -- delayed onPostDetach
    if self.vData.triggerCalculate and self.vData.triggerCalculateTime < g_currentMission.time then
      self.vData.triggerCalculate = false

      self.vData.opModeOld = self.vData.opMode
      if self.vData.opMode > 0 then self.vData.opMode = 1 end
      FS25_EnhancedVehicle:enumerateImplements(self)
    end

    -- get current vehicle position, direction
    local isControlled = self.getIsControlled ~= nil and self:getIsControlled()
    local isEntered = self.getIsEntered ~= nil and self:getIsEntered()
		if isControlled and isEntered then

      -- position, direction, rotation
      self.vData.px, self.vData.py, self.vData.pz = localToWorld(self.rootNode, 0, 0, 0)
      self.vData.dx, self.vData.dy, self.vData.dz = localDirectionToWorld(self.rootNode, 0, 0, 1)
      local length = MathUtil.vector2Length(self.vData.dx, self.vData.dz);
      self.vData.dirX = self.vData.dx / length
      self.vData.dirZ = self.vData.dz / length

      -- calculate current rotation, including if cabin is rotated -> direction should rotate also
      local rot = Direction2RotationDeg(self.vData.dx, self.vData.dz, self.spec_drivable.reverserDirection)
      self.vData.rot = NormalizeAngle(Round(rot, 1))

      -- when track assistant is active and calculated
      if self.vData.opMode == 2 and self.vData.track.isCalculated then

        -- is a plow attached?
        if self.vData.impl.plow ~= nil then
          if self.vData.impl.plow.rotationMax ~= self.vData.track.plow then
            self.vData.track.plow = self.vData.impl.plow.rotationMax
            self.vData.impl.offset = -self.vData.impl.offset
            self.vData.track.offset = -self.vData.track.offset
            FS25_EnhancedVehicle:updateTrack(self, false, 0, false, 0, true, 0)
          end
        end

        -- get distance to end-of-field each second
        if self.vData.track.eofNext < g_currentMission.time then
          FS25_EnhancedVehicle:getHeadlandDistance(self)
          self.vData.track.eofNext = g_currentMission.time + 500

          -- play sound
          if self.vData.is[5] and self.vData.is[6] then
            if self.vData.track.headlandMode >= 1 and self.vData.track.isOnField > 5 and self.vData.track.eofDistance > 0 then
              if self.vData.track.eofDistance < FS25_EnhancedVehicle.track.headlandSoundTriggerDistance then
                if self.vData.track.hl_samplePlayed == nil then
                  playSample(FS25_EnhancedVehicle.sounds["hl_approach"], 1, Between(FS25_EnhancedVehicle.sfx_volume.hl_approach, 0, 10), 0, 0, 0)
                  self.vData.track.hl_samplePlayed = true
                end
              else
                self.vData.track.hl_samplePlayed = nil
              end
            end
          end
        end

        -- headland management
        if self.vData.is[5] and self.vData.is[6] then
          local isOnField = FS25_EnhancedVehicle:getHeadlandInfo(self)
          if self.vData.track.isOnField <= 5 and isOnField then
            if math.abs(self.vData.rot - self.vData.is[4]) <= 0.5 then
              self.vData.track.isOnField = self.vData.track.isOnField + 1
              if debug > 1 then print("Headland: enter field") end
            end
          end
          if self.vData.track.isOnField > 5 and not isOnField then
            self.vData.track.isOnField = 0
            if debug > 1 then print("Headland: left field") end

            -- handle headland
            if self.vData.track.headlandMode <= 1 then
              if debug > 1 then print("Headland: do nothing") end
            elseif self.vData.track.headlandMode == 2 then
              if debug > 1 then print("Headland: turn around") end
              FS25_EnhancedVehicle.onActionCall(self, "FS25_EnhancedVehicle_SNAP_REVERSE", 0, 0, 0, 0)
            elseif self.vData.track.headlandMode == 3 then
              if debug > 1 then print("Headland: disable cruise control") end
              if self.spec_drivable ~= nil and self.spec_drivable.cruiseControl ~= nil then
                if self.spec_drivable.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_OFF then
                  self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
                end
              end
            end
          end
        end -- <- end headland
      else
        self.vData.track.eofDistance = -1
      end -- <- end track assistant
    end
  end

  -- server only ->
  if self.isServer and self.vData ~= nil then
    -- process odo/tripMeter
    if FS25_EnhancedVehicle.functionOdoMeterIsEnabled and self:getIsMotorStarted() then
      if self.lastMovedDistance > 0.001 then
        self.vData.want[14] = self.vData.want[14] + self.lastMovedDistance
        self.vData.want[15] = self.vData.want[15] + self.lastMovedDistance
        -- do we want to send an update of values?
        if math.abs(self.vData.want[14] - self.vData.odoDistanceSent) > self.vData.networkThreshold then
          self:raiseDirtyFlags(self.vData.dirtyFlag)
          self.vData.odoDistanceSent = self.vData.want[14]
        end
        if math.abs(self.vData.want[15] - self.vData.tripDistanceSent) > self.vData.networkThreshold then
          self:raiseDirtyFlags(self.vData.dirtyFlag)
          self.vData.tripDistanceSent = self.vData.want[15]
        end
      end
    end

    -- (server) process changes between "is" and "want"
    FS25_EnhancedVehicle:updatevData(self)
  end
end

-- #############################################################################

function FS25_EnhancedVehicle:updatevData(self)
  if debug > 2 then print("-> " .. myName .. ": updatevData ".. mySelf(self)) end

  -- snap angle change
  if self.vData.is[4] ~= self.vData.want[4] then
    if FS25_EnhancedVehicle.functionSnapIsEnabled then
      if debug > 0 then print("--> ("..self.rootNode..") changed snap angle to: "..self.vData.want[4]) end
    end
    self.vData.is[4] = self.vData.want[4]
  end

  -- snap.enable
  if self.vData.is[5] ~= self.vData.want[5] then
    if FS25_EnhancedVehicle.functionSnapIsEnabled then
      if self.vData.want[5] then
        if debug > 0 then print("--> ("..self.rootNode..") changed snap enable to: ON") end
      else
        if debug > 0 then print("--> ("..self.rootNode..") changed snap enable to: OFF") end
      end
    end
    self.vData.is[5] = self.vData.want[5]
  end

  -- snap on track
  if self.vData.is[6] ~= self.vData.want[6] then
    if FS25_EnhancedVehicle.functionSnapIsEnabled then
      if self.vData.want[6] then
        if debug > 0 then print("--> ("..self.rootNode..") changed snap on track to: ON") end
      else
        if debug > 0 then print("--> ("..self.rootNode..") changed snap on track to: OFF") end
      end
    end
    self.vData.is[6] = self.vData.want[6]
  end

  -- snap track x
  if self.vData.is[7] ~= self.vData.want[7] then
    if FS25_EnhancedVehicle.functionSnapIsEnabled then
      if debug > 0 then print("--> ("..self.rootNode..") changed track px: "..self.vData.want[7]) end
    end
    self.vData.is[7] = self.vData.want[7]
  end

  -- snap track z
  if self.vData.is[8] ~= self.vData.want[8] then
    if FS25_EnhancedVehicle.functionSnapIsEnabled then
      if debug > 0 then print("--> ("..self.rootNode..") changed track pz: "..self.vData.want[8]) end
    end
    self.vData.is[8] = self.vData.want[8]
  end

  -- snap track dX
  if self.vData.is[9] ~= self.vData.want[9] then
    if FS25_EnhancedVehicle.functionSnapIsEnabled then
      if debug > 0 then print("--> ("..self.rootNode..") changed track dX: "..self.vData.want[9]) end
    end
    self.vData.is[9] = self.vData.want[9]
  end

  -- snap track dZ
  if self.vData.is[10] ~= self.vData.want[10] then
    if FS25_EnhancedVehicle.functionSnapIsEnabled then
      if debug > 0 then print("--> ("..self.rootNode..") changed track dZ: "..self.vData.want[10]) end
    end
    self.vData.is[10] = self.vData.want[10]
  end

  -- snap track mpx
  if self.vData.is[11] ~= self.vData.want[11] then
    if FS25_EnhancedVehicle.functionSnapIsEnabled then
      if debug > 0 then print("--> ("..self.rootNode..") changed track snap x: "..self.vData.want[11]) end
    end
    self.vData.is[11] = self.vData.want[11]
  end

  -- snap track mpz
  if self.vData.is[12] ~= self.vData.want[12] then
    if FS25_EnhancedVehicle.functionSnapIsEnabled then
      if debug > 0 then print("--> ("..self.rootNode..") changed track snap z: "..self.vData.want[12]) end
    end
    self.vData.is[12] = self.vData.want[12]
  end

  -- front diff
  if self.vData.is[1] ~= self.vData.want[1] then
    if FS25_EnhancedVehicle.functionDiffIsEnabled then
      if self.vData.want[1] then
        updateDifferential(self.rootNode, 0, self.vData.torqueRatio[1], 1)
        if debug > 0 then print("--> ("..self.rootNode..") changed front diff to: ON") end
      else
        updateDifferential(self.rootNode, 0, self.vData.torqueRatio[1], self.vData.maxSpeedRatio[1] * 1000)
        if debug > 0 then print("--> ("..self.rootNode..") changed front diff to: OFF") end
      end
    end
    self.vData.is[1] = self.vData.want[1]
  end

  -- back diff
  if self.vData.is[2] ~= self.vData.want[2] then
    if FS25_EnhancedVehicle.functionDiffIsEnabled then
      if self.vData.want[2] then
        updateDifferential(self.rootNode, 1, self.vData.torqueRatio[2], 1)
        if debug > 0 then print("--> ("..self.rootNode..") changed back diff to: ON") end
      else
        updateDifferential(self.rootNode, 1, self.vData.torqueRatio[2], self.vData.maxSpeedRatio[2] * 1000)
        if debug > 0 then print("--> ("..self.rootNode..") changed back diff to: OFF") end
      end
    end
    self.vData.is[2] = self.vData.want[2]
  end

  -- wheel drive mode
  if self.vData.is[3] ~= self.vData.want[3] then
    if FS25_EnhancedVehicle.functionDiffIsEnabled then
      if self.vData.want[3] == 0 then
        updateDifferential(self.rootNode, 2, -0.00001, 1)
        if debug > 0 then print("--> ("..self.rootNode..") changed wheel drive mode to: 2WD") end
      elseif self.vData.want[3] == 1 then
        updateDifferential(self.rootNode, 2, self.vData.torqueRatio[3], 1)
        if debug > 0 then print("--> ("..self.rootNode..") changed wheel drive mode to: 4WD") end
      elseif self.vData.want[3] == 2 then
        updateDifferential(self.rootNode, 2, 1, 0)
        if debug > 0 then print("--> ("..self.rootNode..") changed wheel drive mode to: FWD") end
      end
    end
    self.vData.is[3] = self.vData.want[3]
  end

  -- park brake on
  if self.vData.is[13] ~= self.vData.want[13] then
    if FS25_EnhancedVehicle.functionParkingBrakeIsEnabled then
      if self.vData.want[13] then
        if debug > 0 then print("--> ("..self.rootNode..") changed park on to: ON") end
      else
        if debug > 0 then print("--> ("..self.rootNode..") changed park on to: OFF") end
      end
    end
    self.vData.is[13] = self.vData.want[13]
  end

  -- odoMeter
  if self.vData.is[14] ~= self.vData.want[14] then
    if FS25_EnhancedVehicle.functionOdoMeterIsEnabled then
      if debug > 2 then print("--> ("..self.rootNode..") changed odoMeter: "..self.vData.want[14]) end
    end
    self.vData.is[14] = self.vData.want[14]
  end

  -- tripMeter
  if self.vData.is[15] ~= self.vData.want[15] then
    if FS25_EnhancedVehicle.functionOdoMeterIsEnabled then
      if debug > 2 then print("--> ("..self.rootNode..") changed tripMeter: "..self.vData.want[15]) end
    end
    self.vData.is[15] = self.vData.want[15]
  end

  -- odoMode
  if self.vData.is[16] ~= self.vData.want[16] then
    if FS25_EnhancedVehicle.functionOdoMeterIsEnabled then
      if debug > 0 then print("--> ("..self.rootNode..") changed odo mode: "..self.vData.want[16]) end
    end
    self.vData.is[16] = self.vData.want[16]
  end
end

-- #############################################################################

function FS25_EnhancedVehicle:drawVisualizationLines(_step, _segments, _x, _y, _z, _dX, _dZ, _length, _colorR, _colorG, _colorB, _addY, _spikes, _spikeHeight)
  local p1 = { x = _x, y = _y, z = _z }
  local p2
  -- For-loop instead of recursion
  for i = _step, _segments do
    p2 = { x = p1.x + _dX * _length, y = p1.y, z = p1.z + _dZ * _length }
    p2.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p2.x, 0, p2.z) + _addY
    drawDebugLine(p1.x, p1.y, p1.z, _colorR, _colorG, _colorB, p2.x, p2.y, p2.z, _colorR, _colorG, _colorB)
    if _spikes then
      drawDebugLine(p2.x, p2.y, p2.z, _colorR, _colorG, _colorB, p2.x, p2.y + _spikeHeight, p2.z, _colorR, _colorG, _colorB)
    end
    p1 = p2
  end
end

-- #############################################################################

function FS25_EnhancedVehicle:onDraw()
  if debug > 2 then print("-> " .. myName .. ": onDraw, S: " .. tostring(self.isServer) .. ", C: " .. tostring(self.isClient) .. mySelf(self)) end

  -- only on client side and GUI is visible
  if self.isClient and not g_gui:getIsGuiVisible() and self:getIsControlled() then
    -- update current track
    local dx, dz = 0, 0
    if FS25_EnhancedVehicle.functionSnapIsEnabled and self.vData.track.isCalculated then
      -- calculate track number in direction left-right and forward-backward
      dx, dz = self.vData.px - self.vData.track.origin.px, self.vData.pz - self.vData.track.origin.pz
      -- with original track orientation
      local dotLR = dx * -self.vData.track.origin.originaldZ + dz * self.vData.track.origin.originaldX
      self.vData.track.originalTrackLR = dotLR / self.vData.track.workWidth
    end

    -- draw lines
    if FS25_EnhancedVehicle.functionSnapIsEnabled then

      -- should we hide lines?
      local _showLines = true
      if FS25_EnhancedVehicle.track.hideLines then
        if self.vData.is[5] and g_currentMission.time >= FS25_EnhancedVehicle.track.hideLinesAfterValue then
          _showLines = false
        end
      end

      -- draw helper line in front of vehicle
      if self.vData.opMode >= 1 then
        if _showLines and FS25_EnhancedVehicle.track.showLines ~= 2 then
          local p1 = { x = self.vData.px, y = self.vData.py, z = self.vData.pz }
          p1.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p1.x, 0, p1.z) + FS25_EnhancedVehicle.snap.distanceAboveGroundVehicleMiddleLine
          FS25_EnhancedVehicle:drawVisualizationLines(1,
            8,
            p1.x,
            p1.y,
            p1.z,
            self.vData.dirX,
            self.vData.dirZ,
            4,
            FS25_EnhancedVehicle.snap.colorVehicleMiddleLine[1], FS25_EnhancedVehicle.snap.colorVehicleMiddleLine[2], FS25_EnhancedVehicle.snap.colorVehicleMiddleLine[3],
            FS25_EnhancedVehicle.snap.distanceAboveGroundVehicleMiddleLine)
        end
      end

      -- snap to direction lines
      if self.vData.opMode >= 1 and self.vData.impl.isCalculated and self.vData.impl.workWidth > 0 and _showLines and (FS25_EnhancedVehicle.track.showLines == 1 or FS25_EnhancedVehicle.track.showLines == 4) then

        -- for debuging headland detection trigger
--        if self.vData.hlx ~= nil and self.vData.hlz ~= nil then
--          FS25_EnhancedVehicle:drawVisualizationLines(1, 2, self.vData.hlx, self.vData.py, self.vData.hlz, 0, 0, 1, (self.vData.isOnField and 1 or 0), (self.vData.isOnField and 1 or 0), 1, 0, true, 5)
--        end

        -- left line beside vehicle
        local p1 = { x = self.vData.px, y = self.vData.py, z = self.vData.pz }
        p1.x = p1.x + (-self.vData.dirZ * self.vData.impl.workWidth / 2) - (-self.vData.dirZ * self.vData.impl.offset)
        p1.z = p1.z + ( self.vData.dirX * self.vData.impl.workWidth / 2) - ( self.vData.dirX * self.vData.impl.offset)
        p1.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p1.x, 0, p1.z) + FS25_EnhancedVehicle.snap.distanceAboveGroundVehicleSideLine
        FS25_EnhancedVehicle:drawVisualizationLines(1,
          20,
          p1.x,
          p1.y,
          p1.z,
          self.vData.dirX,
          self.vData.dirZ,
          4,
          FS25_EnhancedVehicle.snap.colorVehicleSideLine[1], FS25_EnhancedVehicle.snap.colorVehicleSideLine[2], FS25_EnhancedVehicle.snap.colorVehicleSideLine[3],
          FS25_EnhancedVehicle.snap.distanceAboveGroundVehicleSideLine, (FS25_EnhancedVehicle.snap.attachmentSpikeHeight > 0), FS25_EnhancedVehicle.snap.attachmentSpikeHeight)

        -- right line beside vehicle
        local p1 = { x = self.vData.px, y = self.vData.py, z = self.vData.pz }
        p1.x = p1.x - (-self.vData.dirZ * self.vData.impl.workWidth / 2) - (-self.vData.dirZ * self.vData.impl.offset)
        p1.z = p1.z - ( self.vData.dirX * self.vData.impl.workWidth / 2) - ( self.vData.dirX * self.vData.impl.offset)
        p1.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p1.x, 0, p1.z) + FS25_EnhancedVehicle.snap.distanceAboveGroundVehicleSideLine
        FS25_EnhancedVehicle:drawVisualizationLines(1,
          20,
          p1.x,
          p1.y,
          p1.z,
          self.vData.dirX,
          self.vData.dirZ,
          4,
          FS25_EnhancedVehicle.snap.colorVehicleSideLine[1], FS25_EnhancedVehicle.snap.colorVehicleSideLine[2], FS25_EnhancedVehicle.snap.colorVehicleSideLine[3],
          FS25_EnhancedVehicle.snap.distanceAboveGroundVehicleSideLine, (FS25_EnhancedVehicle.snap.attachmentSpikeHeight > 0), FS25_EnhancedVehicle.snap.attachmentSpikeHeight)

        -- draw attachment left helper line
        if self.vData.impl.left.marker ~= nil then
          p1.x, p1.y, p1.z = localToWorld(self.vData.impl.left.marker, 0, 0, 0)
          p1.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p1.x, 0, p1.z) + FS25_EnhancedVehicle.snap.distanceAboveGroundAttachmentSideLine
          local _dx, _, _dz = localDirectionToWorld(self.vData.impl.left.marker, 0, 0, 1)
          local _length = MathUtil.vector2Length(_dx, _dz);
          FS25_EnhancedVehicle:drawVisualizationLines(1,
            4,
            p1.x,
            p1.y,
            p1.z,
            _dx / _length,
            _dz / _length,
            4,
            FS25_EnhancedVehicle.snap.colorAttachmentSideLine[1], FS25_EnhancedVehicle.snap.colorAttachmentSideLine[2], FS25_EnhancedVehicle.snap.colorAttachmentSideLine[3],
            FS25_EnhancedVehicle.snap.distanceAboveGroundAttachmentSideLine)
        end

        -- draw attachment right helper line
        if self.vData.impl.right.marker ~= nil then
          p1.x, p1.y, p1.z = localToWorld(self.vData.impl.right.marker, 0, 0, 0)
          p1.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p1.x, 0, p1.z) + FS25_EnhancedVehicle.snap.distanceAboveGroundAttachmentSideLine
          local _dx, _, _dz = localDirectionToWorld(self.vData.impl.right.marker, 0, 0, 1)
          local _length = MathUtil.vector2Length(_dx, _dz);
          FS25_EnhancedVehicle:drawVisualizationLines(1,
            4,
            p1.x,
            p1.y,
            p1.z,
            _dx / _length,
            _dz / _length,
            4,
            FS25_EnhancedVehicle.snap.colorAttachmentSideLine[1], FS25_EnhancedVehicle.snap.colorAttachmentSideLine[2], FS25_EnhancedVehicle.snap.colorAttachmentSideLine[3],
            FS25_EnhancedVehicle.snap.distanceAboveGroundAttachmentSideLine)
        end
      end -- <- end of draw snap to direction lines

      -- draw our tracks
      if self.vData.opMode == 2 and self.vData.track.isCalculated and _showLines and (FS25_EnhancedVehicle.track.showLines == 1 or FS25_EnhancedVehicle.track.showLines == 3) then
        -- calculate track number in direction left-right and forward-backward
        -- with current track orientation
        local dotLR = dx * -self.vData.track.origin.dZ + dz * self.vData.track.origin.dX
        local dotFB = dx * -self.vData.track.origin.dX - dz * self.vData.track.origin.dZ
        local dir = 1
        if math.abs(dotFB - self.vData.track.dotFBPrev) > 0.001 then
          if dotFB > self.vData.track.dotFBPrev then
            dir = -1
          else
            dir = 1
          end
        end
        self.vData.track.dotFBPrev = dotFB  -- we need to save this for detecting forward/backward movement

        -- we're in this track numbers on a global scale
        self.vData.track.trackLR = dotLR / self.vData.track.workWidth
        self.vData.track.trackFB = dotFB / self.vData.track.workWidth

        -- do we move in original grid orientation direction?
        self.vData.track.drivingDir = self.vData.track.trackLR - self.vData.track.originalTrackLR
        if self.vData.track.drivingDir == 0 then self.vData.track.drivingDir = 1 else self.vData.track.drivingDir = -1 end

        -- prepare for rendering
        local trackFB = dir * 1.5 + self.vData.track.trackFB
        local trackLRMiddle = Round(self.vData.track.trackLR, 0)
        local trackLRLanes  = trackLRMiddle - math.floor(1 - FS25_EnhancedVehicle.track.numberOfTracks / 2) + 0.5
        local trackLRText   = Round(self.vData.track.originalTrackLR , 0) - math.floor(1 - FS25_EnhancedVehicle.track.numberOfTracks / 2)

        -- draw middle line
        local startX = self.vData.track.origin.px + (-self.vData.track.origin.dZ * (trackLRMiddle * self.vData.track.workWidth)) - ( self.vData.track.origin.dX * (trackFB * self.vData.track.workWidth))
        local startZ = self.vData.track.origin.pz + ( self.vData.track.origin.dX * (trackLRMiddle * self.vData.track.workWidth)) - ( self.vData.track.origin.dZ * (trackFB * self.vData.track.workWidth))
        local startY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, startX, 0, startZ) + FS25_EnhancedVehicle.track.distanceAboveGround
        FS25_EnhancedVehicle:drawVisualizationLines(1,
          12,
          startX,
          startY,
          startZ,
          self.vData.track.origin.dX,
          self.vData.track.origin.dZ,
          self.vData.track.workWidth * dir,
          FS25_EnhancedVehicle.track.color[1] / 2,
          FS25_EnhancedVehicle.track.color[2] / 2,
          FS25_EnhancedVehicle.track.color[3] / 2,
          FS25_EnhancedVehicle.track.distanceAboveGround)

        -- draw offset line
        if self.vData.track.offset > 0.01 or self.vData.track.offset < -0.01 then
          startX = startX + (-self.vData.track.origin.dZ * self.vData.track.offset)
          startZ = startZ + ( self.vData.track.origin.dX * self.vData.track.offset)
          startY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, startX, 0, startZ) + FS25_EnhancedVehicle.track.distanceAboveGround
          FS25_EnhancedVehicle:drawVisualizationLines(1,
            12,
            startX,
            startY,
            startZ,
            self.vData.track.origin.dX,
            self.vData.track.origin.dZ,
            self.vData.track.workWidth * dir,
            0,
            0.75,
            0,
            FS25_EnhancedVehicle.track.distanceAboveGround)
        end

        -- prepare for track numbers
        local activeCamera = self:getActiveCamera()
        local rx, ry, rz = getWorldRotation(activeCamera.cameraNode)
        setTextAlignment(RenderText.ALIGN_CENTER)

        -- draw lines
        local _s = math.floor(1 - FS25_EnhancedVehicle.track.numberOfTracks / 2)
        for i = _s, (_s + FS25_EnhancedVehicle.track.numberOfTracks), 1 do
          trackFB = dir * 0.5 + self.vData.track.trackFB
          local trackTextFB = trackFB
          local segments = 10

          -- middle segment of tracks -> draw longer lines
          if i == 0 or i == 1 then
            trackFB = trackFB + 1.0 * dir
            segments = 12
          end

          -- move track text "backwards"
          if i == 0 then
            trackTextFB = trackTextFB + 1.0 * dir
          end

          -- start coordinates of line
          startX = self.vData.track.origin.px + (-self.vData.track.origin.dZ * (trackLRLanes * self.vData.track.workWidth)) - ( self.vData.track.origin.dX * (trackFB * self.vData.track.workWidth))
          startZ = self.vData.track.origin.pz + ( self.vData.track.origin.dX * (trackLRLanes * self.vData.track.workWidth)) - ( self.vData.track.origin.dZ * (trackFB * self.vData.track.workWidth))
          startY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, startX, 0, startZ) + FS25_EnhancedVehicle.track.distanceAboveGround

          -- draw the line
          FS25_EnhancedVehicle:drawVisualizationLines(1,
            segments,
            startX,
            startY,
            startZ,
            self.vData.track.origin.dX,
            self.vData.track.origin.dZ,
            self.vData.track.workWidth * dir,
            FS25_EnhancedVehicle.track.color[1],
            FS25_EnhancedVehicle.track.color[2],
            FS25_EnhancedVehicle.track.color[3],
            FS25_EnhancedVehicle.track.distanceAboveGround, (FS25_EnhancedVehicle.snap.trackSpikeHeight > 0), FS25_EnhancedVehicle.snap.trackSpikeHeight)

          -- coordinates for track number text
          local textX = self.vData.track.origin.px + (-self.vData.track.origin.originaldZ * (trackLRText * self.vData.track.workWidth)) - ( self.vData.track.origin.dX * (trackTextFB * self.vData.track.workWidth))
          local textZ = self.vData.track.origin.pz + ( self.vData.track.origin.originaldX * (trackLRText * self.vData.track.workWidth)) - ( self.vData.track.origin.dZ * (trackTextFB * self.vData.track.workWidth))
          local textY = 0.1 + getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, textX, 0, textZ) + FS25_EnhancedVehicle.track.distanceAboveGround

          -- render track number
          if i < _s + FS25_EnhancedVehicle.track.numberOfTracks then
            local _curTrack = math.floor(trackLRText)
            if Round(self.vData.track.originalTrackLR, 0) + self.vData.track.deltaTrack == _curTrack then
              setTextBold(true)
              if self.vData.is[5] then
                setTextColor(0, 0.7, 0, 1)
              else
                setTextColor(1, 1, 1, 1)
              end
            else
              setTextBold(false)
              setTextColor(FS25_EnhancedVehicle.track.color[1], FS25_EnhancedVehicle.track.color[2], FS25_EnhancedVehicle.track.color[3], 1)
            end
            renderText3D(textX, textY, textZ, rx, ry, rz, FS25_EnhancedVehicle.fS * Between(self.vData.track.workWidth * 5, 40, 90), tostring(_curTrack))
          end

          -- advance to next lane
          trackLRLanes = trackLRLanes - 1
          trackLRText = trackLRText - 1
        end -- <- end of loop for lines
      end -- <- end of draw tracks
    end -- <- end of snapIsEnabled

    -- reset text stuff to "defaults"
    setTextColor(1,1,1,1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextBold(false)
  end
end

-- #############################################################################

function FS25_EnhancedVehicle:onEnterVehicle()
  if debug > 1 then print("-> " .. myName .. ": onEnterVehicle" .. mySelf(self)) end

  -- update work width for snap lines
  FS25_EnhancedVehicle:enumerateImplements(self)
end

-- #############################################################################

function FS25_EnhancedVehicle:onLeaveVehicle()
  if debug > 1 then print("-> " .. myName .. ": onLeaveVehicle" .. mySelf(self)) end

--[[
  -- disable snap if you leave a vehicle
  if self.vData.is[5] then
    self.vData.want[5] = false
    self.vData.want[6] = false
    if self.isClient and not self.isServer then
      self.vData.is[5] = self.vData.want[5]
      self.vData.is[6] = self.vData.want[6]
    end
    FS25_EnhancedVehicle_Event.sendEvent(self, unpack(self.vData.want))
  end

  -- update work width for snap lines
  FS25_EnhancedVehicle:enumerateImplements(self)
]]--

  -- hide some HUD elements
  FS25_EnhancedVehicle.ui_hud:hideSomething(self)
end

-- #############################################################################

function FS25_EnhancedVehicle:onPostAttachImplement(implementIndex)
  if debug > 1 then print("-> " .. myName .. ": onPostAttachImplement" .. mySelf(self)) end

  -- update work width for snap lines
  FS25_EnhancedVehicle:enumerateImplements(self)

  -- restore old state
  if self.vData.opModeOld ~= nil then --and self.vData.opMode ~= 2track.isVisible then
    self.vData.opMode = self.vData.opModeOld
    self.vData.opModeOld = nil
  end
end

-- #############################################################################

function FS25_EnhancedVehicle:onPostDetachImplement(implementIndex)
  if debug > 1 then print("-> " .. myName .. ": onPostDetachImplement" .. mySelf(self)) end

  self.vData.triggerCalculate = true
  self.vData.triggerCalculateTime = g_currentMission.time + 1*1000
end

-- #############################################################################

function FS25_EnhancedVehicle:onRegisterActionEvents(isSelected, isOnActiveVehicle)
  if debug > 1 then print("-> " .. myName .. ": onRegisterActionEvents " .. tostring(isSelected) .. ", " .. tostring(isOnActiveVehicle) .. ", S: " .. tostring(self.isServer) .. ", C: " .. tostring(self.isClient) .. mySelf(self)) end

  -- continue on client side only
  if not self.isClient then -- or not self:getIsActiveForInput(true, true)
    return
  end

  -- only in active vehicle and when we control it
  if isOnActiveVehicle and self:getIsControlled() then

    -- assemble list of actions to attach
    local actionList = {}
    for _, v in ipairs(FS25_EnhancedVehicle.actions.global) do
      table.insert(actionList, v)
    end
    if FS25_EnhancedVehicle.functionSnapIsEnabled then
      for _, v in ipairs(FS25_EnhancedVehicle.actions.snap) do
        table.insert(actionList, v)
      end
    end
    if FS25_EnhancedVehicle.functionDiffIsEnabled then
      for _, v in ipairs(FS25_EnhancedVehicle.actions.diff) do
        table.insert(actionList, v)
      end
    end
    if FS25_EnhancedVehicle.functionHydraulicIsEnabled then
      for _, v in ipairs(FS25_EnhancedVehicle.actions.hydraulic) do
        table.insert(actionList, v)
      end
    end
    if FS25_EnhancedVehicle.functionParkingBrakeIsEnabled then
      for _, v in ipairs(FS25_EnhancedVehicle.actions.park) do
        table.insert(actionList, v)
      end
    end
    if FS25_EnhancedVehicle.functionOdoMeterIsEnabled then
      for _, v in ipairs(FS25_EnhancedVehicle.actions.odo) do
        table.insert(actionList, v)
      end
    end

      -- attach our actions
    for _ ,actionName in pairs(actionList) do
      if actionName == "FS25_EnhancedVehicle_SNAP_TRACKP" or
         actionName == "FS25_EnhancedVehicle_SNAP_TRACKW" or
         actionName == "FS25_EnhancedVehicle_SNAP_TRACKO" or
         actionName == "FS25_EnhancedVehicle_SNAP_OPMODE" or
         actionName == "FS25_EnhancedVehicle_ODO_MODE"    or
         actionName == "FS25_EnhancedVehicle_SNAP_ANGLE1" or
         actionName == "FS25_EnhancedVehicle_SNAP_ANGLE2" or
         actionName == "FS25_EnhancedVehicle_SNAP_ANGLE3"
      then
        local _, eventName = g_inputBinding:registerActionEvent(actionName, self, FS25_EnhancedVehicle.onActionCallDown, false, true, true, true)
        FS25_EnhancedVehicle:helpMenuPrio(actionName, eventName)
        local _, eventName = g_inputBinding:registerActionEvent(actionName, self, FS25_EnhancedVehicle.onActionCallUp, true, false, false, true)
        FS25_EnhancedVehicle:helpMenuPrio(actionName, eventName)
      else
        local _, eventName = g_inputBinding:registerActionEvent(actionName, self, FS25_EnhancedVehicle.onActionCall, false, true, false, true)
        FS25_EnhancedVehicle:helpMenuPrio(actionName, eventName)
      end
    end
  end
end

-- #############################################################################

function FS25_EnhancedVehicle:helpMenuPrio(actionName, eventName)
  -- help menu priorization
  if g_inputBinding ~= nil and g_inputBinding.events ~= nil and g_inputBinding.events[eventName] ~= nil then
    if (actionName == "FS25_EnhancedVehicle_MENU" or
       actionName == "FS25_EnhancedVehicle_PARK" or
       actionName == "FS25_EnhancedVehicle_SNAP_ONOFF" or
       actionName == "FS25_EnhancedVehicle_SNAP_REVERSE" or
       actionName == "FS25_EnhancedVehicle_SNAP_OPMODE") and
       FS25_EnhancedVehicle.showKeysInHelpMenu then
      g_inputBinding:setActionEventTextVisibility(eventName, true)
      g_inputBinding:setActionEventTextPriority(eventName, GS_PRIO_VERY_LOW)
    else
      g_inputBinding:setActionEventTextVisibility(eventName, false)
      g_inputBinding:setActionEventTextPriority(eventName, GS_PRIO_VERY_LOW)
    end
  end

--GS_PRIO_VERY_HIGH = 1
--GS_PRIO_HIGH = 2
--GS_PRIO_NORMAL = 3
--GS_PRIO_LOW = 4
--GS_PRIO_VERY_LOW = 5
end

-- #############################################################################

function FS25_EnhancedVehicle:onActionCallDown(actionName, keyStatus, arg4, arg5, arg6)
  if FS25_EnhancedVehicle.startActionTime == 0 then
    FS25_EnhancedVehicle.startActionTime = g_currentMission.time
  end

  if g_currentMission.time < FS25_EnhancedVehicle.nextActionTime then
    return
  else
    FS25_EnhancedVehicle.nextActionTime = g_currentMission.time + FS25_EnhancedVehicle.deltaActionTime
    if FS25_EnhancedVehicle.deltaActionTime >= FS25_EnhancedVehicle.minActionTime then
      FS25_EnhancedVehicle.deltaActionTime = FS25_EnhancedVehicle.deltaActionTime * 0.5
    end
  end

  FS25_EnhancedVehicle.onActionCall(self, actionName, keyStatus, arg4, arg5, arg6)
end

-- #############################################################################

function FS25_EnhancedVehicle:onActionCallUp(actionName, keyStatus, arg4, arg5, arg6)
  if debug > 1 then print("-> " .. myName .. ": onActionCallUp " .. actionName .. ", keyStatus: " .. keyStatus .. mySelf(self)) end

  -- switch operational mode (off -> snap direction -> snap track)
  if actionName == "FS25_EnhancedVehicle_SNAP_OPMODE" then
    if g_currentMission.time <= FS25_EnhancedVehicle.startActionTime + 1000 then

      if self.vData.opModeOld ~= nil then
        self.vData.opMode = self.vData.opModeOld
        self.vData.opModeOld = nil
      else
        self.vData.opMode = self.vData.opMode + 1
      end
      if self.vData.opMode > 2 then
        self.vData.opMode = 1
      end

      if self.vData.opMode == 1 then
        -- calculate work width
        if not self.vData.impl.isCalculated then
          FS25_EnhancedVehicle:enumerateImplements(self)
        end
      end

      if self.vData.opMode == 2 then
        -- recalculate track
        if not self.vData.track.isCalculated then
          FS25_EnhancedVehicle:calculateTrack(self)
        end
      end

      -- auto-hide lines
      if FS25_EnhancedVehicle.track.hideLines then
        FS25_EnhancedVehicle.track.hideLinesAfterValue = g_currentMission.time + 1000 * FS25_EnhancedVehicle.track.hideLinesAfter
      end
    end
  end

  -- switch odo mode
  if FS25_EnhancedVehicle.functionOdoMeterIsEnabled then
    if actionName == "FS25_EnhancedVehicle_ODO_MODE" then
      if g_currentMission.time <= FS25_EnhancedVehicle.startActionTime + 1000 then
        -- switch odo mode (odo <-> trip)
        self.vData.want[16] = (self.vData.want[16] + 1) % 2
        if self.isClient and not self.isServer then
          self.vData.is[16] = self.vData.want[16]
        end
        FS25_EnhancedVehicle_Event.sendEvent(self, unpack(self.vData.want))
      end
    end
  end

  -- reset key press delay
  FS25_EnhancedVehicle.startActionTime = 0
  FS25_EnhancedVehicle.nextActionTime  = 0
  FS25_EnhancedVehicle.deltaActionTime = 500
end

-- #############################################################################

function FS25_EnhancedVehicle:onActionCall(actionName, keyStatus, arg4, arg5, arg6)
  if debug > 1 then print("-> " .. myName .. ": onActionCall " .. actionName .. ", keyStatus: " .. keyStatus .. mySelf(self)) end
  if debug > 2 then
    print(arg4)
    print(arg5)
    print(arg6)
  end

  local _snap = false
  -- disable steering angle snap if user interacts
  if actionName == "AXIS_MOVE_SIDE_VEHICLE" and math.abs( keyStatus ) > 0.05 then
    if self.vData.is[5] then
      if FS25_EnhancedVehicle.sounds["snap_off"] ~= nil and FS25_EnhancedVehicle.soundIsOn and g_dedicatedServerInfo == nil then
        playSample(FS25_EnhancedVehicle.sounds["snap_off"], 1, Between(FS25_EnhancedVehicle.sfx_volume.track, 0, 10), 0, 0, 0)
      end

      self.vData.want[5] = false
      self.vData.want[6] = false
      _snap = true
    end
  elseif (actionName == "AXIS_ACCELERATE_VEHICLE" or actionName == "AXIS_BRAKE_VEHICLE") and self.vData.is[13] then
    if self.spec_motorized and self.spec_motorized:getIsOperating() then
      g_currentMission:showBlinkingWarning(g_i18n:getText("global_FS25_EnhancedVehicle_brakeBlocks"), 1500)
    end
  elseif actionName == "FS25_EnhancedVehicle_MENU" then
------------
--    print(DebugUtil.printTableRecursively(self, 0, 0, 2))
------------

    -- open configuration dialog
    if not self.isClient then
      return
    end

    if not g_currentMission.isSynchronizingWithPlayers then
      if not g_gui:getIsGuiVisible() then
        FS25_EnhancedVehicle.ui_menu:setVehicle(self)
        g_gui:showDialog("FS25_EnhancedVehicle_UI")
      end
    end
  elseif FS25_EnhancedVehicle.functionDiffIsEnabled and actionName == "FS25_EnhancedVehicle_FD" then
    -- front diff
    if FS25_EnhancedVehicle.sounds["diff_lock"] ~= nil and FS25_EnhancedVehicle.soundIsOn and g_dedicatedServerInfo == nil then
      playSample(FS25_EnhancedVehicle.sounds["diff_lock"], 1, Between(FS25_EnhancedVehicle.sfx_volume.diff, 0, 10), 0, 0, 0)
    end
    self.vData.want[1] = not self.vData.want[1]
    if self.isClient and not self.isServer then
      self.vData.is[1] = self.vData.want[1]
    end
    FS25_EnhancedVehicle_Event.sendEvent(self, unpack(self.vData.want))
  elseif FS25_EnhancedVehicle.functionDiffIsEnabled and actionName == "FS25_EnhancedVehicle_RD" then
    -- back diff
    if FS25_EnhancedVehicle.sounds["diff_lock"] ~= nil and FS25_EnhancedVehicle.soundIsOn and g_dedicatedServerInfo == nil then
      playSample(FS25_EnhancedVehicle.sounds["diff_lock"], 1, Between(FS25_EnhancedVehicle.sfx_volume.diff, 0, 10), 0, 0, 0)
    end
    self.vData.want[2] = not self.vData.want[2]
    if self.isClient and not self.isServer then
      self.vData.is[2] = self.vData.want[2]
    end
    FS25_EnhancedVehicle_Event.sendEvent(self, unpack(self.vData.want))
  elseif FS25_EnhancedVehicle.functionDiffIsEnabled and actionName == "FS25_EnhancedVehicle_BD" then
    -- both diffs
    if FS25_EnhancedVehicle.sounds["diff_lock"] ~= nil and FS25_EnhancedVehicle.soundIsOn and g_dedicatedServerInfo == nil then
      playSample(FS25_EnhancedVehicle.sounds["diff_lock"], 1, Between(FS25_EnhancedVehicle.sfx_volume.diff, 0, 10), 0, 0, 0)
    end
    self.vData.want[1] = not self.vData.want[2]
    self.vData.want[2] = not self.vData.want[2]
    if self.isClient and not self.isServer then
      self.vData.is[1] = self.vData.want[2]
      self.vData.is[2] = self.vData.want[2]
    end
    FS25_EnhancedVehicle_Event.sendEvent(self, unpack(self.vData.want))
  elseif FS25_EnhancedVehicle.functionDiffIsEnabled and actionName == "FS25_EnhancedVehicle_DM" then
    -- wheel drive mode
    if FS25_EnhancedVehicle.sounds["diff_lock"] ~= nil and FS25_EnhancedVehicle.soundIsOn and g_dedicatedServerInfo == nil then
      playSample(FS25_EnhancedVehicle.sounds["diff_lock"], 1, Between(FS25_EnhancedVehicle.sfx_volume.diff, 0, 10), 0, 0, 0)
    end
    self.vData.want[3] = self.vData.want[3] + 1
    if self.vData.want[3] > 1 then
      self.vData.want[3] = 0
    end
    if self.isClient and not self.isServer then
      self.vData.is[3] = self.vData.want[3]
    end
    FS25_EnhancedVehicle_Event.sendEvent(self, unpack(self.vData.want))
  elseif FS25_EnhancedVehicle.functionHydraulicIsEnabled and actionName == "FS25_EnhancedVehicle_AJ_REAR_UPDOWN" then
    -- rear hydraulic up/down
    FS25_EnhancedVehicle:enumerateAttachments(self)

    -- first the joints itsself
    local _updown = nil
    for _, _v in pairs(joints_back) do
      if _updown == nil then
        _updown = not _v[1].spec_attacherJoints.attacherJoints[_v[2]].moveDown
      end
      _v[1].spec_attacherJoints.setJointMoveDown(_v[1], _v[2], _updown)
      if debug > 1 then print("--> rear up/down: ".._v[1].rootNode.."/".._v[2].."/"..tostring(_updown) ) end
    end

    -- then the attached devices
    for _, object in pairs(implements_back) do
      if object.spec_attachable ~= nil then
        object.spec_attachable.setLoweredAll(object, _updown)
        if debug > 1 then print("--> rear up/down: "..object.rootNode.."/"..tostring(_updown) ) end
      end
    end
  elseif FS25_EnhancedVehicle.functionHydraulicIsEnabled and actionName == "FS25_EnhancedVehicle_AJ_FRONT_UPDOWN" then
    -- front hydraulic up/down
    FS25_EnhancedVehicle:enumerateAttachments(self)

    -- first the joints itsself
    local _updown = nil
    for _, _v in pairs(joints_front) do
      if _updown == nil then
        _updown = not _v[1].spec_attacherJoints.attacherJoints[_v[2]].moveDown
      end
      _v[1].spec_attacherJoints.setJointMoveDown(_v[1], _v[2], _updown)
      if debug > 1 then print("--> front up/down: ".._v[1].rootNode.."/".._v[2].."/"..tostring(_updown) ) end
    end

    -- then the attached devices
    for _, object in pairs(implements_front) do
      if object.spec_attachable ~= nil then
        object.spec_attachable.setLoweredAll(object, _updown)
        if debug > 1 then print("--> front up/down: "..object.rootNode.."/"..tostring(_updown) ) end
      end
    end
  elseif FS25_EnhancedVehicle.functionHydraulicIsEnabled and actionName == "FS25_EnhancedVehicle_AJ_REAR_ONOFF" then
    -- rear hydraulic on/off
    FS25_EnhancedVehicle:enumerateAttachments(self)

    for _, object in pairs(implements_back) do
      -- can it be turned off and on again
      if object.spec_turnOnVehicle ~= nil then
        -- new onoff status
        local _onoff = nil
        if _onoff == nil then
          _onoff = not object.spec_turnOnVehicle.isTurnedOn
        end
        if _onoff and object.spec_turnOnVehicle.requiresMotorTurnOn and self.spec_motorized and not self.spec_motorized:getIsOperating() then
          _onoff = false
        end

        -- set new onoff status
        object.spec_turnOnVehicle.setIsTurnedOn(object, _onoff)
        if debug > 1 then print("--> rear on/off: "..object.rootNode.."/"..tostring(_onoff)) end
      end
    end
  elseif FS25_EnhancedVehicle.functionHydraulicIsEnabled and actionName == "FS25_EnhancedVehicle_AJ_FRONT_ONOFF" then
    -- front hydraulic on/off
    FS25_EnhancedVehicle:enumerateAttachments(self)

    for _, object in pairs(implements_front) do
      -- can it be turned off and on again
      if object.spec_turnOnVehicle ~= nil then
        -- new onoff status
        local _onoff = nil
        if _onoff == nil then
          _onoff = not object.spec_turnOnVehicle.isTurnedOn
        end
        if _onoff and object.spec_turnOnVehicle.requiresMotorTurnOn and self.spec_motorized and not self.spec_motorized:getIsOperating() then
          _onoff = false
        end

        -- set new onoff status
        object.spec_turnOnVehicle.setIsTurnedOn(object, _onoff)

        if debug > 1 then print("--> front on/off: "..object.rootNode.."/"..tostring(_onoff)) end
      end
    end
  elseif FS25_EnhancedVehicle.functionHydraulicIsEnabled and actionName == "FS25_EnhancedVehicle_AJ_FRONT_FOLD" then
    -- front hydraulic fold/unfold
    FS25_EnhancedVehicle:enumerateAttachments(self)

    for _, object in pairs(implements_front) do
      -- can it be folded?
      if object.spec_foldable ~= nil then
        if object.spec_foldable.isFoldAllowed then
          local _newDirection = 0
          if object.spec_foldable.foldMoveDirection == 0 then
            -- if its not folding right now -> check if its lowered
            _newDirection = object.spec_foldable:getIsUnfolded() and 1 or -1
          else
            -- if its folding right now -> reverse
            _newDirection = object.spec_foldable.foldMoveDirection * -1
          end
          object.spec_foldable:setFoldState(_newDirection, false)
          if debug > 1 then print("--> front fold: "..object.rootNode.."/"..tostring(_newDirection)) end
        end
      end
    end
  elseif FS25_EnhancedVehicle.functionHydraulicIsEnabled and actionName == "FS25_EnhancedVehicle_AJ_REAR_FOLD" then
    -- rear hydraulic fold/unfold
    FS25_EnhancedVehicle:enumerateAttachments(self)

    for _, object in pairs(implements_back) do
      -- can it be folded?
      if object.spec_foldable ~= nil then
        if object.spec_foldable.isFoldAllowed then
          local _newDirection = 0
          if object.spec_foldable.foldMoveDirection == 0 then
            -- if its not folding right now -> check if its lowered
            _newDirection = object.spec_foldable:getIsUnfolded() and 1 or -1
          else
            -- if its folding right now -> reverse
            _newDirection = object.spec_foldable.foldMoveDirection * -1
          end
          object.spec_foldable:setFoldState(_newDirection, false)
          if debug > 1 then print("--> rear fold: "..object.rootNode.."/"..tostring(_newDirection)) end
        end
      end
    end
  elseif FS25_EnhancedVehicle.functionParkingBrakeIsEnabled and actionName == "FS25_EnhancedVehicle_PARK" then
    -- parking brake on/off
    if self.vData.is[13] and FS25_EnhancedVehicle.sounds["brakeOff"] ~= nil and FS25_EnhancedVehicle.soundIsOn and g_dedicatedServerInfo == nil then
      playSample(FS25_EnhancedVehicle.sounds["brakeOff"], 1, Between(FS25_EnhancedVehicle.sfx_volume.brake, 0, 10), 0, 0, 0)
    end
    if not self.vData.is[13] and FS25_EnhancedVehicle.sounds["brakeOn"] ~= nil and FS25_EnhancedVehicle.soundIsOn and g_dedicatedServerInfo == nil then
      playSample(FS25_EnhancedVehicle.sounds["brakeOn"], 1, Between(FS25_EnhancedVehicle.sfx_volume.brake, 0, 10), 0, 0, 0)
    end
    self.vData.want[13] = not self.vData.want[13]
    if self.isClient and not self.isServer then
      self.vData.is[13] = self.vData.want[13]
    end
    FS25_EnhancedVehicle_Event.sendEvent(self, unpack(self.vData.want))
  end

  -- snap direction/track assisstant -->
  if FS25_EnhancedVehicle.functionSnapIsEnabled then
    -- switch operational mode (off -> snap direction -> snap track)
    if actionName == "FS25_EnhancedVehicle_SNAP_OPMODE" then
      if g_currentMission.time > FS25_EnhancedVehicle.startActionTime + 1000 then
        if self.vData.opModeOld == nil then
          self.vData.opModeOld = self.vData.opMode
        end
        self.vData.opMode = 0
      end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_LINES_MODE" then
      -- Make the toggle of "show lines" behave in a slightly different sequence:
      --   hidden -> show yellow tracks -> show yellow tracks and vehicle red lines -> show vehicle red lines -> hidden
      local currentShowLines = FS25_EnhancedVehicle.track.showLines
      if     currentShowLines == 2 then
        FS25_EnhancedVehicle.track.showLines = 3
      elseif currentShowLines == 3 then
        FS25_EnhancedVehicle.track.showLines = 1
      elseif currentShowLines == 1 then
        FS25_EnhancedVehicle.track.showLines = 4
      else
        FS25_EnhancedVehicle.track.showLines = 2
      end
      lC:setConfigValue("track", "showLines", FS25_EnhancedVehicle.track.showLines)
    elseif actionName == "FS25_EnhancedVehicle_SNAP_ONOFF" then
      -- steering angle snap on/off
      if not self.vData.is[5] then
        if FS25_EnhancedVehicle.sounds["snap_on"] ~= nil and FS25_EnhancedVehicle.soundIsOn and g_dedicatedServerInfo == nil then
          playSample(FS25_EnhancedVehicle.sounds["snap_on"], 1, Between(FS25_EnhancedVehicle.sfx_volume.track, 0, 10), 0, 0, 0)
        end
        self.vData.want[5] = true

        -- turn on op mode if required
        if self.vData.opMode == 0 then self.vData.opMode = 1 end

        -- auto-hide lines
        if FS25_EnhancedVehicle.track.hideLines then
          FS25_EnhancedVehicle.track.hideLinesAfterValue = g_currentMission.time + 1000 * FS25_EnhancedVehicle.track.hideLinesAfter
        end

        -- calculate snap angle
        local snapToAngle = Between(Round(FS25_EnhancedVehicle.snap.snapToAngle, 0), 1, 90)
        self.vData.want[4] = Round(ClosestAngle(self.vData.rot, snapToAngle), 0)
        if self.vData.want[4] == 360 then self.vData.want[4] = 0 end

        -- if track is enabled -> set angle to track angle
        if self.vData.opMode == 2 and self.vData.track.isCalculated then
          self.vData.want[6] = true

          local lx,_,lz = localDirectionToWorld(self.rootNode, 0, 0, 1)
          local rot1 = Direction2RotationDeg(lx, lz, self.spec_drivable.reverserDirection)
          local rot2 = Direction2RotationDeg(self.vData.track.origin.dX, self.vData.track.origin.dZ)
          rot2 = ClosestAngle(rot2, 0.25)

          local diffdeg = rot1 - rot2
          if diffdeg > 180 then diffdeg = diffdeg - 360 end
          if diffdeg < -180 then diffdeg = diffdeg + 360 end

          -- when facing "backwards" -> flip grid
          if diffdeg < -90 or diffdeg > 90 then
            rot2 = NormalizeAngle(rot2 + 180)
          end
          FS25_EnhancedVehicle:updateTrack(self, true, rot2, false, 0, true, 0, 0)
          self.vData.want[4] = rot2

          -- update headland
          self.vData.track.isOnField = FS25_EnhancedVehicle:getHeadlandInfo(self) and 10 or 0
        end
      else
        if FS25_EnhancedVehicle.sounds["snap_off"] ~= nil and FS25_EnhancedVehicle.soundIsOn and g_dedicatedServerInfo == nil then
          playSample(FS25_EnhancedVehicle.sounds["snap_off"], 1, Between(FS25_EnhancedVehicle.sfx_volume.track, 0, 10), 0, 0, 0)
        end
        self.vData.want[5] = false
        self.vData.want[6] = false
      end
      _snap = true
    elseif actionName == "FS25_EnhancedVehicle_SNAP_REVERSE" then
      -- reverse snap
      if FS25_EnhancedVehicle.sounds["snap_on"] ~= nil and FS25_EnhancedVehicle.soundIsOn and g_dedicatedServerInfo == nil then
        playSample(FS25_EnhancedVehicle.sounds["snap_on"], 1, Between(FS25_EnhancedVehicle.sfx_volume.track, 0, 10), 0, 0, 0)
      end

      -- turn on op mode if required
      if self.vData.opMode == 0 then self.vData.opMode = 1 end

      -- turn snap on
      self.vData.want[5] = true
      self.vData.want[4] = NormalizeAngle(ClosestAngle(self.vData.is[4] + 180, 0.25))

      -- if track is enabled -> also rotate track
      if self.vData.opMode == 2 and self.vData.track.isCalculated then
        self.vData.want[6] = true
        local _newrot = Direction2RotationDeg(self.vData.is[9], self.vData.is[10], 0, 180)
        FS25_EnhancedVehicle:updateTrack(self, true, _newrot, false, 0, true, self.vData.track.deltaTrack, 0)
        self.vData.want[4] = _newrot

        -- update headland
        self.vData.track.isOnField = FS25_EnhancedVehicle:getHeadlandInfo(self) and 10 or 0
      end
      _snap = true
    elseif actionName == "FS25_EnhancedVehicle_SNAP_ANGLE1" then
      -- 1°
      local angleAdjustment = 1 * (keyStatus >= 0 and 1 or -1)
      if self.vData.is[5] then
        self.vData.want[4] = NormalizeAngle(ClosestAngle(self.vData.is[4] + angleAdjustment, 1))
        _snap = true
      end
      -- if track is enabled -> also rotate track
      if self.vData.opMode == 2 and self.vData.track.isCalculated then
        FS25_EnhancedVehicle:updateTrack(self, true, ClosestAngle(Direction2RotationDeg(self.vData.is[9], self.vData.is[10], 0, angleAdjustment), 1), true, 0, true, 0, 0)
        _snap = true
      end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_ANGLE3" then
    -- 45°
      local angleAdjustment = 45 * (keyStatus >= 0 and 1 or -1)
      if self.vData.is[5] then
        self.vData.want[4] = NormalizeAngle(ClosestAngle(self.vData.is[4] + angleAdjustment, 1))
        _snap = true
      end
      -- if track is enabled -> also rotate track
      if self.vData.opMode == 2 and self.vData.track.isCalculated then
        FS25_EnhancedVehicle:updateTrack(self, true, ClosestAngle(Direction2RotationDeg(self.vData.is[9], self.vData.is[10], 0, angleAdjustment), 1), true, 0, true, 0, 0)
        _snap = true
      end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_ANGLE2" then
      -- 0.25°
      local angleAdjustment = 0.25 * (keyStatus >= 0 and 1 or -1)
      if self.vData.is[5] then
        self.vData.want[4] = NormalizeAngle(ClosestAngle(self.vData.is[4] + angleAdjustment, 0.25))
        _snap = true
      end
      -- if track is enabled -> also rotate track
      if self.vData.opMode == 2 and self.vData.track.isCalculated then
        FS25_EnhancedVehicle:updateTrack(self, true, ClosestAngle(Direction2RotationDeg(self.vData.is[9], self.vData.is[10], 0, angleAdjustment), 0.25), true, 0, true, 0, 0)
        _snap = true
      end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_TRACK" then
      -- delta track
      if self.vData.opMode == 2 and self.vData.track.isCalculated then
        self.vData.track.deltaTrack = Between(self.vData.track.deltaTrack + (keyStatus >= 0 and 1 or -1), -5, 5)
      end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_TRACKP" then
    -- track position
      if self.vData.opMode == 2 and self.vData.track.isCalculated then
        FS25_EnhancedVehicle:updateTrack(self, false, -1, false, 0.1 * (keyStatus >= 0 and 1 or -1), true, 0, 0)
      end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_TRACKW" then
    -- track width
      if self.vData.opMode == 2 and self.vData.track.isCalculated then
        FS25_EnhancedVehicle:updateTrack(self, false, -1, false, 0, false, 0, 0, 0.1 * (keyStatus >= 0 and 1 or -1))
      end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_TRACKO" then
    -- track offset
      if self.vData.opMode == 2 and self.vData.track.isCalculated then
        FS25_EnhancedVehicle:updateTrack(self, false, -1, false, 0, false, 0, 0.05 * (keyStatus >= 0 and 1 or -1))
      end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_TRACKJ" then
    -- track jump
      if self.vData.is[5] and self.vData.is[6] then
        if self.vData.opMode == 2 and self.vData.track.isCalculated and self.vData.is[5] and self.vData.track.drivingDir ~= nil then
          FS25_EnhancedVehicle:updateTrack(self, false, -1, false, 0, true, 1 * (keyStatus >= 0 and 1 or -1) * self.vData.track.drivingDir, 0)
        end
      else
        g_currentMission:showBlinkingWarning(g_i18n:getText("global_FS25_EnhancedVehicle_snapNotEnabled"), 4000)
      end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_CALC_WW" then
    -- (re)calculate workwidth
      FS25_EnhancedVehicle:enumerateImplements(self)
      g_currentMission:showBlinkingWarning(g_i18n:getText("global_FS25_EnhancedVehicle_workWidthUpdated"), 2000)
    elseif actionName == "FS25_EnhancedVehicle_SNAP_GRID_RESET" then
      -- recalculate track
      FS25_EnhancedVehicle:calculateTrack(self)
      _snap = true

      -- turn on track visibility
      if self.vData.opMode ~= 2 then
        self.vData.opMode = 2
      end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_HL_MODE" and self.vData.track.headlandMode ~= nil and self.vData.track.isCalculated then
      -- headland mode
      self.vData.track.headlandMode = self.vData.track.headlandMode + 1
      if self.vData.track.headlandMode > 3 then self.vData.track.headlandMode = 1 end
    elseif actionName == "FS25_EnhancedVehicle_SNAP_HL_DIST" and self.vData.track.headlandDistance ~= nil and self.vData.track.isCalculated then
      -- headland distance
      local _state = 0
      if self.vData.track.headlandDistance ~= 9999 then
        local _i = 1
        for _, d in pairs(FS25_EnhancedVehicle.hl_distances) do
          if self.vData.track.headlandDistance == d then
            _state = _i
          end
          _i = _i + 1
        end
      end
      _state = _state + (keyStatus >= 0 and 1 or -1)
      if _state > #FS25_EnhancedVehicle.hl_distances then _state = 0 end
      if _state < 0 then _state = #FS25_EnhancedVehicle.hl_distances end
      self.vData.track.headlandDistance = FS25_EnhancedVehicle.hl_distances[_state]
      if _state == 0 then self.vData.track.headlandDistance = 9999 end
    end
  end

  -- update client-server
  if _snap then
    if self.isClient and not self.isServer then
      self.vData.is[4] = self.vData.want[4]
      self.vData.is[5] = self.vData.want[5]
      self.vData.is[6] = self.vData.want[6]
      self.vData.is[7] = self.vData.want[7]
      self.vData.is[8] = self.vData.want[8]
      self.vData.is[9] = self.vData.want[9]
      self.vData.is[10] = self.vData.want[10]
    end
    FS25_EnhancedVehicle_Event.sendEvent(self, unpack(self.vData.want))
  end

  -- reset odo/trip
  if FS25_EnhancedVehicle.functionOdoMeterIsEnabled then
    if actionName == "FS25_EnhancedVehicle_ODO_MODE" then
      if g_currentMission.time > FS25_EnhancedVehicle.startActionTime + 1000 then
        if (self.vData.is[15] > 0) then
          self.vData.want[15] = 0
          if self.isClient and not self.isServer then
            self.vData.is[15] = self.vData.want[15]
          end
          FS25_EnhancedVehicle_Event.sendEvent(self, unpack(self.vData.want))
        end
      end
    end
  end

end

-- #############################################################################

function FS25_EnhancedVehicle:getHeadlandInfo(self)
  local distance = self.vData.track.headlandDistance
  if distance == 9999 and self.vData.track.workWidth ~= nil then
    distance = self.vData.track.workWidth
  end

  local isOnField = true
  -- look ahead/behind
  local x = self.vData.px + (self.vData.dirX * distance)
  local z = self.vData.pz + (self.vData.dirZ * distance)
  local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)

  local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
  local _density = getDensityAtWorldPos(groundTypeMapId, x, y, z)
  local _densityType = bitAND(bitShiftRight(_density, groundTypeFirstChannel), 2^groundTypeNumChannels - 1)
  isOnField = isOnField and (_densityType ~= g_currentMission.grassValue and _densityType ~= 0)

  -- for debugging
--  self.vData.hlx = x
--  self.vData.hlz = z
--  self.vData.isOnField = isOnField

  return(isOnField)
end

-- #############################################################################

function FS25_EnhancedVehicle:getHeadlandDistance(self)
  local distance = self.vData.track.headlandDistance
  if distance == 9999 and self.vData.track.workWidth ~= nil then
    distance = self.vData.track.workWidth
  end
  local x = self.vData.px + (self.vData.dirX * distance)
  local z = self.vData.pz + (self.vData.dirZ * distance)
  local _x = x
  local _z = z

  local y
  local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels
  local _density, _densityType

  local isOnField = true
  local _dist = 0.0
  local _delta = 0.5

  while(_dist < 100) do
    y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
    groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
    _density = getDensityAtWorldPos(groundTypeMapId, x, y, z)
    _densityType = bitAND(bitShiftRight(_density, groundTypeFirstChannel), 2^groundTypeNumChannels - 1)
    isOnField = isOnField and (_densityType ~= g_currentMission.grassValue and _densityType ~= 0)

    if not isOnField then
      self.vData.track.eofDistance = MathUtil.vector2Length(_x - x, _z - z)
      return
    end

    x = x + (self.vData.dirX * _delta)
    z = z + (self.vData.dirZ * _delta)
    _dist = _dist + _delta
  end

  self.vData.track.eofDistance = -1
end

-- #############################################################################
-- # this function updates the track layout
-- # updateAngle true -> update track direction
-- # updateAngleValue = -1 -> current vehicle angle is used
-- # updatePosition true -> use current vehicle position as new track origin
-- # updateSnap true -> update the snap to track position

function FS25_EnhancedVehicle:updateTrack(self, updateAngle, updateAngleValue, updatePosition, deltaPosition, updateSnap, deltaTrack, deltaOffset, deltaWorkWidth)
  if debug > 1 then print("-> " .. myName .. ": updateTrack" .. mySelf(self)..", uA: "..tostring(updateAngle)..", uAV: "..tostring(updateAngleValue)..", uP: "..tostring(updatePosition)..", dP: "..tostring(deltaPosition)..", uS: "..tostring(updateSnap)..", dT: "..tostring(deltaTrack)) end

  -- defaults
  if updateAngle == nil then
    updateAngle = true
    updateAngleValue = -1
  end
  if updatePosition == nil then updatePosition = true end
  if deltaPosition == nil  then deltaPosition = 0 end
  if updateSnap == nil     then updateSnap = false end
  if deltaTrack == nil     then deltaTrack = 0 end
  if deltaOffset == nil    then deltaOffset = 0 end
  if deltaWorkWidth == nil then deltaWorkWidth = 0 end

  -- set work width from implement or "fake"
  if self.vData.track.workWidth == nil then
    if self.vData.impl.isCalculated and self.vData.impl.workWidth > 0 then
      self.vData.track.workWidth = self.vData.impl.workWidth
    else
      g_currentMission:showBlinkingWarning(g_i18n:getText("global_FS25_EnhancedVehicle_snapNoImplement"), 4000)
      self.vData.track.workWidth = 6
      self.vData.impl.left.px = 3
      if updatePosition then
        self.vData.track.origin.px = self.vData.px
        self.vData.track.origin.pz = self.vData.pz
      end
    end
  end

  -- set offset from implement or "fake"
  if self.vData.track.offset == nil then
    if self.vData.impl.isCalculated then
      self.vData.track.offset = self.vData.impl.offset
    else
      self.vData.track.offset = 0
    end
  end

  if self.vData.track.offset < (-self.vData.track.workWidth / 2) then self.vData.track.offset = self.vData.track.offset + (self.vData.track.workWidth) end
  if self.vData.track.offset > ( self.vData.track.workWidth / 2) then self.vData.track.offset = self.vData.track.offset - (self.vData.track.workWidth) end

  local _broadcastUpdate = false

  -- shall we update the track direction?
  if updateAngle then
    -- if no angle provided -> use current vehicle rotation
    local _rot = 0
    if updateAngleValue == -1 then
      _rot = Direction2RotationDeg(self.vData.dx, self.vData.dz, self.spec_drivable.reverserDirection)

      -- smoothen track angle to snapToAngle
      local snapToAngle = Between(Round(FS25_EnhancedVehicle.snap.snapToAngle, 0), 1, 90)
      _rot = Round(ClosestAngle(_rot, snapToAngle), 0)
    else -- use provided angle
      _rot = updateAngleValue
    end

    -- track direction vector
    self.vData.track.origin.dX =  math.sin(math.rad(_rot))
    self.vData.track.origin.dZ = -math.cos(math.rad(_rot))
    self.vData.track.origin.rot = _rot

    -- send new direction to server
    self.vData.want[9]  = self.vData.track.origin.dX
    self.vData.want[10] = self.vData.track.origin.dZ
    _broadcastUpdate = true
  end

  -- shall we update the track position?
  if updatePosition then
    -- use middle between left and right marker of implement as track origin position
    self.vData.track.origin.px = self.vData.px - (-self.vData.track.origin.dZ * self.vData.impl.left.px) + (-self.vData.track.origin.dZ * (self.vData.track.workWidth / 2))
    self.vData.track.origin.pz = self.vData.pz - ( self.vData.track.origin.dX * self.vData.impl.left.px) + ( self.vData.track.origin.dX * (self.vData.track.workWidth / 2))

    -- save original orientation
    self.vData.track.origin.originaldX = self.vData.track.origin.dX
    self.vData.track.origin.originaldZ = self.vData.track.origin.dZ

    -- send new position to server
    self.vData.want[7]  = self.vData.track.origin.px
    self.vData.want[8]  = self.vData.track.origin.pz
    _broadcastUpdate = true
  end

  -- should we move the track
  if deltaPosition ~= 0 then
    self.vData.track.origin.px = self.vData.track.origin.px + (-self.vData.track.origin.dZ * deltaPosition)
    self.vData.track.origin.pz = self.vData.track.origin.pz + ( self.vData.track.origin.dX * deltaPosition)

    -- send new position to server
    self.vData.want[7]  = self.vData.track.origin.px
    self.vData.want[8]  = self.vData.track.origin.pz
    _broadcastUpdate = true
    updateSnap = true
  end

  -- should we move the offset
  if deltaOffset ~= 0 then
    self.vData.track.offset = self.vData.track.offset + deltaOffset
    updateSnap = true
  end

  -- should we change size of track
  if deltaWorkWidth ~= 0 then
    self.vData.track.workWidth = Between(self.vData.track.workWidth + deltaWorkWidth, 0.1, 100)
    updateSnap = true
  end

  -- shall we update the snap position?
  if updateSnap then
    local dx, dz = self.vData.px - self.vData.track.origin.px, self.vData.pz - self.vData.track.origin.pz

    -- calculate dot in direction left-right and forward-backward
    local dotLR = dx * -self.vData.track.origin.originaldZ + dz * self.vData.track.origin.originaldX
    local trackLR2 = Round(dotLR / self.vData.track.workWidth, 0)
--    local dotLR = dx * -self.vData.track.origin.dZ + dz * self.vData.track.origin.dX
    local dotFB = dx * -self.vData.track.origin.dX - dz * self.vData.track.origin.dZ
--    local trackLR = Round(dotLR / self.vData.track.workWidth, 0)

    -- do we move in original grid oriontation direction?
--    local _drivingDir = trackLR - trackLR2
--    if _drivingDir == 0 then _drivingDir = 1 else _drivingDir = -1 end
    -- new destination track
    trackLR2 = trackLR2 + deltaTrack

    -- snap position
    self.vData.track.origin.snapx = self.vData.track.origin.px + (-self.vData.track.origin.originaldZ * (trackLR2 * self.vData.track.workWidth)) - ( self.vData.track.origin.dX * dotFB) + (-self.vData.track.origin.dZ * self.vData.track.offset)
    self.vData.track.origin.snapz = self.vData.track.origin.pz + ( self.vData.track.origin.originaldX * (trackLR2 * self.vData.track.workWidth)) - ( self.vData.track.origin.dZ * dotFB) + ( self.vData.track.origin.dX * self.vData.track.offset)

    -- send new snap position to server
    self.vData.want[11]  = self.vData.track.origin.snapx
    self.vData.want[12]  = self.vData.track.origin.snapz
    if self.vData.is[5] then
      self.vData.want[6]   = true
    end
    _broadcastUpdate = true
  end

  -- broadcast to server/everyone
  if _broadcastUpdate then
    if self.isClient and not self.isServer then
      self.vData.is[6]  = self.vData.want[6]
      self.vData.is[7]  = self.vData.want[7]
      self.vData.is[8]  = self.vData.want[8]
      self.vData.is[9]  = self.vData.want[9]
      self.vData.is[10] = self.vData.want[10]
      self.vData.is[11] = self.vData.want[11]
      self.vData.is[12] = self.vData.want[12]
    end
    FS25_EnhancedVehicle_Event.sendEvent(self, unpack(self.vData.want))
  end

  -- we have a valid track layout
  self.vData.track.isCalculated = true

  if debug > 1 then print("Origin position: ("..self.vData.track.origin.px.."/"..self.vData.track.origin.pz..") / Origin direction: ("..self.vData.track.origin.dX.."/"..self.vData.track.origin.dZ..") / Snap position: ("..self.vData.track.origin.snapx.."/"..self.vData.track.origin.snapz..") / Rotation: "..self.vData.track.origin.rot.." / Offset: "..self.vData.track.offset) end
  if debug > 2 then print_r(self.vData.track) end
end

-- #############################################################################
-- # this function calculates a fresh track layout

function FS25_EnhancedVehicle:calculateTrack(self)
  if debug > 1 then print("-> " .. myName .. ": calculateTrack" .. mySelf(self)) end

  -- reset/delete all track data
  self.vData.track.origin       = {}
  self.vData.track.isCalculated = false
  self.vData.track.dotFBPrev    = 99999999
  self.vData.track.offset       = nil
  self.vData.track.workWidth    = nil

  -- first, we need information about implements
  FS25_EnhancedVehicle:enumerateImplements(self)

  -- then we update the tracks with "current" angle and new origin
  FS25_EnhancedVehicle:updateTrack(self, true, -1, true, 0, true, 0)
end

-- #############################################################################
-- # this function builds a table of all attachments/implements with working area(s)
-- # the table contains:
-- #  - working width of the working area
-- #  - left/right position (local) of the working area
-- #  - offset of the working area relative to the vehicle

function FS25_EnhancedVehicle:enumerateImplements(self)
  if debug > 1 then print("-> " .. myName .. ": enumerateImplements" .. mySelf(self)) end

  -- build list of attachments
  listOfObjects = {}
  FS25_EnhancedVehicle:enumerateImplements2(self)

  -- add our own vehicle
  if (self.spec_workArea ~= nil) then
    table.insert(listOfObjects, self)
  end

  -- new array and some defaults
  self.vData.impl = { isCalculated = false, workWidth = 0, offset = 0, left = { px = -99999999, marker = nil }, right = { px = 99999999, marker = nil }, plow = nil }

  -- now we go through the list and fetch relevant data
  local _width1, _width2 = 0, 0
  local _min1, _max1 = -99999999, 99999999
  local _min2, _max2 = -99999999, 99999999
  for _, obj in pairs(listOfObjects) do

    -- for objects with AImarkers
    local leftMarker, rightMarker = obj:getAIMarkers()
    if leftMarker ~= nil and rightMarker ~= nil then
      local _lx, _, _ = localToLocal(leftMarker,  obj.rootNode, 0, 0, 0)
      local _rx, _, _ = localToLocal(rightMarker, obj.rootNode, 0, 0, 0)
      if debug > 1 then print(obj.typeName..", lx: ".._lx..", rx: ".._rx) end
      if _lx > _min2 then
        _min2 = _lx
        self.vData.impl.left.marker = leftMarker
      end
      if _rx < _max2 then
        _max2 = _rx
        self.vData.impl.right.marker = rightMarker
      end

      -- working width
      _width2 = math.abs(_min2 - _max2)
      if debug > 1 then print("width 2: ".._width2) end

      -- if it is a plow -> save plow rotation
      if obj.typeName == "plow" or obj.typeName == "plowPacker" then
        self.vData.impl.plow = obj.spec_plow
        self.vData.track.plow = self.vData.impl.plow.rotationMax
      end
    else
      -- for objects without AIMarkers
      local _found = false
      for _, workArea in pairs(obj.spec_workArea.workAreas) do
        if workArea.functionName ~= nil then
          if workArea.functionName ~= "processRidgeMarkerArea" and workArea.functionName ~= "processCombineSwathArea" and workArea.functionName ~= "processCombineChopperArea" then
            local _x1 = localToLocal(workArea.start, obj.rootNode, 0, 0, 0)
            local _x2 = localToLocal(workArea.width, obj.rootNode, 0, 0, 0)

            if debug > 1 then print(obj.typeName..", "..workArea.type..", x1: ".._x1..", x2: ".._x2) end
            _min1 = math.max(_min1, _x1)
            _min1 = math.max(_min1, _x2)
            _max1 = math.min(_max1, _x1)
            _max1 = math.min(_max1, _x2)
            _found = true
          end
        end
      end
      if _found then
        _width1 = _min1 + math.abs(_max1)
        if debug > 1 then print("width 1: ".._width1) end
      end
    end

    -- working width
    if _width1 > self.vData.impl.workWidth then
      self.vData.impl.workWidth = Round(_width1, 4)
      self.vData.impl.left.px = _min1
      self.vData.impl.right.px = _max1
    end
    if _width2 > self.vData.impl.workWidth then
      self.vData.impl.workWidth = Round(_width2, 4)
      self.vData.impl.left.px = _min2
      self.vData.impl.right.px = _max2
    end
    if debug > 1 then print("final width: "..self.vData.impl.workWidth) end

    -- offset
    self.vData.impl.offset = Round((self.vData.impl.left.px + self.vData.impl.right.px) * 0.5, 4)
    if self.vData.impl.offset > -0.1 and self.vData.impl.offset < 0.1 then self.vData.impl.offset = 0 end

    if debug > 1 then print("-> Type: "..obj.typeName..", Width: "..self.vData.impl.workWidth..", Offset: "..self.vData.impl.offset) end

  end

  -- with a valid workwidth we have finished impl calculation successfully
  if self.vData.impl.workWidth > 0 then
    self.vData.impl.isCalculated = true
  end

  if debug > 1 then print("--> Width: "..self.vData.impl.workWidth..", Offset: "..self.vData.impl.offset) end
  if debug > 1 then print(DebugUtil.printTableRecursively(self.vData.impl, 0, 0, 1)) end
end

-- #############################################################################

function FS25_EnhancedVehicle:enumerateImplements2(self)
  if debug > 1 then print("-> " .. myName .. ": enumerateImplements2" .. mySelf(self)) end

  local attachedImplements = nil

  -- are there attachments?
  if self.getAttachedImplements ~= nil then
    attachedImplements = self:getAttachedImplements()
  end
  if attachedImplements ~= nil then
    -- go through all attached implements
    for _, implement in pairs(attachedImplements) do
      -- if implement has a work area -> add to list
      if implement.object ~= nil and implement.object.spec_workArea ~= nil then
        table.insert(listOfObjects, implement.object)
      end

      -- recursive dive into more attachments
      if implement.object.getAttachedImplements ~= nil then
        FS25_EnhancedVehicle:enumerateImplements2(implement.object)
      end
    end
  end
end

-- #############################################################################

function FS25_EnhancedVehicle:enumerateAttachments2(rootNode, obj)
  if debug > 1 then print("entering: "..obj.rootNode) end

  local relX, relY, relZ

  if obj.spec_attacherJoints == nil then return end

  for idx, attacherJoint in pairs(obj.spec_attacherJoints.attacherJoints) do
    -- position relative to our vehicle
    local x, y, z = getWorldTranslation(attacherJoint.jointTransform)
    relX, relY, relZ = worldToLocal(rootNode, x, y, z)
    -- when it can be moved up and down ->
    if attacherJoint.allowsLowering then
      if relZ > 0 then -- front
        table.insert(joints_front, { obj, idx })
      end
      if relZ < 0 then -- back
        table.insert(joints_back, { obj, idx })
      end
      if debug > 2 then print(obj.rootNode.."/"..idx.." x: "..tostring(x)..", y: "..tostring(y)..", z: "..tostring(z)) end
      if debug > 2 then print(obj.rootNode.."/"..idx.." x: "..tostring(relX)..", y: "..tostring(relY)..", z: "..tostring(relZ)) end
    end

    -- what is attached here?
    local implement = obj.spec_attacherJoints:getImplementByJointDescIndex(idx)
    if implement ~= nil and implement.object ~= nil then
      if relZ > 0 then -- front
        table.insert(implements_front, implement.object)
      end
      if relZ < 0 then -- back
        table.insert(implements_back, implement.object)
      end

      -- when it has joints by itsself then recursive into them
      if implement.object.spec_attacherJoints ~= nil then
        if debug > 1 then print("go into recursive:"..obj.rootNode) end
        FS25_EnhancedVehicle:enumerateAttachments2(rootNode, implement.object)
      end

    end
  end
  if debug > 1 then print("leaving: "..obj.rootNode) end
end

-- #############################################################################

function FS25_EnhancedVehicle:enumerateAttachments(obj)
  joints_front = {}
  joints_back = {}
  implements_front = {}
  implements_back = {}

  -- assemble a list of all attachments
  FS25_EnhancedVehicle:enumerateAttachments2(obj.rootNode, obj)
end

-- #############################################################################

function ClosestAngle(n,m)
  if m == 0 then return 0 end
  local q = math.floor(n/m)
  local n1 = m*q
  local n2 = m*(q+1)
  
  if math.abs(n-n1) < math.abs(n-n2) then
    return n1
  end
  return n2
end

-- #############################################################################

function Round(num, dp)
    local mult = 10^(dp or 0)
    return math.floor(num * mult + 0.5)/mult
end

-- #############################################################################

function Between(a, minA, maxA)
  if a == nil then return end
  if minA ~= nil and a <= minA then return minA end
  if maxA ~= nil and a >= maxA then return maxA end
  return a
end

-- #############################################################################
-- # make sure an angle is >= 0 and < 360

function NormalizeAngle(a)
  while a < 0 do
    a = a + 360
  end
  while a >= 360 do
    a = a - 360
  end

  return a
end

-- #############################################################################

function Direction2RotationDeg(x, z, reverserDirection, diff)
  diff = diff or 0

  local rot = 180 - math.deg(MathUtil.getYRotationFromDirection(x,z))
  rot = rot + diff
  if reverserDirection ~= nil and reverserDirection < 0 then
    rot = rot + 180
  end

  return NormalizeAngle(rot)
end

-- #############################################################################

function mySelf(obj)
  return " (rootNode: " .. obj.rootNode .. ", typeName: " .. obj.typeName .. ", typeDesc: " .. obj.typeDesc .. ")"
end

-- #############################################################################

function FS25_EnhancedVehicle:updateVehiclePhysics( originalFunction, axisForward, axisSide, doHandbrake, dt)
  if debug > 2 then print("function Drivable.updateVehiclePhysics() "..tostring(dt)..", "..tostring(axisForward)..", "..tostring(axisSide)..", "..tostring(doHandbrake)) end

  if self.vData ~= nil and self.vData.is[5] then
    if self:getIsVehicleControlledByPlayer() and self:getIsMotorStarted() then
      -- get current position and rotation of vehicle
      local px, _, pz = localToWorld(self.rootNode, 0, 0, 0)
      local lx, _, lz = localDirectionToWorld(self.rootNode, 0, 0, 1)
      local rot = Direction2RotationDeg(lx, lz, self.spec_drivable.reverserDirection)
      rot = Round(rot, 1)
      if rot >= 360.0 then rot = 0 end
      self.vData.rot = rot

      -- when snap to track mode -> get dot
      local dotLR = 0
      if self.vData.is[6] then
        local dx, dz = px - self.vData.is[11], pz - self.vData.is[12]
        dotLR = -(dx * -self.vData.is[10] + dz * self.vData.is[9])
        if math.abs(dotLR) < 0.05 then dotLR = 0 end -- smooth it
      end

      -- if wanted direction is different than current direction OR we're not on track
--      if self.vData.rot ~= self.vData.is[4] or dotLR ~= 0 then
      if math.abs(self.vData.rot - self.vData.is[4]) > 0.0001 or dotLR ~= 0 then

        -- get movingDirection (1=forward, 0=nothing, -1=reverse) but if nothing we choose forward
        local movingDirection = 0
        if g_currentMission.missionInfo.stopAndGoBraking then
          movingDirection = self.movingDirection * self.spec_drivable.reverserDirection
          if math.abs( self.lastSpeed ) < 0.000278 then
            movingDirection = 0
          end
        else
          movingDirection = Utils.getNoNil(self.nextMovingDirection * self.spec_drivable.reverserDirection)
        end
        if movingDirection == 0 then movingDirection = 1 end

        -- "steering force"
        local delta = dt/500 * movingDirection -- higher number means smaller changes results in slower steering

        -- calculate degree difference between "is" and "wanted" (from -180 to 180)
        local _w1 = self.vData.is[4]
        if _w1 > 180 then _w1 = _w1 - 360 end
        local _w2 = self.vData.rot

        -- when snap to track -> gently push the driving direction towards destination position depending on current speed
        if self.vData.is[6] then
--          _old = _w2
          _w2 = _w2 - Between(dotLR * Between(10 - self:getLastSpeed() / 8, 4, 8) * movingDirection * 1.3, -90, 90) -- higher means stronger movement force to destination
--          print("old: ".._old..", new: ".._w2..", dot: "..dotLR..", md: "..movingDirection.." / "..Between(10 - self:getLastSpeed() / 8, 4, 8))
        end
        if _w2 > 180 then _w2 = _w2 - 360 end
        if _w2 < -180 then _w2 = _w2 + 360 end

        -- calculate difference between angles
        local diffdeg = _w1 - _w2
        if diffdeg > 180 then diffdeg = diffdeg - 360 end
        if diffdeg < -180 then diffdeg = diffdeg + 360 end
--        print("delta: "..delta..", d: "..dotLR..", w1: ".._w1..", w2: ".._w2..", rot: "..self.vData.rot..", diffdeg: "..diffdeg)

        -- calculate new steering wheel "direction"
        local _d = 18
        -- if we have still more than 20° to steer -> increase steering wheel constantly until maximum
        -- if in between -20 to 20 -> adjust steering wheel according to remaining degrees
        -- if in between -2 to 2 -> set steering wheel directly
        local a = self.vData.axisSidePrev
        if (diffdeg < -_d) then
          a = a - delta * 0.5
        end
        if (diffdeg > _d) then
          a = a + delta * 0.5
        end
        if (diffdeg >= -_d) and (diffdeg <= _d) then
          local newa = diffdeg / _d * movingDirection -- linear from 1 to 0.1
          if a < newa then
--              print("1 dd: "..diffdeg.." a: "..a.." newa: "..newa..", md: "..movingDirection..", dot: "..dotLR)
            a = a + delta * 1.2 * movingDirection
          end
          if a > newa then
--              print("2 dd: "..diffdeg.." a: "..a.." newa: "..newa..", md: "..movingDirection..", dot: "..dotLR)
            a = a - delta * 1.2 * movingDirection
          end
        end
        if (diffdeg >= -2) and (diffdeg <= 2) then
          a = diffdeg / _d * movingDirection
        end
        a = Between(a, -1, 1)

        axisSide = a
--          print("dt: "..dt.." aS: "..axisSide.." aSp: "..self.vData.axisSidePrev.." delta: "..delta.." diffdeg: "..diffdeg)

        -- save for next calculation cycle
        self.vData.axisSidePrev = a
--          print(" is: "..self.vData.rot.." want: "..self.vData.is[4].." diff: "..diffdeg.. " steerangle: " .. axisSide)
      end
    end
  end

  -- call the original function to do the actual physics stuff
  local state, result = pcall( originalFunction, self, axisForward, axisSide, doHandbrake, dt)
  if not ( state ) then
    print("Ooops in updateVehiclePhysics :" .. tostring(result))
  end

  return result
end
Drivable.updateVehiclePhysics = Utils.overwrittenFunction( Drivable.updateVehiclePhysics, FS25_EnhancedVehicle.updateVehiclePhysics )

-- #############################################################################

function FS25_EnhancedVehicle:updateWheelsPhysics(originalFunction, dt, currentSpeed, acceleration, doHandbrake, stopAndGoBraking)
  if debug > 2 then print("function WheelsUtil.updateWheelsPhysics("..self.typeDesc..", "..tostring(dt)..", "..tostring(currentSpeed)..", "..tostring(acceleration)..", "..tostring(doHandbrake)..", "..tostring(stopAndGoBraking)) end

  local brakeLights = false
  if self.vData ~= nil and self.vData.is[13] then
    if self:getIsVehicleControlledByPlayer() and self:getIsMotorStarted() then
      -- parkBreakIsOn
      brakeLights = not (currentSpeed >= -0.0003 and currentSpeed <= 0.0003)
      acceleration = 0
      currentSpeed = 0
      doHandbrake = true
    end
  end

  -- call the original function to do the actual physics stuff
  local state, result = pcall( originalFunction, self, dt, currentSpeed, acceleration, doHandbrake, stopAndGoBraking )
  if not ( state ) then
    print("Ooops in updateWheelsPhysics :" .. tostring(result))
  end

  if brakeLights and type(self.setBrakeLightsVisibility) == "function" then
    self:setBrakeLightsVisibility(true)
  end

  return result
end
WheelsUtil.updateWheelsPhysics = Utils.overwrittenFunction(WheelsUtil.updateWheelsPhysics, FS25_EnhancedVehicle.updateWheelsPhysics)

-- #############################################################################
-- unfortunately we've to hook into this function to make the parking brake work in manual transmission mode
function FS25_EnhancedVehicle:getSmoothedAcceleratorAndBrakePedals(originalFunction, acceleratorPedal, brakePedal, dt)
  if debug > 2 then print("function WheelsUtil.getSmoothedAcceleratorAndBrakePedals("..self.typeDesc..", "..tostring(dt)..", "..tostring(acceleratorPedal)..", "..tostring(brakePedal)) end

  if self ~= nil and self.vData ~= nil and self.vData.is[13] then
    if self:getIsVehicleControlledByPlayer() then
      return originalFunction(self, 0, 1, dt)
    end
  end
  return originalFunction(self, acceleratorPedal, brakePedal, dt)
end
WheelsUtil.getSmoothedAcceleratorAndBrakePedals = Utils.overwrittenFunction(WheelsUtil.getSmoothedAcceleratorAndBrakePedals, FS25_EnhancedVehicle.getSmoothedAcceleratorAndBrakePedals)
