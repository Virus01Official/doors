# Room.gd
extends Node3D

@export var connections_path := NodePath("Connections")
var connections := []

func _ready():
	var cnode = get_node(connections_path)
	for c in cnode.get_children():
		connections.append(c)

func get_free_connections():
	return connections.filter(func(c): return not c.used and c.can_connect)
