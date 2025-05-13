local WifiController = require("wifi_controller")
local MqttController = require("mqtt_controller")

-- Configure networks list
local NETWORKS = {
    { ssid = "IZZI-33EC", pwd = "FKarr6FnGhaZqHerXc" },
    { ssid = "SiTeConectasTeHackeo", pwd = "NiditoBodet01" },
}

-- Configure MQTT settings
local DEVICE_ID = "NODEMCU_01" -- unique client ID, change numeration for each device

local BASE       = "motors/" .. DEVICE_ID
local GLOBAL_CFG = "motors/config"
local DEVICE_STATUS = BASE .. "/connection"
local function cfgLimitTopic()    return GLOBAL_CFG .. "/limits"               end
local function cfgSampleTopic()   return GLOBAL_CFG .. "/sample_time"          end
local function pidTopic(m)        return BASE .. "/"..m.."/config/pid"         end
local function setpointTopic(m)   return BASE .. "/"..m.."/config/setpoint"    end
local function workingTopic(m)    return BASE .. "/"..m.."/telemetry/working"  end
local function positionTopic(m)   return BASE .. "/"..m.."/telemetry/position" end
local function errorLogTopic(m)   return BASE .. "/"..m.."/log/error"          end

local MQTT_SETTINGS = {
    broker_host  = "192.168.100.116", -- MQTT broker IP or hostname | $ ipconfig getifaddr en0
    broker_port  = 1883,
    client_id    = DEVICE_ID,
    lwt_topic    = DEVICE_STATUS,
    sub_topics   = {
        { topic = cfgLimitTopic(), qos = 2 },
        { topic = cfgSampleTopic(), qos = 2 },
        { topic = pidTopic(1), qos = 2 },
        { topic = pidTopic(2), qos = 2 },
        { topic = setpointTopic(1), qos = 2 },
        { topic = setpointTopic(2), qos = 2 },
    }
}

-- Create WifiController instance
local wifiController = WifiController:new(NETWORKS)

-- Create MqttController instance
local mqttController = MqttController:new(MQTT_SETTINGS)

wifiController:on("connected", function(ip)
    print("[MAIN] Connected with IP: " .. ip)
    mqttController:start()
end)

mqttController:on("connected", function(ip)
    print("[MAIN] MQTT connected to " .. ip .. " broker.")
    mqttController:publish(DEVICE_STATUS, sjson.encode({ status = "CONNECTED" }), 2, 1)
end)

wifiController:start()
