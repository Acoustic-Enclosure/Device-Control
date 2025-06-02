local MqttController = {}
MqttController.__index = MqttController

function MqttController:new(config)
    local obj = {
        broker_host     = config.broker_host or "",
        broker_port     = config.broker_port or 1883,
        client_id       = config.client_id or "NODEMCU_0X",
        username        = config.username or "",
        password        = config.password or "",
        lwt_topic       = config.lwt_topic or "",
        sub_topics      = config.sub_topics or {},
        reconnect_delay = 5000,
        retry_timer     = nil,
        mqtt_client     = nil,
        events          = {},
    }

    setmetatable(obj, MqttController)
    return obj
end

function MqttController:on(event, fn)
    self.events[event] = fn
end

function MqttController:emit(event, ...)
    if self.events[event] then
        self.events[event](...)
    end
end

function MqttController:retry()
    if self.retry_timer then self.retry_timer:stop() end
    self.retry_timer = tmr.create()
    self.retry_timer:alarm(self.reconnect_delay, tmr.ALARM_SINGLE, function()
        self:start()
    end)
end

function MqttController:_init_client()
    local client = mqtt.Client(self.client_id, 60, self.username, self.password, 1)

    client:lwt(self.lwt_topic, sjson.encode({ status = "DISCONNECTED" }), 2)

    client:on("message", function(c, topic, payload)
        print(string.format("[MQTT] Message on %s: %s", topic, payload or ""))
        self:emit("message", topic, payload)
    end)

    client:on("offline", function(c)
        print("[MQTT] Went offline, retrying in " .. self.reconnect_delay .. "ms")
        self:retry()
    end)

    self.mqtt_client = client
end

function MqttController:start()
    if not self.mqtt_client then
        self:_init_client()
    end

    self.mqtt_client:connect(self.broker_host, self.broker_port, false,
        function(client)
            if self.retry_timer then self.retry_timer:stop() end
            for _, entry in ipairs(self.sub_topics) do
                local topic = entry.topic
                local qos = entry.qos or 0
                client:subscribe(topic, qos)
            end
            self:emit("connected", self.broker_host.."/"..self.broker_port)
        end,
        function(c, reason)
            print("[MQTT] Failed to connect to broker, reason: " .. reason)
            self:retry()
        end
    )
end

function MqttController:publish(topic, message, qos, retain)
    if self.mqtt_client then
        self.mqtt_client:publish(topic, message, qos, retain or 0)
    else
        print("[MQTT] Cannot publish, client not connected")
    end
end

return MqttController
