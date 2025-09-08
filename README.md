# Roblox Networker Class

The **Networker Class** provides a **unified abstraction layer** for handling communication in Roblox between:  

- **Server ↔ Client**  
- **Client ↔ Server**  
- **Server ↔ Server** (via bindables)  
- **Client ↔ Client** (via bindables)  

It streamlines the usage of:  
- `RemoteEvent`  
- `UnreliableRemoteEvent`  
- `BindableEvent`  
- `RemoteFunction`  
- `BindableFunction`  

The Networker leverages **lazy-loading and auto-registration** to reduce clutter in `ReplicatedStorage`, minimize boilerplate, and enforce a consistent API for all networking use cases.  

---

## Key Features  
- Single API for all event and function types.  
- Reliable & Unreliable communication support (`RemoteEvent` vs `UnreliableRemoteEvent`).  
- Intra-context communication (server ↔ server, client ↔ client) using bindables.  
- Lazy-loaded signals – automatically creates or resolves networking objects only when required.  
- Signal wrapper integration powered by [`roblox_signal_class`](https://github.com/Tactycl/roblox_signal_class).  

---

## Dependencies  
This library depends on:  
- [roblox_signal_class](https://github.com/Tactycl/roblox_signal_class)  

Make sure it is included in your project before using the Networker.  

---

## Installation  

Place the module inside your project (e.g., under `ReplicatedStorage.Modules`).  
Require it in both client and server scripts:  

```lua
local Networker = require(path.to.Networker)
```

The Networker is a singleton – requiring it anywhere in your codebase will always return the same instance.  

---

## API Reference  

### Event Handling  

- **`OnEvent(signalName: string): Signal`**  
  Subscribes to a `RemoteEvent` (Server ↔ Client).  

- **`OnEventUnreliable(signalName: string): Signal`**  
  Subscribes to an `UnreliableRemoteEvent`.  

- **`OnBindableEvent(signalName: string): Signal`**  
  Subscribes to a `BindableEvent` (Server ↔ Server, Client ↔ Client).  

---

### Function Handling  

- **`OnInvoke(signalName: string): Signal`**  
  Subscribes to a `RemoteFunction` (Server ↔ Client). Supports return values.  

- **`OnBindableInvoke(signalName: string): Signal`**  
  Subscribes to a `BindableFunction` (Server ↔ Server, Client ↔ Client). Supports return values.  

---

### Firing Events  

- **`FireClient(signalName: string, player: Player, ...: any)`**  
  Fires a `RemoteEvent` from Server → Client.  

- **`FireClientUnreliable(signalName: string, player: Player, ...: any)`**  
  Fires an `UnreliableRemoteEvent` from Server → Client.  

- **`FireAllClients(signalName: string, ...: any)`**  
  Fires a `RemoteEvent` from Server → all clients.  

- **`FireAllClientsUnreliable(signalName: string, ...: any)`**  
  Fires an `UnreliableRemoteEvent` from Server → all clients.  

- **`FireServer(signalName: string, ...: any)`**  
  Fires a `RemoteEvent` from Client → Server.  

- **`FireServerUnreliable(signalName: string, ...: any)`**  
  Fires an `UnreliableRemoteEvent` from Client → Server.  

- **`Fire(signalName: string, ...: any)`**  
  Fires a `BindableEvent` (Client ↔ Client or Server ↔ Server).  

---

### Invoking Functions  

- **`InvokeClient(signalName: string, player: Player, ...: any): any`**  
  Invokes a `RemoteFunction` from Server → Client.  

- **`InvokeServer(signalName: string, ...: any): any`**  
  Invokes a `RemoteFunction` from Client → Server.  

- **`Invoke(signalName: string, ...: any): any`**  
  Invokes a `BindableFunction` (Client ↔ Client or Server ↔ Server).  

---

## Example Usage  

### Server Script Example
```lua
local Networker = require(path.to.Networker)

-- Listening for an event from clients
Networker:OnEvent("PlayerJumped"):Connect(function(player, jumpPower)
    print(player.Name .. " jumped with power " .. jumpPower)
end)

-- Sending data to all clients
Networker:FireAllClients("MatchStart", os.time())
```

### Client Script Example
```lua
local Networker = require(path.to.Networker)

-- Listening for server broadcasts
Networker:OnEvent("MatchStart"):Connect(function(startTime)
    print("Match started at timestamp:", startTime)
end)

-- Firing an event to the server
Networker:FireServer("PlayerJumped", 50)
```
