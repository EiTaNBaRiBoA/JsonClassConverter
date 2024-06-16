class_name JsonClassConverter

## Checks cast class
static func _check_cast_class(castClass : GDScript) -> bool:
	if typeof(castClass) == Variant.Type.TYPE_NIL:
		printerr("the passing cast is null")
		return false
	return true



## Checks if dir exists
static func check_dir(path: String) -> void:
	if !DirAccess.dir_exists_absolute(path): DirAccess.make_dir_absolute(path)


#region Json to Class

## Load json to class from a file
static func load_json_file(castClass : GDScript ,file_name: String, dir : String, security_key : String = "") -> Object:
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
		var parsedResults = JSON.parse_string(file.get_as_text())
		file.close()
		if parsedResults is Dictionary or parsedResults is Array:
			return json_to_class(castClass, parsedResults)
	return castClass.new()



## Convert a JSON string to class
static func json_string_to_class(castClass : GDScript , json_string: String) -> Object:
	if not _check_cast_class(castClass): 
		printerr("the passing cast is null")
		return null
	var json = JSON.new()
	var parse_result: Error = json.parse_string(json_string)
	if parse_result == Error.OK:
		return json_to_class(castClass,json.data)
	return castClass.new()


## Convert a JSON dictionary into a class
static func json_to_class(castClass : GDScript, json: Dictionary) -> Object:
	var _class = castClass.new()
	var properties: Array = _class.get_property_list()
	for key in json.keys():
		for property in properties:
			if property.name == "script": continue
			if property.name == key and property.usage >= PropertyUsageFlags.PROPERTY_USAGE_SCRIPT_VARIABLE:
				if (property["class_name"] in ["Reference", "Object"] and property["type"] == 17):
					_class.set(key, json_to_class(json[key], _class.get(key)))
				else:
					_class.set(key, json[key])
				break
			if key == property.hint_string and property.usage >= PropertyUsageFlags.PROPERTY_USAGE_SCRIPT_VARIABLE:
				if (property["class_name"] in ["Reference", "Object"] and property["type"] == 17):
					_class.set(property.name, json_to_class(json[key], _class.get(key)))
				else:
					_class.set(property.name, json[key])
				break
	return _class

#endregion

#region Class to Json
##Stores json to a file, returns if success
static func store_json_file( file_name: String,dir : String, data : Dictionary , security_key : String = "") -> bool: # # The task that is under focus
	check_dir(dir)
	var file: FileAccess
	if security_key.length() == 0:
		file = FileAccess.open(dir + file_name, FileAccess.WRITE)
	else:
		file = FileAccess.open_encrypted_with_pass(dir + file_name, FileAccess.WRITE, security_key)
	## on restore if app is closed this will give the focusing task index to set in the dropdown and the focustype  
	if not file:
		printerr("Error writing to a file")
		return false
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true

## Convert a class into JSON string
static func class_to_json_string(_class: Object) -> String:
	return JSON.stringify(class_to_json(_class))


## Convert class to JSON dictionary
static func class_to_json(_class: Object) -> Dictionary:
	var dictionary: Dictionary = {}
	var properties: Array = _class.get_property_list()
	for property in properties:
		var property_name = property["name"]
		if property_name == "script": continue
		var property_value = _class.get(property_name)
		if not property_name.is_empty() and property.usage >= PropertyUsageFlags.PROPERTY_USAGE_SCRIPT_VARIABLE:
			
			if (property["class_name"] in ["Reference", "Object"] and property["type"] == 17):
				dictionary[property.name] = class_to_json(property_value)
			elif property_value is Array:
				# Handle arrays by recursively converting elements if necessary
				dictionary[property_name] = convert_array_to_json(property_value)
			else:
				dictionary[property.name] = property_value
		elif not property["hint_string"].is_empty() and property.usage >= PropertyUsageFlags.PROPERTY_USAGE_SCRIPT_VARIABLE:
			if (property["class_name"] in ["Reference", "Object"] and property["type"] == 17):
				dictionary[property.hint_string] = class_to_json(property_value)
			else:
				dictionary[property.hint_string] = property_value
	return dictionary
# Helper function to recursively convert arrays
static func convert_array_to_json(array: Array) -> Array:
	var json_array: Array = []
	for element in array:
		if element is Object:
			json_array.append(class_to_json(element))
		elif element is Array:
			json_array.append(convert_array_to_json(element)) # Recursive call for nested arrays
		else:
			json_array.append(element) 
	return json_array
#endregion
