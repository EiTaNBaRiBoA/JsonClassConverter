# JsonClassConverter

This GDScript provides a powerful set of utility functions for converting Godot classes to JSON dictionaries and vice versa, simplifying serialization and deserialization tasks.

## Features

* **Serialization (Class to JSON):**
	* Converts Godot class instances into JSON-compatible dictionaries.
	* Handles nested objects and arrays recursively, preserving complex data structures.
	* Supports saving JSON data to files with optional encryption for enhanced security.
	* Option to save nested resources as separate `.tres` files or directly embed their data.
* **Deserialization (JSON to Class):**
	* Loads JSON data from files with optional decryption for secure data retrieval.
	* Converts JSON strings and dictionaries back into Godot class instances.
	* Reconstructs nested object hierarchies, including custom classes and resource references.
* **Automatic Type Recognition:** Intelligently manages various data types, including:
	* Vectors (Vector2, Vector3, etc.)
	* Colors
	* Arrays
	* Dictionaries
	* Custom classes (using `@export`) 

## Installation

1. **Download:** Download the `JsonClassConverter.gd` file from this repository.
2. **Add to Project:** Place the `JsonClassConverter.gd` file in your Godot project folder (e.g., in a `scripts/` directory).

## Usage

### 1. Class to JSON

**a) Convert a Class Instance to a JSON Dictionary:**

```gdscript
# Assuming you have a class named 'PlayerData' (see Example section):
var player_data = PlayerData.new()
# ... Set properties of player_data ...

# Convert to a JSON dictionary:
# Option 1: Save resources inline within the JSON (default)
var json_data = JsonClassConverter.class_to_json(json_data) 

# Option 2: Save resources as separate temporary .tres files (in 'user://temp_resource/')
var json_data = JsonClassConverter.class_to_json(json_data, true)

json_data now holds a Dictionary representation of your class instance.

# Option 3: Convert a Class Instance to a JSON String
var json_string: String = JsonClassConverter.class_to_json_string(player_data)
```

**b) Save JSON Data to a File:**

```gdscript
var file_success: bool = JsonClassConverter.store_json_file("user://saves/player_data.json", json_data, "my_secret_key")  # Optional encryption key

# Check if saving was successful:
if file_success:
	print("Player data saved successfully!")
else:
	print("Error saving player data.") 
```

### 2. JSON to Class

**a) Load JSON Data from a File:**

```gdscript
var loaded_data: PlayerData = JsonClassConverter.json_file_to_class(PlayerData, "user://saves/player_data.json", "your_secret_key") 

if loaded_data:
	# ... Access properties of loaded_data ...
else:
	print("Error loading player data.")
```

**b) Convert a JSON String to a Class Instance:**

```gdscript
var json_string = '{ "name": "Alice", "score": 1500 }'
var player_data: PlayerData = JsonClassConverter.json_string_to_class(PlayerData, json_string) 
```

**c) Convert a JSON Dictionary to a Class Instance:**

```gdscript
var json_dict = { "name": "Bob", "score": 2000 }
var player_data: PlayerData = JsonClassConverter.json_to_class(PlayerData, json_dict)
```

## Important Notes

* **Supported Properties:** Only properties marked with `@export` or the `[PROPERTY_USAGE_STORAGE]` meta tag will be serialized and deserialized.
* **Class Matching:** Ensure the `castClass` argument (e.g., `PlayerData`) matches the exact class name of the data you're loading. 
* **Error Handling:** Implement robust error handling in your project to catch potential issues like file loading failures or JSON parsing errors. 

## Example Class (PlayerData.gd)

```gdscript
class_name PlayerData

@export var name: String
@export var score: int 
@export var inventory: Array = [] 
```

## Example Usage

```gdscript
# Create a PlayerData instance
var player = PlayerData.new()
player.name = "Bob"
player.score = 100
player.inventory = ["Sword", "Potion"]

# Save the player data to a JSON file
JsonClassConverter.store_json_file("user://player.sav", JsonClassConverter.class_to_json(player))

# Load the player data from the JSON file
var loaded_player: PlayerData = JsonClassConverter.json_file_to_class(PlayerData, "user://player.sav")

# Print the loaded player's name
print(loaded_player.name)  # Output: Bob
