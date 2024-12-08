--
-- Mod: FS25_EnhancedVehicle_Loader
--
-- Author: Majo76
-- email: ls (at) majo76 (dot) de
-- @Date: 12.11.2024
-- @Version: 1.0.0.0

-- #############################################################################

debug = 2 -- 0=0ff, 1=some, 2=everything, 3=madness

local directory = g_currentModDirectory
local modName = g_currentModName

source(Utils.getFilename("FS25_EnhancedVehicle.lua", directory))
source(Utils.getFilename("FS25_EnhancedVehicle_Event.lua", directory))
source(Utils.getFilename("ui/FS25_EnhancedVehicle_DialogSettings.lua", directory))
source(Utils.getFilename("ui/FS25_EnhancedVehicle_DialogHUD.lua", directory))
source(Utils.getFilename("ui/FS25_EnhancedVehicle_HUD.lua", directory))

-- include our libUtils
source(Utils.getFilename("libUtils.lua", g_currentModDirectory))
lU = libUtils()
lU:setDebug(0)

-- include our new libConfig XML management
source(Utils.getFilename("libConfig.lua", g_currentModDirectory))
lC = libConfig("FS25_EnhancedVehicle", 1, 0)
lC:setDebug(0)

local EnhancedVehicle

local function isEnabled()
  return EnhancedVehicle ~= nil
end

-- #############################################################################

function EV_init()
  if debug > 1 then print("EV_init()") end
  
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
  if debug > 1 then print("EV_load()") end
  
  -- create our EV class
  assert(g_EnhancedVehicle == nil)
  EnhancedVehicle = FS25_EnhancedVehicle:new(mission, directory, modName, g_i18n, g_gui, g_gui.inputManager, g_messageCenter)
  getfenv(0)["g_EnhancedVehicle"] = EnhancedVehicle

  mission.EnhancedVehicle = EnhancedVehicle

  addModEventListener(EnhancedVehicle);
end

-- #############################################################################

function EV_unload()
  if debug > 1 then print("EV_unload()") end

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
  if debug > 1 then print("EV_load()") end

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
  if debug > 1 then print("EV_validateTypes()") end
    
  -- attach only to vehicles
  if (types.typeName == 'vehicle') then
    FS25_EnhancedVehicle.installSpecializations(g_vehicleTypeManager, g_specializationManager, directory, modName)
  end
end

-- #############################################################################

EV_init()
