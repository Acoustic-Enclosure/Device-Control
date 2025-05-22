local WifiController = require("wifi_controller")
local MqttController = require("mqtt_controller")
local MotorController = require("motor_controller")

-- Configure networks list
local NETWORKS = {
    { ssid = "IZZI-33EC", pwd = "FKarr6FnGhaZqHerXc" },
    { ssid = "SiTeConectasTeHackeo", pwd = "NiditoBodet01" },
}

-- Configure MQTT settings
local DEVICE_ID = "NODEMCU_01" -- unique client ID, change numeration for each device

local BASE          = "motors/" .. DEVICE_ID
local DEVICE_STATUS = BASE .. "/connection"
local CLEANUP_TOPIC = BASE .. "/cleanup"
local ACTION_TOPIC  = BASE .. "/+/config/setpoint"
local function setpointTopic(m)   return BASE .. "/"..m.."/config/setpoint" end
local function workingTopic(m)    return BASE .. "/"..m.."/telemetry/working"  end
local function positionTopic(m)   return BASE .. "/"..m.."/telemetry/position" end
local function errorLogTopic(m)   return BASE .. "/"..m.."/log/error"          end

local MQTT_SETTINGS = {
    broker_host  = "192.168.0.61", -- MQTT broker IP or hostname | $ ipconfig getifaddr en0
    broker_port  = 1883,
    client_id    = DEVICE_ID,
    lwt_topic    = DEVICE_STATUS,
    sub_topics   = {
        { topic = ACTION_TOPIC,            qos = 2 },
        { topic = CLEANUP_TOPIC,           qos = 2 },
    }
}

-- Create variable for motor
local motor = nil

-- Create WifiController instance
local wifiController = WifiController:new(NETWORKS)

-- Create MqttController instance
local mqttController = MqttController:new(MQTT_SETTINGS)

wifiController:on("connected", function(ip)
    print("[MAIN] Connected with IP: " .. ip)
    collectgarbage()
    mqttController:start()
end)

mqttController:on("connected", function(ip)
    print("[MAIN] MQTT connected to " .. ip .. " broker.")
    collectgarbage()
    mqttController:publish(DEVICE_STATUS, sjson.encode({ status = "CONNECTED" }), 2, 1)
end)

mqttController:on("message", function(topic, payload)
    collectgarbage()
    local ok, msg = pcall(sjson.decode, payload)
    if not ok then
        print("[ERROR] Failed to decode message: ", payload)
        return
    end

    if topic == setpointTopic(1) then
        local motorId = string.match(topic, BASE.."/(.-)/config/setpoint")
        if not motorId then
            return
        end
        motorId = tonumber(motorId)

        mqttController:publish(workingTopic(motorId), sjson.encode({ status = "BUSY" }), 2)
        
        motor = MotorController:new(5, 7, 8, motorId, 1, 2)

        motor:initialize(msg.kp, msg.ki, msg.kd)
        motor:setSetpoint(msg.setpoint)
        motor:startControl(
            function(data)
                mqttController:publish(positionTopic(motorId), sjson.encode(data), 2)
            end,
            function()
                if motor then
                    motor:cleanup()
                else
                    print("[INFO] Motor not initialized, skipping cleanup.")
                end
                mqttController:publish(workingTopic(motorId), sjson.encode({ status = "READY" }), 2)
                motor = nil
            end
        )
    elseif topic == CLEANUP_TOPIC then
        if motor then
            motor:cleanup()
            motor = nil
        else
            print("[INFO] Motor not initialized, skipping cleanup.")
        end
        mqttController:publish(workingTopic(msg.motorId), sjson.encode({ status = "READY" }), 2)
    else
        print("[INFO] Unknown topic: " .. topic)
    end
end)

wifiController:start()
