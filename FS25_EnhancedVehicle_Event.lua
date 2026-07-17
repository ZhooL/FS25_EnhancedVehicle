--
-- Mod: FS25_EnhancedVehicle_Event
--
-- Author: Majo76
-- Network snapshot/event hardening: EnhancedVehicle contributors
--

local myName = "FS25_EnhancedVehicle_Event"

FS25_EnhancedVehicle_Event = {}
local FS25_EnhancedVehicle_Event_mt = Class(FS25_EnhancedVehicle_Event, Event)

InitEventClass(FS25_EnhancedVehicle_Event, "FS25_EnhancedVehicle_Event")

function FS25_EnhancedVehicle_Event.emptyNew()
  return Event.new(FS25_EnhancedVehicle_Event_mt)
end

function FS25_EnhancedVehicle_Event.new(vehicle, snapshot)
  local self = FS25_EnhancedVehicle_Event.emptyNew()
  self.vehicle = vehicle
  self.snapshot = snapshot
  return self
end

-- This serializer is shared by state events and the vehicle join stream. Keep
-- additions here so late joiners and live updates always reconstruct the same
-- state.
function FS25_EnhancedVehicle_Event.writeSnapshot(streamId, snapshot)
  local values = snapshot.values
  streamWriteBool(streamId,    values[1])
  streamWriteBool(streamId,    values[2])
  streamWriteInt8(streamId,    values[3])
  streamWriteFloat32(streamId, values[4])
  streamWriteBool(streamId,    values[5])
  streamWriteBool(streamId,    values[6])
  streamWriteFloat32(streamId, values[7])
  streamWriteFloat32(streamId, values[8])
  streamWriteFloat32(streamId, values[9])
  streamWriteFloat32(streamId, values[10])
  streamWriteFloat32(streamId, values[11])
  streamWriteFloat32(streamId, values[12])
  streamWriteBool(streamId,    values[13])
  streamWriteFloat32(streamId, values[14])
  streamWriteFloat32(streamId, values[15])
  streamWriteInt8(streamId,    values[16])

  streamWriteBool(streamId, snapshot.tripReset == true)
  streamWriteBool(streamId, snapshot.trackValid == true)
  streamWriteInt8(streamId, snapshot.opMode)
  streamWriteFloat32(streamId, snapshot.trackOriginX)
  streamWriteFloat32(streamId, snapshot.trackOriginZ)
  streamWriteFloat32(streamId, snapshot.trackDirectionX)
  streamWriteFloat32(streamId, snapshot.trackDirectionZ)
  streamWriteFloat32(streamId, snapshot.trackOriginalDirectionX)
  streamWriteFloat32(streamId, snapshot.trackOriginalDirectionZ)
  streamWriteFloat32(streamId, snapshot.trackSnapX)
  streamWriteFloat32(streamId, snapshot.trackSnapZ)
  streamWriteFloat32(streamId, snapshot.trackWorkWidth)
  streamWriteFloat32(streamId, snapshot.trackOffset)
  streamWriteInt8(streamId, snapshot.trackDelta)
  streamWriteInt8(streamId, snapshot.headlandMode)
  streamWriteFloat32(streamId, snapshot.headlandDistance)
end

function FS25_EnhancedVehicle_Event.readSnapshot(streamId)
  local snapshot = { values = {} }
  local values = snapshot.values
  values[1] =  streamReadBool(streamId)
  values[2] =  streamReadBool(streamId)
  values[3] =  streamReadInt8(streamId)
  values[4] =  streamReadFloat32(streamId)
  values[5] =  streamReadBool(streamId)
  values[6] =  streamReadBool(streamId)
  values[7] =  streamReadFloat32(streamId)
  values[8] =  streamReadFloat32(streamId)
  values[9] =  streamReadFloat32(streamId)
  values[10] = streamReadFloat32(streamId)
  values[11] = streamReadFloat32(streamId)
  values[12] = streamReadFloat32(streamId)
  values[13] = streamReadBool(streamId)
  values[14] = streamReadFloat32(streamId)
  values[15] = streamReadFloat32(streamId)
  values[16] = streamReadInt8(streamId)

  snapshot.tripReset = streamReadBool(streamId)
  snapshot.trackValid = streamReadBool(streamId)
  snapshot.opMode = streamReadInt8(streamId)
  snapshot.trackOriginX = streamReadFloat32(streamId)
  snapshot.trackOriginZ = streamReadFloat32(streamId)
  snapshot.trackDirectionX = streamReadFloat32(streamId)
  snapshot.trackDirectionZ = streamReadFloat32(streamId)
  snapshot.trackOriginalDirectionX = streamReadFloat32(streamId)
  snapshot.trackOriginalDirectionZ = streamReadFloat32(streamId)
  snapshot.trackSnapX = streamReadFloat32(streamId)
  snapshot.trackSnapZ = streamReadFloat32(streamId)
  snapshot.trackWorkWidth = streamReadFloat32(streamId)
  snapshot.trackOffset = streamReadFloat32(streamId)
  snapshot.trackDelta = streamReadInt8(streamId)
  snapshot.headlandMode = streamReadInt8(streamId)
  snapshot.headlandDistance = streamReadFloat32(streamId)
  return snapshot
