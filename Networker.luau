--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(script.Parent.Signal)

local Networker = {}
Networker.__index = Networker

local _instance: Networker? = nil
local IS_CLIENT = RunService:IsClient()
local FOLDER_NAME = "NetworkerEvents"
local EVENT_INSTANCES = {
	"RemoteEvent",
	"UnreliableRemoteEvent",
	"BindableEvent",
	"RemoteFunction",
	"BindableFunction",
}

type SignalObject = RemoteEvent | UnreliableRemoteEvent | BindableEvent | RemoteFunction | BindableFunction
type EventIdentifier = string
type Callback = (...any) -> (...any)

export type Networker = {
	Folder: Folder?,

	signalWrappers: {[EventIdentifier]: Signal.Signal},
	functionWrappers: {[EventIdentifier]: Callback},
	instances: {[string]: SignalObject},

	autoCleanup: boolean,
	debug: boolean,
	strict: boolean,
	cleanupCoroutine: thread?,
	cleanupInterval: number,

	_resolveExpectedObject: (self: Networker, Adornee: Instance, name: string) -> (Instance?),
	_throwUnexpectedEvent: (self: Networker) -> (),
	_init: (self: Networker) -> (),
	_fireWrapper: (signalName: EventIdentifier, ...any) -> (),
	_fireReceiver: (signalName: EventIdentifier, ...any) -> (),
	_getOrCreateWrapper: (self: Networker, signalName: EventIdentifier) -> (Signal.Signal),
	_setReceiving: (self: Networker, signalName: EventIdentifier, func: Callback) -> (),

	ClearUnusedSignals: (self: Networker) -> (),
	EnableAutoCleanup: (self: Networker, interval: number?) -> (),
	DisableAutoCleanup: (self: Networker) -> (),

	OnEvent: (self: Networker, signalName: EventIdentifier) -> (Signal.Signal),
	OnEventUnreliable: (self: Networker, signalName: EventIdentifier) -> (Signal.Signal),
	OnBindableEvent: (self: Networker, signalName: EventIdentifier) -> (Signal.Signal),
	OnInvoke: (self: Networker, signalName: EventIdentifier, func: Callback) -> (),
	OnBindableInvoke: (self: Networker, signalName: EventIdentifier, func: Callback) -> (),

	FireClient: (self: Networker, signalName: EventIdentifier, player: Player, ...any) -> (),
	FireAllClients: (self: Networker, signalName: EventIdentifier, ...any) -> (),
	FireAllClientsExcept: (self: Networker, signalName: EventIdentifier, exceptPlayer: Player, ...any) -> (),

	FireClientUnreliable: (self: Networker, signalName: EventIdentifier, player: Player, ...any) -> (),
	FireAllClientsUnreliable: (self: Networker, signalName: EventIdentifier, ...any) -> (),
	FireAllClientsExceptUnreliable: (self: Networker, signalName: EventIdentifier, exceptPlayer: Player, ...any) -> (),

	FireServer: (self: Networker, signalName: EventIdentifier, ...any) -> (),
	FireServerUnreliable: (self: Networker, signalName: EventIdentifier, ...any) -> (),

	Fire: (self: Networker, signalName: EventIdentifier, ...any) -> (),

	InvokeClient: (self: Networker, signalName: EventIdentifier, player: Player, ...any) -> (...any),
	InvokeServer: (self: Networker, signalName: EventIdentifier, ...any) -> (...any),
	Invoke: (self: Networker, signalName: EventIdentifier, ...any) -> (...any),
}

function Networker.new(): Networker
	if _instance then
		return _instance
	end

	local self = (setmetatable({}, Networker):: unknown):: Networker
	self.Folder = nil
	self.signalWrappers = {}
	self.functionWrappers = {}
	self.instances = {}
	self.autoCleanup = false
	self.debug = false
	self.strict = true
	self.cleanupCoroutine = nil
	self.cleanupInterval = 60
	self:_init()

	_instance = self
	return self
end

function Networker:_resolveExpectedObject(Adornee: Instance, name: string)
	local object = Adornee:WaitForChild(name, 5)
	if not object then
		local networkSide = if IS_CLIENT then "client" else "server"
		local msg = string.format("Failed to require 'Networker' on the %s. Check if you require 'Networker' on both client and server on startup.", networkSide)

		if self.strict then
			error(msg, 2)
		else
			warn(msg)
		end
	end

	return object
end

function Networker:_throwUnexpectedEvent()
	error("Event was fired but no EventIdentifier was attached.", 2)
end

