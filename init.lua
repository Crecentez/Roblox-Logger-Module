-- Logger.lua
-- © 2025 Crecentez / Lunoxi Studios
-- Licensed under the MIT License. See LICENSE file.
-- V1.1.2

--!strict

-- TYPES
export type LogEntry = {
	logType: string,
	message: string,
	timestamp: number,
	context: string?,
}

export type LoggerConfig = {
	Buffered: boolean,
	ContextEnabled: boolean,
}

export type BufferedEntry = {
	text: string,
	isWarn: boolean,
}

export type GroupEntry = {
	name: string,
	entries: { [number]: string },
}

-- Lightweight signal returned by Logger.OnLog; no BindableEvent dependency.
export type Signal = {
	_listeners: { (entry: LogEntry) -> () },
	Connect: (self: Signal, callback: (entry: LogEntry) -> ()) -> () -> (),
	Fire: (self: Signal, entry: LogEntry) -> (),
}

export type LoggerType = {
	Type: string,
	timers: { [string]: number },
	_groups: { GroupEntry },

	-- Static constructor
	new: (logType: string) -> LoggerType,
	-- V1.0.0
	Log: (self: LoggerType, ...any) -> (),
	Print: (self: LoggerType, ...any) -> (),
	Warn: (self: LoggerType, ...any) -> (),
	Error: (self: LoggerType, ...any) -> (),
	Assert: (self: LoggerType, condition: boolean?, ...any) -> (),
	StartTimer: (self: LoggerType, name: string) -> (),
	GetTimer: (self: LoggerType, name: string) -> string,
	-- V1.1.0
	Debug: (self: LoggerType, ...any) -> (),
	BeginGroup: (self: LoggerType, name: string) -> (),
	EndGroup: (self: LoggerType) -> (),
}

-- SIGNAL — pub/sub without BindableEvent instance overhead

local SignalImpl = {}
SignalImpl.__index = SignalImpl

local function newSignal(): Signal
	return setmetatable({ _listeners = {} } :: any, SignalImpl) :: Signal
end

-- Returns a disconnect function.
function SignalImpl:Connect(callback: (entry: LogEntry) -> ()): () -> ()
	table.insert(self._listeners, callback)
	return function()
		for i, fn in ipairs(self._listeners) do
			if fn == callback then
				table.remove(self._listeners, i)
				break
			end
		end
	end
end

function SignalImpl:Fire(entry: LogEntry)
	for _, fn in ipairs(self._listeners) do
		fn(entry)
	end
end

-- MODULE

local Logger = {}
Logger.__index = Logger

--[[
Per-logger filtering. Three-state semantics:
   nil   → follow the global "Logging" game attribute
   true  → always enabled for this logger type
   false → always disabled for this logger type
]]
Logger.Settings = {} :: { [string]: boolean }

Logger.Config = {
	Buffered = false, -- when true, all output queues until Logger.Flush()
	ContextEnabled = false, -- when true, timestamp and callsite are prepended to every log
} :: LoggerConfig

Logger._buffer = {} :: { BufferedEntry }

-- Subscribe: Logger.OnLog:Connect(function(entry: LogEntry) ... end) → disconnect fn
-- Fires for every dispatched log, including those captured into groups.
Logger.OnLog = newSignal()

-- INTERNAL HELPERS

local function getPrefix(logType: string): string
	return "[" .. logType .. "]\t::\t"
end

local function isLoggingEnabled(): boolean
	return game:GetAttribute("Logging") ~= false
end

-- Per-instance setting takes priority; falls back to the global attribute.
local function isInstanceEnabled(logType: string): boolean
	local override = Logger.Settings[logType]
	if override ~= nil then
		return override
	end
	return isLoggingEnabled()
end

-- Recursively formats a value. Tables are indented; all other values use tostring.
local function prettyPrint(value: any, depth: number): string
	if type(value) ~= "table" then
		return tostring(value)
	end
	local indent = string.rep("  ", depth)
	local lines: { string } = { "{" }
	for k, v in pairs(value :: { [any]: any }) do
		local key = type(k) == "string" and ('"' .. k .. '"') or tostring(k)
		table.insert(lines, indent .. "  [" .. key .. "] = " .. prettyPrint(v, depth + 1))
	end
	table.insert(lines, indent .. "}")
	return table.concat(lines, "\n")