end

function FS25_EnhancedVehicle_Event:readStream(streamId, connection)
  if debug > 1 then print("-> " .. myName .. ": readStream() - " .. streamId) end
  self.vehicle = NetworkUtil.readNodeObject(streamId)
  self.snapshot = FS25_EnhancedVehicle_Event.readSnapshot(streamId)
  self:run(connection)
end

function FS25_EnhancedVehicle_Event:writeStream(streamId, connection)
  if debug > 1 then print("-> " .. myName .. ": writeStream() - " .. streamId) end
  NetworkUtil.writeNodeObject(streamId, self.vehicle)
  FS25_EnhancedVehicle_Event.writeSnapshot(streamId, self.snapshot)
end

function FS25_EnhancedVehicle_Event:run(connection)
  if self.vehicle == nil or self.vehicle.vData == nil then
    return
  end

  if connection:getIsServer() then
    -- Canonical state received from the server.
    local snapshot = FS25_EnhancedVehicle.sanitizeNetworkSnapshot(self.vehicle, self.snapshot, false)
    FS25_EnhancedVehicle.applyNetworkSnapshot(self.vehicle, snapshot, true)
    return
  end

  -- Requests from clients are accepted only for the connection that currently
  -- owns the vehicle. This also prevents forged node-object events.
  if self.vehicle.getOwnerConnection == nil or self.vehicle:getOwnerConnection() ~= connection then
    local now = g_time or 0
    local lastWarning = FS25_EnhancedVehicle.lastRejectedEventWarningTime
    if lastWarning == nil or now - lastWarning >= 5000 then
      print("Warning: " .. myName .. " rejected state from a non-owner connection")
      FS25_EnhancedVehicle.lastRejectedEventWarningTime = now
    end
    return
  end

  local snapshot = FS25_EnhancedVehicle.sanitizeNetworkSnapshot(self.vehicle, self.snapshot, true)
  FS25_EnhancedVehicle.applyNetworkSnapshot(self.vehicle, snapshot, false)
  FS25_EnhancedVehicle:updatevData(self.vehicle)

  local canonical = FS25_EnhancedVehicle.buildNetworkSnapshot(self.vehicle, false)
  -- Include the sender so clamped/rejected fields and trip resets converge to
  -- the same canonical server snapshot immediately.
  g_server:broadcastEvent(FS25_EnhancedVehicle_Event.new(self.vehicle, canonical), nil, nil, self.vehicle)
end

function FS25_EnhancedVehicle_Event.sendEvent(vehicle, request)
  if vehicle == nil or vehicle.vData == nil then
    return
  end

  local tripReset = type(request) == "table" and request.tripReset == true
  local snapshot = FS25_EnhancedVehicle.buildNetworkSnapshot(vehicle, tripReset)

  if g_server ~= nil then
    snapshot = FS25_EnhancedVehicle.sanitizeNetworkSnapshot(vehicle, snapshot, true)
    FS25_EnhancedVehicle.applyNetworkSnapshot(vehicle, snapshot, false)
    FS25_EnhancedVehicle:updatevData(vehicle)
    snapshot = FS25_EnhancedVehicle.buildNetworkSnapshot(vehicle, false)
    g_server:broadcastEvent(FS25_EnhancedVehicle_Event.new(vehicle, snapshot), nil, nil, vehicle)
  elseif g_client ~= nil then
    g_client:getServerConnection():sendEvent(FS25_EnhancedVehicle_Event.new(vehicle, snapshot))
  end
end
