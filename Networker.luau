--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(script.Parent.Signal)

local Networker = {}
Networker.__index = Networker

-- Singleton
local _instance: Networker? = nil
local IS_CLIENT = RunService:IsClient()
local FOLDER_NAME = "NetworkerEvents"

-- Types
export type SignalType = "RemoteEvent" | "UnreliableRemoteEvent" | "BindableEvent" | "RemoteFunction" | "BindableFunction"
export type SignalObject = RemoteEvent | UnreliableRemoteEvent | BindableEvent | RemoteFunction | BindableFunction

export type Networker = {
	eventsFolder: Folder?,
	registeredSignals: {[string]: SignalObject},
	signalWrappers: {[string]: Signal.Signal},
	remoteConnections: {[string]: RBXScriptConnection},

	_init: (self: Networker) -> (),
	_initRemote: (self: Networker, signalName: string, remote: SignalObject) -> (),
	_registerSignal: (self: Networker, signalName: string, obj: SignalObject) -> (),
	_createSignal: (self: Networker, signalName: string, isFunctionCall: boolean, isBindable: boolean, isUnreliable: boolean) -> (SignalObject?),
	_fireRemote: (self: Networker, remote: SignalObject, ...any) -> (),
	_getOrCreate: (self: Networker, signalName: string, isFunctionCall: boolean, isBindable: boolean, isUnreliable: boolean) -> (SignalObject?),

	OnEvent: (self: Networker, signalName: string) -> Signal.Signal,
	OnEventUnreliable: (self: Networker, signalName: string) -> Signal.Signal,
	OnBindableEvent: (self: Networker, signalName: string) -> Signal.Signal,
	OnInvoke: (self: Networker, signalName: string) -> Signal.Signal,
	OnBindableInvoke: (self: Networker, signalName: string) -> Signal.Signal,

	FireClient: (self: Networker, signalName: string, player: Player, ...any) -> (),
	FireClientUnreliable: (self: Networker, signalName: string, player: Player, ...any) -> (),
	FireAllClients: (self: Networker, signalName: string, ...any) -> (),
	FireAllClientsUnreliable: (self: Networker, signalName: string, ...any) -> (),

	InvokeClient: (self: Networker, signalName: string, player: Player, ...any) -> any,

	FireServer: (self: Networker, signalName: string, ...any) -> (),
	FireServerUnreliable: (self: Networker, signalName: string, ...any) -> (),
	InvokeServer: (self: Networker, signalName: string, ...any) -> any,

	Fire: (self: Networker, signalName: string, ...any) -> (),
	Invoke: (self: Networker, signalName: string, ...any) -> any,
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
	self.signalWrappers = {}
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
		self.eventsFolder = Instance.new("Folder")
		self.eventsFolder.Name = FOLDER_NAME
		self.eventsFolder.Parent = ReplicatedStorage
	end
end

function Networker:_initRemote(signalName: string, remote: SignalObject)
	if not self.signalWrappers[signalName] then
		self.signalWrappers[signalName] = Signal.new()
	end

	local wrapper = self.signalWrappers[signalName]
	if self.remoteConnections[signalName] then
		self.remoteConnections[signalName]:Disconnect()
		self.remoteConnections[signalName] = nil
	end

	if remote:IsA("RemoteEvent") then
		if IS_CLIENT then
			self.remoteConnections[signalName] = remote.OnClientEvent:Connect(function(...)
				wrapper:Fire(...)
			end)
		else
			self.remoteConnections[signalName] = remote.OnServerEvent:Connect(function(...)
				wrapper:Fire(...)
			end)
		end

	elseif remote:IsA("UnreliableRemoteEvent") then
		if IS_CLIENT then
			self.remoteConnections[signalName] = remote.OnClientEvent:Connect(function(...)
				wrapper:Fire(...)
			end)
		else
			self.remoteConnections[signalName] = remote.OnServerEvent:Connect(function(...)
				wrapper:Fire(...)
			end)
		end

	elseif remote:IsA("BindableEvent") then
		self.remoteConnections[signalName] = remote.Event:Connect(function(...)
			wrapper:Fire(...)
		end)

	elseif remote:IsA("RemoteFunction") then
		if IS_CLIENT then
			remote.OnClientInvoke = function(...)
				local listeners = self.signalWrappers[signalName]._listeners
				local listener = listeners[#listeners]
				if listener then
					return listener.callback(...)
				end
			end
			
		else
			remote.OnServerInvoke = function(...)
				local listeners = self.signalWrappers[signalName]._listeners
				local listener = listeners[#listeners]
				if listener then
					return listener.callback(...)
				end
			end
		end

	elseif remote:IsA("BindableFunction") then
		remote.OnInvoke = function(...)
			local listeners = self.signalWrappers[signalName]._listeners
			local listener = listeners[#listeners]
			if listener then
				return listener.callback(...)
			end
		end
	end
end

function Networker:_registerSignal(signalName: string, obj: SignalObject)
	if self.registeredSignals[signalName] then
		self.registeredSignals[signalName]:Destroy()
		self.registeredSignals[signalName] = nil
		self.remoteConnections[signalName] = nil
		self.signalWrappers[signalName] = nil
	end

	self.registeredSignals[signalName] = obj
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
	if not self.signalWrappers[signalName] then
		self.signalWrappers[signalName] = Signal.new()
	end
	return remote
end

-- Public API --

function Networker:OnEvent(signalName: string): Signal.Signal
	self:_getOrCreate(signalName, false, false, false)
	return self.signalWrappers[signalName]
end

function Networker:OnEventUnreliable(signalName: string): Signal.Signal
	self:_getOrCreate(signalName, false, false, true)
	return self.signalWrappers[signalName]
end

function Networker:OnBindableEvent(signalName: string): Signal.Signal
	self:_getOrCreate(signalName, false, true, false)
	return self.signalWrappers[signalName]
end

function Networker:OnInvoke(signalName: string): Signal.Signal
	self:_getOrCreate(signalName, true, false, false)
	return self.signalWrappers[signalName]
end

function Networker:OnBindableInvoke(signalName: string): Signal.Signal
	self:_getOrCreate(signalName, true, true, false)
	return self.signalWrappers[signalName]
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
	return nil
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
	return nil
end

return Networker.new()
