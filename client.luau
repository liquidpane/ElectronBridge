--// ElectronBridge by @liquidpane
--// Client side

--!strict

--// SETTINGS

local SAFETY_ENABLED = true --// if error handling is enabled or not
local REMOTE_WFC_TIMEOUT = 5 --// how long will it wait for the remote event before it errors

--//

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local bridgeData: {[string]: {connections: {RBXScriptConnection}?, remoteEvent: RemoteEvent? | RemoteFunction?}} = {}

local ElectronBridge = {}

local function getRemoteEvent(name: string): RemoteEvent
	local remoteEvent = bridgeData[name].remoteEvent

	if not remoteEvent then
		remoteEvent = ReplicatedStorage:WaitForChild("ElectronBridge_" .. name, REMOTE_WFC_TIMEOUT)
		
		if not remoteEvent then
			error("Missing remote event: " .. name)
		elseif not remoteEvent:IsA("RemoteEvent") then
			error(`Found an instance under the name: ElectronBridge_{name} that isnt a remote event!`)
		end
	end
	
	bridgeData[name].remoteEvent = remoteEvent :: RemoteEvent

	return remoteEvent :: RemoteEvent
end

local function getRemoteFunction(name: string): RemoteFunction
	local remoteEvent = bridgeData[name].remoteEvent

	if not remoteEvent then
		remoteEvent = ReplicatedStorage:WaitForChild("ElectronBridge_" .. name .. "FUNCTION", REMOTE_WFC_TIMEOUT)

		if not remoteEvent then
			error("Missing remote event: " .. name)
		elseif not remoteEvent:IsA("RemoteFunction") then
			error(`Found an instance under the name: ElectronBridge_{name}FUNCTION that isnt a remote function!`)
		end
	end

	bridgeData[name].remoteEvent = remoteEvent :: RemoteFunction

	return remoteEvent :: RemoteFunction
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

function Bridge.Send(bridge: Bridge, ...): ()
	if not bridgeData[bridge.bridgeName] then
		bridgeData[bridge.bridgeName] = {}
	end
	
	if not bridge.isFunction then
		local remoteEvent = getRemoteEvent(bridge.bridgeName)
		remoteEvent:FireServer(...)
	else
		local remoteEvent = getRemoteFunction(bridge.bridgeName)
		return remoteEvent:InvokeServer(...)
	end
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
	if SAFETY_ENABLED and not validateNewBridgeName(bridgeName, false) then
		error("Bridge name is already registered!")
	end
	
	local bridge = setmetatable(
		{
			bridgeName = bridgeName,
			isFunction = false
		}, 
		ElectronBridge
	)
	
	return bridge
end

function ElectronBridge.NewFunction(bridgeName: string): Bridge
	if SAFETY_ENABLED and not validateNewBridgeName(bridgeName, true) then
		error("Bridge name is already registered!")
	end

	local bridge = setmetatable(
		{
			bridgeName = bridgeName,
			isFunction = true
		}, 
		ElectronBridge
	)

	return bridge
end

export type Bridge = typeof(setmetatable(
	{} :: {
		bridgeName: string,
		isFunction: boolean
	},
	ElectronBridge
))

return ElectronBridge
