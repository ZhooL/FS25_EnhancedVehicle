--
-- Lib: libConfig (for Farming Simulator 22++)
--
-- Author: Majo76
-- email: ls (at) majo76 (dot) de
-- @Date: 06.12.2021
-- @Version: 1.0.1.0

-- #############################################################################

LibConfig = {
  myName = "libConfig",
  logger = LibUtils.Logger,
  configSetName = nil
}
LibConfig.__index = LibConfig

-- #############################################################################

function LibConfig:new(configSetName, configVersionCurrent, configVersionOld, logger)
  logger.info(LibConfig.myName .. ": new()")
  local instance = setmetatable({}, self)
  instance.logger = logger

  -- some stuff we need
  instance.configSetName     = configSetName
  instance.modDirectory      = g_currentModDirectory
  instance.settingsDirectory = getUserProfileAppPath() .. "modSettings/"
  instance.confDirectory     = instance.settingsDirectory .. instance.configSetName .. "/"
  instance.confFileOld       = instance.confDirectory .. instance.configSetName .. "_v" .. configVersionOld .. ".xml"
  instance.confFileCurrent   = instance.confDirectory .. instance.configSetName .. "_v" .. configVersionCurrent .. ".xml"

  -- for storing all the data
  instance.dataDefault = {}
  instance.dataCurrent = {}
  return instance
end

-- #############################################################################

function LibConfig:clearConfig()
  self.dataDefault = {}
  self.dataCurrent = {}
end

-- #############################################################################

function LibConfig:addConfigValue(section, name, typ, value, newLine)
  self.logger.debug("-> "..self.myName.." ("..self.configSetName..") addConfigValue()")
  self.logger.debug("--> section: "..section..", name: "..name..", typ: "..typ..", value: "..tostring(value))

  -- create empty table node
  local newData = {}
  newData.section = section
  newData.typ     = typ
  newData.name    = name
  newData.value   = value
  newData.newLine = newLine or false

  -- insert into our data storage
  table.insert(self.dataDefault, newData)
  table.insert(self.dataCurrent, newData)

  self.logger.trace(DebugUtil.printTableRecursively(self.dataCurrent, 0, 0, 3))
end

-- #############################################################################

function LibConfig:getConfigValue(section, name)
  self.logger.info("-> "..self.myName.." ("..self.configSetName..") getConfigValue()")
  self.logger.debug("--> section: "..section..", name: "..name)

  -- search through data
  for _, data in pairs(self.dataCurrent) do
    if data.section == section and data.name == name then
      self.logger.debug("---> typ: "..data.typ..", value: "..tostring(data.value))
      return(data.value)
    end
  end

  return(nil)
end

-- #############################################################################

function LibConfig:setConfigValue(section, name, value)
  self.logger.info("-> "..self.myName.." ("..self.configSetName..") setConfigValue()")
  self.logger.debug("--> section: "..section..", name: "..name..", value: "..tostring(value))

  -- search through data and change value
  for _, data in pairs(self.dataCurrent) do
    if data.section == section and data.name == name then
      data.value = value
    end
  end

  -- save changes
  self:writeConfig()

  self.logger.trace(DebugUtil.printTableRecursively(self.dataCurrent, 0, 0, 3))
end

-- #############################################################################

function LibConfig:readConfig()
  self.logger.info("-> "..self.myName.." ("..self.configSetName..") readConfig()")

  -- skip on dedicated servers
  if g_dedicatedServerInfo ~= nil then
    return
  end

  local confFile = self.confFileOld
  self.logger.debug("--> trying old confFile", "confFile", confFile)
  if not fileExists(confFile) then
    self.logger.debug("---> not found. trying current version", "confFileCurrent", self.confFileCurrent)
    confFile = self.confFileCurrent
    if not fileExists(confFile) then
      self.logger.debug("---> not found. that's bad. no config file at all")
      return
    end
  end

  local xml = loadXMLFile(self.configSetName, confFile, self.configSetName)
  local pos = {}
  -- sort our data by sections
  local sortedKeys = self:getKeysSortedByValue(self.dataCurrent, function(a, b) return a.section < b.section end)

  for _, key in ipairs(sortedKeys) do
    local data = self.dataCurrent[key]
    local group = data.section
    if pos[group] ==  nil then
      pos[group] = 0
    end
    local groupNameTag = string.format("%s.%s(%d)", self.configSetName, group, pos[group])
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
end

-- #############################################################################

function LibConfig:writeConfig()
  self.logger.info("-> "..self.myName.." ("..self.configSetName..") writeConfig()")

  -- skip on dedicated servers
  if g_dedicatedServerInfo ~= nil then
    return
  end

  -- if old version exists -> delete it
  self.logger.info("--> trying to delete old confFile", "confFileOld", self.confFileOld)
  if fileExists(self.confFileOld) then
    self.logger.info("---> found. deleting")
    -- TODO
  end

  -- new file
  self.logger.info("--> writing to current confFile", "confFileCurrent", self.confFileCurrent, "confDirectory", self.confDirectory, "settingsDirectory", self.settingsDirectory)

  -- create folders
  createFolder(self.settingsDirectory)
  createFolder(self.confDirectory);

  local xml = createXMLFile(self.confDirectory, self.confFileCurrent, self.confDirectory)
  local pos = {}
  -- sort our data by sections and name (inside a section)
  local sortedKeys = self:getKeysSortedByValue(self.dataCurrent, function(a, b) return a.section..a.name < b.section..b.name end)

  for _, key in ipairs(sortedKeys) do
    local data = self.dataCurrent[key]
    local group = data.section
    if pos[group] ==  nil then
      pos[group] = 0
    end
    local groupNameTag = string.format("%s.%s(%d)", self.configSetName, group, pos[group])
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

  self.logger.trace(DebugUtil.printTableRecursively(self.dataCurrent, 0, 0, 3))
end

-- #############################################################################

function LibConfig:getKeysSortedByValue(tbl, sortFunction)
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

function LibConfig:splitter(str, pat, limit)
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
