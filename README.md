# Roblox Networker Class

This class is supposed to help you manage your RemoteEvents, UnreliableRemoteEvents, BindableEvents, RemoteFunctions and BindableFunctions more easily.
This class also clears up all the mess in ReplicatedStorage and more while making the game, because Events are lazy loaded.

# Types used in API documentation

Callback: (...any) -> any

# API

:OnEvent(signalName: string, callback: Callback), returns none -> Waits for a RemoteEvent (Used for communication between Server & Client), automatically uses either OnServerEvent or OnClientEvent<br/>
:OnEventUnreliable(signalName: string, callback: Callback), returns none -> Same as :OnEvent, but it uses an <b>UnreliableRemoteEvent</b><br/>
:OnBindableEvent(signalName: string, callback: Callback), returns none -> Waits for a BindableEvent (Used for communication between Server & Server or Client & Client)
:OnInvoke(signalName: string, callback: Callback), returns none -> Waits for a RemoteFunction (Used for yielding communication between Server & Client, also lets you "return" values back with a simple return), automatically uses either OnServerInvoke or OnClientInvoke<br/>
:OnBindableInvoke(signalName: string, callback: Callback), returns none -> Waits for a BindableFunction (Used for yielding communication between Server & Server or Client & Client, also lets you "return" values back with a simple return)<br/>
<br/>
:FireClient(signalName: string, player: Player, ...: any), returns none -> Fires a RemoteEvent from the Server to the Client specified with (player: Player)<br/>
:FireClientUnreliable(signalName: string, player: Player, ...: any), returns none -> Same as :FireClient, but it uses an <b>UnreliableRemoteEvent</b><br/>
:FireAllClients(signalName: string, ...: any), returns none -> Same as :FireClient but it notifies ALL clients instead of one<br/>
:FireAllClientsUnreliable(signalName: string, ...: any), returns none -> Same as :FireAllClients, but it uses an <b>UnreliableRemoteEvent</b><br/>
:FireServer(signalName: string, ...: any), returns none -> Fires a RemoteEvent from the Client to the Server <br/>
:FireServerUnreliable(signalName: string, ...: any), returns none -> Same as :FireServer, but it uses an <b>UnreliableRemoteEvent</b><br/>
:Fire(signalName: string, ...: any), returns none -> Fires a BindableEvent from Client to Client or Server to Server <br/>
:InvokeClient(signalName: string, player: Player, ...: any), returns (any) -> Fires a RemoteFunction from Server to Client <br/>
:InvokeServer(signalName: string, ...: any), returns (any) -> Fires a RemoteFunction from Client to Server <br/>
:Invoke(signalName: string, ...: any), returns (any) -> Fires a BindableFunction from Client to Client or Server to Server <br/>
