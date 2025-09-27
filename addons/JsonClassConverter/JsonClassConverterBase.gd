@abstract class_name JsonClassConverterBase

const SCRIPT_INHERITANCE = "script_inheritance"

#region Checks and Gets

## Checks if the directory for the given file path exists, creating it if necessary.
static func _check_dir(file_path: String) -> void:
	if !DirAccess.dir_exists_absolute(file_path.get_base_dir()):
		DirAccess.make_dir_absolute(file_path.get_base_dir())

## Checks if the provided class is valid (not null)
static func _check_cast_class(castClass: GDScript) -> bool:
	if typeof(castClass) == Variant.Type.TYPE_NIL:
		printerr("The provided class is null.")
		return false
	return true

## Helper function to find a GDScript by its class name.
static func _get_gdscript(hint_class: String) -> GDScript:
	for className: Dictionary in ProjectSettings.get_global_class_list():
		if className.class == hint_class:
			return load(className.path)
	return null

## Extracts the main path from a resource path (removes node path if present).
static func _get_main_tres_path(path: String) -> String:
	var path_parts: PackedStringArray = path.split("::", true, 1)
	if path_parts.size() > 0:
		return path_parts[0]
	else:
		return path

## Get's a dictionary from a given string or dictionary if it is a path or dictionary or string
static func _get_dict_from_type(json: Variant) -> Dictionary:
	var dict: Dictionary = {}
	if json is Dictionary:
		dict = json
	elif json is Object:
		dict = JsonClassConverter.class_to_json(json)
	else:
		var result = JSON.parse_string(json)
		if result == null:
			#first_json is not a file json string , loading it from path
			dict = JsonClassConverter.json_file_to_dict(json)
		else:
			dict = result
	return dict

#endregion

#region Converters

#region Class to Json

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

## Helper function to turn a refCount into parsable value.
static func refcounted_to_value(variant_value: Variant, is_typed: bool = false) -> Variant:
		if variant_value is Object:
			return JsonClassConverter.class_to_json(variant_value, !is_typed)
		elif variant_value is Array:
			return convert_array_to_json(variant_value)
		elif variant_value is Dictionary:
			return convert_dictionary_to_json(variant_value)
		else:
			return variant_value

#endregion

#region Json to Class

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
			if SCRIPT_INHERITANCE in json_key:
				key_script = _get_gdscript(json_key.get(SCRIPT_INHERITANCE))
			else:
				key_script = load(propert_value.get_typed_key_script().get_path())
			key_obj = JsonClassConverter.json_to_class(key_script, json_key)
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
			if SCRIPT_INHERITANCE in json_value:
				value_script = _get_gdscript(json_value.get(SCRIPT_INHERITANCE))
			else:
				value_script = load(propert_value.get_typed_value_script().get_path())
			value_obj = JsonClassConverter.json_to_class(value_script, json_value)
		elif typeof(json_value) == TYPE_ARRAY:
			value_obj = convert_json_to_array(json_value)
		elif typeof(json_value) == TYPE_BOOL or typeof(json_value) == TYPE_INT or typeof(json_value) == TYPE_FLOAT:
			value_obj = json_value
		else:
			value_obj = str_to_var(json_value)
			if !value_obj: # if null revert to json key
				value_obj = json_value
		propert_value.set(key_obj, value_obj)

## Helper function to recursively convert JSON arrays to Godot arrays.
static func convert_json_to_array(json_array: Array, cast_class: GDScript = null) -> Array:
	var godot_array: Array = []
	for element: Variant in json_array:
		if typeof(element) == TYPE_DICTIONARY:
			# If json element has a script_inheritance, get the script (for inheritance or for untyped array/dictionary)
			if SCRIPT_INHERITANCE in element:
				cast_class = _get_gdscript(element.get(SCRIPT_INHERITANCE))
			godot_array.append(JsonClassConverter.json_to_class(cast_class, element))
		elif typeof(element) == TYPE_ARRAY:
			godot_array.append(convert_json_to_array(element))
		else:
			godot_array.append(element)
	return godot_array

#endregion

#endregion


#region Json Utilties
## Defines the types of operations that can be performed on the data structures.
enum Operation {
	Add, # Adds values. If key exists, combines them into an array.
	AddDiffer, # Adds or merges values only if they are different.
	Replace, # Replaces values in the base structure with values from the reference.
	Remove, # Removes keys/values present in the reference structure from the base.
	RemoveValue # Removes keys/values only if their values match the reference.
}
#endregion
