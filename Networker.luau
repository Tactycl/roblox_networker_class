--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = {}
Networker.__index = Networker

-- Singleton
local _instance: Networker? = nil
local IS_CLIENT = RunService:IsClient()
local FOLDER_NAME = "NetworkerEvents"

-- Types
export type SignalType = "RemoteEvent" | "UnreliableRemoteEvent" | "BindableEvent" | "RemoteFunction" | "BindableFunction"
export type SignalObject = RemoteEvent | UnreliableRemoteEvent | BindableEvent | RemoteFunction | BindableFunction
export type Callback = (...any) -> any
export type WaitingSignal = {
	signalName: string,
	callback: Callback,
	assignedRemote: SignalObject?,
}

export type Networker = {
	eventsFolder: Folder?,
	registeredSignals: {[string]: SignalObject},
	waitingSignals: {WaitingSignal},
	remoteConnections: {[string]: RBXScriptConnection},
	
	_init: (self: Networker) -> (),
}

local function resolveSignalType(isFunctionCall: boolean, isBindable: boolean, isUnreliable: boolean): SignalType
	if isFunctionCall then
		return (isBindable and "BindableFunction") or "RemoteFunction"
	else
		if isBindable then
			return "BindableEvent"
		elseif isUnreliable then
			return "UnreliableRemoteEvent"
		else
			return "RemoteEvent"
		end
	end
end

function Networker.new(): Networker
	if _instance then
		return _instance
	end

	local self = (setmetatable({}, Networker):: unknown):: Networker
	self.eventsFolder = nil
	self.registeredSignals = {}
	self.waitingSignals = {}
	self.remoteConnections = {}
	self:_init()

	_instance = self
	return self
end

function Networker:_init()
	if IS_CLIENT then
		self.eventsFolder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
		self.eventsFolder.ChildAdded:Connect(function(obj)
			if self.registeredSignals[obj.Name] == obj then return end
			if obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent") or obj:IsA("BindableEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableFunction") then
				self:_registerSignal(obj.Name, obj)
			end
		end)

		for _, obj in self.eventsFolder:GetChildren() do
			if obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent") or obj:IsA("BindableEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableFunction") then
				self:_registerSignal(obj.Name, obj)
			end
		end

	else
		self.eventsFolder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		self.eventsFolder = Instance.new("Folder")
		self.eventsFolder.Name = FOLDER_NAME
		self.eventsFolder.Parent = ReplicatedStorage
	end
end

function Networker:_getWaitingSignalsByName(signalName: string): {WaitingSignal}
	local out = {}
	for _, waiting in self.waitingSignals do
		if waiting.signalName == signalName then
			table.insert(out, waiting)
		end
	end
	return out
end

