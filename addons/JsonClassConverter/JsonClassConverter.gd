class_name JsonClassConverter

# Flag to control whether to save nested resources as separate .tres files 
static var save_temp_resources_tres: bool = false

## Checks if the provided class is valid (not null)
static func _check_cast_class(castClass: GDScript) -> bool:
	if typeof(castClass) == Variant.Type.TYPE_NIL:
		printerr("The provided class is null.")
		return false
	return true

## Checks if the directory for the given file path exists, creating it if necessary.
static func check_dir(file_path: String) -> void:
	if !DirAccess.dir_exists_absolute(file_path.get_base_dir()):
		DirAccess.make_dir_absolute(file_path.get_base_dir())

#region Json to Class

## Loads a JSON file and parses it into a Dictionary.
## Supports optional decryption using a security key.
static func json_file_to_dict(file_path: String, security_key: String = "") -> Dictionary:
	var file: FileAccess
	if FileAccess.file_exists(file_path):
		if security_key.length() == 0:
			file = FileAccess.open(file_path, FileAccess.READ)
		else:
			file = FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, security_key)
		if not file:
			printerr("Error opening file: ", file_path)
			return {}
		var parsed_results: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed_results is Dictionary or parsed_results is Array:
			return parsed_results
	return {}

## Loads a JSON file and converts its contents into a Godot class instance.
## Uses the provided GDScript (castClass) as a template for the class.
static func json_file_to_class(castClass: GDScript, file_path: String, security_key: String = "") -> Object:
	if not _check_cast_class(castClass):
		printerr("The provided class is null.")
		return null
	var parsed_results = json_file_to_dict(file_path, security_key)
	if parsed_results == null:
		return castClass.new()
	return json_to_class(castClass, parsed_results)

## Converts a JSON string into a Godot class instance.
static func json_string_to_class(castClass: GDScript, json_string: String) -> Object:
	if not _check_cast_class(castClass):
		printerr("The provided class is null.")
		return null
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result == Error.OK:
		return json_to_class(castClass, json.data)
	return castClass.new()

## Converts a JSON dictionary into a Godot class instance.
## This is the core deserialization function.
static func json_to_class(castClass: GDScript, json: Dictionary) -> Object:
	# Create an instance of the target class
	var _class: Object = castClass.new() as Object
	var properties: Array = _class.get_property_list()

	# Iterate through each key-value pair in the JSON dictionary
	for key: String in json.keys():
		var value: Variant = json[key]
		
		# Special handling for Vector types (stored as strings in JSON)
		if type_string(typeof(value)) == "String" and value.begins_with("Vector"):
			value = str_to_var(value)

		# Find the matching property in the target class
		for property: Dictionary in properties:
			# Skip the 'script' property (built-in)
			if property.name == "script":
				continue

			# Get the current value of the property in the class instance
			var property_value: Variant = _class.get(property.name)

			# If the property name matches the JSON key and is a script variable:
			if property.name == key and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE:
				# Case 1: Property is an Object (not an array)
				if not property_value is Array and property.type == TYPE_OBJECT:
					var inner_class_path: String = ""
					if property_value:
						# If the property already holds an object, try to get its script path
						for inner_property: Dictionary in property_value.get_property_list():
							if inner_property.has("hint_string") and inner_property["hint_string"].contains(".gd"):
								inner_class_path = inner_property["hint_string"]
						# Recursively deserialize nested objects
						_class.set(property.name, json_to_class(load(inner_class_path), value))
					elif value:
						var script_type: GDScript = null
						# Determine the script type for the nested object
						if value is Dictionary and value.has("script_inheritance"):
							script_type = get_gdscript(value["script_inheritance"])
						else:
							script_type = get_gdscript(property.class_name )

						# If the value is a resource path, load the resource
						if value is String and value.is_absolute_path():
							_class.set(property.name, ResourceLoader.load(get_main_tres_path(value)))
						else:
							# Recursively deserialize nested objects
							_class.set(property.name, json_to_class(script_type, value))

				# Case 2: Property is an Array
				elif property_value is Array:
					var arr_script: GDScript = null
					if property_value.is_typed() and property_value.get_typed_script():
						arr_script = load(property_value.get_typed_script().get_path())
						# Recursively convert the JSON array to a Godot array
					var arrayTemp: Array = convert_json_to_array(value, arr_script)
						
						# Handle Vector arrays (convert string elements back to Vectors)
					if type_string(property_value.get_typed_builtin()).begins_with("Vector"):
						for obj_array: Variant in arrayTemp:
							_class.get(property.name).append(str_to_var(type_string(property_value.get_typed_builtin()) + obj_array))
					else:
						_class.get(property.name).assign(arrayTemp)
				# Case 3: Property is a Typed Dictionary
				elif property_value is Dictionary and property_value.is_typed():
					convert_json_to_dictionary(property_value, value)
				# Case 4: Property is a simple type (not an object or array)
				else:
					# Special handling for Color type (stored as a hex string)
					if property.type == TYPE_COLOR:
						value = Color(value)
					if property.type == TYPE_INT and property.hint == PROPERTY_HINT_ENUM:
						var enum_strs: Array = property.hint_string.split(",")
						var enum_value: int = 0
						for enum_str: String in enum_strs:
							if enum_str.contains(":"):
								var enum_keys: Array = enum_str.split(":")
								for i: int in enum_keys.size():
									if enum_keys[i].to_lower() == value.to_lower():
										enum_value = int(enum_keys[i + 1])
						_class.set(property.name, enum_value)
					else:
						_class.set(property.name, value)

	# Return the fully deserialized class instance
	return _class

