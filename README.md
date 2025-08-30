# Roblox Networker Class

This class is supposed to help you manage your RemoteEvents, UnreliableRemoteEvents, BindableEvents, RemoteFunctions and BindableFunctions more easily.
This class also clears up all the mess in ReplicatedStorage and more while making the game, because Events are lazy loaded.

# Types used in API documentation

Callback: (...any) -> any

# API

:OnEvent(signalName: string, callback: Callback), returns none -> Waits for a RemoteEvent (Used for communication between Server & Client), automatically uses either OnServerEvent or OnClientEvent<br/>
:OnEventUnreliable(signalName: string, callback: Callback), returns none -> Same as :OnEvent, but it uses an <b>UnreliableRemoteEvent</b><br/>