function Networker:_initRemote(signalName: string, remote: SignalObject)
	if self.remoteConnections[signalName] then
		self.remoteConnections[signalName]:Disconnect()
		self.remoteConnections[signalName] = nil
	end

	local function callSignals(...)
		for _, waiting in self:_getWaitingSignalsByName(signalName) do
			waiting.callback(...)
		end
	end

	local function callSignal(...)
		local waitingSignals = self:_getWaitingSignalsByName(signalName)
		local waitingSignal = waitingSignals[#waitingSignals]
		if not waitingSignal then
			return nil
		end
		
		return waitingSignal.callback(...)
	end

	local con: RBXScriptConnection? = nil
	if remote:IsA("RemoteEvent") then
		if IS_CLIENT then
			con = remote.OnClientEvent:Connect(callSignals)

		else
			con = remote.OnServerEvent:Connect(callSignals)
		end
		
	elseif remote:IsA("UnreliableRemoteEvent") then
		if IS_CLIENT then
			con = remote.OnClientEvent:Connect(callSignals)

		else
			con = remote.OnServerEvent:Connect(callSignals)
		end

	elseif remote:IsA("BindableEvent") then
		con = remote.Event:Connect(callSignals)

	elseif remote:IsA("RemoteFunction") then
		if IS_CLIENT then
			remote.OnClientInvoke = callSignal
		else
			remote.OnServerInvoke = callSignal
		end

	elseif remote:IsA("BindableFunction") then
		remote.OnInvoke = callSignal
	end

	if con then
		self.remoteConnections[signalName] = con
	end
end

function Networker:_registerSignal(signalName: string, obj: SignalObject)
	if self.registeredSignals[signalName] then
		self.registeredSignals[signalName]:Destroy()
		self.registeredSignals[signalName] = nil
		self.remoteConnections[signalName] = nil
	end

	self.registeredSignals[signalName] = obj
	for _, waiting in self:_getWaitingSignalsByName(signalName) do
		waiting.assignedRemote = obj
	end

	self:_initRemote(signalName, obj)
end

function Networker:_createSignal(signalName: string, isFunctionCall: boolean, isBindable: boolean, isUnreliable: boolean): SignalObject?
	local signalType = resolveSignalType(isFunctionCall, isBindable, isUnreliable)
	if IS_CLIENT and (signalType ~= "BindableEvent" and signalType ~= "BindableFunction") then
		return nil
	end

	if not self.eventsFolder then
		return nil
	end

	local newSignal = Instance.new(signalType)
	newSignal.Name = signalName
	newSignal.Parent = self.eventsFolder

	self:_registerSignal(signalName, newSignal)
	return newSignal
end

function Networker:_fireRemote(remote: SignalObject, ...: any)
	if remote:IsA("RemoteEvent") then
		if IS_CLIENT then
			remote:FireServer(...)

		else
			error("Use FireClient or FireAllClients for RemoteEvents")
		end
		
	elseif remote:IsA("UnreliableRemoteEvent") then
		if IS_CLIENT then
			remote:FireServer(...)

		else
			error("Use FireClient or FireAllClients for RemoteEvents")
		end

	elseif remote:IsA("BindableEvent") then
		remote:Fire(...)

	elseif remote:IsA("RemoteFunction") then
		if IS_CLIENT then
			return remote:InvokeServer(...)

		else
			error("Use InvokeClient for RemoteFunctions")
		end

	elseif remote:IsA("BindableFunction") then
		return remote:Invoke(...)
	end
end

function Networker:_getOrCreate(signalName: string, isFunctionCall: boolean, isBindable: boolean, isUnreliable: boolean): SignalObject?
	local remote = self.registeredSignals[signalName]
	if not remote then
		remote = self:_createSignal(signalName, isFunctionCall, isBindable, isUnreliable)
	end
	return remote
end

-- Public API --

function Networker:OnEvent(signalName: string, callback: Callback)
	local remote = self:_getOrCreate(signalName, false, false, false)
	local entry: WaitingSignal = {
		signalName = signalName,
		callback = callback,
		assignedRemote = remote,
	}

	table.insert(self.waitingSignals, entry)
end

function Networker:OnEventUnreliable(signalName: string, callback: Callback)
	local remote = self:_getOrCreate(signalName, false, false, true)
	local entry: WaitingSignal = {
		signalName = signalName,
		callback = callback,
		assignedRemote = remote,
	}

	table.insert(self.waitingSignals, entry)
end

function Networker:OnBindableEvent(signalName: string, callback: Callback)
	local remote = self:_getOrCreate(signalName, false, true, false)
	local entry: WaitingSignal = {
		signalName = signalName,
		callback = callback,
		assignedRemote = remote,
	}

	table.insert(self.waitingSignals, entry)
end

function Networker:OnInvoke(signalName: string, callback: Callback)
	local remote = self:_getOrCreate(signalName, true, false, false)
	local entry: WaitingSignal = {
		signalName = signalName,
		callback = callback,
		assignedRemote = remote,
	}

	table.insert(self.waitingSignals, entry)
end

function Networker:OnBindableInvoke(signalName: string, callback: Callback)
	local remote = self:_getOrCreate(signalName, true, true, false)
	local entry: WaitingSignal = {
		signalName = signalName,
		callback = callback,
		assignedRemote = remote,
	}

	table.insert(self.waitingSignals, entry)
end

function Networker:FireClient(signalName: string, player: Player, ...: any)
	if IS_CLIENT then return end
	local remote = self:_getOrCreate(signalName, false, false, false)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, ...)
	end
end

function Networker:FireClientUnreliable(signalName: string, player: Player, ...: any)
	if IS_CLIENT then return end
	local remote = self:_getOrCreate(signalName, false, false, true)
	if remote and remote:IsA("UnreliableRemoteEvent") then
		remote:FireClient(player, ...)
	end
end

function Networker:FireAllClients(signalName: string, ...: any)
	if IS_CLIENT then return end
	local remote = self:_getOrCreate(signalName, false, false, false)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients(...)
	end
end

function Networker:FireAllClientsUnreliable(signalName: string, ...: any)
	if IS_CLIENT then return end
	local remote = self:_getOrCreate(signalName, false, false, true)
	if remote and remote:IsA("UnreliableRemoteEvent") then
		remote:FireAllClients(...)
	end
end

function Networker:InvokeClient(signalName: string, player: Player, ...: any)
	if IS_CLIENT then return end
	local remote = self:_getOrCreate(signalName, true, false, false)
	if remote and remote:IsA("RemoteFunction") then
		return remote:InvokeClient(player, ...)
	end
end

function Networker:FireServer(signalName: string, ...: any)
	if not IS_CLIENT then return end
	local remote = self:_getOrCreate(signalName, false, false, false)
	if remote then
		self:_fireRemote(remote, ...)
	end
end

function Networker:FireServerUnreliable(signalName: string, ...: any)
	if not IS_CLIENT then return end
	local remote = self:_getOrCreate(signalName, false, false, true)
	if remote then
		self:_fireRemote(remote, ...)
	end
end

function Networker:InvokeServer(signalName: string, ...: any): any
	if not IS_CLIENT then return end
	local remote = self:_getOrCreate(signalName, true, false, false)
	if remote then
		return self:_fireRemote(remote, ...)
	end
	return
end

function Networker:Fire(signalName: string, ...: any)
	local remote = self:_getOrCreate(signalName, false, true, false)
	if remote then
		self:_fireRemote(remote, ...)
	end
end

function Networker:Invoke(signalName: string, ...: any): any
	local remote = self:_getOrCreate(signalName, true, true, false)
	if remote then
		return self:_fireRemote(remote, ...)
	end
	return
end

return Networker.new()
