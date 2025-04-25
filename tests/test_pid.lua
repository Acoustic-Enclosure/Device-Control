local PIDController = require("../pid_controller")

local pid = PIDController:new(1.0, 0.1, 0.01)

print("Testing PID Controller...")
local output = pid:compute(100, 90) -- Example setpoint and measured value
print("PID output:", output)