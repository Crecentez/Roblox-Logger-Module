local Logger = require(game.ReplicatedStorage.Logger)
local DemoLogger = Logger.new(script.Name)

-- Enable logging if not set
if game:GetAttribute("Logging") == nil then
	game:SetAttribute("Logging", true)
end

-- Log everything
DemoLogger:Log("Demo script started!")

-- Conditional logging
DemoLogger:Print("This prints only when logging is enabled")

-- Warning example
local players = game.Players:GetPlayers()
if #players == 0 then
	DemoLogger:Warn("No players in the game!")
end

-- Assertion example
local succ, err = pcall(function()
	local firstPlayer = players[1]
	DemoLogger:Assert(firstPlayer ~= nil, "Expected at least one player!")
end)

if succ then
	DemoLogger:Print("Wow, no problems!")
else
	DemoLogger:Warn(err)
end

-- Timer example
DemoLogger:StartTimer("HeavyTask")
for i = 1, 1000000 do
	local _ = i * i
end
DemoLogger:Log("HeavyTask took:", DemoLogger:GetTimer("HeavyTask"))
