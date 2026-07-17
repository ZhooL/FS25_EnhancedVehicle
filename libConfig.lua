--
-- Lib: libConfig (for Farming Simulator 22++)
--
-- Author: Majo76
-- email: ls (at) majo76 (dot) de
-- @Date: 06.12.2021
-- @Version: 1.0.1.0

-- #############################################################################

local myName = "libConfig"

libConfig = {}
libConfig.__index = libConfig

setmetatable(libConfig, {
  __call = function (cls, ...)
  local self = setmetatable({}, cls)

  self.debug = 0
  self:new(...)

  return self
  end,
})

-- #############################################################################

function libConfig:new(myName, configVersionCurrent, configVersionOld)
  if self.debug > 0 then print("-> libConfig: new()") end

  self.myName = myName
  self.configVersionCurrent = configVersionCurrent
  self.configVersionOld     = configVersionOld

  -- some stuff we need
  self.modDirectory      = g_currentModDirectory
  self.settingsDirectory = getUserProfileAppPath() .. "modSettings/"
  self.confDirectory     = self.settingsDirectory .. self.myName .. "/"

  -- for storing all the data
  self.dataDefault = {}
  self.dataCurrent = {}
end

-- #############################################################################

function libConfig:setDebug(dbg)
  self.debug = dbg or 0
end

-- #############################################################################

function libConfig:clearConfig()
  self.dataDefault = {}
  self.dataCurrent = {}
end

-- #############################################################################

function libConfig:addConfigValue(section, name, typ, value, newLine)
  if self.debug > 0 then print("-> "..myName.." ("..self.myName..") addConfigValue()") end
  if self.debug > 1 then print("--> section: "..section..", name: "..name..", typ: "..typ..", value: "..tostring(value)) end

  -- create empty table node
  local newData = {}
  newData.section = section
  newData.typ     = typ
  newData.name    = name
  newData.value   = value
  newData.newLine = newLine or false

  local defaultValue = value
  if type(value) == "table" then
    defaultValue = {}
    for key, item in pairs(value) do
      defaultValue[key] = item
    end
  end

  -- Keep independent objects so changing the current value never mutates the
  -- default used by the reset/reload paths.
  table.insert(self.dataDefault, {
    section = newData.section,
    typ = newData.typ,
    name = newData.name,
    value = defaultValue,
    newLine = newData.newLine
  })
  table.insert(self.dataCurrent, newData)

  if self.debug > 2 then print(DebugUtil.printTableRecursively(self.dataCurrent, 0, 0, 3)) end
end

-- #############################################################################

function libConfig:getConfigValue(section, name)
  if self.debug > 0 then print("-> "..myName.." ("..self.myName..") getConfigValue()") end
  if self.debug > 1 then print("--> section: "..section..", name: "..name) end

  -- search through data
  for _, data in pairs(self.dataCurrent) do
    if data.section == section and data.name == name then
      if self.debug > 1 then print("---> typ: "..data.typ..", value: "..tostring(data.value)) end
      return(data.value)
    end
  end

  return(nil)
end

-- #############################################################################

function libConfig:setConfigValue(section, name, value, deferWrite)
  if self.debug > 0 then print("-> "..myName.." ("..self.myName..") setConfigValue()") end
  if self.debug > 1 then print("--> section: "..section..", name: "..name..", value: "..tostring(value)) end

  -- search through data and change value
  for _, data in pairs(self.dataCurrent) do
    if data.section == section and data.name == name then
      data.value = value
    end
  end

  -- Preserve the historical immediate-write behaviour for callers which do
  -- not opt in to batching.
  if not deferWrite then
    self:writeConfig()
  end

  if self.debug > 2 then print(DebugUtil.printTableRecursively(self.dataCurrent, 0, 0, 3)) end
end

-- #############################################################################

