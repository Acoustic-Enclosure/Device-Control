local PWMController = require("pwm_controller")
local Encoder = require("encoder")

local encoder = Encoder:new(1, 2) -- D1 and D2
local pwm = PWMController:new(5, 6, 7) -- D5 pwm and D6, D7 for direction

print("Testing PWM Controller...")

pwm:start() -- Start PWM output

local function turnMotor()
    pwm:setSpeedAndDirection(512, "forward") -- Turn motor forward
    print("Motor turning forward")
    tmr.delay(5000000) -- Wait for 5 seconds

    pwm:setSpeedAndDirection(0, "none") -- Pause
    print("Pausing motor")
    tmr.delay(1000000) -- Wait for 1 second

    pwm:setSpeedAndDirection(512, "reverse") -- Turn motor reverse
    print("Motor turning reverse")
    tmr.delay(5000000) -- Wait for 5 seconds

    pwm:setSpeedAndDirection(0, "none") -- Pause
    print("Pausing motor")
    tmr.delay(1000000) -- Wait for 1 second
end

while true do
    turnMotor()
end
