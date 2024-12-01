--
-- Mod: FS25_EnhancedVehicle_Loader
--
-- Author: Majo76
-- email: ls (at) majo76 (dot) de
-- @Date: 12.11.2024
-- @Version: 1.0.0.0

-- #############################################################################

-- TODO: remove this after migration to EVLog
debug = 1

local directory = g_currentModDirectory
local modName = g_currentModName

source(Utils.getFilename("FS25_EnhancedVehicle.lua", directory))
source(Utils.getFilename("FS25_EnhancedVehicle_Event.lua", directory))
source(Utils.getFilename("ui/FS25_EnhancedVehicle_UI.lua", directory))
source(Utils.getFilename("ui/FS25_EnhancedVehicle_HUD.lua", directory))

-- include our libUtils
source(Utils.getFilename("libUtils.lua", g_currentModDirectory))

-- our global libUtils instance
lU = LibUtils:new(LibUtils.Logger:new(LibUtils.Logger.LEVEL.OFF))

-- our global logger
EVLog = LibUtils.Logger:new(LibUtils.Logger.LEVEL.INFO)

-- include our new libConfig XML management
source(Utils.getFilename("libConfig.lua", g_currentModDirectory))

-- our global libConfig instance
lC = LibConfig:new("FS25_EnhancedVehicle", 1, 0, LibUtils.Logger:new(LibUtils.Logger.LEVEL.OFF))

local EnhancedVehicle

local function isEnabled()
  return EnhancedVehicle ~= nil
end

-- #############################################################################

function EV_init()
  EVLog:info("EV_init()")
  
  -- hook into early load
  Mission00.load = Utils.prependedFunction(Mission00.load, EV_load)
  -- hook into late load
  Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, EV_loadedMission)

  -- hook into late unload
  FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, EV_unload)

  -- hook into validateTypes
  TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, EV_validateTypes)
end

-- #############################################################################

function EV_load(mission)
  EVLog:info("EV_load()")
  
  -- create our EV class
  assert(g_EnhancedVehicle == nil)
  EnhancedVehicle = FS25_EnhancedVehicle:new(mission, directory, modName, g_i18n, g_gui, g_gui.inputManager, g_messageCenter)
  getfenv(0)["g_EnhancedVehicle"] = EnhancedVehicle

  mission.EnhancedVehicle = EnhancedVehicle

  addModEventListener(EnhancedVehicle);
end

-- #############################################################################

function EV_unload()
  EVLog:info("EV_unload()")

  if not isEnabled() then
    return
  end

  removeModEventListener(EnhancedVehicle)
  
  EnhancedVehicle:delete()
  EnhancedVehicle = nil
  getfenv(0)["g_EnhancedVehicle"] = nil
end

-- #############################################################################

function EV_loadedMission(mission)
  EVLog:info("EV_load()")

  if not isEnabled() then
    return
  end

  if mission.cancelLoading then
    return
  end

  EnhancedVehicle:onMissionLoaded(mission)
end

-- #############################################################################

function EV_validateTypes(types)
  EVLog:info("EV_validateTypes()")

  -- attach only to vehicles
  if (types.typeName == 'vehicle') then
    FS25_EnhancedVehicle.installSpecializations(g_vehicleTypeManager, g_specializationManager, directory, modName)
  end
end

-- #############################################################################

EV_init()
