local Logger = require(game.ReplicatedStorage.Logger)
local log = Logger.new(script.Name)

-- ── Basic logging ──────────────────────────────────────────────────────────────

log:Log("Demo started (always prints)")
log:Print("Conditional print (respects Logging attribute)")
log:Warn("Conditional warning")

-- ── Per-logger filtering ───────────────────────────────────────────────────────

local silenced = Logger.new("Silenced")
Logger.Settings["Silenced"] = false   -- this logger will never print
silenced:Print("You will not see this")
silenced:Log("Log bypasses filters, so this still appears")

Logger.Settings["Silenced"] = nil     -- restore to follow global

-- ── Structured logging ─────────────────────────────────────────────────────────

log:Print("Player data:", {
	userId  = 1234,
	score   = 4200,
	active  = true,
	tags    = { "vip", "beta" },
})

-- ── Debug with lazy evaluation ─────────────────────────────────────────────────
-- The function is only called if this logger is enabled, so expensive
-- computations are skipped when logging is off.

log:Debug(function()
	local result = 0
	for i = 1, 10 do result += i end
	return "Lazy sum result: " .. result
end)

-- ── Context injection ──────────────────────────────────────────────────────────

Logger.Config.ContextEnabled = true
log:Print("This line includes a timestamp and callsite")
Logger.Config.ContextEnabled = false

-- ── Grouped logging ────────────────────────────────────────────────────────────

log:BeginGroup("Startup Sequence")
log:Print("Loading config...")
log:Print("Connecting remotes...")
log:Warn("Remote 'UpdateScore' not found — using fallback")
log:Print("Done")
log:EndGroup()  -- all entries printed as a block here

-- ── Buffered logging ───────────────────────────────────────────────────────────

Logger.Config.Buffered = true

log:Print("Buffered message 1")
log:Print("Buffered message 2")
log:Warn("Buffered warning")

print("--- flushing buffer ---")
Logger.Flush()  -- all three lines print here

Logger.Config.Buffered = false

-- ── Event subscription ─────────────────────────────────────────────────────────

local disconnect = Logger.OnLog:Connect(function(entry)
	print(string.format(
		"[EVENT] type=%s | msg=%s | ts=%d",
		entry.logType,
		entry.message,
		entry.timestamp
	))
end)

log:Print("This log fires the OnLog event above")
log:Debug("So does this one")

disconnect()  -- unsubscribe; events stop here
log:Print("This one does NOT fire the event")

-- ── Assertions ─────────────────────────────────────────────────────────────────

local players = game.Players:GetPlayers()
local ok, err = pcall(function()
	log:Assert(players[1] ~= nil, "Expected at least one player")
end)
if not ok then
	log:Warn("Assert caught:", err)
end

-- ── Timers ─────────────────────────────────────────────────────────────────────

log:StartTimer("HeavyTask")
for i = 1, 1_000_000 do
	local _ = i * i
end
log:Log("HeavyTask took:", log:GetTimer("HeavyTask"))