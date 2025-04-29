local rotary = require("rotary")

-- Initialize the rotary module on pins D1 and D2
local ROTARY_ID = 0
local pinA, pinB = 1, 2 -- D1 and D2
rotary.close(ROTARY_ID) -- Close any previous instance
rotary.setup(ROTARY_ID, pinA, pinB)

print("Testing Rotary Module Measurements...")

-- Set up a timer to periodically print the position in degrees and radians
local ticksPerRevolution = 2710
local printTimer = tmr.create()
printTimer:alarm(100, tmr.ALARM_AUTO, function()
    local position = rotary.getpos(ROTARY_ID)
    local degrees = (position / ticksPerRevolution) * 360
    local radians = (position / ticksPerRevolution) * 2 * math.pi
    print("Position: ", position, " ticks", degrees, " degrees, ", radians, " radians")
    -- print("Position: ", position, " ticks")
end)