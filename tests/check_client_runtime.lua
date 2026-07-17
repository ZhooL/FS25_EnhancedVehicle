-- Client-only regression checks with lightweight GIANTS engine mocks.

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

local function assertTrue(value, label)
  if not value then error(label .. ": expected true", 2) end
end

debug = 0
ClassIds = { SHAPE = 1 }
function Class(classTable)
  classTable.superClass = classTable.superClass or function()
    return { delete = function() end, onOpen = function() end }
  end
  return { __index = classTable }
end

HUDDisplayElement = {}
Utils = {
  getFilename = function(filename, directory) return directory .. filename end,
  appendedFunction = function(original, appended)
    return function(...)
      if original ~= nil then original(...) end
      return appended(...)
    end
  end
}

local nodes = {}
local nextNode = 1
local sceneRoot = 9999
local function newNode()
  local node = nextNode
  nextNode = nextNode + 1
  nodes[node] = { exists = true, visible = nil, children = {}, isShape = false }
  return node
end

function loadI3DFile()
  local root = newNode()
  local materialShape = newNode()
  nodes[materialShape].isShape = true
  nodes[materialShape].material = 777
  nodes[materialShape].parent = root
  table.insert(nodes[root].children, materialShape)
  return root, 0
end
function clone() return newNode() end
function getRootNode() return sceneRoot end
function getChildAt(parent, index) return nodes[parent].children[index + 1] end
function getNumOfChildren(parent) return #nodes[parent].children end
function getHasClassId(node, classId) return classId == ClassIds.SHAPE and nodes[node].isShape end
function getMaterial(node) return nodes[node].material end
function createTransformGroup() return newNode() end
function createPlaneShapeFrom2DContour() return newNode() end
function link(parent, node)
  nodes[node].parent = parent
  if nodes[parent] ~= nil then table.insert(nodes[parent].children, node) end
end
function setVisibility(node, visible) nodes[node].visible = visible end
function setTranslation(node, x, y, z) nodes[node].translation = { x, y, z } end
function setDirection(node, x, y, z, ux, uy, uz) nodes[node].direction = { x, y, z, ux, uy, uz } end
function setScale(node, x, y, z) nodes[node].scale = { x, y, z } end
function setRotation(node, x, y, z) nodes[node].rotation = { x, y, z } end
function setMaterial(node, material) nodes[node].material = material end
function setShaderParameterRecursive(node, name, r, g, b, a)
  nodes[node].shader = { name, r, g, b, a }
end
function entityExists(node) return nodes[node] ~= nil and nodes[node].exists end
function delete(node) nodes[node].exists = false end

local isClient = true
g_currentMission = {
  getIsClient = function() return isClient end,
  hud = {
    fillLevelsDisplay = { y = 0.2, offsetY = 0.03 },
    sideNotifications = { markProgressBarForDrawing = function() end }
  }
}
Logging = {
  errors = {},
  warnings = {},
  error = function(message) table.insert(Logging.errors, message) end,
  warning = function(message) table.insert(Logging.warnings, message) end
}

dofile("ui/FS25_EnhancedVehicle_LineRenderer.lua")

