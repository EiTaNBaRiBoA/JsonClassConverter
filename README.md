# JsonClassConverter

This GDScript provides a powerful set of utility functions for converting Godot classes to JSON dictionaries and vice versa, simplifying serialization and deserialization tasks.

## Features

* **Serialization (Class to JSON):**
	* Converts Godot class instances into JSON-compatible dictionaries.
	* Handles nested objects and arrays recursively, preserving complex data structures.
	* Supports saving JSON data to files with optional encryption for enhanced security.
* **Deserialization (JSON to Class):**
	* Loads JSON data from files with optional decryption for secure data retrieval.
	* Converts JSON strings and dictionaries back into Godot class instances.
	* Reconstructs nested object hierarchies, including custom classes and resource references.
* **JSON Comparison & Diffing:**
	* Quickly check if two JSON files, strings, or dictionaries are identical.
	* Generate a detailed "diff" dictionary highlighting changes, additions, and deletions between two JSON objects.
* **JSON Operations:**
	* Perform powerful patch operations between two JSON objects, including `Add`, `AddDiffer`, `Replace`, `Remove`, and `RemoveValue`.
	* Apply changes from one JSON object to another, useful for patching saved data or syncing states.
* **Automatic Type Recognition:** Intelligently manages various data types, including:
	* Vectors (`Vector2`, `Vector3`, etc.)
	* Colors
	* Enums
	* Arrays (including typed arrays)
	* Dictionaries (including typed dictionaries)
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

# json_data now holds a Dictionary representation of your class instance.

# Option 2: Convert a Class Instance to a JSON String
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
```


## 3. JSON Utilities and Operations

The class also provides powerful tools for comparing and manipulating JSON data directly.

**a) Check for Equality**

You can quickly check if two JSON sources (file paths, strings, or dictionaries) are identical.

```gdscript
var dict1 = {"name": "Alice", "score": 100}
var dict2 = {"name": "Alice", "score": 100}
var dict3 = {"name": "Bob", "score": 150}

var are_equal = JsonClassConverter.check_equal_jsons(dict1, dict2)
print(are_equal) # Output: true

var are_different = JsonClassConverter.check_equal_jsons(dict1, dict3)
print(are_different) # Output: false
```

**b) Compare and Find Differences (Diff)**

Generate a dictionary that highlights the differences between two JSON objects. The diff dictionary shows the old and new values for changed keys.

```gdscript
var old_data = {"name": "Player1", "level": 5, "items": ["sword"]}
var new_data = {"name": "Player1", "level": 6, "items": ["sword", "shield"], "new_key": "value"}

var diff = JsonClassConverter.compare_jsons_diff(old_data, new_data)
# diff will contain a detailed report of the changes.
print(diff)
```

**c) Perform JSON Operations**

Apply changes from one JSON object to another using a specific operation. This is useful for patching data, merging configurations, or syncing states.

The available operations are defined in the `JsonClassConverter.Operation` enum:

  * `Add`: Adds keys from the reference JSON.
  * `AddDiffer`: Adds keys from the reference JSON that do not exist in the source JSON.
  * `Replace`: Updates values in the source JSON with values from the reference JSON for all matching keys.
  * `Remove`: Removes keys from the source JSON that also exist in the reference JSON, regardless of their value.
  * `RemoveValue`: Removes a key-value pair from the source JSON only if both the key *and* its value match a pair in the reference JSON.

```gdscript
# --- Example Data ---
var source_json = {"a": 1, "b": 2, "c": 3} ## source_json can be an class object, file path or dictionary.
var reference_json = {"b": 20, "c": 3, "d": 4} ## reference_json can be an class object, file path or dictionary.

# --- Operation: Add ---
# Adds key "d" because it's in reference_json but not in source_json
var add_result = JsonClassConverter.json_operation(source_json, reference_json, JsonClassConverter.Operation.Add)
print(add_result) # Output: {"a": 1, "b": [2,20], "c": [3,3], "d": 4}

# --- Operation: AddDiffer ---
# Adds key "d" because it's in reference_json but not in source_json
var add_result = JsonClassConverter.json_operation(source_json, reference_json, JsonClassConverter.Operation.AddDiffer)
print(add_result) # Output: {"a": 1, "b": [2,20], "c": 3, "d": 4}

# --- Operation: Replace ---
# Replaces value of "b" with 20 and "c" with 3
var replace_result = JsonClassConverter.json_operation(source_json, reference_json, JsonClassConverter.Operation.Replace)
print(replace_result) # Output: {"a": 1, "b": 20, "c": 3}

# --- Operation: Remove ---
# Removes "b" and "c" because their keys exist in reference_json
var remove_result = JsonClassConverter.json_operation(source_json, reference_json, JsonClassConverter.Operation.Remove)
print(remove_result) # Output: {"a": 1}

# --- Operation: RemoveValue ---
# Removes "c" because both key and value ("c": 3) match.
# Does not remove "b" because values differ (2 vs 20).
var remove_value_result = JsonClassConverter.json_operation(source_json, reference_json, JsonClassConverter.Operation.RemoveValue)
print(remove_value_result) # Output: {"a": 1, "b": 2}
```
