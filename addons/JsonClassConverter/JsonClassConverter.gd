@abstract class_name JsonClassConverter extends JsonClassConverterBase


#region Class to Json

## Stores a JSON dictionary to a file, optionally with encryption.
static func store_json_file(file_path: String, data: Dictionary, security_key: String = "") -> bool:
	_check_dir(file_path)
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
static func class_to_json_string(_class: Object) -> String:
	return JSON.stringify(class_to_json(_class))

## Converts a Godot class instance into a JSON dictionary, specify_class for manual class specifying (true under inheritance).
## This is the core serialization function.
static func class_to_json(_class: Object, specify_class: bool = false) -> Dictionary:
	var dictionary: Dictionary = {}
	# Store the script name for reference during deserialization if inheritance exists
	if specify_class:
		dictionary.set(SCRIPT_INHERITANCE, _class.get_script().get_global_name())
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
				dictionary[property_name] = JsonClassHelpers.convert_array_to_json(property_value)
			elif property_value is Dictionary:
				# Recursively convert dictionaries to JSON
				dictionary[property_name] = JsonClassHelpers.convert_dictionary_to_json(property_value)
			# If the property is a Resource:
			elif property["type"] == TYPE_OBJECT and property_value != null and property_value.get_property_list():
				if property_value is Resource and ResourceLoader.exists(property_value.resource_path):
					var main_src: String = _get_main_tres_path(property_value.resource_path)
					if main_src.get_extension() != "tres":
						# Store the resource path if it's not a .tres file
						dictionary[property.name] = property_value.resource_path
					else:
						# Recursively serialize the nested resource
						dictionary[property.name] = class_to_json(property_value)
				else:
					dictionary[property.name] = class_to_json(property_value, property.class_name != property_value.get_script().get_global_name())
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

#endregion


#region Json to Class

## Loads a JSON file and converts its contents into a Godot class instance.
## Uses the provided GDScript (castClass) as a template for the class.
static func json_file_to_class(castClass: GDScript, file_path: String, security_key: String = "") -> Object:
	if not _check_cast_class(castClass):
		printerr("The provided class is null.")
		return null
	var parsed_results = json_file_to_dict(file_path, security_key)
	if parsed_results.is_empty():
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


## Converts a JSON dictionary into a Godot class instance.
## This is the core deserialization function.
static func json_to_class(castClass: GDScript, json: Dictionary) -> Object:
	# Create an instance of the target class
	var is_null_script_and_is_object: bool = false
	var _class: Object = null
	## Passing null as a casted class
	if castClass == null:
		var script_name: String = json.get(SCRIPT_INHERITANCE, null)
		# Looking for the script
		if script_name != null:
			var script_type: GDScript = _get_gdscript(script_name)
			if script_type != null:
				_class = script_type.new() as Object
			# creating an object with attributes
			else:
				_class = Object.new()
				is_null_script_and_is_object = true
	# Creating an class object
	else:
		_class = castClass.new() as Object
	var properties: Array = _class.get_property_list()
	
	# Iterate through each key-value pair in the JSON dictionary
	for key: String in json.keys():
		var value: Variant = json[key]
		
		# Special handling for Vector types (stored as strings in JSON)
		if type_string(typeof(value)) == "String" and value.begins_with("Vector"):
			value = str_to_var(value)
			
		if not is_null_script_and_is_object:
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
							if value is Dictionary and value.has(SCRIPT_INHERITANCE):
								script_type = _get_gdscript(value.get(SCRIPT_INHERITANCE))
							else:
								script_type = _get_gdscript(property.class_name )
								
							# If the value is a resource path, load the resource
							if value is String and value.is_absolute_path():
								_class.set(property.name, ResourceLoader.load(_get_main_tres_path(value)))
							else:
								# Recursively deserialize nested objects
								_class.set(property.name, json_to_class(script_type, value))
								
					# Case 2: Property is an Array
					elif property_value is Array:
						var arr_script: GDScript = null
						if property_value.is_typed() and property_value.get_typed_script():
							arr_script = load(property_value.get_typed_script().get_path())
							# Recursively convert the JSON array to a Godot array
						var arrayTemp: Array = JsonClassHelpers.convert_json_to_array(value, arr_script)
							
							# Handle Vector arrays (convert string elements back to Vectors)
						if type_string(property_value.get_typed_builtin()).begins_with("Vector"):
							for obj_array: Variant in arrayTemp:
								_class.get(property.name).append(str_to_var(type_string(property_value.get_typed_builtin()) + obj_array))
						else:
							_class.get(property.name).assign(arrayTemp)
					# Case 3: Property is a Typed Dictionary
					elif property_value is Dictionary and property_value.is_typed():
						JsonClassHelpers.convert_json_to_dictionary(property_value, value)
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
		else:
			if value is Dictionary:
				## Trying to cast to object or class
				_class.set(key, json_to_class(_get_gdscript(value.get(SCRIPT_INHERITANCE)), value))
			elif value is String and value.is_absolute_path():
				_class.set(key, ResourceLoader.load(_get_main_tres_path(value)))
			elif value is Array:
				_class.set(key, JsonClassHelpers.convert_json_to_array(value))
			else:
				_class.set(key, value)
	# Return the fully deserialized class instance
	return _class

#endregion


#region Json Utilties
## Checks if two jsons are equal, can recieve json string, file path , dictionary
static func check_equal_json_files(first_json: Variant, second_json: Variant) -> bool:
	if _get_dict_from_type(first_json).hash() == _get_dict_from_type(second_json).hash():
		return true
	return false

## finds between two jsons the diff and returns the diff dictionary showing old value and new value
static func compare_jsons_diff(first_json: Variant, second_json: Variant) -> Dictionary:
	var first_dict: Dictionary = _get_dict_from_type(first_json)
	var second_dict: Dictionary = _get_dict_from_type(second_json)
	if check_equal_json_files(first_dict, second_dict):
		return {}
	return _compare_recursive(first_dict, second_dict)

## operations between two json from and to differences between one json to the other json
static func json_operation(from_json: Variant, json_ref: Variant, operation_type: Operation) -> Dictionary:
	var first_dict: Dictionary = _get_dict_from_type(from_json)
	var second_dict: Dictionary = _get_dict_from_type(json_ref)
	if check_equal_json_files(first_dict, second_dict) && operation_type != Operation.Add:
		if operation_type == Operation.Replace:
			return first_dict
		else:
			return {}
	return JsonClassHelpers._apply_keys_recursively(operation_type, first_dict, second_dict)


enum Operation {
	Add, AddDiffer, Replace, Remove, RemoveValue
}

#endregion
