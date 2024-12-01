--
-- Lib: libUtils (for Farming Simulator 22++)
--
-- Author: Majo76
-- email: ls (at) majo76 (dot) de
-- @Date: 22.11.2021
-- @Version: 1.0.0.0

-- #############################################################################

LibUtils = {
  myName = "libUtils",
  logger = LibUtils.Logger
}
LibUtils.__index = LibUtils

-- #############################################################################

function LibUtils:new(logger)
  logger.info(LibUtils.myName .. ": new()")
  local instance = setmetatable({}, self)
  instance.logger = logger
  return instance
end

-- #############################################################################
-- ### Console logger
-- ### Examples:
-- ### Log = LibUtils.Logger:new(LibUtils.Logger.LEVEL.INFO)
-- ### Log.info("Hello World") -> [INFO] Hello World
-- ### Log.debug("Hello World", "key", "value") -> [DEBUG] Hello World, key=value

LibUtils.Logger = {
  __index = LibUtils.Logger,

  LEVEL = {
    OFF   = {intValue = 0, name = "OFF"},
    INFO  = {intValue = 1, name = "INFO"},
    DEBUG = {intValue = 2, name = "DEBUG"},
    TRACE = {intValue = 3, name = "TRACE"}
  },

  level = LibUtils.Logger.LEVEL.OFF,

  new = function(self, level)
    local instance = setmetatable({}, self)
    instance.level = level
    return instance
  end,

  info = function(self, message, ...)
    self:log(self.LEVEL.INFO, message, ...)
  end,

  debug = function(self, message, ...)
    self:log(self.LEVEL.DEBUG, message, ...)
  end,

  trace = function(self, message, ...)
    self:log(self.LEVEL.TRACE, message, ...)
  end,

  log = function(self, level, message, ...)
    local args = {...}
    local attributes = ""
    for i = 1, #args, 2 do
      attributes = attributes .. ", " .. tostring(args[i]) .. "=" .. tostring(args[i + 1])
    end

    if self.level >= level.intValue then
      print("[" .. level.name .. "] " .. tostring(message) .. attributes)
    end
  end
}

-- #############################################################################

function LibUtils:args_to_txt(...)
  local args = { ... }
  local txt = ""
  local i, v
  for i, v in ipairs(args) do
    if i > 1 then
      txt = txt .. ", "
    end
    txt = txt .. i .. ": " .. tostring(v)
  end

  return(txt)
end
