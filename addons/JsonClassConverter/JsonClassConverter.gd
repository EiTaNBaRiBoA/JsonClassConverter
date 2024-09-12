class_name JsonClassConverter

static var save_temp_resources_tres: bool = false

## Checks cast class
static func _check_cast_class(castClass: GDScript) -> bool:
	if typeof(castClass) == Variant.Type.TYPE_NIL:
		printerr("the passing cast is null")
		return false
	return true

## Checks if dir exists
static func check_dir(file_path: String) -> void:
	if !DirAccess.dir_exists_absolute(file_path.get_base_dir()):
		DirAccess.make_dir_absolute(file_path.get_base_dir())

#region Json to Class

static func json_file_to_dict(file_path: String, security_key: String = "") -> Dictionary:
	var file: FileAccess
	if FileAccess.file_exists(file_path):
		if security_key.length() == 0:
			file = FileAccess.open(file_path, FileAccess.READ)
		else:
			file = FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, security_key)
		if not file:
			return {}
		var parsed_results: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed_results is Dictionary or parsed_results is Array:
			return parsed_results
	return {}

## Load json to class from a file
static func json_file_to_class(castClass: GDScript, file_path: String, security_key: String = "") -> Object:
	if not _check_cast_class(castClass):
		printerr("the passing cast is null")
		return null
	var parsed_results = json_file_to_dict(file_path, security_key)
	if parsed_results == null:
		return castClass.new()
	return json_to_class(castClass, parsed_results)

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
		var value: Variant = json[key]
		if type_string(typeof(value)) == "String" and value.begins_with("Vector"):
			value = str_to_var(value)
		for property: Dictionary in properties: # Typed loop variable 'property'
			if property.name == "script":
				continue
			var property_value: Variant = _class.get(property.name)
			if property.name == key and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE:
				if not property_value is Array and property.type == TYPE_OBJECT:
					var inner_class_path: String = ""
					if property_value:
						for inner_property: Dictionary in property_value.get_property_list(): # Typed loop variable 'inner_property'
							if inner_property.has("hint_string") and inner_property["hint_string"].contains(".gd"):
								inner_class_path = inner_property["hint_string"]
						_class.set(property.name, json_to_class(load(inner_class_path), value)) ## loading class
					elif value:
						var script_type: GDScript = null
						if value is Dictionary and value.has("ScriptName"):
							script_type = get_gdscript(value.ScriptName)
						else:
							script_type = get_gdscript(property. class_name )
						if value is String and value.is_absolute_path():
							_class.set(property.name, ResourceLoader.load(get_main_tres_path(value)))
						else:
							_class.set(property.name, json_to_class(script_type, value))
				elif property_value is Array:
					if property.has("hint_string"):
						var class_hint: String = property["hint_string"]
						if class_hint.contains(":"):
							class_hint = class_hint.split(":")[1] # Assuming format "24/34:Class"
						
						var arrayTemp: Array = convert_json_to_array(value, get_gdscript(class_hint))
						if type_string(property_value.get_typed_builtin()).begins_with("Vector"):
							for obj_array: Variant in arrayTemp:
								_class.get(property.name).append(str_to_var(obj_array))
						else:
							_class.get(property.name).assign(arrayTemp)
				else:
					# Edge case where the property type is color but , it doesn't have Vector in it's name
					if property.type == TYPE_COLOR:
						value = Color(value)
					_class.set(property.name, value)
	return _class

static func get_gdscript(hint_class: String) -> GDScript:
	for className: Dictionary in ProjectSettings.get_global_class_list():
		if className. class == hint_class:
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

## Convert a class into JSON string , save_temp_res for saving in user:// a temp resources tres as gd
static func class_to_json_string(_class: Object, save_temp_res: bool = false) -> String:
	return JSON.stringify(class_to_json(_class, save_temp_res))

## Convert class to JSON dictionary , save_temp_res for saving in user:// a temp resources tres else saved as gd
static func class_to_json(_class: Object, save_temp_res: bool = false) -> Dictionary:
	var dictionary: Dictionary = {}
	save_temp_resources_tres = save_temp_res
	dictionary["ScriptName"] = _class.get_script().get_global_name()
	var properties: Array = _class.get_property_list()
	for property: Dictionary in properties: # Typed loop variable 'property'
		var property_name: String = property["name"]
		if property_name == "script":
			continue
		var property_value: Variant = _class.get(property_name)
		if not property_name.is_empty() and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE > 0:
			if property_value is Array:
				dictionary[property_name] = convert_array_to_json(property_value)
			elif property_value is Dictionary:
				dictionary[property_name] = convert_dictionary_to_json(property_value)
			elif property["type"] == TYPE_OBJECT and property_value != null and property_value.get_property_list():
				if property_value is Resource and ResourceLoader.exists(property_value.resource_path):
					var main_src: String = get_main_tres_path(property_value.resource_path)
					if main_src.get_extension() != "tres":
						dictionary[property.name] = property_value.resource_path
					elif save_temp_resources_tres:
						# Creating a tempfile to avoid overriding the main resource
						var tempfile = "user://temp_resource/"
						# Creating a temp path for taking the node path
						var nodePath: String = get_node_tres_path(property_value.resource_path)
						if not nodePath.is_empty():
							tempfile += nodePath
						else:
							tempfile += get_main_tres_path(property_value.resource_path)
						tempfile += ".tres"
						dictionary[property.name] = tempfile
						ResourceSaver.save(property_value, tempfile)
					else:
						dictionary[property.name] = class_to_json(property_value, save_temp_resources_tres)
				else:
					dictionary[property.name] = class_to_json(property_value, save_temp_resources_tres)
			elif type_string(typeof(property_value)).begins_with("Vector"):
				dictionary[property_name] = var_to_str(property_value)
			elif property["type"] == TYPE_COLOR:
				dictionary[property_name] = property_value.to_html()
			else:
				dictionary[property.name] = property_value
	return dictionary

## returns main path of the resource
static func get_main_tres_path(path: String) -> String:
	var path_parts: PackedStringArray = path.split("::", true, 1)
	if path_parts.size() > 0:
		return path_parts[0]
	else:
		return path

## returns node path of the resource
static func get_node_tres_path(path: String) -> String:
	var path_parts: PackedStringArray = path.split("::", true, 1)
	if path_parts.size() > 1:
		return path_parts[1]
	else:
		return ""


# Helper function to recursively convert arrays
static func convert_array_to_json(array: Array) -> Array:
	var json_array: Array = []
	for element: Variant in array: # element's type is inferred to be Variant
		if element is Object:
			json_array.append(class_to_json(element, save_temp_resources_tres))
		elif element is Array:
			json_array.append(convert_array_to_json(element))
		elif element is Dictionary:
			json_array.append(convert_dictionary_to_json(element))
		elif type_string(typeof(element)).begins_with("Vector"):
			json_array.append(var_to_str(element))
		else:
			json_array.append(element)
	return json_array

# Helper function to recursively convert dictionaries
static func convert_dictionary_to_json(dictionary: Dictionary) -> Dictionary:
	var json_dictionary: Dictionary = {}
	for key: Variant in dictionary.keys(): # key's type is inferred to be Variant
		var value: Variant = dictionary[key]
		if value is Object:
			json_dictionary[key] = class_to_json(value, save_temp_resources_tres)
		elif value is Array:
			json_dictionary[key] = convert_array_to_json(value)
		elif value is Dictionary:
			json_dictionary[key] = convert_dictionary_to_json(value)
		else:
			json_dictionary[key] = value
	return json_dictionary
#endregion