function libConfig:readConfig()
  if self.debug > 0 then print("-> "..myName.." ("..self.myName..") readConfig()") end

  -- skip on dedicated servers
  if g_dedicatedServerInfo ~= nil then
    return
  end

  self.confFile = self.confDirectory .. self.myName .. "_v"..self.configVersionOld..".xml"
  if self.debug > 1 then print("--> confFile: "..self.confFile) end
  if not fileExists(self.confFile) then
    if self.debug > 1 then print("---> not found. trying current version") end
    self.confFile = self.confDirectory .. self.myName .. "_v"..self.configVersionCurrent..".xml"
    if self.debug > 1 then print("--> confFile: "..self.confFile) end
    if not fileExists(self.confFile) then
      if self.debug > 1 then print("---> not found. that's bad. no config file at all") end
      return
    end
  end

  local xml = loadXMLFile(self.myName, self.confFile, self.myName)
  local pos = {}
  -- sort our data by sections
  local sortedKeys = self:getKeysSortedByValue(self.dataCurrent, function(a, b) return a.section < b.section end)

  for _, key in ipairs(sortedKeys) do
    local data = self.dataCurrent[key]
    local group = data.section
    if pos[group] ==  nil then
      pos[group] = 0
    end
    local groupNameTag = string.format("%s.%s(%d)", self.myName, group, pos[group])
    if data.newLine then
      pos[group] = pos[group] + 1
    end
    if data.typ == "float" then
      self.dataCurrent[key].value = Utils.getNoNil(getXMLFloat(xml, groupNameTag .. "#" .. data.name), self.dataCurrent[key].value)
    end
    if data.typ == "int" then
      self.dataCurrent[key].value = Utils.getNoNil(getXMLInt(xml, groupNameTag .. "#" .. data.name), self.dataCurrent[key].value)
    end
    if data.typ == "bool" then
      self.dataCurrent[key].value = Utils.getNoNil(getXMLBool(xml, groupNameTag .. "#" .. data.name), self.dataCurrent[key].value)
    end
    if data.typ == "table" then
      self.dataCurrent[key].value = self:splitter( Utils.getNoNil(getXMLString(xml, groupNameTag .. "#" .. data.name), self.dataCurrent[key].value), ",")
    end
  end

  delete(xml)
end

-- #############################################################################

function libConfig:writeConfig()
  if self.debug > 0 then print("-> "..myName.." ("..self.myName..") writeConfig()") end

  -- skip on dedicated servers
  if g_dedicatedServerInfo ~= nil then
    return
  end

  -- if old version exists -> delete it
  self.confFile = self.confDirectory .. self.myName .. "_v"..self.configVersionOld..".xml"
  if self.debug > 1 then print("--> confFile: "..self.confFile) end
  if fileExists(self.confFile) then
    if self.debug > 1 then print("---> found. deleting") end
    -- TODO
  end

  -- new file
  self.confFile = self.confDirectory .. self.myName .. "_v"..self.configVersionCurrent..".xml"
  if self.debug > 1 then print("--> confFile: "..self.confFile) end

  -- create folders
  createFolder(self.settingsDirectory)
  createFolder(self.confDirectory);

  local xml = createXMLFile(self.myName, self.confFile, self.myName)
  local pos = {}
  -- sort our data by sections and name (inside a section)
  local sortedKeys = self:getKeysSortedByValue(self.dataCurrent, function(a, b) return a.section..a.name < b.section..b.name end)

  for _, key in ipairs(sortedKeys) do
    local data = self.dataCurrent[key]
    local group = data.section
    if pos[group] ==  nil then
      pos[group] = 0
    end
    local groupNameTag = string.format("%s.%s(%d)", self.myName, group, pos[group])
    if data.newLine then
      pos[group] = pos[group] + 1
    end
    if data.typ == "float" then
      setXMLFloat(xml, groupNameTag .. "#" .. data.name, tonumber(data.value))
    end
    if data.typ == "int" then
      setXMLInt(xml, groupNameTag .. "#" .. data.name, math.floor(tonumber(data.value)))
    end
    if data.typ == "bool" then
      setXMLBool(xml, groupNameTag .. "#" .. data.name, data.value)
    end
    if data.typ == "table" then
      setXMLString(xml, groupNameTag .. "#" .. data.name, table.concat(data.value, ","))
    end
  end

  -- write file to disk
  saveXMLFile(xml)
  delete(xml)

  if self.debug > 2 then print(DebugUtil.printTableRecursively(self.dataCurrent, 0, 0, 3)) end
end

-- #############################################################################

function libConfig:getKeysSortedByValue(tbl, sortFunction)
  local keys = {}
  for key in pairs(tbl) do
    table.insert(keys, key)
  end

  table.sort(keys, function(a, b)
    return sortFunction(tbl[a], tbl[b])
  end)

  return keys
end

-- #############################################################################

function libConfig:splitter(str, pat, limit)
  local t = {}
  local fpat = "(.-)" .. pat
  local last_end = 1
  local s, e, cap = str:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
      table.insert(t, cap)
    end

    last_end = e+1
    s, e, cap = str:find(fpat, last_end)

    if limit ~= nil and limit <= #t then
      break
    end
  end

  if last_end <= #str then
    cap = str:sub(last_end)
    table.insert(t, cap)
  end

  return t
end
