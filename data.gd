extends Node

var deaf_mode = false
var fps_enabled = false
var rusher_spawned = false
var Volume = 100
var FOV = 75
var Sensitivity = 0.010

const SAVE_PATH = "user://settings.cfg"

func _ready():
	load_settings()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("settings", "deaf_mode", deaf_mode)
	config.set_value("settings", "Volume", Volume)
	config.set_value("settings", "FOV", FOV)
	config.set_value("settings", "Sensitivity", Sensitivity)
	config.save(SAVE_PATH)

func load_settings():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # No save file yet, use defaults
	deaf_mode = config.get_value("settings", "deaf_mode", deaf_mode)
	Volume = config.get_value("settings", "Volume", Volume)
	FOV = config.get_value("settings", "FOV", FOV)
	Sensitivity = config.get_value("settings", "Sensitivity", Sensitivity)