local renderer = FS25_EnhancedVehicle_LineRenderer.new("./", 2)
assertEqual(renderer.maxSegments, 2, "renderer segment limit")
assertTrue(renderer:load(), "client renderer load")
assertTrue(renderer:load(), "idempotent renderer load")
assertEqual(#renderer.pool, 1, "template pool size")
assertEqual(nodes[renderer.pool[1]].parent, sceneRoot, "template linked to scene root")
assertTrue(renderer:beginFrame(), "begin frame")
assertEqual(renderer:drawSegment(0/0, 0, 0, 1, 0, 0, 1, 1, 1), false, "NaN rejection")
assertEqual(renderer:drawSegment(0, 0, 0, math.huge, 0, 0, 1, 1, 1), false, "infinity rejection")
assertEqual(renderer:drawSegment(0, 0, 0, 0, 0, 0, 1, 1, 1), false, "zero length rejection")
assertEqual(renderer:drawSegment(0, 0, 0, 1, 0, 0, 1, 1, 1, -1), false, "negative width rejection")
assertTrue(renderer:drawSegment(0, 0, 0, 4, 0, 0, -1, 0.5, 2), "horizontal segment")
local first = renderer.pool[1]
assertNear(nodes[first].translation[1], 2, 0.000001, "segment midpoint")
assertNear(nodes[first].scale[3], 4, 0.000001, "segment length scale")
assertEqual(nodes[first].shader[2], 0, "red clamp")
assertEqual(nodes[first].shader[3], 0.5, "green color")
assertEqual(nodes[first].shader[4], 1, "blue clamp")
assertTrue(renderer:drawSegment(0, 0, 0, 0, 5, 0, 1, 1, 1), "vertical segment")
assertEqual(nodes[renderer.pool[2]].parent, sceneRoot, "pooled clone linked to scene root")
assertEqual(nodes[renderer.pool[2]].direction[4], 1, "vertical alternate up axis")
assertEqual(renderer:drawSegment(0, 0, 0, 0, 0, 3, 1, 1, 1), false, "pool overflow")
assertEqual(#Logging.warnings, 1, "single overflow warning")
renderer:endFrame()
assertEqual(renderer.visibleCount, 2, "visible segment count")

assertTrue(renderer:beginFrame(), "second frame")
assertTrue(renderer:drawSegment(0, 0, 0, 0, 0, 2, 1, 1, 1), "pooled segment reuse")
renderer:endFrame()
assertEqual(renderer.pool[1], first, "first pooled node reused")
assertEqual(nodes[renderer.pool[2]].visible, false, "unused node hidden")
renderer:clear()
assertEqual(renderer.visibleCount, 0, "clear visible count")
renderer:delete()
assertEqual(renderer.isLoaded, false, "renderer deleted state")
assertEqual(nodes[first].exists, false, "renderer nodes deleted")

isClient = false
local serverRenderer = FS25_EnhancedVehicle_LineRenderer.new("./")
assertEqual(serverRenderer:load(), false, "server renderer suppression")
assertEqual(#serverRenderer.pool, 0, "server renderer has no nodes")

-- HUD lifecycle and fill-level position restoration.
FS25_EnhancedVehicle = {
  functionSnapIsEnabled = true,
  hud = {
    colorInactive = { 0.7, 0.7, 0.7, 1 },
    colorActive = { 0.2, 0.5, 0, 1 },
    colorStandby = { 1, 0.5, 0, 1 },
    track = { enabled = true, offsetX = 0, offsetY = 0, moveFillLevelsDisplayDeltaY = 0 },
    diff = {}, misc = {}, park = {}, dmg = {}, fuel = {}
  }
}
g_i18n = { getText = function(_, key) return key end }

dofile("ui/FS25_EnhancedVehicle_HUD.lua")

local speedMeter = {
  speedBg = { x = 0.7, y = 0.1, width = 0.2, height = 0.2 },
  uiScale = 1,
  scalePixelToScreenHeight = function(_, value) return value / 1000 end
}
local gameInfo = {
  uiScale = 1,
  infoBgScale = { height = 0.1 },
  getPosition = function() return 0.1, 0.8 end
}
local hud = FS25_EnhancedVehicle_HUD:new(speedMeter, gameInfo, "./")
local eligible = { spec_motorized = {}, ["spec_FS25_EnhancedVehicle.EnhancedVehicle"] = {} }
assertTrue(hud:isVehicleEligible(eligible), "eligible vehicle")
assertEqual(hud:isVehicleEligible({ spec_motorized = {} }), false, "ineligible vehicle")

local trackBox = {
  visible = true,
  getPosition = function() return 0.3, 0.4 end,
  getHeight = function() return 0.1 end,
  setVisible = function(self, value) self.visible = value end,
  delete = function(self) self.deleted = true end
}
hud.trackBox = trackBox
hud.marginElement = 0.01
hud.vehicle = eligible
hud:updateFillLevelsPosition()
assertNear(g_currentMission.hud.fillLevelsDisplay.y, 0.51, 0.000001, "fill display moved")
assertEqual(g_currentMission.hud.fillLevelsDisplay.offsetY, 0, "fill display offset moved")
hud:setVehicle(nil)
assertNear(g_currentMission.hud.fillLevelsDisplay.y, 0.2, 0.000001, "fill display restored")
assertNear(g_currentMission.hud.fillLevelsDisplay.offsetY, 0.03, 0.000001, "fill offset restored")
assertEqual(trackBox.visible, false, "HUD elements hidden on switch")

hud.trackBox = trackBox
hud:setVehicle(eligible)
assertEqual(hud.vehicle, eligible, "HUD vehicle switched")
hud:hideSomething({ isClient = true })
assertEqual(hud.vehicle, eligible, "unrelated vehicle ignored")
hud:hideSomething(eligible)
assertEqual(hud.vehicle, nil, "active vehicle hidden")
hud.trackBox = trackBox
hud:delete()
assertTrue(hud.isDeleted, "HUD deleted state")
assertTrue(trackBox.deleted, "HUD elements deleted")
hud:delete()

print("Validated client renderer pooling, transforms, invalid values, and HUD lifecycle")
