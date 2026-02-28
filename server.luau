--// ElectronBridge by @liquidpane
--// Server side

--!strict

--// SETTINGS

local SAFETY_ENABLED = true --// if error handling is enabled or not

--//

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local bridgeData: {[string]: {connections: {RBXScriptConnection}?, remoteEvent: RemoteEvent?}} = {}

local function registerNewRemoteEvent(name: string): RemoteEvent
	local remoteEvent: RemoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = "ElectronBridge_" .. name
	remoteEvent.Parent = ReplicatedStorage

	bridgeData[name].remoteEvent = remoteEvent
	
	return remoteEvent
end

local function getRemoteEvent(name: string): RemoteEvent
	local remoteEvent = bridgeData[name].remoteEvent
	
	if not remoteEvent then
		return registerNewRemoteEvent(name)
	end
	
	return remoteEvent
end

local function validateNewBridgeName(name: string): boolean
	return not bridgeData[name]
end

local Bridge = {}

function Bridge.SendToIndividual(bridge: Bridge, individual: Player, ...)
	if not bridgeData[bridge.bridgeName] then
		bridgeData[bridge.bridgeName] = {}
	end
	
	local remoteEvent = getRemoteEvent(bridge.bridgeName)

	remoteEvent:FireClient(individual, ...)
end

function Bridge.SendToGroup(bridge: Bridge, group: {Player}, ...)
	if not bridgeData[bridge.bridgeName] then
		bridgeData[bridge.bridgeName] = {}
	end
	
	local remoteEvent = getRemoteEvent(bridge.bridgeName)

	for _, individual in group do
		remoteEvent:FireClient(individual, ...)
	end
end

function Bridge.Send(bridge: Bridge, ...)
	if not bridgeData[bridge.bridgeName] then
		bridgeData[bridge.bridgeName] = {}
	end
	
	local remoteEvent = getRemoteEvent(bridge.bridgeName)
	
	remoteEvent:FireAllClients(...)
end

function Bridge.Connect(bridge: Bridge, callback: (player: Player, ...any) -> ()): RBXScriptConnection
	if not bridgeData[bridge.bridgeName] then
		bridgeData[bridge.bridgeName] = {}
	end
	
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
	if SAFETY_ENABLED and not validateNewBridgeName(bridgeName) then
		error("Bridge name is already registered!")
	end
	
	local bridge = setmetatable(
		{
			bridgeName = bridgeName
		}, 
		ElectronBridge
	)

	return bridge
end

export type Bridge = typeof(setmetatable(
	{} :: {
		bridgeName: string
	},
	ElectronBridge
))

return ElectronBridge
