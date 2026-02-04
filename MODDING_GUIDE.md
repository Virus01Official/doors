# Modding Guide for Horror Game

## Quick Start

1. Navigate to your game's mod folder:
   - **Windows**: `%APPDATA%/Godot/app_userdata/Rooms/mods/`
   - **Linux**: `~/.local/share/godot/app_userdata/Rooms/mods/`
   - **Mac**: `~/Library/Application Support/Godot/app_userdata/Rooms/mods/`

2. Create a new folder for your mod (e.g., `my_custom_mod`)

3. Create a `mod.json` file inside your mod folder

## Mod Structure

```
mods/
└── my_custom_mod/
    ├── mod.json          (Required - mod configuration)
    ├── rooms/            (Optional - custom room scenes)
    │   ├── custom_room_1.tscn
    │   └── custom_room_2.tscn
    ├── monsters/         (Optional - custom monster scenes)
    │   └── custom_monster.tscn
    ├── items/            (Optional - custom item scenes)
    │   └── custom_item.tscn
    └── scripts/          (Optional - custom GDScript files)
        └── custom_behavior.gd
```

## mod.json Configuration

```json
{
  "name": "My Awesome Mod",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Adds new rooms and monsters to the game",
  "dependencies": [],
  "enabled": true
}
```

### Fields:
- **name** (string): Display name of your mod
- **version** (string): Mod version (semantic versioning recommended)
- **author** (string): Your name or username
- **description** (string): Brief description of what your mod does
- **dependencies** (array): List of mod names this mod requires
- **enabled** (boolean): Whether the mod should load (true/false)

## Creating Custom Rooms

### Requirements:
Your room scene **must** have:
1. A `Begin_Pos` node (MeshInstance3D) - marks where the room starts
2. An `End_Pos` node (MeshInstance3D) - marks where the room ends
3. Optional: `Door` area for progression
4. Optional: `Wardrobe` node for hiding spots
5. Optional: `KeySpawn` nodes for key placement

### Example Room Structure:
```
CustomRoom (Node3D)
├── Begin_Pos (MeshInstance3D)
├── End_Pos (MeshInstance3D)
├── Floor (MeshInstance3D)
├── Walls (Node3D)
│   ├── Wall1 (MeshInstance3D)
│   ├── Wall2 (MeshInstance3D)
│   └── ...
├── Lights (Node3D)
│   ├── SpotLight1 (SpotLight3D)
│   └── SpotLight2 (SpotLight3D)
├── Door (Area3D - optional)
│   └── CollisionShape3D
└── Wardrobe (Node3D - optional)
```

### Tips:
- The `Begin_Pos` and `End_Pos` determine how rooms connect
- Lights will randomly flicker/break based on game mechanics
- Doors trigger room progression
- Wardrobes provide hiding spots from monsters

## Creating Custom Monsters

### Requirements:
Your monster scene should:
1. Extend CharacterBody3D or similar
2. Have appropriate collision shapes
3. Implement movement/AI behavior
4. Have a `target_position` property for Rush-type monsters (optional)

### Example Monster Script:
```gdscript
extends CharacterBody3D

@export var speed := 15.0
var target_position: Vector3

func _physics_process(delta):
    if target_position:
        var direction = (target_position - global_position).normalized()
        velocity = direction * speed
        move_and_slide()
```

## Creating Custom Items

### Requirements:
Your item scene should:
1. Have a visual model (MeshInstance3D)
2. Have an Area3D with collision for pickup
3. Be in the "item" group
4. Have a consistent naming convention

### Example Item Structure:
```
CustomKey (Node3D)
├── Model (MeshInstance3D)
├── PickupArea (Area3D)
│   └── CollisionShape3D
└── AnimationPlayer (optional)
```

Add the item to the "item" group in the scene editor.

## Advanced: Custom Scripts

You can add custom behavior scripts that will be loaded with your mod. These can:
- Modify game behavior
- Add new mechanics
- Hook into existing systems

### Example Custom Script:
```gdscript
extends Node

func _ready():
    print("Custom mod script loaded!")
    # Add your custom behavior here
    
func modify_game_behavior():
    # Your code here
    pass
```

## Dependencies

If your mod requires another mod to work, list it in `dependencies`:

```json
{
  "name": "Advanced Monsters",
  "dependencies": ["Base Monster Pack", "Custom Rooms"],
  "version": "1.0.0"
}
```

Mods will load in dependency order.

## Testing Your Mod

1. Place your mod folder in the mods directory
2. Launch the game
3. Check the console/log for mod loading messages
4. Your content should appear in-game automatically

## Debugging

Common issues:
- **Mod not loading**: Check mod.json syntax (use a JSON validator)
- **Rooms not appearing**: Ensure Begin_Pos and End_Pos nodes exist
- **Monsters not spawning**: Check if monster scene is valid
- **Crashes**: Review console for error messages

## Example Mods

### Simple Room Mod

**mod.json:**
```json
{
  "name": "Spooky Hallways",
  "version": "1.0.0",
  "author": "ModderName",
  "description": "Adds 3 new hallway variations",
  "enabled": true
}
```

Add your room scenes to `rooms/` folder.

### Monster Pack

**mod.json:**
```json
{
  "name": "Extra Monsters",
  "version": "1.0.0",
  "author": "ModderName",
  "description": "Adds 2 new monster types",
  "enabled": true
}
```

Add your monster scenes to `monsters/` folder.

## Best Practices

1. **Version Control**: Use semantic versioning (1.0.0, 1.1.0, 2.0.0)
2. **Testing**: Test with other mods to ensure compatibility
3. **Performance**: Keep polygon counts reasonable
4. **Documentation**: Include a README with your mod
5. **Naming**: Use unique names to avoid conflicts

## Sharing Mods

When sharing your mod:
1. Zip the entire mod folder
2. Include a README with installation instructions
3. List any dependencies clearly
4. Specify game version compatibility

## Support

For issues or questions:
- Check game logs at `user://logs/`
- Review this documentation
- Contact the modding community

Happy Modding! 🎮
