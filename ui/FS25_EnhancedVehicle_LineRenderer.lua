--
-- FS25_EnhancedVehicle line renderer
--
-- Draws persistent, filled scene geometry instead of debug lines. The caller
-- owns terrain sampling and must bracket all segments with beginFrame/endFrame.

FS25_EnhancedVehicle_LineRenderer = {}
local FS25_EnhancedVehicle_LineRenderer_mt = Class(FS25_EnhancedVehicle_LineRenderer)

FS25_EnhancedVehicle_LineRenderer.MAX_SEGMENTS = 384
FS25_EnhancedVehicle_LineRenderer.RIBBON_WIDTH = 0.08
FS25_EnhancedVehicle_LineRenderer.RIBBON_THICKNESS = 0.015
FS25_EnhancedVehicle_LineRenderer.POST_SIZE = 0.04

local MIN_SEGMENT_LENGTH = 0.001
local UNIT_PLANE_CONTOUR = {
  -0.5, -0.5,
   0.5, -0.5,
   0.5,  0.5,
  -0.5,  0.5
}

local function isFinite(value)
  return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function clampColor(value)
  if not isFinite(value) then
    return 1
  end

  return math.max(0, math.min(value, 1))
end

local function logError(message, ...)
  if Logging ~= nil then
    Logging.error(message, ...)
  else
    print(string.format("Error: " .. message, ...))
  end
end

local function logWarning(message, ...)
  if Logging ~= nil then
    Logging.warning(message, ...)
  else
    print(string.format("Warning: " .. message, ...))
  end
end

local function findFirstMaterial(node)
  if getHasClassId(node, ClassIds.SHAPE) then
    local material = getMaterial(node, 0)
    if material ~= nil and material ~= 0 then
      return material
    end
  end
  for index = 0, getNumOfChildren(node) - 1 do
    local material = findFirstMaterial(getChildAt(node, index))
    if material ~= nil then return material end
  end
  return nil
end

-- #############################################################################

function FS25_EnhancedVehicle_LineRenderer.new(modDirectory, maxSegments)
  local self = setmetatable({}, FS25_EnhancedVehicle_LineRenderer_mt)

  self.filename = Utils.getFilename("resources/guidanceRibbon.i3d", modDirectory)
  self.maxSegments = math.min(math.max(maxSegments or FS25_EnhancedVehicle_LineRenderer.MAX_SEGMENTS, 1), FS25_EnhancedVehicle_LineRenderer.MAX_SEGMENTS)
  self.pool = {}
  self.templateNode = nil
  self.usedCount = 0
  self.visibleCount = 0
  self.isFrameActive = false
  self.isLoaded = false
  self.hasLoggedOverflow = false
  self.hasLoggedCloneFailure = false

  return self
end

-- #############################################################################

function FS25_EnhancedVehicle_LineRenderer:load()
  if self.isLoaded then
    return true
  end

  if g_currentMission == nil or not g_currentMission:getIsClient() then
    return false
  end

  local rootNode, failedReason = loadI3DFile(self.filename, false, false, false)
  if rootNode == nil or rootNode == 0 then
    logError("FS25_EnhancedVehicle could not load guidance-line geometry '%s' (reason %s)", self.filename, tostring(failedReason))
    return false
  end

  setVisibility(rootNode, false)
  local material = findFirstMaterial(rootNode)
  if material == nil or material == 0 then
    delete(rootNode)
    logError("FS25_EnhancedVehicle guidance-line material is unavailable in '%s'", self.filename)
    return false
  end

  local group = createTransformGroup("FS25_EnhancedVehicle_guidanceSegment")
  if group == nil or group == 0 then
    delete(rootNode)
    logError("FS25_EnhancedVehicle could not create a guidance-line transform group")
    return false
  end
  link(getRootNode(), group)

  -- FS25 does not submit inline XML IndexedTriangleSet geometry reliably.
  -- Build a supported CPU plane once, then pool clones of two-sided crossed
  -- planes.  One pair lies on the terrain; the other pair keeps vertical posts
  -- and near-camera diagnostics visible without depending on the view angle.
  local rotations = {
    { 0, 0, 0 },
    { math.pi, 0, 0 },
    { 0, 0, math.pi * 0.5 },
    { 0, 0, -math.pi * 0.5 }
  }
  for index, rotation in ipairs(rotations) do
    local plane = createPlaneShapeFrom2DContour(
      "FS25_EnhancedVehicle_guidancePlane" .. tostring(index), UNIT_PLANE_CONTOUR, false)
    if plane == nil or plane == 0 then
      delete(group)
      delete(rootNode)
      logError("FS25_EnhancedVehicle could not create supported guidance-line geometry")
      return false
    end
    link(group, plane)
    setTranslation(plane, 0, 0, 0)
    setRotation(plane, rotation[1], rotation[2], rotation[3])
    setMaterial(plane, material, 0)
  end
  delete(rootNode)

  self.templateNode = group
  self.pool[1] = group
  self.isLoaded = true
  setVisibility(group, false)

  return true
