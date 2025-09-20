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


#region Comparison Helper
# Compares two dictionaries.
static func _compare_dictionaries(a: Dictionary, b: Dictionary) -> Dictionary:
	var diff: Dictionary = {}
	var all_keys: Array = a.keys()
	for key in b.keys():
		if not all_keys.has(key):
			all_keys.append(key)
	for key in all_keys:
		var key_in_a: bool = a.has(key)
		var key_in_b: bool = b.has(key)

		if key_in_a and not key_in_b:
			# Key was removed in 'b'.
			diff[key] = {"old": a[key], "new": null}
		elif not key_in_a and key_in_b:
			# Key was added in 'b'.
			diff[key] = {"old": null, "new": b[key]}
		else:
			# Key exists in both, so we recurse to compare their values.
			var result: Dictionary = _compare_recursive(a[key], b[key])
			if not result.is_empty():
				# If the recursive comparison found a difference, add it to our diff report.
				diff[key] = result
	return diff


# Compares two arrays.
static func _compare_arrays(a: Array, b: Array) -> Dictionary:
	# This correctly handles nested structures within the arrays.
	if JSON.stringify(a) != JSON.stringify(b):
		return {"old": a, "new": b}
	# The arrays are identical.
	return {}
	
#endregion


#region Operation Helpers

# removes keys from json_modify using the json_ref as a reference
static func _apply_keys_recursively(operation_type: JsonClassConverter.Operation, json_modify: Variant, json_ref: Variant) -> Variant:
# We determine the type of the data to process it accordingly.
	if json_ref is Dictionary:
		# Iterate over a copy of the keys, as we will be modifying the
		# dictionary during the loop, which is not safe otherwise.
		for key in json_ref.keys():
			# Check if the key exists in the dictionary of keys to remove.
			if json_modify.has(key):
				if (operation_type == JsonClassConverter.Operation.RemoveValue):
					if (operation_key_value(operation_type, json_modify, key, json_modify[key], json_ref[key])):
						continue
					else:
						# If the key was not erased (either because the key didn't match the removal dict,
						# or the key matched but the value didn't), we recurse into the value.
						operation_key_value(operation_type, json_modify, key, json_modify[key], _apply_keys_recursively(operation_type, json_modify[key], json_ref[key]))
				else: # remove , replace , add (for add and replace we need recursive if they are the same value key)
					operation_key_value(operation_type, json_modify, key, json_modify[key], json_ref[key])
			else:
				# Adding new key to json_modify
				operation_key_value(operation_type, json_modify, key, null, json_ref[key])
	elif json_ref is Array:
		if json_modify is not Array:
			return json_ref
		# If the data is an array, we simply recurse into each of its elements.
		for i in json_ref:
			var new_value = _apply_keys_recursively(operation_type, json_modify[i], json_ref[i])
			match operation_type:
				JsonClassConverter.Operation.Remove || JsonClassConverter.Operation.RemoveValue:
					if new_value == null:
						json_modify.remove_at(i)
				_:
					json_modify[i] = new_value
	else: # not object or array or dict than primitive
		return operation_values(operation_type, json_modify, json_ref)
	return json_modify

## Works on dictionaries only
static func operation_key_value(operation_type: JsonClassConverter.Operation, json_modify: Variant, key: Variant, old_value: Variant, new_value: Variant) -> bool:
	match operation_type:
		JsonClassConverter.Operation.Add:
			if old_value is Array:
				old_value.append(new_value)
				return true
			elif old_value != null:
				json_modify[key] = [old_value, new_value]
				return true
			else:
				json_modify[key] = new_value
				return true
		JsonClassConverter.Operation.Replace:
				if (old_value == new_value):
					return false # same value to the key nothing to replace
				else:
					json_modify[key] = new_value
					return true # successfully replaced the value of a key
		JsonClassConverter.Operation.Remove:
			json_modify.erase(key)
		JsonClassConverter.Operation.RemoveValue:
			if (old_value == new_value):
				json_modify.erase(key)
				return true # success removed the key
			elif new_value == null:
				json_modify.erase(key)
				 # if we want to remove a key by a specific value null specifically 
				 # "test" : 1 , we pass "test" : null and it will delete the key
				return true
			else:
				return false # not same values
	return false # couldn't complete operation
#endregion

## Works on primitives only
static func operation_values(operation_type: JsonClassConverter.Operation, old_value: Variant, new_value: Variant) -> Variant:
	match operation_type:
		JsonClassConverter.Operation.Add:
			return [old_value, new_value]
		JsonClassConverter.Operation.Replace:
			return new_value
		JsonClassConverter.Operation.Remove:
			return null # later using operationtype we could remove the key
		JsonClassConverter.Operation.RemoveValue:
			if (old_value == new_value):
				return null
				 # if we want to remove a key by a specific value null specifically 
				 # "test" : 1 , we pass "test" : null and it will delete the key
			else:
				return old_value
	return old_value # couldn't complete operation