end

-- Serializes a args array into a single printable string.
-- Tables are pretty-printed; all other values use tostring.
local function serializeArgs(args: { any }): string
	local parts: { string } = {}
	for _, v in ipairs(args) do
		table.insert(parts, prettyPrint(v, 0))
	end
	return table.concat(parts, " ")
end

-- If the first arg is a callable, invoke it now to get the real value.
-- This should only be called after confirming the log level is active,
-- so expensive computations are skipped when logging is off.
local function resolveArgs(args: { any }): { any }
	if type(args[1]) == "function" then
		args[1] = (args[1] :: () -> any)()
	end
	return args
end

local function extractTraceLine(trace: string): string
	return trace:match("\n%s*(.-)\n") or "unknown"
end

-- Produces "[HH:MM:SS | callsite] " when ContextEnabled is true.
local function buildContextPrefix(callsite: string): string
	local dt = DateTime.now():ToLocalTime()
	local ts = string.format("%02d:%02d:%02d", dt.Hour, dt.Minute, dt.Second)
	return "[" .. ts .. " | " .. callsite .. "] "
end

-- Central dispatcher. Fires OnLog, then routes to group buffer, module buffer, or stdout.
local function dispatch(self: LoggerType, fullText: string, rawMessage: string, isWarn: boolean, contextStr: string?)
	local timestamp = DateTime.now().UnixTimestampMillis

	-- Always fire the event so external subscribers see every log immediately,
	-- even when the output itself is grouped or buffered.
	Logger.OnLog:Fire({
		logType = self.Type,
		message = rawMessage,
		timestamp = timestamp,
		context = contextStr,
	})

	-- Capture into the innermost active group instead of printing.
	if #self._groups > 0 then
		self._groups[#self._groups].entries[timestamp] = fullText
		return
	end

	if Logger.Config.Buffered then
		table.insert(Logger._buffer, { text = fullText, isWarn = isWarn })
	elseif isWarn then
		warn(fullText)
	else
		print(fullText)
	end
end

-- CONSTRUCTOR

function Logger.new(logType: string): LoggerType
	if game:GetAttribute("Logging") == nil then
		game:SetAttribute("Logging", true)
	end

	return setmetatable({
		Type = logType or "__Unknown__",
		timers = {},
		_groups = {},
	}, Logger) :: LoggerType
end

-- LOGGING METHODS

-- Log: unconditional; ignores per-instance and global filtering.
function Logger:Log(...)
	local args = resolveArgs({ ... })
	local msg = serializeArgs(args)
	local ctxPrefix = ""
	local ctxStr: string? = nil
	if Logger.Config.ContextEnabled then
		local line = extractTraceLine(debug.traceback("", 2))
		ctxStr = line
		ctxPrefix = buildContextPrefix(line)
	end
	dispatch(self, ctxPrefix .. getPrefix(self.Type) .. msg, msg, false, ctxStr)
end

-- Print: conditional; respects per-instance Settings and global attribute.
function Logger:Print(...)
	if not isInstanceEnabled(self.Type) then
		return
	end
	local args = resolveArgs({ ... })
	local msg = serializeArgs(args)
	local ctxPrefix = ""
	local ctxStr: string? = nil
	if Logger.Config.ContextEnabled then
		local line = extractTraceLine(debug.traceback("", 2))
		ctxStr = line
		ctxPrefix = buildContextPrefix(line)
	end
	dispatch(self, ctxPrefix .. getPrefix(self.Type) .. msg, msg, false, ctxStr)
end

-- Warn: conditional warn; respects per-instance Settings and global attribute.
function Logger:Warn(...)
	if not isInstanceEnabled(self.Type) then
		return
	end
	local args = resolveArgs({ ... })
	local msg = serializeArgs(args)
	local ctxPrefix = ""
	local ctxStr: string? = nil
	if Logger.Config.ContextEnabled then
		local line = extractTraceLine(debug.traceback("", 2))
		ctxStr = line
		ctxPrefix = buildContextPrefix(line)
	end
	dispatch(self, ctxPrefix .. getPrefix(self.Type) .. msg, msg, true, ctxStr)
end

-- Error: always throws; bypasses filters but supports lazy eval and structured args.
function Logger:Error(...)
	local trace = debug.traceback("", 2)
	local traceLine = extractTraceLine(trace)
	local msg = serializeArgs(resolveArgs({ ... }))
	local fullMsg = getPrefix(self.Type) .. msg .. " [" .. traceLine .. "]"
	Logger.OnLog:Fire({
		logType = self.Type,
		message = msg,
		timestamp = DateTime.now().UnixTimestampMillis,
		context = traceLine,
	})
	error(fullMsg, 2)
end

-- Assert: throws if condition is falsy; message args support lazy eval and structured logging.
function Logger:Assert(condition: boolean?, ...)
	if not condition then
		local trace = debug.traceback("", 2)
		local traceLine = extractTraceLine(trace)
		local msg = serializeArgs(resolveArgs({ ... }))
		local fullMsg = getPrefix(self.Type) .. msg .. " [" .. traceLine .. "]"
		Logger.OnLog:Fire({
			logType = self.Type,
			message = msg,
			timestamp = DateTime.now().UnixTimestampMillis,
			context = traceLine,
		})
		error(fullMsg, 2)
	end
end

function Logger:StartTimer(name: string)
	self.timers[name] = DateTime.now().UnixTimestampMillis
end

function Logger:GetTimer(name: string): string
	local startTime = self.timers[name]
	if not startTime then
		return "00:00.0000"
	end

	self.timers[name] = nil

	local elapsedMs = DateTime.now().UnixTimestampMillis - startTime
	local minutes = math.floor(elapsedMs / 60000)
	local seconds = math.floor((elapsedMs % 60000) / 1000)
	local milliseconds = elapsedMs % 1000

	return string.format("%02i:%02i.%04i", minutes, seconds, milliseconds)
end

-- Debug: conditional print with a [DEBUG] prefix.
-- Supports lazy eval: logger:Debug(function() return "expensive: " .. compute() end)
function Logger:Debug(...)
	if not isInstanceEnabled(self.Type) then
		return
	end
	local args = resolveArgs({ ... })
	local msg = serializeArgs(args)
	local ctxPrefix = ""
	local ctxStr: string? = nil
	if Logger.Config.ContextEnabled then
		local line = extractTraceLine(debug.traceback("", 2))
		ctxStr = line
		ctxPrefix = buildContextPrefix(line)
	end
	dispatch(self, ctxPrefix .. "[DEBUG] " .. getPrefix(self.Type) .. msg, msg, false, ctxStr)
end

-- BeginGroup: subsequent logs from this instance are buffered until EndGroup.
-- Groups can be nested; inner groups are flushed into the outer group.
function Logger:BeginGroup(name: string)
	table.insert(self._groups, { name = name, entries = {} })
end

-- EndGroup: formats the current group's buffered entries as a block and outputs them.
-- If inside a parent group, the block is captured there instead.
function Logger:EndGroup()
	local group = table.remove(self._groups) :: GroupEntry?
	if not group then
		warn(getPrefix(self.Type) .. "EndGroup called with no active group")
		return
	end

	local pfx = getPrefix(self.Type)
	local lines: { string } = { pfx .. "-- Group: " .. group.name .. " --" }
	for ts, msg in pairs(group.entries) do
		table.insert(lines, "  [" .. tostring(ts) .. "] " .. msg)
	end
	table.insert(lines, pfx .. "-- End: " .. group.name .. " --")
	local block = table.concat(lines, "\n")

	if #self._groups > 0 then
		-- Nested group: pipe the formatted block into the parent group
		self._groups[#self._groups].entries[DateTime.now().UnixTimestampMillis] = block
	elseif Logger.Config.Buffered then
		table.insert(Logger._buffer, { text = block, isWarn = false })
	else
		print(block)
	end
end

-- MODULE-LEVEL API (STATIC)

-- Flush: outputs all buffered entries in order, then clears the buffer.
-- No-op when Buffered is false (buffer will be empty).
function Logger.Flush()
	for _, entry in ipairs(Logger._buffer) do
		if entry.isWarn then
			warn(entry.text)
		else
			print(entry.text)
		end
	end
	table.clear(Logger._buffer)
end

return Logger
