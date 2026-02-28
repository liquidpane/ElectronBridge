--// ElectronBridge by @liquidpane
--// Client side

--!strict

--// SETTINGS

local SAFETY_ENABLED = true --// if error handling is enabled or not
local REMOTE_WFC_TIMEOUT = 5 --// how long will it wait for the remote event before it errors

--//

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local bridgeData: {[string]: {connections: {RBXScriptConnection}?, remoteEvent: RemoteEvent?}} = {}

local ElectronBridge = {}

local function getRemoteEvent(name: string): RemoteEvent
	local remoteEvent = bridgeData[name].remoteEvent

	if not remoteEvent then
		remoteEvent = ReplicatedStorage:WaitForChild("ElectronBridge_" .. name, REMOTE_WFC_TIMEOUT)
		
		if not remoteEvent then
			error("Missing remote event: " .. name)
		elseif not remoteEvent:IsA("RemoteEvent") then
			error(`Found and instance under the name: ElectronBridge_{name} that isnt a remote event!`)
		end
	end
	
	bridgeData[name].remoteEvent = remoteEvent :: RemoteEvent

	return remoteEvent :: RemoteEvent
end

local function validateNewBridgeName(name: string): boolean
	return not bridgeData[name]
end

local Bridge = {}

function Bridge.Send(bridge: Bridge, ...)
	if not bridgeData[bridge.bridgeName] then
		bridgeData[bridge.bridgeName] = {}
	end
	
	local remoteEvent = getRemoteEvent(bridge.bridgeName)
	remoteEvent:FireServer(...)
end

function Bridge.Connect(bridge: Bridge, callback: (...any) -> ()): RBXScriptConnection
	if not bridgeData[bridge.bridgeName] then
		bridgeData[bridge.bridgeName] = {}
	end
	
	local remoteEvent = getRemoteEvent(bridge.bridgeName)
	
	local connection = remoteEvent.OnClientEvent:Connect(callback)
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
			bridgeData[bridge.bridgeName].remoteEvent = nil
		end
		
		bridgeData[bridge.bridgeName] = nil
	end
	
	table.clear(bridge)
	setmetatable(bridge, nil)
end

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
