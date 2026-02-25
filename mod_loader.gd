extends Node

# Supports custom rooms, monsters, items, and scripts

signal mod_loaded(mod_name: String)
signal all_mods_loaded()

const MOD_DIR := "user://mods/"
const MOD_CONFIG_FILE := "mod.json"

var loaded_mods := {}
var mod_registry := {
	"rooms": [],
	"monsters": [],
	"items": [],
	"scripts": [],
	"resources": {}
}

class ModInfo:
	var name: String
	var version: String
	var author: String
	var description: String
	var mod_path: String
	var dependencies: Array[String] = []
	var enabled: bool = true

func _ready():
	_ensure_mod_directory()
	
func _ensure_mod_directory():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("mods"):
		dir.make_dir("mods")
		print("Created mods directory at: ", ProjectSettings.globalize_path("user://mods/"))

func load_all_mods() -> void:
	print("=== Starting Mod Loading ===")
	var mod_folders = _get_mod_folders()
	
	if mod_folders.is_empty():
		print("No mods found in: ", ProjectSettings.globalize_path(MOD_DIR))
		all_mods_loaded.emit()
		return
	
	# Load mod configs first
	var mod_infos: Array[ModInfo] = []
	for folder in mod_folders:
		var mod_info = _load_mod_config(folder)
		if mod_info:
			mod_infos.append(mod_info)
	
	# Sort by dependencies (simple dependency resolution)
	mod_infos = _sort_by_dependencies(mod_infos)
	
	# Load each mod
	for mod_info in mod_infos:
		if mod_info.enabled:
			_load_mod(mod_info)
	
	print("=== Mod Loading Complete ===")
	print("Loaded mods: ", loaded_mods.keys())
	all_mods_loaded.emit()

