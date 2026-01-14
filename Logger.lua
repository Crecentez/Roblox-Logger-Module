-- Logger.lua
-- © 2025 Crecentez / Lunoxi Studios
-- Licensed under the MIT License. See LICENSE file.

--!strict

export type LoggerType = {
	Type: string,
	timers: { [string]: number },

	-- Creates a new logger instance
	new: (logType: string) -> LoggerType,
	-- Logs a message unconditionally
	Log: (self: LoggerType, ...any) -> (),
	-- Logs a message if logging is enabled
	Print: (self: LoggerType, ...any) -> (),
	-- Warns a message if logging is enabled
	Warn: (self: LoggerType, ...any) -> (),
	-- Throws an error with the log prefix
	Error: (self: LoggerType, ...any) -> (),
	-- Asserts a condition, throws error if false or nil
	Assert: (self: LoggerType, condition: boolean?, ...any) -> (),
	-- Starts a timer with a given name
	StartTimer: (self: LoggerType, name: string) -> (),
	-- Gets elapsed time for a timer in mm:ss.mmmm format
	GetTimer: (self: LoggerType, name: string) -> string,
}

local Logger = {}
Logger.__index = Logger

--[[
	Internal helper: returns formatted log prefix
	@param logType string: Type of log
	@return string: formatted prefix "[Type]	::	"
]]
local function getPrefix(logType: string): string
	return "[" .. logType .. "]\t::\t"
end

--[[
	Internal helper: checks if logging is enabled via game attribute
	@return boolean: true if logging enabled
]]
local function isLoggingEnabled(): boolean
	return game:GetAttribute("Logging") ~= false
end

--[[
	Creates a new Logger instance
	@param logType string: The log type/category
	@return LoggerType: A new Logger object
]]
function Logger.new(logType: string): LoggerType
	if game:GetAttribute("Logging") == nil then
		game:SetAttribute("Logging", true)
	end

	return setmetatable({
		Type = logType or "__Unknown__",
		timers = {}
	}, Logger) :: LoggerType
end

--[[
	Logs a message to output unconditionally
	@param ... any: Values to log
]]
function Logger:Log(...)
	print(getPrefix(self.Type), ...)
end

--[[
	Logs a message only if logging is enabled
	@param ... any: Values to log
]]
function Logger:Print(...)
	if isLoggingEnabled() then
		print(getPrefix(self.Type), ...)
	end
end

--[[
	Logs a warning message only if logging is enabled
	@param ... any: Values to warn
]]
function Logger:Warn(...)
	if isLoggingEnabled() then
		warn(getPrefix(self.Type), ...)
	end
end

--[[
	Throws an error with logger prefix
	@param ... any: Values to include in error message
	@note: Uses table.concat to combine values into a string
]]
function Logger:Error(...)
	local trace = debug.traceback("", 2)
	local traceLine = trace:match("\n%s*(.-)\n")
	local msg = table.concat({ ... }, " ")
	error(getPrefix(self.Type) .. msg .. " [" .. (traceLine or "unknown location") .. "]", 2)
end

--[[
	Asserts a condition and throws an error if false or nil
	@param condition boolean?: Condition to test
	@param ... any: Values to include in error message if assertion fails
]]
function Logger:Assert(condition: boolean?, ...)
	if not condition then
		local trace = debug.traceback("", 2)
		local traceLine = trace:match("\n%s*(.-)\n")
		local msg = table.concat({ ... }, " ")
		error(getPrefix(self.Type) .. msg .. " [" .. (traceLine or "unknown location") .. "]", 2)
	end
end

--[[
	Starts a timer with a given name
	@param name string: Timer identifier
]]
function Logger:StartTimer(name: string)
	self.timers[name] = DateTime.now().UnixTimestampMillis
end

--[[
	Gets the elapsed time of a named timer in "mm:ss.mmmm" format
	@param name string: Timer identifier
	@return string: Elapsed time formatted as minutes:seconds.milliseconds
	@note: Returns "00:00.0000" if timer not found
]]
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

return Logger
