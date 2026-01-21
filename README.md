# Logger.luau

A small, strict-typed logging utility for Roblox projects.  
Provides categorized logging, conditional output, assertions, and basic performance timing.

---

## Features

- Categorized log output with automatic prefixes
- Global logging toggle using a game attribute
- Warnings and errors with source location information
- Assertions with formatted error messages
- Named timers for simple performance measurements
- Written in Luau with `--!strict`

---

## Installation

1. Place `Logger.luau` in a shared location (for example, `ReplicatedStorage`)
2. Require it from your scripts:

```lua
local Logger = require(game.ReplicatedStorage.Logger)
```

## Basic Usage
```lua
local Logger = require(game.ReplicatedStorage.Logger)
local log = Logger.new("MyScript")

log:Log("This always prints")
log:Print("This prints only when logging is enabled")
log:Warn("Something might be wrong")
```

## Logging Control
Logging is controlled through a game attribute:
```lua
game:SetAttribute("Logging", true)   -- enable logging
game:SetAttribute("Logging", false)  -- disable Print and Warn output
```
`Log()` and `Error()` always output, regardless of this setting.

## API
`Logger.new(logType: string) -> LoggerType`
Creates a new logger instance with the given category name.
```lua
local log = Logger.new("Combat") -- Preferably use script.Name for log type
```

---

`Logger:Log(...any)`
Logs a message unconditionally.

---

`Logger:Print(...any)`
Logs a message only if logging is enabled.

---

`Logger:Warn(...any)`
Logs a warning only if logging is enabled.

---

`Logger:Assert(condition: boolean?, ...any)`
Throws an error if the condition is false or nil.
```lua
log:Assert(player ~= nil, "Player expected")
```

---

`Logger:StartTimer(name: string)`
Starts a named timer.
```lua
log:StartTimer("LoadAssets")
```

---

`Logger:GetTimer(name: string) -> string`
Stops the timer and returns elapsed time in `mm:ss.mmm` format.
```lua
log:Log("Load time:", log:GetTimer("LoadAssets"))
```
---

If the timer does nto exist, this returns:
```lua
00:00.0000
```
---

## Example
```lua
local Logger = require(game.ReplicatedStorage.Logger)
local DemoLogger = Logger.new(script.Name)

DemoLogger:Log("Demo script started")

local players = game.Players:GetPlayers()
DemoLogger:Assert(#players > 0, "Expected at least one player")

DemoLogger:StartTimer("HeavyTask")
for i = 1, 1_000_000 do
	local _ = i * i
end

DemoLogger:Log("HeavyTask took:", DemoLogger:GetTimer("HeavyTask"))
```

## License
MIT License
© 2025 Crecentez / Lunoxi Studios

## Notes
 - Intended for server or shared modules
 - Safe to leave in production when logging is disabled
 - Useful as a base utility for larger systems
