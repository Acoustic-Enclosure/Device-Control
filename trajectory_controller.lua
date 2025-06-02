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
        feedforwardValue = 0,       -- Feedforward compensation value
        -- Callbacks
        dataCallback = nil,         -- Callback for telemetry data
        completeCallback = nil      -- Callback when trajectory completes
    }
    setmetatable(obj, TrajectoryController)
    return obj
end

-- Initialize the controller with PID parameters
function TrajectoryController:initialize(kp, ki, kd)
    -- Initialize PWM
    self.pwm:setSpeedAndDirection(0, "none")
    self.pwm:start()

    -- Initialize rotary encoder
    self:resetRotary()

    -- Create PID controller
    self.pid = PIDController:new(kp, ki, kd, 0, 0)
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
        setpointValue = 0
        feedforward = 0

    -- Phase 2: Smooth transition (startTime to stopTime)
    elseif self.elapsedTime < self.stopTime then
        -- Normalize time to 0-1 range for interpolation
        local normalizedTime = (self.elapsedTime - self.startTime) / (self.stopTime - self.startTime)
        -- Apply cubic easing function: 1-(1-t)^3
        local t = 1 - math.pow(1 - normalizedTime, 3)
        -- Calculate interpolated setpoint
        setpointValue = t * self.targetSetpoint
        -- Calculate decreasing feedforward value
        feedforward = self.feedforwardValue * (1 - normalizedTime)

    -- Phase 3: Final hold (stopTime to executionTime)
    else
        setpointValue = self.targetSetpoint
        feedforward = 0
    end

    -- Update PID setpoint
    self.currentSetpoint = setpointValue
    self.pid:setSetpoint(self.currentSetpoint)

    -- Perform control cycle
    self:_controlCycle(feedforward)

    -- Check if trajectory is complete
    if self.elapsedTime >= self.executionTime then
        -- Stop trajectory and call completion callback
        self:stop()
        if self.completeCallback then
            self.completeCallback()
        end
    end

    -- Periodic garbage collection
    if math.floor(self.elapsedTime / self.updateInterval) % 20 == 0 then
        collectgarbage()
    end
end

-- Private function to perform a single control cycle
function TrajectoryController:_controlCycle(feedforward)
    -- Get current position
    local position = rotary.getpos(self.rotaryId)
    local normalizedPosition = (position % self.ticksPerRevolution + self.ticksPerRevolution) % self.ticksPerRevolution
    local feedback = (normalizedPosition / self.ticksPerRevolution) * 360 -- Convert ticks to degrees

    -- Compute PID output
    local output, error = self.pid:compute(feedback)

    -- Add feedforward to output
    if output and feedforward then
        output = output + feedforward
    end

    -- Apply output to motor
    if output then
        local speed = math.abs(output)
        local direction = output >= 0 and "forward" or "reverse"
        self.pwm:setSpeedAndDirection(speed, direction)
    end

    -- Send telemetry data via callback
    if self.dataCallback then
        local progress = math.min(math.floor((self.elapsedTime / self.executionTime) * 100), 100)

        self.dataCallback({
            setpoint = self.currentSetpoint,
            input = feedback,
            output = output or 0,
            error = error or 0
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