function Networker:_init()
	if IS_CLIENT then
		self.Folder = self:_resolveExpectedObject(ReplicatedStorage, FOLDER_NAME)
		if not self.Folder then
			return
		end

	else
		self.Folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) or Instance.new("Folder")
		self.Folder.Name = FOLDER_NAME

		for _, instanceName in EVENT_INSTANCES do
			local instance = self.Folder:FindFirstChildOfClass(instanceName) or Instance.new(instanceName)
			instance.Name = instanceName
			instance.Parent = self.Folder
		end

		self.Folder.Parent = ReplicatedStorage
	end

	for _, instanceName in EVENT_INSTANCES do
		local instance = self:_resolveExpectedObject(self.Folder, instanceName)
		if not instance then
			continue
		end

		if instance:IsA("RemoteEvent") or instance:IsA("UnreliableRemoteEvent") then
			if IS_CLIENT then
				instance.OnClientEvent:Connect(function(signalName: EventIdentifier, ...)
					self:_fireWrapper(signalName, ...)
				end)

			else
				instance.OnServerEvent:Connect(function(player: Player, signalName: EventIdentifier, ...)
					self:_fireWrapper(signalName, unpack({player, ...}))
				end)
			end

		elseif instance:IsA("BindableEvent") then
			instance.Event:Connect(function(signalName: EventIdentifier, ...)
				self:_fireWrapper(signalName, ...)
			end)

		elseif instance:IsA("RemoteFunction") then
			if IS_CLIENT then
				instance.OnClientInvoke = function(signalName: EventIdentifier, ...)
					return self:_fireReceiver(signalName, ...)
				end

			else
				instance.OnServerInvoke = function(player: Player, signalName: EventIdentifier, ...)
					return self:_fireReceiver(signalName, unpack({player, ...}))
				end
			end

		elseif instance:IsA("BindableFunction") then
			instance.OnInvoke = function(signalName: EventIdentifier, ...)
				return self:_fireReceiver(signalName, ...)
			end
		end

		self.instances[instanceName] = instance
	end
end

function Networker:_fireWrapper(signalName: EventIdentifier, ...)
	if typeof(signalName) ~= "string" then
		self:_throwUnexpectedEvent()
	end

	local wrapper = self.signalWrappers[signalName]
	if not wrapper then
		return
	end

	if self.debug then
		print("[Networker] Fired Signal Wrapper for signal:", signalName, "With Args:", ...)
	end
	wrapper:Fire(...)
end

function Networker:_fireReceiver(signalName: EventIdentifier, ...)
	if typeof(signalName) ~= "string" then
		self:_throwUnexpectedEvent()
	end

	local receiver = self.functionWrappers[signalName]
	if not receiver then
		return
	end

	if self.debug then
		print("[Networker] Fired Function Receiver for signal:", signalName, "With Args:", ...)
	end
	return receiver(...)
end

function Networker:_getOrCreateWrapper(signalName: EventIdentifier)
	if not self.signalWrappers[signalName] then
		local signal = Signal.new()
		self.signalWrappers[signalName] = signal

		return signal
	end

	return self.signalWrappers[signalName]
end

function Networker:_setReceiving(signalName: EventIdentifier, func: Callback)
	self.functionWrappers[signalName] = func
end

