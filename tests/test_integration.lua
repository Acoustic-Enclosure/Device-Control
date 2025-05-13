local PIDController = require("pid_controller")
local PWMController = require("pwm_controller")
local rotary = require("rotary")

-- Initialize PID
local ki = 0 -- 1.8
local kp = 12 -- 8
local kd = 0 -- 0.5
local cwDirection = 0 -- Clockwise direction
local ccwDirection = 1 -- Counter-clockwise direction
local setpoint = 120 -- Fixed setpoint value in degrees
local pid = PIDController:new(kp, ki, kd, cwDirection, setpoint)

-- Initialize PWM
local pwm = PWMController:new(5, 7, 8) -- D5 pwm and D7-D8 for direction (Pulled to ground)

-- Initialize test LED
local ledPin = 4 -- D4 pin for LED
gpio.mode(ledPin, gpio.OUTPUT)
gpio.write(ledPin, gpio.HIGH) -- Turn off LED initially

-- Initialize rotary encoder
local ROTARY_ID = 0
local pinA, pinB = 1, 2 -- D1 and D2
rotary.close(ROTARY_ID) -- Close any previous instance
rotary.setup(ROTARY_ID, pinA, pinB)
local ticksPerRevolution = 2710

-- Set PID output limits
local maxOutput = 1023 --255 -- Max PWM value
local minOutput = -maxOutput -- Min PWM value
pid:setOutputLimits(minOutput, maxOutput)

-- Set sample time for PID
pid:setSampleTime(50000) -- 50ms

-- Set initial setpoint to the current rotary position to start paused
local initialPosition = rotary.getpos(ROTARY_ID)
local initialDegrees = (initialPosition / ticksPerRevolution) * 360
pid:setSetpoint(initialDegrees)

-- Start PWM
pwm:setSpeedAndDirection(0, "none") -- Stop PWM initially
pwm:start()

-- Main control loop
pid:setSetpoint(setpoint)

local function controlLoop()
    local position = rotary.getpos(ROTARY_ID)
    local feedback = (position / ticksPerRevolution) * 360 -- Get rotary position in degrees
    local output = pid:compute(feedback)
    print("TEST| Feedback:", feedback, "Output:", output)

    if output then
        local speed = math.abs(output)
        local direction = output >= 0 and "forward" or "reverse"
        pwm:setSpeedAndDirection(speed, direction)
    end

    if math.abs(feedback - setpoint) < 1 then -- Tolerance of 1 degree
        gpio.write(ledPin, gpio.LOW) -- Turn on LED
    else
        gpio.write(ledPin, gpio.HIGH) -- Turn off LED
    end
end

-- Use a timer to periodically call the control loop
local controlTimer = tmr.create()
controlTimer:alarm(100, tmr.ALARM_AUTO, controlLoop)
