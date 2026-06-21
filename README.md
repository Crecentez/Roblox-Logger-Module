# Logger.luau

A strict-typed logging utility for Roblox projects.  
Provides categorized logging, per-logger filtering, structured output, timers, buffering, grouping, and an event system.

---

## Features

- Categorized log output with automatic prefixes
- Global logging toggle via a game attribute
- Per-logger enable/disable overrides via `Logger.Settings`
- Warnings and errors with automatic callsite detection
- Assertions with formatted error messages
- Named timers for performance measurement
- Structured logging — tables are pretty-printed automatically
- Optional context injection (timestamp + callsite on every line)
- Buffered logging — queue output and flush on demand
- Grouped logging — collect related logs and print as a formatted block
- Lazy evaluation — pass a function; it only runs if logging is active
- Event system — subscribe to every dispatched log via `Logger.OnLog`
- Written in Luau with `--!strict`

---

## Installation

1. Place `Logger.luau` in a shared location (e.g. `ReplicatedStorage`)
2. Require it from your scripts:

```lua
local Logger = require(game.ReplicatedStorage.Logger)
```

---

## Basic Usage

```lua
local Logger = require(game.ReplicatedStorage.Logger)
local log = Logger.new("MyScript")

log:Log("This always prints")
log:Print("This prints only when logging is enabled")
log:Warn("Something might be wrong")
```

---

## Logging Control

### Global toggle
Controlled by a game attribute set automatically on the first `Logger.new` call:
```lua
game:SetAttribute("Logging", true)   -- enable all conditional logging
game:SetAttribute("Logging", false)  -- silence Print, Warn, and Debug
```
`Log()` and `Error()` always output regardless of this setting.

### Per-logger override
`Logger.Settings` lets you silence or force-enable individual loggers, overriding the global attribute:
```lua
Logger.Settings["Combat"] = false  -- silence only the Combat logger
Logger.Settings["Net"]    = true   -- force Net logger on even if global is off
Logger.Settings["Combat"] = nil    -- remove override; follows global again
```

---

## Module Config

```lua
Logger.Config.Buffered       = false  -- default: print immediately
Logger.Config.ContextEnabled = false  -- default: no timestamp/callsite prefix
```

---

## API

### `Logger.new(logType: string) -> LoggerType`
Creates a new logger instance.
```lua
local log = Logger.new("Combat")
```

---

### `Logger:Log(...any)`
Unconditional output. Ignores all filters.

---

### `Logger:Print(...any)`
Conditional output. Respects `Logger.Settings` and the global attribute.

---

### `Logger:Warn(...any)`
Conditional warning. Respects `Logger.Settings` and the global attribute.

---

### `Logger:Debug(...any)`
Conditional output with a `[DEBUG]` prefix. Supports lazy evaluation:
```lua
log:Debug(function() return "Expensive value: " .. computeSomething() end)
-- The function only runs if this logger is currently enabled.
```

---

### `Logger:Error(...any)`
Always throws. Includes an automatic callsite in the error message.

---

### `Logger:Assert(condition: boolean?, ...any)`
Throws if `condition` is falsy. Includes an automatic callsite.
```lua
log:Assert(player ~= nil, "Player expected")
```

---

### `Logger:StartTimer(name: string)`
Starts a named timer.
```lua
log:StartTimer("LoadAssets")
```

### `Logger:GetTimer(name: string) -> string`
Stops the named timer and returns elapsed time as `mm:ss.mmmm`.
Returns `"00:00.0000"` if the timer was never started.
```lua
log:Log("Loaded in", log:GetTimer("LoadAssets"))
```

---

### `Logger:BeginGroup(name: string)`
Starts a named log group. All subsequent logs from this instance are buffered until `EndGroup` is called. Groups can be nested.

### `Logger:EndGroup()`
Closes the current group and prints all buffered entries as a formatted block.
```lua
log:BeginGroup("Startup")
log:Print("Loading config...")
log:Print("Config loaded")
log:EndGroup()
-- Prints the entire block at once when EndGroup is called.
```

---

### `Logger.Flush()`
Outputs all buffered logs (when `Logger.Config.Buffered = true`) and clears the buffer.
```lua
Logger.Config.Buffered = true
log:Print("queued message")
Logger.Flush()  -- prints now
```

---

### `Logger.OnLog`
Fires after every dispatched log, including logs captured into groups.
```lua
local disconnect = Logger.OnLog:Connect(function(entry)
    -- entry.logType, entry.message, entry.timestamp, entry.context
    print("LOG EVENT:", entry.logType, entry.message)
end)

disconnect()  -- unsubscribe
```

---

## Structured Logging

If any argument is a table, it is automatically pretty-printed:
```lua
log:Print({ userId = 123, score = 4200, active = true })
-- [MyScript] ::  {
--   ["userId"] = 123
--   ["score"] = 4200
--   ["active"] = true
-- }
```

---

## Context Injection

Enable to prepend a timestamp and callsite to every log line:
```lua
Logger.Config.ContextEnabled = true
log:Print("Hello")
-- [14:32:05 | Script 'ServerScript.Main', Line 12] [MyScript] ::  Hello
```

---

## Example

```lua
local Logger = require(game.ReplicatedStorage.Logger)

-- Per-logger filtering
Logger.Settings["Net"] = false  -- silence Net logger

local log = Logger.new(script.Name)

-- Structured log
log:Print({ event = "PlayerJoined", userId = 1234 })

-- Lazy evaluation (compute() not called if logging is off)
log:Debug(function() return "State: " .. computeExpensiveState() end)

-- Grouped output
log:BeginGroup("Init")
log:Print("Loading modules...")
log:Print("Connecting remotes...")
log:EndGroup()

-- Timers
log:StartTimer("HeavyTask")
for i = 1, 1_000_000 do local _ = i * i end
log:Log("HeavyTask took:", log:GetTimer("HeavyTask"))

-- Event subscription
local disconnect = Logger.OnLog:Connect(function(entry)
    if entry.logType == "Combat" then
        -- forward to external analytics, etc.
    end
end)
```

---

## License
MIT License  
© 2025 Crecentez / Lunoxi Studios

## Notes
- Intended for server or shared modules
- Safe to leave in production when logging is disabled via `Logger.Settings` or the global attribute
- `Logger.Config.Buffered` is useful for batching logs during startup then flushing after