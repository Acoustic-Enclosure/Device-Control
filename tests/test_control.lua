local MotorControl = require("../motor_control")

local motor = MotorControl:new({1, 2}, {3, 4}, {kp = 1.0, ki = 0.1, kd = 0.01})

print("Testing Motor Control...")
motor:control(100) -- Example setpoint
print("Motor control executed with setpoint 100")