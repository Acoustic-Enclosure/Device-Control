print(wifi.sta.getip())
print(wifi.sta.status())

    wifi.setmode(wifi.STATION)
    station_cfg={}
    station_cfg.ssid="IZZI-33EC"
    station_cfg.pwd="FKarr6FnGhaZqHerXc"
    wifi.sta.config(station_cfg)