## Helper function to find a GDScript by its class name.
static func get_gdscript(hint_class: String) -> GDScript:
	for className: Dictionary in ProjectSettings.get_global_class_list():
		if className.class == hint_class:
			return load(className.path)
	return null
	
## Helper function to recursively convert JSON arrays to Godot arrays.
static func convert_json_to_array(json_array: Array, cast_class: GDScript = null) -> Array:
	var godot_array: Array = []
	for element: Variant in json_array:
		if typeof(element) == TYPE_DICTIONARY:
			# If json element has a script_inheritance, get the script (for inheritance or for untyped array/dictionary)
			if "script_inheritance" in element:
				cast_class = get_gdscript(element["script_inheritance"])
			godot_array.append(json_to_class(cast_class, element))
		elif typeof(element) == TYPE_ARRAY:
			godot_array.append(convert_json_to_array(element))
		else:
			godot_array.append(element)
	return godot_array

## Helper function to recursively convert JSON dictionaries to Godot arrays.
static func convert_json_to_dictionary(propert_value: Dictionary, json_dictionary: Dictionary) -> void:
	for json_key: Variant in json_dictionary.keys():
		var json_value: Variant = json_dictionary.get(json_key)
		var key_obj: Variant = null
		var value_obj: Variant = null
		if propert_value.get_typed_key_script() and typeof(json_key) == TYPE_STRING:
			var data = JSON.parse_string(json_key)
			if data:
				json_key = data
		if typeof(json_key) == TYPE_DICTIONARY or typeof(json_key) == TYPE_OBJECT:
			var key_script: GDScript = null
			if "script_inheritance" in json_key:
				key_script = get_gdscript(json_key["script_inheritance"])
			else:
				key_script = load(propert_value.get_typed_key_script().get_path())
			key_obj = json_to_class(key_script, json_key)
		elif typeof(json_key) == TYPE_ARRAY:
			key_obj = convert_json_to_array(json_key)
		else:
			key_obj = str_to_var(json_key)
			if !key_obj: # if null revert to json key
				key_obj = json_key
		
		if propert_value.get_typed_value_script() and typeof(json_value) == TYPE_STRING:
			var data = JSON.parse_string(json_value)
			if data:
				json_value = data
		if typeof(json_value) == TYPE_DICTIONARY or typeof(json_value) == TYPE_OBJECT:
			var value_script: GDScript = null
			if "script_inheritance" in json_value:
				value_script = get_gdscript(json_value["script_inheritance"])
			else:
				value_script = load(propert_value.get_typed_value_script().get_path())
			value_obj = json_to_class(value_script, json_value)
		elif typeof(json_value) == TYPE_ARRAY:
			value_obj = convert_json_to_array(json_value)
		elif typeof(json_value) == TYPE_BOOL or typeof(json_value) == TYPE_INT or typeof(json_value) == TYPE_FLOAT:
			value_obj = json_value
		else:
			value_obj = str_to_var(json_value)
			if !value_obj: # if null revert to json key
				value_obj = json_value
		propert_value.set(key_obj, value_obj)

#endregion

#region Class to Json
## Stores a JSON dictionary to a file, optionally with encryption.
static func store_json_file(file_path: String, data: Dictionary, security_key: String = "") -> bool:
	check_dir(file_path)
	var file: FileAccess
	if security_key.length() == 0:
		file = FileAccess.open(file_path, FileAccess.WRITE)
	else:
		file = FileAccess.open_encrypted_with_pass(file_path, FileAccess.WRITE, security_key)
	if not file:
		printerr("Error writing to a file")
		return false
	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true

## Converts a Godot class instance into a JSON string.
static func class_to_json_string(_class: Object, save_temp_res: bool = false) -> String:
	return JSON.stringify(class_to_json(_class, save_temp_res))