function Networker:ClearUnusedSignals()
	local clearedSignals = {}
	for key, signal in self.signalWrappers do
		if signal:HasConnections() then
			continue
		end

		signal:Destroy()
		self.signalWrappers[key] = nil

		table.insert(clearedSignals, key)
	end

	if self.debug and #clearedSignals > 0 then
		print("[Networker] Cleared", #clearedSignals, "Signal(s) with signalName(s):", unpack(clearedSignals))
	end
end

function Networker:EnableAutoCleanup(interval: number?)
	if self.autoCleanup then
		return
	end
	self.autoCleanup = true

	if interval then
		self.cleanupInterval = interval
	end

	if self.cleanupCoroutine and typeof(self.cleanupCoroutine) == "thread" then
		coroutine.close(self.cleanupCoroutine)
	end

	self.cleanupCoroutine = coroutine.create(function()
		while self.autoCleanup do
			task.wait(self.cleanupInterval)
			self:ClearUnusedSignals()
		end
	end)
	coroutine.resume(self.cleanupCoroutine)
end

function Networker:DisableAutoCleanup()
	if not self.autoCleanup then
		return
	end
	self.autoCleanup = false

	if self.cleanupCoroutine and typeof(self.cleanupCoroutine) == "thread" then
		coroutine.close(self.cleanupCoroutine)
		self.cleanupCoroutine = nil
	end
end

function Networker:OnEvent(signalName: EventIdentifier): Signal.Signal
	return self:_getOrCreateWrapper(signalName .. "_RE")
end

function Networker:OnEventUnreliable(signalName: EventIdentifier): Signal.Signal
	return self:_getOrCreateWrapper(signalName .. "_URE")
end

function Networker:OnBindableEvent(signalName: EventIdentifier): Signal.Signal
	return self:_getOrCreateWrapper(signalName .. "_BE")
end

function Networker:OnInvoke(signalName: EventIdentifier, func: Callback)
	self:_setReceiving(signalName .. "_RF", func)
end

function Networker:OnBindableInvoke(signalName: EventIdentifier, func: Callback)
	self:_setReceiving(signalName .. "_BF", func)
end

function Networker:FireClient(signalName: string, player: Player, ...)
	if IS_CLIENT then return end
	local remote = self.instances["RemoteEvent"]
	if remote and typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
		remote:FireClient(player, signalName .. "_RE", ...)
	end
end

function Networker:FireAllClients(signalName: string, ...)
	if IS_CLIENT then return end
	local remote = self.instances["RemoteEvent"]
	if remote and typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
		remote:FireAllClients(signalName .. "_RE", ...)
	end
end

function Networker:FireAllClientsExcept(signalName: string, exceptPlayer: Player, ...)
	if IS_CLIENT then return end
	local remote = self.instances["RemoteEvent"]
	if remote and typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
		for _, player in Players:GetPlayers() do
			if player == exceptPlayer then
				continue
			end

			remote:FireClient(player, signalName .. "_RE", ...)
		end
	end
end

function Networker:FireClientUnreliable(signalName: string, player: Player, ...)
	if IS_CLIENT then return end
	local remote = self.instances["UnreliableRemoteEvent"]
	if remote and typeof(remote) == "Instance" and remote:IsA("UnreliableRemoteEvent") then
		remote:FireClient(player, signalName .. "_URE", ...)
	end
end

function Networker:FireAllClientsUnreliable(signalName: string, ...)
	if IS_CLIENT then return end
	local remote = self.instances["UnreliableRemoteEvent"]
	if remote and typeof(remote) == "Instance" and remote:IsA("UnreliableRemoteEvent") then
		remote:FireAllClients(signalName .. "_URE", ...)
	end
end

function Networker:FireAllClientsExceptUnreliable(signalName: string, exceptPlayer: Player, ...)
	if IS_CLIENT then return end
	local remote = self.instances["UnreliableRemoteEvent"]
	if remote and typeof(remote) == "Instance" and remote:IsA("UnreliableRemoteEvent") then
		for _, player in Players:GetPlayers() do
			if player == exceptPlayer then
				continue
			end

			remote:FireClient(player, signalName .. "_URE", ...)
		end
	end
end

function Networker:InvokeClient(signalName: string, player: Player, ...): any
	if IS_CLIENT then return end
	local remote = self.instances["RemoteFunction"]
	if remote and typeof(remote) == "Instance" and remote:IsA("RemoteFunction") then
		return remote:InvokeClient(player, signalName .. "_RF", ...)
	end
	return
end

function Networker:FireServer(signalName: string, ...)
	if not IS_CLIENT then return end
	local remote = self.instances["RemoteEvent"]
	if remote and typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
		remote:FireServer(signalName .. "_RE", ...)
	end
end

function Networker:FireServerUnreliable(signalName: string, ...)
	if not IS_CLIENT then return end
	local remote = self.instances["UnreliableRemoteEvent"]
	if remote and typeof(remote) == "Instance" and remote:IsA("UnreliableRemoteEvent") then
		remote:FireServer(signalName .. "_URE", ...)
	end
end

function Networker:InvokeServer(signalName: string, ...): any
	if not IS_CLIENT then return end
	local remote = self.instances["RemoteFunction"]
	if remote and typeof(remote) == "Instance" and remote:IsA("RemoteFunction") then
		return remote:InvokeServer(signalName .. "_RF", ...)
	end
	return
end

function Networker:Fire(signalName: string, ...)
	local remote = self.instances["BindableEvent"]
	if remote and typeof(remote) == "Instance" and remote:IsA("BindableEvent") then
		remote:Fire(signalName .. "_BE", ...)
	end
end

function Networker:Invoke(signalName: string, ...): any
	local remote = self.instances["BindableFunction"]
	if remote and typeof(remote) == "Instance" and remote:IsA("BindableFunction") then
		return remote:Invoke(signalName .. "_BF", ...)
	end
	return
end

return Networker.new()
