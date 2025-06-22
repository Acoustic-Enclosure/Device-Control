local WifiController = require("wifi_controller")
local MqttController = require("mqtt_controller")
local TrajectoryController = require("trajectory_controller")

-- Configure networks list
local NETWORKS = {
    { ssid = "IZZI-33EC", pwd = "FKarr6FnGhaZqHerXc" },
}

-- Configure MQTT settings
local DEVICE_ID = "NODEMCU_05" -- unique client ID, change numeration for each device

local BASE          = "motors/" .. DEVICE_ID
local DEVICE_STATUS = BASE .. "/connection"
local CLEANUP_TOPIC = BASE .. "/cleanup"
local ACTION_TOPIC  = BASE .. "/+/config/setpoint"
local function setpointTopic(m)   return BASE .. "/"..m.."/config/setpoint" end
local function workingTopic(m)    return BASE .. "/"..m.."/telemetry/working"  end
local function positionTopic(m)   return BASE .. "/"..m.."/telemetry/position" end
local function errorLogTopic(m)   return BASE .. "/"..m.."/log/error"          end

local MQTT_SETTINGS = {
    broker_host    = "192.168.0.61", -- EMQX Cloud broker | $ ipconfig getifaddr en0
    broker_port    = 1883,
    client_id      = DEVICE_ID,
    username       = DEVICE_ID,
    password       = "device",
    lwt_topic      = DEVICE_STATUS,
    sub_topics     = {
        { topic = ACTION_TOPIC,     qos = 2 },
        { topic = CLEANUP_TOPIC,    qos = 2 },
    }
}

-- Create variable for motor trajectory controller
local motor = nil

-- Create WifiController instance
local wifiController = WifiController:new(NETWORKS)

-- Create MqttController instance
local mqttController = MqttController:new(MQTT_SETTINGS)

-- Memory optimization helper
local function optimizeMemory(label)
    collectgarbage()
    -- print("[MEM] " .. (label or "") .. " " .. node.heap())
end

local function cleanupMotor(motorId)
    if motor then
        motor:cleanup()
        motor = nil
    -- else
    --     print("[INFO] No active motor to clean up.")
    end
    mqttController:publish(workingTopic(motorId), sjson.encode({ status = "READY" }), 2)
end

local function initMotor(motorId)
    optimizeMemory("Before motor init:")
    local success, result = pcall(function()
        if motorId == 1 then
            return TrajectoryController:new(7, 3, 4, motorId, 1, 2)
        else
            return TrajectoryController:new(8, 3, 4, motorId, 5, 6)
        end
    end)

    if not success then
        -- print("[ERROR] Failed to initialize motor " .. motorId .. ": " .. result)
        return nil
    end

    optimizeMemory("After motor init:")
    return result
end

wifiController:on("connected", function(ip)
    optimizeMemory("Wi-Fi connected:")
    mqttController:start()
end)

mqttController:on("connected", function(ip)
    optimizeMemory("MQTT connected:")
    mqttController:publish(DEVICE_STATUS, sjson.encode({ status = "CONNECTED" }), 2) -- without retain
    cleanupMotor(1) -- Clean up any previous motor state
    cleanupMotor(2) -- Clean up any previous motor state
end)

mqttController:on("message", function(topic, payload)
    optimizeMemory("Before message processing:")

    local ok, msg = pcall(sjson.decode, payload)
    if not ok then
        -- print("[ERROR] Failed to decode message: ", payload)
        return
    end

    if topic == CLEANUP_TOPIC then
        node.restart()
        cleanupMotor(msg.motorId)
        return
    elseif topic == setpointTopic(1) or topic == setpointTopic(2) then
        local motorId = string.match(topic, BASE.."/(.-)/config/setpoint")
        if not motorId then
            return
        end
        motorId = tonumber(motorId)

        mqttController:publish(workingTopic(motorId), sjson.encode({ status = "BUSY" }), 2)

        motor = initMotor(motorId)
        if not motor then
            return
        end

        -- Initialize controller with PID values
        motor:initialize(msg.kp, msg.ki, msg.kd, msg.kv, msg.ka, msg.telemetry)

        -- Start trajectory
        motor:moveToPosition(
            msg.setpoint,
            function(data)
                mqttController:publish(positionTopic(motorId), sjson.encode(data), 0) -- QoS 0 for telemetry
            end,
            function()
                cleanupMotor(motorId)
            end
        )
    end
    optimizeMemory("After message processing:")
end)

wifiController:start()
