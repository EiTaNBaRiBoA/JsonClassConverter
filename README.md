# JsonClassConverter

This GDScript provides a set of utility functions for converting Godot classes to JSON dictionaries and vice versa. 

## Features

* **Serialization (Class to JSON):**
	* Converts Godot class instances to JSON-like dictionaries.
	* Handles nested objects and arrays recursively.
	* Supports saving JSON data to files (with optional encryption).
* **Deserialization (JSON to Class):**
	* Loads JSON data from files (with optional decryption).
	* Converts JSON strings and dictionaries into class instances.
	* Handles nested object structures. 
* **Automatic Type Recognition:**  Intelligently handles various data types, including Vectors, Colors, and custom classes.

## Installation

1. Create a new script file named `JsonClassConverter.gd` (or similar) in your Godot project.
2. Copy and paste the code provided into the script file.

## Usage

### 1. Class to JSON

**a) Convert a Class Instance to a JSON Dictionary:**

```gdscript
# Assume you have a class named 'PlayerData':
var player_data = PlayerData.new()
# ... (Set properties of player_data)

# Convert to a JSON dictionary:
var json_data = JsonClassConverter.class_to_json(player_data) 

# json_data now contains a Dictionary representation of your class instance
```

**b) Convert a Class Instance to a JSON String:**

```gdscript
var json_string: String = JsonClassConverter.class_to_json_string(player_data)
```

**c) Save JSON Data to a File:**

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
var loaded_data: PlayerData = JsonClassConverter.json_file_to_class(PlayerData, "user://saves/player_data.json", "my_secret_key") # Optional decryption key

if loaded_data:
	# ... (Access properties of the loaded_data)
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

* **Exported Properties:** Only exported properties (those declared with `@export`) or properties with the `[PROPERTY_USAGE_STORAGE]` meta will be serialized and deserialized.
* **Class Names:**  When loading from JSON, make sure the `castClass` argument (e.g., `PlayerData` in the examples) matches the actual class name you want to deserialize into. 
* **Error Handling:**  Consider adding more robust error handling to the functions (e.g., checking if files exist, handling JSON parsing errors).
* **Vector and Color Representation:** Vectors and Colors are stored as strings (e.g., `"Vector2(1, 2)"`) to ensure compatibility.

## Example

```gdscript
# Example Class (PlayerData.gd)
class_name PlayerData

@export var name: String
@export var score: int 
@export var inventory: Array = [] 
```

```gdscript
# Using the JsonClassConverter 
var player = PlayerData.new()
player.name = "Bob"
player.score = 100
player.inventory = ["Sword", "Potion"]

# Save to file
JsonClassConverter.store_json_file("user://player.sav", JsonClassConverter.class_to_json(player))

# Load from file
var new_player : PlayerData = JsonClassConverter.json_file_to_class(PlayerData, "user://player.sav")

print(new_player.name) # Prints: Bob