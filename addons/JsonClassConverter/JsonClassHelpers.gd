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

## Recursively applies an operation to a variant. Dispatches to dictionary/array handlers.
static func _apply_operation_recursively(base_var: Variant, ref_var: Variant, op_type: Operation) -> Variant:
	if ref_var is Dictionary and base_var is Dictionary:
		return _process_dictionary(base_var, ref_var, op_type)
	elif ref_var is Array and base_var is Array:
		return _process_array(base_var, ref_var, op_type)
	else:
		# Handle primitives or type mismatches
		return _process_primitive(base_var, ref_var, op_type)


## Handles the recursive operation logic for Dictionaries.
static func _process_dictionary(base_dict: Dictionary, ref_dict: Dictionary, op_type: Operation) -> Dictionary:
	for key in ref_dict:
		var ref_value = ref_dict[key]
		
		if base_dict.has(key):
			var base_value = base_dict[key]
			var result = _apply_operation_recursively(base_value, ref_value, op_type)
			
			# For remove operations, a null result signifies deletion.
			if result == null and (op_type == Operation.Remove or op_type == Operation.RemoveValue):
				base_dict.erase(key)
			else:
				base_dict[key] = result
		
		# If the key doesn't exist in base, add it (for relevant operations).
		elif op_type == Operation.Add or op_type == Operation.AddDiffer or op_type == Operation.Replace:
			base_dict[key] = ref_value
			
	return base_dict


## Handles the recursive operation logic for Arrays.
static func _process_array(base_arr: Array, ref_arr: Array, op_type: Operation) -> Array:
	match op_type:
		Operation.Add, Operation.AddDiffer:
			for item in ref_arr:
				if not base_arr.has(item):
					base_arr.append(item)
			return base_arr
		
		Operation.Replace:
			# Replacing an array means returning the reference array.
			return ref_arr
			
		Operation.Remove, Operation.RemoveValue:
			# Filter the base array, keeping only items NOT in the reference array.
			var new_arr: Array = []
			for item in base_arr:
				if not ref_arr.has(item):
					new_arr.append(item)
			return new_arr
			
	return base_arr


## Handles the operation logic for primitive values.
static func _process_primitive(base_val: Variant, ref_val: Variant, op_type: Operation) -> Variant:
	match op_type:
		Operation.Add:
			return [base_val, ref_val]
		Operation.AddDiffer:
			return base_val if base_val == ref_val else [base_val, ref_val]
		Operation.Replace:
			return ref_val
		Operation.Remove:
			# A null return signals to the dictionary processor to erase the key.
			return null
		Operation.RemoveValue:
			return null if base_val == ref_val else base_val
	return base_val


## Helper to safely get a Dictionary from a Variant (JSON string or Dictionary).
static func _get_dict_from_type(data: Variant) -> Dictionary:
	if data is Dictionary:
		return data
	if data is String:
		var json = JSON.parse_string(data)
		if json is Dictionary:
			return json
	return {}
