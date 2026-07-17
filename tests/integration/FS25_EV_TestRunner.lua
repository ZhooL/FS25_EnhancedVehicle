-- Test-only FS25 integration runner. scripts/build_integration.py injects this
-- source into a temporary archive; release validation forbids it from shipping.

FS25_EV_TestRunner = {
  cases = {},
  caseIndex = 0,
  currentCase = nil,
  caseState = nil,
  caseStartedAt = 0,
  passCount = 0,
  failCount = 0,
  skipCount = 0,
  started = false,
  complete = false,
  pendingLoads = {},
  spawnedVehicles = {},
  captures = {},
  startupWait = 0
}

local runner = FS25_EV_TestRunner
local DEFAULT_CASE_TIMEOUT = 45000
local testModDirectory = g_currentModDirectory

local function openStatusStream()
  if io == nil or io.open == nil or getUserProfileAppPath == nil then return nil end
  local ok, stream = pcall(io.open, getUserProfileAppPath() .. "EVTEST.status", "w")
  if ok then return stream end
  return nil
end

runner.statusStream = openStatusStream()

local function clean(value)
  value = tostring(value or "")
  value = string.gsub(value, "[\r\n]+", " | ")
  return value
end

local function emit(kind, name, details)
  local line = string.format("EVTEST %s %s", kind, clean(name))
  if details ~= nil and details ~= "" then
    line = line .. " " .. clean(details)
  end
  print(line)
  if runner.statusStream ~= nil then
    runner.statusStream:write(line, "\n")
    runner.statusStream:flush()
  end
end

local function requireValue(condition, message)
  if not condition then error(message or "assertion failed", 2) end
end

local function near(actual, expected, tolerance, message)
  requireValue(type(actual) == "number", (message or "value") .. " is not numeric")
  requireValue(math.abs(actual - expected) <= tolerance,
    string.format("%s: expected %.5f, got %.5f", message or "value", expected, actual))
end

local function frameCount(state, dt)
  state.elapsed = (state.elapsed or 0) + dt
  state.frames = (state.frames or 0) + 1
end

local function case(name, callback, timeout)
  table.insert(runner.cases, { name = name, callback = callback, timeout = timeout or DEFAULT_CASE_TIMEOUT })
end

local function skip(reason)
  return { skip = reason }
end

local function getPlayerPosition()
  if g_localPlayer ~= nil and g_localPlayer.getPosition ~= nil then
    return g_localPlayer:getPosition()
  end
  return 0, nil, 0
end

function runner:onVehicleLoaded(vehicles, loadState, arguments)
  local key = arguments ~= nil and arguments.key or "unknown"
  self.pendingLoads[key] = { vehicles = vehicles or {}, state = loadState }
end

function runner:spawnStock(key, filename, offsetX, offsetZ, configurations)
  requireValue(VehicleLoadingData ~= nil, "VehicleLoadingData is unavailable")
  local item = g_storeManager:getItemByXMLFilename(filename)
  requireValue(item ~= nil, "stock store item is unavailable: " .. filename)
  local x, y, z = getPlayerPosition()
  local data = VehicleLoadingData.new()
  data:setStoreItem(item)
  data:setConfigurations(configurations or {})
  data:setIsRegistered(false)
  data:setIsSaved(false)
  requireValue(data.isRegistered == false and data.isSaved == false,
    "test vehicle loading data is not isolated from registration/save")
  data:setPosition(x + (offsetX or 0), y, z + (offsetZ or 0), 0.5)
  self.pendingLoads[key] = false
  data:load(self.onVehicleLoaded, self, { key = key })
end

