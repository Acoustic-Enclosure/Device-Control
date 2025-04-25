local PIDController = require("pid_controller")
local PWMController = require("pwm_controller")
local Encoder = require("encoder")

-- Initialize components
local ki = 0.0038
local kp = 1 -- 9.7873e+05
local kd = 8 -- -1.5608e+06
local cwDirection = 1 -- Clockwise direction
local ccwDirection = 0 -- Counter-clockwise direction
local setpoint = 360 -- Fixed setpoint value in degrees

local pid = PIDController:new(kp, ki, kd, cwDirection, setpoint) -- Example PID parameters
local pwm = PWMController:new(5, 7, 8) -- D5 pwm and D7-D8 for direction (Pulled to ground)
local encoder = Encoder:new(1, 2) -- D1 and D2
local ledPin = 0 -- D0 pin for LED

gpio.mode(ledPin, gpio.OUTPUT)
gpio.write(ledPin, gpio.LOW) -- Turn off LED initially

-- Set PID output limits
local maxOutput = 255 --255 -- Max PWM value
local minOutput = -maxOutput -- Min PWM value
pid:setOutputLimits(minOutput, maxOutput)
print("PID output limits set to:", minOutput, "to", maxOutput)

-- Set sample time for PID
pid:setSampleTime(50000) -- 50ms

-- Set initial setpoint to the current encoder reading to start paused
print("Initial encoder position (degrees):", encoder:getPositionInDegrees())
pid:setSetpoint(encoder:getPositionInDegrees())

-- Start PWM
pwm:setSpeedAndDirection(0, "none") -- Stop PWM initially
pwm:start()

-- Main control loop
pid:setSetpoint(setpoint)

local function controlLoop()
    local feedback = encoder:getPositionInDegrees() -- Get encoder position in degrees
    local output = pid:compute(feedback)
    print("TEST| Feedback:", feedback, "Output:", output)

    if output then
        local speed = math.abs(output)
        local direction = output >= 0 and "forward" or "reverse"
        pwm:setSpeedAndDirection(speed, direction)

        if math.abs(feedback - setpoint) < 1 then -- Tolerance of 1 degree
            gpio.write(ledPin, gpio.HIGH) -- Turn on LED
            tmr.create():alarm(1000, tmr.ALARM_SINGLE, function()
                gpio.write(ledPin, gpio.LOW) -- Turn off LED after 1 second
            end)
        end
    end
end

-- Use a timer to periodically call the control loop
local controlTimer = tmr.create()
controlTimer:alarm(100, tmr.ALARM_AUTO, controlLoop)
