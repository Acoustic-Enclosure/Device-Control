-- Initialize the rotary module on pins D1 and D2
rotary.close(1) -- Close any previous instance
rotary.setup(1, 1, 2) -- D1 and D2
rotary.close(2) -- Close any previous instance
rotary.setup(2, 5, 6) -- D3 and D4

print("Testing Rotary Module Measurements...")

-- Set up a timer to periodically print the position in degrees and radians
local ticksPerRevolution = 2730 -- previously 2710
local printTimer = tmr.create()
local degrees1 = 0
local degrees2 = 0
printTimer:alarm(500, tmr.ALARM_AUTO, function()
    local position1 = rotary.getpos(1)
    if position1 then 
        degrees1 = (position1 / ticksPerRevolution) * 360
    end

    local position2 = rotary.getpos(2)
    if position2 then 
        degrees2 = (position2 / ticksPerRevolution) * 360
    end
    print("Rotary 1 Position: " .. position1 .. " ticks, " .. degrees1 .. " degrees")
    print("Rotary 2 Position: " .. position2 .. " ticks, " .. degrees2 .. " degrees")
end)