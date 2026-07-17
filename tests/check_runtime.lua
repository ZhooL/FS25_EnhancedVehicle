-- Lightweight Lua 5.1 regression checks for logic that can run without the
-- GIANTS engine. Engine-facing rendering/HUD behavior is validated separately
-- by syntax/XML checks and in-game smoke testing.

local function assertEqual(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
  end
end

local function assertNear(actual, expected, tolerance, label)
  if math.abs(actual - expected) > tolerance then
    error(string.format("%s: expected %.8f, got %.8f", label, expected, actual), 2)
  end
end

local function copyArray(values)
  local result = {}
  for index, value in ipairs(values) do result[index] = value end
  return result
end

debug = 0
function Class(classTable)
  return { __index = classTable }
end

Utils = {
  overwrittenFunction = function(_, replacement) return replacement end
}
WheelsUtil = {
  getSmoothedAcceleratorAndBrakePedals = function(_, accelerator, brake)
    return accelerator, brake
  end
}
MathUtil = {
  vector2Length = function(x, z) return math.sqrt(x * x + z * z) end,
  getYRotationFromDirection = function(x, z) return math.atan2(x, z) end
}

function localToWorld(node)
  return node.worldX or 0, node.worldY or 0, node.worldZ or 0
end

function localDirectionToWorld(node, _, _, directionZ)
  directionZ = directionZ or 1
  return (node.directionX or 0) * directionZ, 0, (node.directionZ or 1) * directionZ
end

function localToLocal(node, referenceNode)
  if node.name == "guidance" then
    return node.frameX or 0, node.frameY or 0, node.frameZ or 0
  end
  assertEqual(referenceNode.name, "guidance", "work-area reference node")
  return node.guidanceX, node.guidanceY or 0, node.guidanceZ or 0
end

function localDirectionToLocal(node, _, x, y, z)
  if node.frameRotated then
    return z, y, -x
  end
  return x, y, z
end

g_currentMission = { terrainSize = 2048 }

dofile("FS25_EnhancedVehicle.lua")
FS25_EnhancedVehicle.functionSnapIsEnabled = true
FS25_EnhancedVehicle.functionParkingBrakeIsEnabled = true
FS25_EnhancedVehicle.hl_distances = {
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20,
  -1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -12, -14, -16, -18, -20
}

assertEqual(FS25_EnhancedVehicle.getGuidanceDirectionSign({ spec_reverseDriving = {}, spec_drivable = { reverserDirection = -1 } }), -1, "reverse-driving fallback direction")
assertEqual(FS25_EnhancedVehicle.getGuidanceDirectionSign({ spec_reverseDriving = { aiSteeringNode = {} }, spec_drivable = { reverserDirection = -1 } }), 1, "dedicated reverse AI direction")
assertEqual(FS25_EnhancedVehicle.getGuidanceDirectionSign({ spec_reverseDriving = {}, spec_drivable = { reverserDirection = 0 } }), 1, "reverse-driving transition direction")

local function newNetworkVehicle()
  local values = { false, false, 1, 10, true, true, 100, 200, 0, 1, 110, 220, false, 123, 45, 0 }
  local directionNode = { name = "guidance", worldX = 10, worldZ = 20, directionX = 0, directionZ = 1 }
  local vehicle = {
    rootNode = directionNode,
    vData = {
      want = copyArray(values),
      is = copyArray(values),
      opMode = 2,
      impl = { isCalculated = true, workWidth = 12, offset = 1 },
      track = {
        isCalculated = true,
        origin = {
          px = 100, pz = 200, dX = 0, dZ = 1,
          originaldX = 0, originaldZ = 1, snapx = 110, snapz = 220
        },
        workWidth = 12,
        offset = 1,
        deltaTrack = 2,
        headlandMode = 2,
        headlandDistance = 10
      }
    }
  }
  function vehicle:getAIDirectionNode() return directionNode end
  return vehicle
end

-- Client packets cannot write server-owned counters and all guidance values
-- are normalized/constrained before becoming canonical.
local vehicle = newNetworkVehicle()
local request = FS25_EnhancedVehicle.buildNetworkSnapshot(vehicle, false)
request.values[14] = 999999
request.values[15] = 999999
request.trackOriginX = 1000000000
request.trackDirectionX = 1
request.trackDirectionZ = 1
request.trackWorkWidth = 500
request.trackOffset = 999
request.trackDelta = 99
request.opMode = 99
request.headlandMode = 99
request.headlandDistance = 11

local canonical = FS25_EnhancedVehicle.sanitizeNetworkSnapshot(vehicle, request, true)
assertEqual(canonical.values[14], 123, "server-owned odometer")
assertEqual(canonical.values[15], 45, "server-owned trip meter")
assertEqual(canonical.trackOriginX, 100, "out-of-map origin rejection")
assertNear(canonical.trackDirectionX, math.sqrt(0.5), 0.000001, "normalized direction X")
assertNear(canonical.trackDirectionZ, math.sqrt(0.5), 0.000001, "normalized direction Z")
assertEqual(canonical.trackWorkWidth, 100, "work-width clamp")
assertEqual(canonical.trackOffset, -1, "offset wrapping")
assertEqual(canonical.trackDelta, 5, "turnover clamp")
assertEqual(canonical.opMode, 2, "operation-mode clamp")
assertEqual(canonical.headlandMode, 3, "headland-mode clamp")
assertEqual(canonical.headlandDistance, 10, "unsupported headland distance rejection")

local wrappingRequest = FS25_EnhancedVehicle.buildNetworkSnapshot(vehicle, false)
wrappingRequest.trackWorkWidth = 6
wrappingRequest.trackOffset = 2.99 + 0.05
local wrapped = FS25_EnhancedVehicle.sanitizeNetworkSnapshot(vehicle, wrappingRequest, true)
assertNear(wrapped.trackOffset, -2.96, 0.000001, "positive offset increment wraps")
wrappingRequest.trackOffset = -2.99 - 0.05
wrapped = FS25_EnhancedVehicle.sanitizeNetworkSnapshot(vehicle, wrappingRequest, true)
assertNear(wrapped.trackOffset, 2.96, 0.000001, "negative offset increment wraps")
assertEqual(FS25_EnhancedVehicle.wrapTrackOffset(3, 6, 0), 3, "positive half-width endpoint")
assertEqual(FS25_EnhancedVehicle.wrapTrackOffset(-3, 6, 0), -3, "negative half-width endpoint")

request.tripReset = true
canonical = FS25_EnhancedVehicle.sanitizeNetworkSnapshot(vehicle, request, true)
assertEqual(canonical.values[15], 0, "explicit trip reset")
FS25_EnhancedVehicle.applyNetworkSnapshot(vehicle, canonical, true)
assertEqual(vehicle.vData.is[15], 0, "client snapshot reconstruction")
assertEqual(vehicle.vData.track.isCalculated, true, "track validity reconstruction")
assertEqual(vehicle.vData.track.origin.originaldZ, canonical.trackOriginalDirectionZ, "original direction reconstruction")

local rebuildingVehicle = newNetworkVehicle()
rebuildingVehicle.vData.impl = { isCalculated = false }
local rebuildingSnapshot = FS25_EnhancedVehicle.buildNetworkSnapshot(rebuildingVehicle, false)
FS25_EnhancedVehicle.applyNetworkSnapshot(rebuildingVehicle, rebuildingSnapshot, true)
assertEqual(rebuildingVehicle.vData.networkTrackNeedsRebuild, true, "initial implement rebuild request")
FS25_EnhancedVehicle.applyNetworkSnapshot(rebuildingVehicle, rebuildingSnapshot, true)
assertEqual(rebuildingVehicle.vData.networkTrackNeedsRebuild, true, "preserved pending implement rebuild")

-- Deterministic property checks exercise malformed and extreme client packets.
math.randomseed(250118)
local nonFinite = { 0/0, math.huge, -math.huge, nil }
for iteration = 1, 250 do
  local fuzz = FS25_EnhancedVehicle.buildNetworkSnapshot(vehicle, false)
  fuzz.values = copyArray(fuzz.values)
  fuzz.values[3] = math.random(-100000, 100000) * 0.25
  fuzz.values[4] = nonFinite[(iteration % #nonFinite) + 1]
  fuzz.values[14] = math.random(-100000, 100000)
  fuzz.values[15] = math.random(-100000, 100000)
  fuzz.trackOriginX = math.random(-10000000, 10000000)
  fuzz.trackOriginZ = nonFinite[((iteration + 1) % #nonFinite) + 1]
  fuzz.trackDirectionX = math.random(-1000, 1000) / 100
  fuzz.trackDirectionZ = math.random(-1000, 1000) / 100
  fuzz.trackOriginalDirectionX = nonFinite[((iteration + 2) % #nonFinite) + 1]
  fuzz.trackOriginalDirectionZ = nonFinite[((iteration + 3) % #nonFinite) + 1]
  fuzz.trackWorkWidth = math.random(-10000, 10000)
  fuzz.trackOffset = math.random(-10000, 10000)
  fuzz.trackDelta = math.random(-100, 100)
  fuzz.opMode = math.random(-100, 100)
  fuzz.headlandMode = math.random(-100, 100)

  local sanitized = FS25_EnhancedVehicle.sanitizeNetworkSnapshot(vehicle, fuzz, true)
  local directionLength = MathUtil.vector2Length(sanitized.trackDirectionX, sanitized.trackDirectionZ)
  local originalDirectionLength = MathUtil.vector2Length(sanitized.trackOriginalDirectionX, sanitized.trackOriginalDirectionZ)
  assertNear(directionLength, 1, 0.000001, "fuzz normalized direction " .. iteration)
  assertNear(originalDirectionLength, 1, 0.000001, "fuzz normalized original direction " .. iteration)
  assertEqual(sanitized.values[14], vehicle.vData.want[14], "fuzz server-owned odometer " .. iteration)
  assertEqual(sanitized.values[15], vehicle.vData.want[15], "fuzz server-owned trip " .. iteration)
  if sanitized.trackWorkWidth < 0.1 or sanitized.trackWorkWidth > 100 then
    error("fuzz work width escaped bounds at iteration " .. iteration)
  end
  if math.abs(sanitized.trackOffset) > sanitized.trackWorkWidth * 0.5 then
    error("fuzz track offset escaped width at iteration " .. iteration)
  end
  if sanitized.trackDelta < -5 or sanitized.trackDelta > 5 then
    error("fuzz track delta escaped bounds at iteration " .. iteration)
  end
  if sanitized.opMode < 0 or sanitized.opMode > 2 then
    error("fuzz operation mode escaped bounds at iteration " .. iteration)
  end
end

-- Work width uses AI markers and all three work-area nodes in the root
-- vehicle's guidance coordinate space, even when the implement root differs.
local markerLeft = { guidanceX = 5 }
local markerRight = { guidanceX = -3 }
local implementOne = {
  typeName = "cultivator",
  spec_workArea = {
    workAreas = {
      { functionName = "processCultivatorArea", start = { guidanceX = 4 }, width = { guidanceX = -4 }, height = { guidanceX = 2 } }
    }
  }
}
function implementOne:getAIMarkers() return markerLeft, markerRight end

local implementTwo = {
  typeName = "sowingMachine",
  spec_workArea = {
    workAreas = {
      { functionName = "processSowingMachineArea", start = { guidanceX = -6 }, width = { guidanceX = 1 }, height = { guidanceX = 3 } }
    }
  }
}

local guidanceVehicle = {
  rootNode = { name = "wrongRoot" },
  vData = { track = {} }
}
local guidanceNode = { name = "guidance" }
function guidanceVehicle:getAIDirectionNode() return guidanceNode end
function guidanceVehicle:getAttachedImplements()
  return { { object = implementOne }, { object = implementTwo } }
end

FS25_EnhancedVehicle:enumerateImplements(guidanceVehicle)
assertEqual(guidanceVehicle.vData.impl.isCalculated, true, "implement calculation")
assertEqual(guidanceVehicle.vData.impl.workWidth, 11, "combined implement width")
assertEqual(guidanceVehicle.vData.impl.offset, -0.5, "combined implement offset")
assertEqual(guidanceVehicle.vData.impl.left.marker, markerLeft, "left AI marker")
assertEqual(guidanceVehicle.vData.impl.right.marker, markerRight, "right AI marker")
assertEqual(FS25_EnhancedVehicle.guidanceGeometryNeedsRefresh(guidanceVehicle, guidanceNode, 1), false, "stable guidance geometry frame")
guidanceNode.frameRotated = true
assertEqual(FS25_EnhancedVehicle.guidanceGeometryNeedsRefresh(guidanceVehicle, guidanceNode, 1), true, "rotated guidance geometry frame")
guidanceNode.frameRotated = false
assertEqual(FS25_EnhancedVehicle.guidanceGeometryNeedsRefresh(guidanceVehicle, guidanceNode, -1), true, "reversed guidance geometry frame")

-- A hydraulic group chooses one target for every eligible implement.
local function turnable(isOn, canTurnOn)
  local object = { spec_turnOnVehicle = { isTurnedOn = isOn }, canTurnOn = canTurnOn }
  function object:getIsTurnedOn() return self.spec_turnOnVehicle.isTurnedOn end
  function object:getCanToggleTurnedOn() return true end
  function object:getCanBeTurnedOn() return self.canTurnOn end
  function object:setIsTurnedOn(value) self.spec_turnOnVehicle.isTurnedOn = value end
  return object
end

local hydraulicVehicle = {}
local first = turnable(true, true)
local second = turnable(false, true)
FS25_EnhancedVehicle.setHydraulicGroupTurnedOn(hydraulicVehicle, { first, second }, "test")
assertEqual(first.spec_turnOnVehicle.isTurnedOn, true, "mixed group first target")
assertEqual(second.spec_turnOnVehicle.isTurnedOn, true, "mixed group second target")

second.canTurnOn = false
second.spec_turnOnVehicle.isTurnedOn = false
FS25_EnhancedVehicle.setHydraulicGroupTurnedOn(hydraulicVehicle, { first, second }, "test")
assertEqual(first.spec_turnOnVehicle.isTurnedOn, false, "unpowered group first target")
assertEqual(second.spec_turnOnVehicle.isTurnedOn, false, "unpowered group second target")

-- Parking brake changes are specialization-scoped and flow through superFunc.
local physicsVehicle = {
  vData = { is = { [5] = false, [13] = true } },
  lastSpeedReal = 0.01,
  brakeLights = false
}
function physicsVehicle:getIsVehicleControlledByPlayer() return true end
function physicsVehicle:setBrakeLightsVisibility(value) self.brakeLights = value end
local physicsArgs
local function physicsSuper(_, axisForward, axisSide, doHandbrake, dt)
  physicsArgs = { axisForward, axisSide, doHandbrake, dt }
  return 0.5
end
local acceleration = FS25_EnhancedVehicle.updateVehiclePhysics(physicsVehicle, physicsSuper, 1, 0.25, false, 16)
assertEqual(acceleration, 0.5, "physics return value")
assertEqual(physicsArgs[1], 0, "parking-brake acceleration")
assertEqual(physicsArgs[3], true, "parking-brake handbrake")
assertEqual(physicsVehicle.brakeLights, true, "parking-brake lights")

-- Event and join-stream snapshots have one symmetric serializer, and event
-- construction itself does not mutate the vehicle.
Event = { new = function(metaTable) return setmetatable({}, metaTable) end }
function InitEventClass() end
dofile("FS25_EnhancedVehicle_Event.lua")

local stream = {}
local function writer(kind)
  return function(_, value) stream[#stream + 1] = { kind, value } end
end
streamWriteBool = writer("bool")
streamWriteInt8 = writer("int8")
streamWriteFloat32 = writer("float32")

local readIndex = 0
local function reader(kind)
  return function()
    readIndex = readIndex + 1
    assertEqual(stream[readIndex][1], kind, "snapshot stream type " .. readIndex)
    return stream[readIndex][2]
  end
end
streamReadBool = reader("bool")
streamReadInt8 = reader("int8")
streamReadFloat32 = reader("float32")

local snapshot = FS25_EnhancedVehicle.buildNetworkSnapshot(vehicle, false)
local beforeEvent = vehicle.vData.want[1]
FS25_EnhancedVehicle_Event.new(vehicle, snapshot)
assertEqual(vehicle.vData.want[1], beforeEvent, "side-effect-free event constructor")
FS25_EnhancedVehicle_Event.writeSnapshot(1, snapshot)
local decoded = FS25_EnhancedVehicle_Event.readSnapshot(1)
assertEqual(readIndex, #stream, "snapshot stream field count")
assertEqual(decoded.values[14], snapshot.values[14], "snapshot odometer round trip")
assertEqual(decoded.trackValid, snapshot.trackValid, "snapshot validity round trip")
assertEqual(decoded.trackOriginalDirectionZ, snapshot.trackOriginalDirectionZ, "snapshot direction round trip")
assertEqual(decoded.headlandDistance, snapshot.headlandDistance, "snapshot headland round trip")

-- Config writes are batchable, and default/current records are independent.
g_currentModDirectory = "./"
function getUserProfileAppPath() return "/tmp/" end
dofile("libConfig.lua")
local config = libConfig("RuntimeTest", 1, 0)
local writeCount = 0
function config:writeConfig() writeCount = writeCount + 1 end
local tableValue = { "a", "b" }
config:addConfigValue("section", "flag", "bool", true)
config:addConfigValue("section", "items", "table", tableValue)
config.dataCurrent[1].value = false
config.dataCurrent[2].value[1] = "changed"
assertEqual(config.dataDefault[1].value, true, "independent scalar default")
assertEqual(config.dataDefault[2].value[1], "a", "independent table default")
config:setConfigValue("section", "flag", true, true)
assertEqual(writeCount, 0, "deferred config write")
config:setConfigValue("section", "flag", false)
assertEqual(writeCount, 1, "immediate config write")

print("Validated runtime network fuzzing, guidance, hydraulics, physics, event, and config logic")
