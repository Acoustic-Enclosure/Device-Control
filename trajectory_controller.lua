local PIDController = require("pid_controller")
local PWMController = require("pwm_controller")

local TrajectoryController = {}
TrajectoryController.__index = TrajectoryController

function TrajectoryController:new(pwmPin, dirPin1, dirPin2, rotaryId, rotaryPinA, rotaryPinB)
    local obj = {
        -- Motor control components
        pid = nil,
        pwm = PWMController:new(pwmPin, dirPin1, dirPin2),
        rotaryId = rotaryId,
        rotaryPinA = rotaryPinA,
        rotaryPinB = rotaryPinB,
        ticksPerRevolution = 2730,  -- Previously 2710
        -- Trajectory parameters
        executionTime = 6000,       -- Total execution time in ms
        startTime = 500,            -- When to begin interpolation in ms
        stopTime = 4000,            -- When to end interpolation in ms
        updateInterval = 150,       -- Update interval in ms
        -- Runtime state
        targetSetpoint = 0,         -- Final position to reach
        currentSetpoint = 0,        -- Current interpolated position
        isRunning = false,
        timer = nil,
        beginTime = nil,
        elapsedTime = 0,
        -- Feedforward parameters
        Kv = 0,                     -- Velocity gain (damping coefficient)
        Ka = 0,                     -- Acceleration gain (inertia coefficient)
        -- Callbacks
        dataCallback = nil,         -- Callback for telemetry data
        completeCallback = nil,     -- Callback when trajectory completes
        telemetry = false           -- Enable telemetry
    }
    setmetatable(obj, TrajectoryController)
    return obj
end

-- Initialize the controller with PID parameters
function TrajectoryController:initialize(kp, ki, kd, kv, ka, telemetry)
    -- Initialize PWM
    self.pwm:setSpeedAndDirection(0, "none")
    self.pwm:start()

    -- Initialize rotary encoder
    self:resetRotary()

    -- Create PID controller
    self.pid = PIDController:new(kp, ki, kd, 0, 0)

    -- Set feedforward parameters
    if kv then self.Kv = kv end
    if ka then self.Ka = ka end

    -- Set telemetry flag
    if telemetry ~= nil then self.telemetry = telemetry end

    return self
end

-- Reset rotary encoder
function TrajectoryController:resetRotary()
    rotary.close(self.rotaryId) -- Close any previous instance
    rotary.setup(self.rotaryId, self.rotaryPinA, self.rotaryPinB)
    if rotary.getpos(self.rotaryId) > 10 then
        self:resetRotary()
    end
end

-- Start trajectory execution to reach the target setpoint
function TrajectoryController:moveToPosition(targetPosition, dataCallback, completeCallback)
    -- Stop any previous execution
    self:stop()

    -- Set up new trajectory
    self.targetSetpoint = targetPosition
    self.dataCallback = dataCallback
    self.completeCallback = completeCallback
    self.beginTime = tmr.now() / 1000  -- Current time in ms
    self.isRunning = true
    self.elapsedTime = 0

    -- Create timer for trajectory execution
    self.timer = tmr.create()
    self.timer:alarm(self.updateInterval, tmr.ALARM_AUTO, function()
        self:_processTrajectory()
    end)

    return true
end

-- Private function to process each trajectory step
function TrajectoryController:_processTrajectory()
    if not self.isRunning then return end

    -- Calculate elapsed time
    self.elapsedTime = (tmr.now() / 1000) - self.beginTime

    -- Calculate current setpoint based on trajectory
    local setpointValue = 0
    local feedforward = 0

    -- Phase 1: Initial hold (0 to startTime)
    if self.elapsedTime < self.startTime then

    -- Phase 2: Smooth transition (startTime to stopTime)
    elseif self.elapsedTime < self.stopTime then
        -- Normalize time to 0-1 range for interpolation
        local normalizedTime = (self.elapsedTime - self.startTime) / (self.stopTime - self.startTime)
        -- Apply cubic interpolation
        local t = 10 * normalizedTime^3 - 15 * normalizedTime^4 + 6 * normalizedTime^5
        -- Calculate interpolated setpoint
        setpointValue = t * self.targetSetpoint
        -- Calculate feedforward
        local vel_reference = self.targetSetpoint * (30 * normalizedTime^4 - 60 * normalizedTime^3 + 30 * normalizedTime^2)
        local acc_reference = self.targetSetpoint * (120 * normalizedTime^3 - 180 * normalizedTime^2 + 60 * normalizedTime)
        if acc_reference < 0 then acc_reference = 0 end
        feedforward = self.Ka * acc_reference + self.Kv * vel_reference

    -- Phase 3: Final hold (stopTime to executionTime)
    else
        setpointValue = self.targetSetpoint
    end

    -- Update PID setpoint
    self.currentSetpoint = setpointValue
    self.pid:setSetpoint(self.currentSetpoint)

    -- Perform control cycle
    self:_controlCycle(feedforward, false)

    -- Check if trajectory is complete
    if self.elapsedTime >= self.executionTime then
        self:_controlCycle(feedforward, true) -- Final control cycle with feedforward

        if self.completeCallback then
            self.completeCallback()
        end
    end

    -- Periodic garbage collection
    collectgarbage()
end

-- Private function to perform a single control cycle
function TrajectoryController:_controlCycle(feedforward, last)
    if last then 
        -- Before stopping, do a final small movement on the opposite direction
        self.pwm:setSpeedAndDirection(254, "reverse")
        tmr.delay(800000) -- 800ms delay (in microseconds)

        -- Stop trajectory and call completion callback
        self:stop()
    end

    -- Get current position
    local position = rotary.getpos(self.rotaryId)
    local input = (position / self.ticksPerRevolution) * 360 -- Convert ticks to degrees
    -- if input > 720 then self:resetRotary() end

    -- Compute PID output
    local output, error = self.pid:compute(input)

    -- Add feedforward to output
    if output and feedforward then
        output = output + feedforward
        if output > self.pid.outMax then
            output = self.pid.outMax
        elseif output < self.pid.outMin then
            output = self.pid.outMin
        end
    end

    -- Apply output to motor
    if output and not last then
        local speed = math.abs(output)
        local direction = output >= 0 and "forward" or "reverse"
        self.pwm:setSpeedAndDirection(speed, direction)
    end

    if last then 
        -- Send telemetry data via callback
        self.dataCallback({
            error = error
        })
    elseif self.telemetry then
        self.dataCallback({
            setpoint = self.currentSetpoint,
            input = input,
            output = output,
        })
    end
end

-- Stop trajectory execution
function TrajectoryController:stop()
    if self.timer then
        self.timer:unregister()
        self.timer = nil
    end

    self.pwm:setSpeedAndDirection(0, "none")
    self.pwm:stop()
    self.isRunning = false
end

-- Clean up resources
function TrajectoryController:cleanup()
    self:stop()
    self:resetRotary()
end

return TrajectoryController
