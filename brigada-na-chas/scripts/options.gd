extends RefCounted
static func defaults() -> Dictionary:
	return {"shadows":true,"msaa":2,"brightness":0.75,"fov":78.0,"sensitivity":1.0,"volume":0.8,"effects":false,"fullscreen":false,"details":false}
static func load_settings() -> Dictionary:
	var settings=defaults()
	var config=ConfigFile.new()
	if config.load("user://settings.cfg")==OK:
		for key in settings:
			var value=config.get_value("settings",key,settings[key])
			if typeof(value)==typeof(settings[key]): settings[key]=value
	settings.brightness=clampf(settings.brightness,0.35,1.2)
	settings.fov=clampf(settings.fov,65,100)
	settings.sensitivity=clampf(settings.sensitivity,0.3,2.5)
	settings.volume=clampf(settings.volume,0,1)
	settings.msaa=clampi(settings.msaa,0,3)
	return settings
static func save_settings(settings: Dictionary) -> void:
	var config=ConfigFile.new()
	for key in settings: config.set_value("settings",key,settings[key])
	config.save("user://settings.cfg")
