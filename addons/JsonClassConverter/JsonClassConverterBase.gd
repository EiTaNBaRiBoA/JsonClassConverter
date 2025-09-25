@abstract class_name JsonClassConverterBase

const SCRIPT_INHERITANCE = "script_inheritance"

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


static func _valid_json_type(json: Variant) -> bool:
	if json is String or json is Dictionary:
		return true
	else:
		printerr("Invalid first_json json dictionary or file path")
		return false

## Get's a dictionary from a given string or dictionary if it is a path or dictionary or string
static func _get_dict_from_type(json: Variant) -> Dictionary:
	var dict: Dictionary = {}
	if (_valid_json_type(json)):
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

# Internal recursive function to perform the comparison.
static func _compare_recursive(a: Variant, b: Variant) -> Dictionary:
	# If the types are different, they are not equal. Return the change.
	if typeof(a) != typeof(b):
		return {"old": a, "new": b}
	# Handle comparison based on the type of the variables.
	match typeof(a):
		TYPE_DICTIONARY:
			return JsonClassHelpers._compare_dictionaries(a, b)
		TYPE_ARRAY:
			return JsonClassHelpers._compare_arrays(a, b)
		_:
			# For all other primitive types (int, float, bool, string, null).
			if a != b:
				return {"old": a, "new": b}
			else:
				# They are identical, so there is no difference.
				return {}