## Converts a Godot class instance into a JSON dictionary.
## This is the core serialization function.
static func class_to_json(_class: Object, save_temp_res: bool = false, inheritance: bool = false) -> Dictionary:
	var dictionary: Dictionary = {}
	save_temp_resources_tres = save_temp_res
	# Store the script name for reference during deserialization if inheritance exists
	if inheritance:
		dictionary["script_inheritance"] = _class.get_script().get_global_name()
	var properties: Array = _class.get_property_list()

	# Iterate through each property of the class
	for property: Dictionary in properties:
		var property_name: String = property["name"]
		# Skip the built-in 'script' property
		if property_name == "script":
			continue
		var property_value: Variant = _class.get(property_name)

		# Only serialize properties that are exported or marked for storage
		if not property_name.is_empty() and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE > 0:
			if property_value is Array:
				# Recursively convert arrays to JSON
				dictionary[property_name] = convert_array_to_json(property_value)
			elif property_value is Dictionary:
				# Recursively convert dictionaries to JSON
				dictionary[property_name] = convert_dictionary_to_json(property_value)
			# If the property is a Resource:
			elif property["type"] == TYPE_OBJECT and property_value != null and property_value.get_property_list():
				if property_value is Resource and ResourceLoader.exists(property_value.resource_path):
					var main_src: String = get_main_tres_path(property_value.resource_path)
					if main_src.get_extension() != "tres":
						# Store the resource path if it's not a .tres file
						dictionary[property.name] = property_value.resource_path
					elif save_temp_resources_tres:
						# Save the resource as a separate .tres file
						var tempfile = "user://temp_resource/"
						check_dir(tempfile)
						var nodePath: String = get_node_tres_path(property_value.resource_path)
						if not nodePath.is_empty():
							tempfile += nodePath
							tempfile += ".tres"
						else:
							tempfile += property_value.resource_path.get_file()
						dictionary[property.name] = tempfile
						ResourceSaver.save(property_value, tempfile)
					else:
						# Recursively serialize the nested resource
						dictionary[property.name] = class_to_json(property_value, save_temp_resources_tres)
				else:
					dictionary[property.name] = class_to_json(property_value, save_temp_resources_tres, property.class_name != property_value.get_script().get_global_name())
			# Special handling for Vector types (store as strings)
			elif type_string(typeof(property_value)).begins_with("Vector"):
				dictionary[property_name] = var_to_str(property_value)
			elif property["type"] == TYPE_COLOR:
				# Store Color as a hex string
				dictionary[property_name] = property_value.to_html()
			else:
				# Store other basic types directly
				if property.type == TYPE_INT and property.hint == PROPERTY_HINT_ENUM:
					var enum_params: String = property.hint_string
					for enum_value: String in enum_params.split(","):
						if enum_value.contains(":"):
							if property_value == str_to_var(enum_value.split(":")[1]):
								dictionary[property.name] = enum_value.split(":")[0]
						else:
							dictionary[property.name] = enum_value
				else:
					dictionary[property.name] = property_value
	return dictionary

## Extracts the main path from a resource path (removes node path if present).
static func get_main_tres_path(path: String) -> String:
	var path_parts: PackedStringArray = path.split("::", true, 1)
	if path_parts.size() > 0:
		return path_parts[0]
	else:
		return path

## Extracts the node path from a resource path.
static func get_node_tres_path(path: String) -> String:
	var path_parts: PackedStringArray = path.split("::", true, 1)
	if path_parts.size() > 1:
		return path_parts[1]
	else:
		return ""


## Helper function to recursively convert Godot arrays to JSON arrays.
static func convert_array_to_json(array: Array) -> Array:
	var json_array: Array = []
	for element: Variant in array:
		json_array.append(refcounted_to_value(element, array.is_typed()))
	return json_array

## Helper function to recursively convert Godot dictionaries to JSON dictionaries.
static func convert_dictionary_to_json(dictionary: Dictionary) -> Dictionary:
	var json_dictionary: Dictionary = {}
	for key: Variant in dictionary.keys():
		var parsed_key: Variant = refcounted_to_value(key, dictionary.is_typed())
		var parsed_value: Variant = refcounted_to_value(dictionary.get(key), dictionary.is_typed())
		json_dictionary.set(parsed_key, parsed_value)
	return json_dictionary
#endregion

## Helper function to turn a refCount into parsable value.
static func refcounted_to_value(variant_value: Variant, is_typed: bool = false) -> Variant:
		if variant_value is Object:
			return class_to_json(variant_value, save_temp_resources_tres, !is_typed)
		elif variant_value is Array:
			return convert_array_to_json(variant_value)
		elif variant_value is Dictionary:
			return convert_dictionary_to_json(variant_value)
		else:
			return variant_value
