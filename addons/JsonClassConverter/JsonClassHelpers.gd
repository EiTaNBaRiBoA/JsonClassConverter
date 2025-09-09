@abstract class_name JsonClassHelpers extends JsonClassConverterBase

#region Class to json
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
			if "script_inheritance" in json_key:
				key_script = _get_gdscript(json_key["script_inheritance"])
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
			if "script_inheritance" in json_value:
				value_script = _get_gdscript(json_value["script_inheritance"])
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
			if "script_inheritance" in element:
				cast_class = _get_gdscript(element["script_inheritance"])
			godot_array.append(JsonClassConverter.json_to_class(cast_class, element))
		elif typeof(element) == TYPE_ARRAY:
			godot_array.append(convert_json_to_array(element))
		else:
			godot_array.append(element)
	return godot_array

#endregion
