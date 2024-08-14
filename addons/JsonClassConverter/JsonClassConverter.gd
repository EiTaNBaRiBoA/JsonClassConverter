class_name JsonClassConverter

## Checks cast class
static func _check_cast_class(castClass: GDScript) -> bool:
	if typeof(castClass) == Variant.Type.TYPE_NIL:
		printerr("the passing cast is null")
		return false
	return true

## Checks if dir exists
static func check_dir(path: String) -> void:
	if !DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)

#region Json to Class

## Load json to class from a file
static func load_json_file(castClass: GDScript, file_name: String, dir: String, security_key: String = "") -> Object:
	if not _check_cast_class(castClass):
		printerr("the passing cast is null")
		return null
	check_dir(dir)
	var file: FileAccess
	if FileAccess.file_exists(dir + file_name):
		if security_key.length() == 0:
			file = FileAccess.open(dir + file_name, FileAccess.READ)
		else:
			file = FileAccess.open_encrypted_with_pass(dir + file_name, FileAccess.READ, security_key)
		if not file:
			return castClass.new()
		var parsed_results: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed_results is Dictionary or parsed_results is Array:
			return json_to_class(castClass, parsed_results)
	return castClass.new()

## Convert a JSON string to class
static func json_string_to_class(castClass: GDScript, json_string: String) -> Object:
	if not _check_cast_class(castClass):
		printerr("the passing cast is null")
		return null
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result == Error.OK:
		return json_to_class(castClass, json.data)
	return castClass.new()

## Convert a JSON dictionary into a class
static func json_to_class(castClass: GDScript, json: Dictionary) -> Object:
	var _class: Object = castClass.new() as Object
	var properties: Array = _class.get_property_list()

	for key: String in json.keys(): # Typed loop variable 'key'
		for property: Dictionary in properties: # Typed loop variable 'property'
			if property.name == "script":
				continue
			var property_value: Variant = _class.get(property.name)
			var value: Variant = json[key]
			if property.name == key and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE:
				if property_value is not Array and property.type == TYPE_OBJECT:
					var inner_class_path: String = ""
					if property_value:
						for inner_property: Dictionary in property_value.get_property_list(): # Typed loop variable 'inner_property'
							if inner_property.has("hint_string") and inner_property["hint_string"].contains(".gd"):
								inner_class_path = inner_property["hint_string"]
						_class.set(property.name, json_to_class(load(inner_class_path), json[key])) ## loading class
				elif property_value is Array:
					if property.has("hint_string"):
						var class_hint: String = property["hint_string"]
						if class_hint.contains(":"):
							class_hint = class_hint.split(":")[1] # Assuming format "24/34:Class"
						for obj_array: Variant in convert_json_to_array(value, get_gdscript(class_hint)):
							_class.get(property.name).append(obj_array)
				else:
					_class.set(property.name, json[key])
	return _class

static func get_gdscript(hint_class: String) -> GDScript:
	for className: Dictionary in ProjectSettings.get_global_class_list():
		if className.class == hint_class:
			return load(className.path)
	return null
	
# Helper function to recursively convert JSON arrays to Godot arrays
static func convert_json_to_array(json_array: Array, cast_class: GDScript = null) -> Array:
	var godot_array: Array = []
	for element: Variant in json_array: # element's type is inferred to be Variant
		if typeof(element) == TYPE_DICTIONARY:
			if cast_class == null:
				cast_class = get_gdscript(element["ScriptName"])
			godot_array.append(json_to_class(cast_class, element))
		elif typeof(element) == TYPE_ARRAY:
			godot_array.append(convert_json_to_array(element))
		else:
			godot_array.append(element)
	return godot_array

#endregion

#region Class to Json
##Stores json to a file, returns if success
static func store_json_file(file_name: String, dir: String, data: Dictionary, security_key: String = "") -> bool:
	check_dir(dir)
	var file: FileAccess
	if security_key.length() == 0:
		file = FileAccess.open(dir + file_name, FileAccess.WRITE)
	else:
		file = FileAccess.open_encrypted_with_pass(dir + file_name, FileAccess.WRITE, security_key)
	if not file:
		printerr("Error writing to a file")
		return false
	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true

## Convert a class into JSON string
static func class_to_json_string(_class: Object) -> String:
	return JSON.stringify(class_to_json(_class))

## Convert class to JSON dictionary
static func class_to_json(_class: Object) -> Dictionary:
	var dictionary: Dictionary = {}
	dictionary["ScriptName"] = _class.get_script().get_global_name()
	var properties: Array = _class.get_property_list()
	for property: Dictionary in properties: # Typed loop variable 'property'
		var property_name: String = property["name"]
		if property_name == "script":
			continue
		var property_value: Variant = _class.get(property_name)
		if not property_name.is_empty() and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE:
			if property_value is Array:
				dictionary[property_name] = convert_array_to_json(property_value)
			elif property_value is Dictionary:
				dictionary[property_name] = convert_dictionary_to_json(property_value)
			elif property["type"] == TYPE_OBJECT and property_value != null and property_value.get_property_list():
				dictionary[property.name] = class_to_json(property_value)
			else:
				dictionary[property.name] = property_value
	return dictionary

# Helper function to recursively convert arrays
static func convert_array_to_json(array: Array) -> Array:
	var json_array: Array = []
	for element: Variant in array: # element's type is inferred to be Variant
		if element is Object:
			json_array.append(class_to_json(element))
		elif element is Array:
			json_array.append(convert_array_to_json(element))
		elif element is Dictionary:
			json_array.append(convert_dictionary_to_json(element))
		else:
			json_array.append(element)
	return json_array

# Helper function to recursively convert dictionaries
static func convert_dictionary_to_json(dictionary: Dictionary) -> Dictionary:
	var json_dictionary: Dictionary = {}
	for key: Variant in dictionary.keys(): # key's type is inferred to be Variant
		var value: Variant = dictionary[key]
		if value is Object:
			json_dictionary[key] = class_to_json(value)
		elif value is Array:
			json_dictionary[key] = convert_array_to_json(value)
		elif value is Dictionary:
			json_dictionary[key] = convert_dictionary_to_json(value)
		else:
			json_dictionary[key] = value
	return json_dictionary
#endregion