end

-- #############################################################################

function FS25_EnhancedVehicle_LineRenderer:_acquireNode(index)
  if index > self.maxSegments then
    if not self.hasLoggedOverflow then
      logWarning("FS25_EnhancedVehicle guidance-line renderer reached its %d-segment limit; extra segments are skipped", self.maxSegments)
      self.hasLoggedOverflow = true
    end

    return nil
  end

  local node = self.pool[index]
  if node ~= nil then
    return node
  end

  node = clone(self.templateNode, false, false, false)
  if node == nil or node == 0 then
    if not self.hasLoggedCloneFailure then
      logError("FS25_EnhancedVehicle could not grow the guidance-line geometry pool")
      self.hasLoggedCloneFailure = true
    end

    return nil
  end

  link(getRootNode(), node)
  setVisibility(node, false)
  self.pool[index] = node

  return node
end

-- #############################################################################

function FS25_EnhancedVehicle_LineRenderer:beginFrame()
  if not self.isLoaded then
    return false
  end

  if self.isFrameActive then
    self:endFrame()
  end

  self.usedCount = 0
  self.isFrameActive = true

  return true
end

-- #############################################################################

-- Draw a prism centered between two world-space endpoints. The unit mesh's
-- local +Z axis follows the segment. Width defaults to a horizontal ribbon;
-- pass POST_SIZE for both width and thickness to draw a vertical marker post.
function FS25_EnhancedVehicle_LineRenderer:drawSegment(x1, y1, z1, x2, y2, z2, r, g, b, width, thickness)
  if not self.isFrameActive then
    return false
  end

  if not isFinite(x1) or not isFinite(y1) or not isFinite(z1) or
     not isFinite(x2) or not isFinite(y2) or not isFinite(z2) then
    return false
  end

  width = width or FS25_EnhancedVehicle_LineRenderer.RIBBON_WIDTH
  thickness = thickness or FS25_EnhancedVehicle_LineRenderer.RIBBON_THICKNESS
  if not isFinite(width) or not isFinite(thickness) or width <= 0 or thickness <= 0 then
    return false
  end

  local dx = x2 - x1
  local dy = y2 - y1
  local dz = z2 - z1
  local length = math.sqrt(dx * dx + dy * dy + dz * dz)
  if not isFinite(length) or length < MIN_SEGMENT_LENGTH then
    return false
  end

  local index = self.usedCount + 1
  local node = self:_acquireNode(index)
  if node == nil then
    return false
  end

  local invLength = 1 / length
  local dirX = dx * invLength
  local dirY = dy * invLength
  local dirZ = dz * invLength
  local upX, upY, upZ = 0, 1, 0

  -- A vertical segment cannot use a parallel world-up reference.
  if math.abs(dirY) > 0.999 then
    upX, upY, upZ = 1, 0, 0
  end

  setTranslation(node, (x1 + x2) * 0.5, (y1 + y2) * 0.5, (z1 + z2) * 0.5)
  setDirection(node, dirX, dirY, dirZ, upX, upY, upZ)
  setScale(node, width, thickness, length)
  setShaderParameterRecursive(node, "colorScale", clampColor(r), clampColor(g), clampColor(b), 1, false)
  setVisibility(node, true)

  self.usedCount = index

  return true
end

-- #############################################################################

function FS25_EnhancedVehicle_LineRenderer:endFrame()
  if not self.isLoaded then
    return
  end

  for index = self.usedCount + 1, self.visibleCount do
    setVisibility(self.pool[index], false)
  end

  self.visibleCount = self.usedCount
  self.isFrameActive = false
end

-- #############################################################################

function FS25_EnhancedVehicle_LineRenderer:clear()
  if not self.isLoaded then
    return
  end

  for index = 1, math.max(self.usedCount, self.visibleCount) do
    setVisibility(self.pool[index], false)
  end

  self.usedCount = 0
  self.visibleCount = 0
  self.isFrameActive = false
end

-- #############################################################################

function FS25_EnhancedVehicle_LineRenderer:delete()
  for _, node in ipairs(self.pool) do
    if entityExists(node) then
      delete(node)
    end
  end

  self.pool = {}
  self.templateNode = nil
  self.usedCount = 0
  self.visibleCount = 0
  self.isFrameActive = false
  self.isLoaded = false
end
