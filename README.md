# Roblox Networker Class  

The **Networker Class** provides a clean and scalable abstraction layer for managing communication between **Server ↔ Client** and **intra-context (Server ↔ Server, Client ↔ Client)** interactions in Roblox.  

It encapsulates and streamlines the use of:  
- `RemoteEvent`  
- `UnreliableRemoteEvent`  
- `BindableEvent`  
- `RemoteFunction`  
- `BindableFunction`  

By **lazy-loading events and functions**, the Networker eliminates clutter in `ReplicatedStorage`, resulting in a more maintainable and efficient architecture.  

---

## Key Benefits  
- Centralized networking logic with a consistent API.  
- Lazy-loading strategy to reduce `ReplicatedStorage` pollution.  
- Unified handling of events and functions across server and client contexts.  
- Support for both **reliable** and **unreliable** communication.  

---

## Types Used  

```lua
-- A callback is any function receiving arbitrary parameters and optionally returning values.
type Callback = (...any) -> any
```

---

## API Reference  

### Event Handling  
- **`OnEvent(signalName: string, callback: Callback)`**  
  Listens for a `RemoteEvent` (Server ↔ Client). Automatically uses `OnServerEvent` or `OnClientEvent`.  

- **`OnEventUnreliable(signalName: string, callback: Callback)`**  
  Same as `OnEvent`, but uses an `UnreliableRemoteEvent`.  

- **`OnBindableEvent(signalName: string, callback: Callback)`**  
  Listens for a `BindableEvent` (Server ↔ Server or Client ↔ Client).  

---

### Function Handling  
- **`OnInvoke(signalName: string, callback: Callback)`**  
  Listens for a `RemoteFunction` (Server ↔ Client). Supports returning values via `return`.  

- **`OnBindableInvoke(signalName: string, callback: Callback)`**  
  Listens for a `BindableFunction` (Server ↔ Server or Client ↔ Client). Supports returning values via `return`.  

---

### Firing Events  
- **`FireClient(signalName: string, player: Player, ...: any)`**  
  Fires a `RemoteEvent` from Server → Client.  

- **`FireClientUnreliable(signalName: string, player: Player, ...: any)`**  
  Same as above, but uses an `UnreliableRemoteEvent`.  

- **`FireAllClients(signalName: string, ...: any)`**  
  Fires a `RemoteEvent` from Server → **all clients**.  

- **`FireAllClientsUnreliable(signalName: string, ...: any)`**  
  Same as above, but uses an `UnreliableRemoteEvent`.  

- **`FireServer(signalName: string, ...: any)`**  
  Fires a `RemoteEvent` from Client → Server.  

- **`FireServerUnreliable(signalName: string, ...: any)`**  
  Same as above, but uses an `UnreliableRemoteEvent`.  

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
Networker:OnEvent("PlayerJumped", function(player, jumpPower)
    print(player.Name .. " jumped with power " .. jumpPower)
end)

-- Sending data to all clients
Networker:FireAllClients("MatchStart", os.time())
```

### Client Script Example
```lua
local Networker = require(path.to.Networker)

-- Listening for server broadcasts
Networker:OnEvent("MatchStart", function(startTime)
    print("Match started at timestamp:", startTime)
end)

-- Firing an event to the server
Networker:FireServer("PlayerJumped", 50)
```