func _get_mod_folders() -> Array[String]:
	var folders: Array[String] = []
	var dir = DirAccess.open(MOD_DIR)
	
	if not dir:
		push_error("Failed to open mod directory: " + MOD_DIR)
		return folders
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			folders.append(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return folders

func _load_mod_config(folder_name: String) -> ModInfo:
	var config_path = MOD_DIR.path_join(folder_name).path_join(MOD_CONFIG_FILE)
	
	if not FileAccess.file_exists(config_path):
		push_warning("Mod config not found: " + config_path)
		return null
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse mod config: " + config_path)
		return null
	
	var data = json.data
	var mod_info = ModInfo.new()
	mod_info.name = data.get("name", folder_name)
	mod_info.version = data.get("version", "1.0.0")
	mod_info.author = data.get("author", "Unknown")
	mod_info.description = data.get("description", "")
	mod_info.mod_path = MOD_DIR.path_join(folder_name)
	mod_info.dependencies = data.get("dependencies", [])
	mod_info.enabled = data.get("enabled", true)
	
	return mod_info

func _sort_by_dependencies(mods: Array[ModInfo]) -> Array[ModInfo]:
	# Simple topological sort for dependencies
	var sorted: Array[ModInfo] = []
	var remaining = mods.duplicate()
	
	while not remaining.is_empty():
		var found = false
		for i in range(remaining.size() - 1, -1, -1):
			var mod = remaining[i]
			var deps_satisfied = true
			
			for dep in mod.dependencies:
				if not _is_mod_loaded(dep, sorted):
					deps_satisfied = false
					break
			
			if deps_satisfied:
				sorted.append(mod)
				remaining.remove_at(i)
				found = true
		
		if not found and not remaining.is_empty():
			push_warning("Circular dependency detected or missing dependencies")
			sorted.append_array(remaining)
			break
	
	return sorted

func _is_mod_loaded(mod_name: String, loaded_list: Array[ModInfo]) -> bool:
	for mod in loaded_list:
		if mod.name == mod_name:
			return true
	return false

func _load_mod(mod_info: ModInfo) -> void:
	print("Loading mod: ", mod_info.name, " v", mod_info.version)
	
	var mod_data = {
		"info": mod_info,
		"rooms": [],
		"monsters": [],
		"items": [],
		"scripts": []
	}
	
	# Load rooms
	_load_mod_rooms(mod_info, mod_data)
	
	# Load monsters
	_load_mod_monsters(mod_info, mod_data)
	
	# Load items
	_load_mod_items(mod_info, mod_data)
	
	# Load scripts
	_load_mod_scripts(mod_info, mod_data)
	
	loaded_mods[mod_info.name] = mod_data
	mod_loaded.emit(mod_info.name)
	
	print("  ✓ Loaded: ", mod_info.name)

func _load_mod_rooms(mod_info: ModInfo, mod_data: Dictionary) -> void:
	var rooms_path = mod_info.mod_path.path_join("rooms")
	var dir = DirAccess.open(rooms_path)
	
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var room_path = rooms_path.path_join(file_name)
			var room_scene = load(room_path)
			
			if room_scene:
				mod_data.rooms.append(room_scene)
				mod_registry.rooms.append({
					"scene": room_scene,
					"mod": mod_info.name,
					"name": file_name.get_basename()
				})
				print("    + Room: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _load_mod_monsters(mod_info: ModInfo, mod_data: Dictionary) -> void:
	var monsters_path = mod_info.mod_path.path_join("monsters")
	var dir = DirAccess.open(monsters_path)
	
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var monster_path = monsters_path.path_join(file_name)
			var monster_scene = load(monster_path)
			
			if monster_scene:
				mod_data.monsters.append(monster_scene)
				mod_registry.monsters.append({
					"scene": monster_scene,
					"mod": mod_info.name,
					"name": file_name.get_basename()
				})
				print("    + Monster: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _load_mod_items(mod_info: ModInfo, mod_data: Dictionary) -> void:
	var items_path = mod_info.mod_path.path_join("items")
	var dir = DirAccess.open(items_path)
	
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var item_path = items_path.path_join(file_name)
			var item_scene = load(item_path)
			
			if item_scene:
				mod_data.items.append(item_scene)
				mod_registry.items.append({
					"scene": item_scene,
					"mod": mod_info.name,
					"name": file_name.get_basename()
				})
				print("    + Item: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _load_mod_scripts(mod_info: ModInfo, mod_data: Dictionary) -> void:
	var scripts_path = mod_info.mod_path.path_join("scripts")
	var dir = DirAccess.open(scripts_path)
	
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".gd"):
			var script_path = scripts_path.path_join(file_name)
			var script = load(script_path)
			
			if script:
				mod_data.scripts.append(script)
				mod_registry.scripts.append({
					"script": script,
					"mod": mod_info.name,
					"name": file_name.get_basename()
				})
				print("    + Script: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

# Public API for getting mod content

func get_all_room_scenes() -> Array[PackedScene]:
	var rooms: Array[PackedScene] = []
	for entry in mod_registry.rooms:
		rooms.append(entry.scene)
	return rooms

func get_all_monster_scenes() -> Array[PackedScene]:
	var monsters: Array[PackedScene] = []
	for entry in mod_registry.monsters:
		monsters.append(entry.scene)
	return monsters

func get_all_item_scenes() -> Array[PackedScene]:
	var items: Array[PackedScene] = []
	for entry in mod_registry.items:
		items.append(entry.scene)
	return items

func get_rooms_from_mod(mod_name: String) -> Array[PackedScene]:
	var rooms: Array[PackedScene] = []
	if loaded_mods.has(mod_name):
		rooms = loaded_mods[mod_name].rooms
	return rooms

func get_monsters_from_mod(mod_name: String) -> Array[PackedScene]:
	var monsters: Array[PackedScene] = []
	if loaded_mods.has(mod_name):
		monsters = loaded_mods[mod_name].monsters
	return monsters

func is_mod_loaded(mod_name: String) -> bool:
	return loaded_mods.has(mod_name)

func get_loaded_mod_names() -> Array:
	return loaded_mods.keys()

func reload_mods() -> void:
	# Clear existing
	loaded_mods.clear()
	mod_registry = {
		"rooms": [],
		"monsters": [],
		"items": [],
		"scripts": [],
		"resources": {}
	}
	
	# Reload all
	load_all_mods()
