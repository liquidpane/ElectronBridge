--// ElectronBridge by @liquidpane
--// Server side

--!strict

--// SETTINGS

local SAFETY_ENABLED = true --// if error handling is enabled or not

--//

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local bridgeData: {[string]: {connections: {RBXScriptConnection}?, remoteEvent: RemoteEvent? | RemoteFunction?}} = {}

local function registerNewRemoteEvent(name: string): RemoteEvent
	local remoteEvent: RemoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = "ElectronBridge_" .. name
	remoteEvent.Parent = ReplicatedStorage

	bridgeData[name].remoteEvent = remoteEvent
	
	return remoteEvent
end

local function registerNewRemoteFunction(name: string): RemoteFunction
	local remoteEvent: RemoteFunction = Instance.new("RemoteFunction")
	remoteEvent.Name = "ElectronBridge_" .. name .. "FUNCTION"
	remoteEvent.Parent = ReplicatedStorage

	bridgeData[name].remoteEvent = remoteEvent

	return remoteEvent
end

local function getRemoteEvent(name: string): RemoteEvent
	local remoteEvent = bridgeData[name].remoteEvent :: RemoteEvent
	
	return remoteEvent
end

local function getRemoteFunction(name: string): RemoteFunction
	local remoteEvent = bridgeData[name].remoteEvent :: RemoteFunction

	return remoteEvent
end


local function validateNewBridgeName(name: string, isRemoteFunction: boolean): boolean
	if not bridgeData[name] then
		return true
	end

	if bridgeData[name].remoteEvent == nil then return false end

	local remote = bridgeData[name].remoteEvent :: RemoteEvent | RemoteFunction
	if isRemoteFunction and remote:IsA("RemoteFunction") then
		return true
	elseif not isRemoteFunction and remote:IsA("RemoteEvent") then
		return true
	end

	return false
end

local Bridge = {}

function Bridge.SendToIndividual(bridge: Bridge, individual: Player, ...)
	local remoteEvent = getRemoteEvent(bridge.bridgeName)

	remoteEvent:FireClient(individual, ...)
end

function Bridge.SendToGroup(bridge: Bridge, group: {Player}, ...)
	local remoteEvent = getRemoteEvent(bridge.bridgeName)

	for _, individual in group do
		remoteEvent:FireClient(individual, ...)
	end
end

function Bridge.Send(bridge: Bridge, ...)
	if SAFETY_ENABLED and bridge.isRemoteFunction then
		error("Cannot send a remote function to the client!")
	end

	local remoteEvent = getRemoteEvent(bridge.bridgeName)
	
	remoteEvent:FireAllClients(...)
end

function Bridge.Connect(bridge: Bridge, callback: (player: Player, ...any) -> ()): RBXScriptConnection?
	if bridge.isRemoteFunction then
		local remoteEvent = getRemoteFunction(bridge.bridgeName)
		remoteEvent.OnServerInvoke = callback
		return nil
	else
		local remoteEvent = getRemoteEvent(bridge.bridgeName)
		local connection = remoteEvent.OnServerEvent:Connect(callback)
		local bridgeConnections = bridgeData[bridge.bridgeName].connections
		if not bridgeConnections then
			bridgeData[bridge.bridgeName].connections = {connection}
		else
			table.insert(bridgeConnections, connection)
		end
		return connection
	end
end

function Bridge.Destroy(bridge: Bridge)
	local bridgeDataLocal = bridgeData[bridge.bridgeName]
	if bridgeDataLocal then
		local bridgeConnections = bridgeDataLocal.connections
		if bridgeConnections then
			for _, connection in bridgeConnections do
				connection:Disconnect()
			end
			table.clear(bridgeConnections)
		end

		local remoteEvent = bridgeDataLocal.remoteEvent
		if remoteEvent then
			remoteEvent:Destroy()
			bridgeData[bridge.bridgeName].remoteEvent = nil
		end

		bridgeData[bridge.bridgeName] = nil
	end

	table.clear(bridge)
	setmetatable(bridge, nil)
end

local ElectronBridge = {}
ElectronBridge.__index = Bridge

function ElectronBridge.New(bridgeName: string): Bridge
	if SAFETY_ENABLED and not validateNewBridgeName(bridgeName, false) then
		error("Bridge name is already registered!")
	end
	
	local bridge = setmetatable(
		{
			bridgeName = bridgeName,
			isRemoteFunction = false
		}, 
		ElectronBridge
	)
	
	bridgeData[bridgeName] = {}
	registerNewRemoteEvent(bridgeName)

	return bridge
end

function ElectronBridge.NewFunction(bridgeName: string): Bridge
	if SAFETY_ENABLED and not validateNewBridgeName(bridgeName, true) then
		error("Bridge name is already registered!")
	end

	local bridge = setmetatable(
		{
			bridgeName = bridgeName,
			isRemoteFunction = true
		}, 
		ElectronBridge
	)

	bridgeData[bridgeName] = {}
	registerNewRemoteFunction(bridgeName)

	return bridge
end

export type Bridge = typeof(setmetatable(
	{} :: {
		bridgeName: string,
		isRemoteFunction: boolean
	},
	ElectronBridge
	))


return ElectronBridge