function runner:consumeLoad(key)
  local result = self.pendingLoads[key]
  if result == false or result == nil then return nil end
  self.pendingLoads[key] = nil
  requireValue(result.state == VehicleLoadingState.OK,
    string.format("vehicle load %s failed with state %s", key, tostring(result.state)))
  requireValue(#result.vehicles > 0, "vehicle load returned no vehicles: " .. key)
  local vehicle = result.vehicles[1]
  table.insert(self.spawnedVehicles, vehicle)
  return vehicle
end

local function findInputJoint(tool, jointType)
  if tool.getInputAttacherJoints == nil then return nil end
  for index, input in ipairs(tool:getInputAttacherJoints()) do
    if input.jointType == jointType then return index end
  end
  return nil
end

local function attachAt(tractor, tool, jointIndex)
  local joint = tractor:getAttacherJoints()[jointIndex]
  requireValue(joint ~= nil, "tractor attacher joint is missing: " .. tostring(jointIndex))
  local inputIndex = findInputJoint(tool, joint.jointType)
  requireValue(inputIndex ~= nil, "implement has no compatible input joint")
  tractor:attachImplement(tool, inputIndex, jointIndex, true, nil, nil, true, true)
end

local function captureDirection(vehicle)
  local node = FS25_EnhancedVehicle.getGuidanceDirectionNode(vehicle)
  local sign = FS25_EnhancedVehicle.getGuidanceDirectionSign(vehicle)
  local x, _, z = localDirectionToWorld(node, 0, 0, sign)
  local length = MathUtil.vector2Length(x, z)
  requireValue(length > 0.0001, "guidance direction has zero length")
  return node, x / length, z / length, sign
end

local function restoreGraphics()
  local saved = runner.savedGraphics
  if saved == nil then return end
  if saved.postAA ~= nil and setPostProcessAntiAliasing ~= nil then
    setPostProcessAntiAliasing(saved.postAA)
  end
  if saved.msaa ~= nil and setMSAA ~= nil then setMSAA(saved.msaa) end
  if saved.dlss ~= nil and setDLSSQuality ~= nil then setDLSSQuality(saved.dlss) end
  runner.savedGraphics = nil
end

local function deleteSpawnedVehicles()
  if g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil and
     g_localPlayer:getCurrentVehicle() ~= nil and g_localPlayer.leaveVehicle ~= nil then
    g_localPlayer:leaveVehicle(nil, true)
  end
  for index = #runner.spawnedVehicles, 1, -1 do
    local vehicle = runner.spawnedVehicles[index]
    if vehicle ~= nil and vehicle.delete ~= nil and vehicle.isDeleted ~= true then
      pcall(function() vehicle:delete() end)
    end
  end
  runner.spawnedVehicles = {}
end

local function cleanupResources()
  restoreGraphics()
  if runner.captureRenderer ~= nil then
    pcall(function() runner.captureRenderer:delete() end)
    runner.captureRenderer = nil
  end
  deleteSpawnedVehicles()
end

case("mission_load", function()
  requireValue(g_currentMission ~= nil, "mission is unavailable")
  requireValue(g_EnhancedVehicle ~= nil, "g_EnhancedVehicle was not constructed")
  requireValue(g_currentMission.EnhancedVehicle == g_EnhancedVehicle,
    "mission EnhancedVehicle reference is inconsistent")
  requireValue(g_EnhancedVehicle.version == "1.1.8.0", "unexpected mod version")
  requireValue(runner.statusStream ~= nil, "structured status stream is unavailable")
  return true
end)

case("dedicated_client_isolation", function()
  if g_dedicatedServerInfo == nil then return skip("client mission") end
  requireValue(FS25_EnhancedVehicle.ui_hud == nil, "dedicated server allocated a HUD")
  requireValue(FS25_EnhancedVehicle.ui_menu == nil, "dedicated server allocated a GUI")
  requireValue(FS25_EnhancedVehicle.lineRenderer == nil,
    "dedicated server allocated guidance geometry")
  return true
end)

case("renderer_pool_lifecycle", function(self)
  if g_dedicatedServerInfo ~= nil then return skip("dedicated server") end
  local renderer = FS25_EnhancedVehicle_LineRenderer.new(testModDirectory, 2)
  requireValue(renderer:load(), "renderer failed to load stock test geometry")
  requireValue(getParent(renderer.pool[1]) == getRootNode(),
    "renderer template is detached from the scene graph")
  requireValue(renderer:beginFrame(), "renderer frame did not start")
  requireValue(not renderer:drawSegment("invalid", 0, 0, 1, 0, 0, 1, 1, 1),
    "renderer accepted a non-numeric endpoint")
  requireValue(not renderer:drawSegment(0, 0, 0, 0, 0, 0, 1, 1, 1),
    "renderer accepted a zero-length segment")
  requireValue(renderer:drawSegment(0, 0, 0, 2, 0, 0, -1, 0.5, 2),
    "renderer rejected a valid segment")
  requireValue(renderer:drawSegment(0, 0, 0, 0, 2, 0, 1, 1, 1),
    "renderer rejected a vertical segment")
  renderer:endFrame()
  local firstNode = renderer.pool[1]
  renderer:beginFrame()
  requireValue(renderer:drawSegment(0, 0, 0, 0, 0, 2, 1, 1, 1),
    "renderer did not reuse a pooled segment")
  renderer:endFrame()
  requireValue(renderer.pool[1] == firstNode, "renderer replaced a reusable node")
  renderer:clear()
  requireValue(renderer.visibleCount == 0, "renderer clear left visible segments")
  renderer:delete()
  requireValue(not renderer.isLoaded and #renderer.pool == 0, "renderer deletion was incomplete")
  return true
end)

case("spawn_reverse_vehicle", function(self, dt, state)
  if g_dedicatedServerInfo ~= nil then return skip("dedicated server") end
  frameCount(state, dt)
  if state.phase == nil then
    self:spawnStock("tractor", "data/vehicles/valtra/sSeries/sSeries.xml", 0, 12,
      { vehicleType = 2 })
    state.phase = "loading"
    return false
  elseif state.phase == "loading" then
    local vehicle = self:consumeLoad("tractor")
    if vehicle == nil then return false end
    self.tractor = vehicle
    requireValue(vehicle.spec_reverseDriving ~= nil, "Valtra reverse-driving specialization missing")
    requireValue(vehicle.vData ~= nil, "EnhancedVehicle specialization data missing")
    requireValue(vehicle.getIsRegistered == nil or not vehicle:getIsRegistered(),
      "test tractor was unexpectedly registered")
    requireValue(FS25_EnhancedVehicle.ui_hud ~= nil, "client HUD was not constructed")
    return true
  end
end, 60000)

case("reverse_cab_transition", function(self, dt, state)
  if g_dedicatedServerInfo ~= nil then return skip("dedicated server") end
  frameCount(state, dt)
  local vehicle = self.tractor
  requireValue(vehicle ~= nil, "test tractor is unavailable")
  if state.phase == nil then
    vehicle:setIsReverseDriving(false, true, true)
    requireValue(vehicle.spec_reverseDriving.isChangingDirection,
      "normal-cab transition did not start")
    requireValue(vehicle.spec_drivable.reverserDirection == 0,
      "normal-cab transition did not neutralize the reverser")
    vehicle:reverseDirectionChanged(-1)
    requireValue(not vehicle.spec_reverseDriving.isChangingDirection,
      "normal-cab completion callback left a transition active")
    requireValue(vehicle.spec_drivable.reverserDirection > 0,
      "normal reverser direction was not established")
    state.normalNode, state.normalX, state.normalZ, state.normalSign = captureDirection(vehicle)
    requireValue(vehicle.spec_reverseDriving.isReverseDriving == false,
      "normal cab state was not applied")
    vehicle:setIsReverseDriving(true, true, true)
    requireValue(vehicle.spec_reverseDriving.isChangingDirection,
      "reverse-cab transition did not start")
    requireValue(vehicle.spec_drivable.reverserDirection == 0,
      "reverse-cab transition did not neutralize the reverser")
    local node, x, z, sign = captureDirection(vehicle)
    local dot = state.normalX * x + state.normalZ * z
    requireValue(vehicle.spec_reverseDriving.isReverseDriving == true,
      "reverse cab state was not applied")
    requireValue(node ~= state.normalNode or sign ~= state.normalSign or dot < -0.8,
      "reverse cab did not change the effective guidance frame")
    vehicle:reverseDirectionChanged(1)
    requireValue(not vehicle.spec_reverseDriving.isChangingDirection,
      "reverse-cab completion callback left a transition active")
    requireValue(vehicle.spec_drivable.reverserDirection < 0,
      "reverse-cab reverser transition did not finish")
    vehicle:setIsReverseDriving(false, true, true)
    requireValue(vehicle.spec_reverseDriving.isChangingDirection and
                 vehicle.spec_drivable.reverserDirection == 0,
      "normal-cab restoration did not enter its neutral transition")
    vehicle:reverseDirectionChanged(-1)
    requireValue(vehicle.spec_drivable.reverserDirection > 0,
      "normal reverser direction was not restored")
    return true
  end
end, 60000)

case("front_rear_implement_extrema", function(self, dt, state)
  if g_dedicatedServerInfo ~= nil then return skip("dedicated server") end
  frameCount(state, dt)
  if state.phase == nil then
    self:spawnStock("rearTool", "data/vehicles/samasz/xt390/xt390.xml", 4, 16)
    state.phase = "rearLoading"
    return false
  elseif state.phase == "rearLoading" then
    local tool = self:consumeLoad("rearTool")
    if tool == nil then return false end
    self.rearTool = tool
    self:spawnStock("frontTool", "data/vehicles/samasz/kdf341S/kdf341S.xml", -4, 16)
    state.phase = "frontLoading"
    return false
  elseif state.phase == "frontLoading" then
    local tool = self:consumeLoad("frontTool")
    if tool == nil then return false end
    self.frontTool = tool
    attachAt(self.tractor, self.rearTool, 1)
    attachAt(self.tractor, self.frontTool, 2)
    state.phase = "attaching"
    state.waitFrames = 30
    return false
  elseif state.phase == "attaching" then
    state.waitFrames = state.waitFrames - 1
    if state.waitFrames > 0 then return false end
    local attached = self.tractor:getAttachedImplements()
    requireValue(#attached >= 2, "front/rear implements did not attach")
    local joints = {}
    for _, implement in ipairs(attached) do joints[implement.jointDescIndex] = true end
    requireValue(joints[1] and joints[2], "implements did not occupy front and rear joints")
    FS25_EnhancedVehicle:enumerateImplements(self.tractor)
    local impl = self.tractor.vData.impl
    requireValue(impl.isCalculated, "combined implement geometry was not calculated")
    requireValue(impl.workWidth > 0.1 and impl.workWidth <= 100,
      "combined implement width is invalid")
    requireValue(impl.left.px > impl.right.px, "combined extrema are inverted")
    near(impl.workWidth, impl.left.px - impl.right.px, 0.001,
      "combined extrema width")
    return true
  end
end, 90000)

case("parking_hydraulics_hud_trip", function(self)
  if g_dedicatedServerInfo ~= nil then return skip("dedicated server") end
  local vehicle = self.tractor
  local previousBrake = vehicle.vData.want[13]
  FS25_EnhancedVehicle.onActionCall(vehicle, "FS25_EnhancedVehicle_PARK", 1, 0, 0, 0)
  requireValue(vehicle.vData.want[13] ~= previousBrake, "parking brake action did not toggle")

  FS25_EnhancedVehicle.onActionCall(
    vehicle, "FS25_EnhancedVehicle_AJ_FRONT_ONOFF", 1, 0, 0, 0)
  FS25_EnhancedVehicle.onActionCall(
    vehicle, "FS25_EnhancedVehicle_AJ_REAR_ONOFF", 1, 0, 0, 0)

  local hud = FS25_EnhancedVehicle.ui_hud
  requireValue(hud ~= nil and not hud.isDeleted, "HUD is unavailable")
  hud:setVehicle(vehicle)
  requireValue(hud.vehicle == vehicle, "HUD did not accept the test vehicle")
  hud:setVehicle(nil)
  requireValue(hud.vehicle == nil, "HUD did not release the test vehicle")
  hud:setVehicle(vehicle)

  vehicle.vData.want[15] = 42
  vehicle.vData.is[15] = 42
  local snapshot = FS25_EnhancedVehicle.buildNetworkSnapshot(vehicle, true)
  snapshot.tripReset = true
  snapshot = FS25_EnhancedVehicle.sanitizeNetworkSnapshot(vehicle, snapshot, true)
  FS25_EnhancedVehicle.applyNetworkSnapshot(vehicle, snapshot, true)
  requireValue(vehicle.vData.is[15] == 0, "trip reset did not reach canonical state")
  return true
end)

local function graphicsCase(label, kind, value)
  case("aa_" .. label, function(self, dt, state)
    if g_dedicatedServerInfo ~= nil then return skip("dedicated server") end
    frameCount(state, dt)
    if state.phase == nil then
      if self.savedGraphics == nil then
        self.savedGraphics = {
          postAA = getPostProcessAntiAliasing ~= nil and getPostProcessAntiAliasing() or nil,
          msaa = getMSAA ~= nil and getMSAA() or nil,
          dlss = getDLSSQuality ~= nil and getDLSSQuality() or nil
        }
      end
      if kind == "post" then
        if PostProcessAntiAliasing == nil or value == nil or
           getSupportsPostProcessAntiAliasing == nil or
           not getSupportsPostProcessAntiAliasing(value) then
          return skip("AA mode is unsupported by this GPU")
        end
        if DLSSQuality ~= nil and setDLSSQuality ~= nil then setDLSSQuality(DLSSQuality.OFF) end
        if MSAA ~= nil and setMSAA ~= nil then setMSAA(MSAA.OFF) end
        setPostProcessAntiAliasing(value)
      elseif kind == "msaa" then
        if MSAA == nil or MSAA.MSAA_4 == nil or setMSAA == nil then
          return skip("MSAA is unavailable")
        end
        if PostProcessAntiAliasing ~= nil and setPostProcessAntiAliasing ~= nil then
          setPostProcessAntiAliasing(PostProcessAntiAliasing.OFF)
        end
        setMSAA(MSAA.MSAA_4)
      end
      state.phase = "settling"
      state.waitFrames = 30
      return false
    elseif state.phase == "settling" then
      state.waitFrames = state.waitFrames - 1
      if state.waitFrames > 0 then return false end
      if self.captureRenderer == nil then
        self.captureRenderer = FS25_EnhancedVehicle_LineRenderer.new(testModDirectory, 4)
        requireValue(self.captureRenderer:load(), "capture renderer failed to load")
      end
      local camera = g_cameraManager:getActiveCamera()
      requireValue(camera ~= nil and entityExists(camera), "active camera is unavailable")
      -- Put the test ribbon close to the camera so terrain, buildings and the
      -- deliberately unregistered test vehicles cannot occlude it.  The
      -- dimensions preserve a broad, centered semantic target without relying
      -- on a pixel-perfect image.
      local x1, y1, z1 = localToWorld(camera, -0.55, -0.18, -2.2)
      local x2, y2, z2 = localToWorld(camera, 0.55, -0.18, -2.2)
      local sx1, sy1 = project(x1, y1, z1)
      local sx2, sy2 = project(x2, y2, z2)
      requireValue(sx1 >= 0 and sx1 <= 1 and sy1 >= 0 and sy1 <= 1 and
                   sx2 >= 0 and sx2 <= 1 and sy2 >= 0 and sy2 <= 1,
        "capture guidance segment projects outside the viewport")
      requireValue(self.captureRenderer:beginFrame(), "capture frame did not start")
      requireValue(self.captureRenderer:drawSegment(
        x1, y1, z1, x2, y2, z2, 0.05, 1, 0.95, 0.12, 0.035),
        "capture guidance segment was rejected")
      self.captureRenderer:endFrame()
      requireValue(self.captureRenderer.visibleCount == 1 and
                   getVisibility(self.captureRenderer.pool[1]),
        "capture guidance segment is not visible")
      state.captureDetails = string.format(
        "r=0.05 g=1 b=0.95 x1=%.6f y1=%.6f x2=%.6f y2=%.6f", sx1, sy1, sx2, sy2)
      requireValue(g_screenshotsDirectory ~= nil, "screenshot directory is unavailable")
      state.screenshotName = g_screenshotsDirectory ..
        string.format("EVTEST_%s_%s.png", label, getDate("%Y_%m_%d_%H_%M_%S"))
      -- saveScreenshot captures the previously rendered framebuffer.  Keep the
      -- target visible long enough to guarantee it has been submitted before
      -- requesting the capture.
      state.phase = "visible"
      state.waitFrames = 30
      return false
    elseif state.phase == "visible" then
      state.waitFrames = state.waitFrames - 1
      if state.waitFrames > 0 then return false end
      emit("CAPTURE", label, state.captureDetails)
      local screenshotSaved = saveScreenshot(state.screenshotName, false)
      requireValue(screenshotSaved ~= false, "engine rejected screenshot request")
      state.phase = "captured"
      state.waitFrames = 60
      return false
    elseif state.phase == "captured" then
      state.waitFrames = state.waitFrames - 1
      if state.waitFrames > 0 then return false end
      self.captureRenderer:clear()
      return true
    end
  end, 60000)
end

graphicsCase("off", "post", PostProcessAntiAliasing ~= nil and PostProcessAntiAliasing.OFF or nil)
graphicsCase("taa", "post", PostProcessAntiAliasing ~= nil and PostProcessAntiAliasing.TAA or nil)
graphicsCase("dlaa", "post", PostProcessAntiAliasing ~= nil and PostProcessAntiAliasing.DLAA or nil)
graphicsCase("msaa4", "msaa", nil)

case("mod_teardown", function(self, dt, state)
  frameCount(state, dt)
  if state.phase == nil then
    cleanupResources()
    state.phase = "unload"
    state.waitFrames = 3
    return false
  elseif state.phase == "unload" then
    state.waitFrames = state.waitFrames - 1
    if state.waitFrames > 0 then return false end
    requireValue(type(EV_unload) == "function", "loader unload callback is unavailable")
    EV_unload()
    requireValue(g_EnhancedVehicle == nil, "global mod reference survived unload")
    requireValue(FS25_EnhancedVehicle.ui_hud == nil, "HUD survived unload")
    requireValue(FS25_EnhancedVehicle.lineRenderer == nil, "renderer survived unload")
    return true
  end
end, 60000)

function runner:finishCurrent(result)
  local name = self.currentCase.name
  if type(result) == "table" and result.skip ~= nil then
    self.skipCount = self.skipCount + 1
    emit("SKIP", name, result.skip)
  else
    self.passCount = self.passCount + 1
    emit("PASS", name)
  end
  self.currentCase = nil
  self.caseState = nil
end

function runner:failCurrent(reason)
  self.failCount = self.failCount + 1
  emit("FAIL", self.currentCase ~= nil and self.currentCase.name or "runner", reason)
  self.currentCase = nil
  self.caseState = nil
end

function runner:startNextCase()
  self.caseIndex = self.caseIndex + 1
  self.currentCase = self.cases[self.caseIndex]
  if self.currentCase == nil then
    self.complete = true
    emit("COMPLETE", string.format("pass=%d fail=%d skip=%d",
      self.passCount, self.failCount, self.skipCount))
    if self.statusStream ~= nil then
      self.statusStream:close()
      self.statusStream = nil
    end
    return
  end
  self.caseState = {}
  self.caseStartedAt = g_time or 0
  emit("START", self.currentCase.name)
end

function runner:update(dt)
  if self.complete then return end
  if not self.started then
    self.startupWait = self.startupWait + dt
    if g_currentMission == nil or g_EnhancedVehicle == nil or
       g_currentMission.cancelLoading == true then
      if self.startupWait > 120000 then
        self.complete = true
        emit("FAIL", "mission_start", "mission or EnhancedVehicle did not become ready")
        emit("COMPLETE", "pass=0 fail=1 skip=0")
      end
      return
    end
    if g_dedicatedServerInfo == nil and g_gui ~= nil then
      print("EVTEST GUI " .. clean(g_gui.currentGuiName or ""))
    end
    self.started = true
    self:startNextCase()
    return
  end

  if self.currentCase == nil then
    self:startNextCase()
    return
  end
  local elapsed = (g_time or 0) - self.caseStartedAt
  if elapsed > self.currentCase.timeout then
    self:failCurrent("case timeout")
    return
  end
  local ok, result = xpcall(
    function() return self.currentCase.callback(self, dt, self.caseState) end,
    function(message) return tostring(message) end)
  if not ok then
    self:failCurrent(result)
  elseif result == true or type(result) == "table" then
    self:finishCurrent(result)
  end
end

function runner:deleteMap()
  if not self.complete then cleanupResources() end
  if self.statusStream ~= nil then
    self.statusStream:close()
    self.statusStream = nil
  end
end

-- A dedicated server does not call mod-event-listener update methods until a
-- client has joined, even when pause_game_if_empty is disabled.  Run the
-- server-only smoke checks from the mission-finished lifecycle instead.  This
-- callback fires after EnhancedVehicle's own appended callback, so it verifies
-- the fully initialized mod without requiring a second licensed client.
local function runDedicatedCase(name, callback)
  emit("START", name)
  local ok, reason = xpcall(callback, function(message) return tostring(message) end)
  if ok then
    runner.passCount = runner.passCount + 1
    emit("PASS", name)
  else
    runner.failCount = runner.failCount + 1
    emit("FAIL", name, reason)
  end
end

function runner:onDedicatedMissionLoaded(mission)
  local dynamicInfo = mission ~= nil and mission.missionDynamicInfo or nil
  local isHeadlessServer = g_dedicatedServerInfo ~= nil or
    (dynamicInfo ~= nil and dynamicInfo.isMultiplayer == true)
  if not isHeadlessServer or self.complete then return end
  self.started = true

  runDedicatedCase("mission_load", function()
    requireValue(mission ~= nil and mission == g_currentMission,
      "dedicated mission is unavailable")
    requireValue(g_EnhancedVehicle ~= nil, "g_EnhancedVehicle was not constructed")
    requireValue(mission.EnhancedVehicle == g_EnhancedVehicle,
      "mission EnhancedVehicle reference is inconsistent")
    requireValue(g_EnhancedVehicle.version == "1.1.8.0", "unexpected mod version")
    requireValue(self.statusStream ~= nil, "structured status stream is unavailable")
  end)

  runDedicatedCase("dedicated_client_isolation", function()
    requireValue(FS25_EnhancedVehicle.ui_hud == nil, "dedicated server allocated a HUD")
    requireValue(FS25_EnhancedVehicle.ui_menu == nil, "dedicated server allocated a GUI")
    requireValue(FS25_EnhancedVehicle.lineRenderer == nil,
      "dedicated server allocated guidance geometry")
    requireValue(FS25_EnhancedVehicle.sounds ~= nil and
                 next(FS25_EnhancedVehicle.sounds) == nil,
      "dedicated server allocated client sound objects")
  end)

  runDedicatedCase("mod_teardown", function()
    requireValue(type(EV_unload) == "function", "loader unload callback is unavailable")
    EV_unload()
    requireValue(g_EnhancedVehicle == nil, "global mod reference survived unload")
    requireValue(FS25_EnhancedVehicle.ui_hud == nil, "HUD survived unload")
    requireValue(FS25_EnhancedVehicle.ui_menu == nil, "GUI survived unload")
    requireValue(FS25_EnhancedVehicle.lineRenderer == nil, "renderer survived unload")
  end)

  self.complete = true
  emit("COMPLETE", string.format("pass=%d fail=%d skip=%d",
    self.passCount, self.failCount, self.skipCount))
  if self.statusStream ~= nil then
    self.statusStream:close()
    self.statusStream = nil
  end
end

-- g_dedicatedServerInfo is not populated yet when extraSourceFiles are read,
-- so install both paths and decide when the callbacks actually run.
Mission00.loadMission00Finished = Utils.appendedFunction(
  Mission00.loadMission00Finished,
  function(mission) runner:onDedicatedMissionLoaded(mission) end)
FS25_EnhancedVehicle.loadMap = Utils.appendedFunction(
  FS25_EnhancedVehicle.loadMap,
  function() runner:onDedicatedMissionLoaded(g_currentMission) end)
addModEventListener(runner)
