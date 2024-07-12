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
	var parse_result: Error = json.parse(json_string)
	if parse_result == Error.OK:
		return json_to_class(castClass,json.data)
	return castClass.new()


## Convert a JSON dictionary into a class
static func json_to_class(castClass : GDScript, json: Dictionary) -> Object:
	var _class = castClass.new()
	var properties: Array = _class.get_property_list()

	for key in json.keys():
		for property in properties:
			if property.name == "script": 
				continue
			var property_value = _class.get(property.name)
			var value = json[key]
			if property.name == key and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE:
				if (property["class_name"] in ["Reference", "Object"] and property["type"] == TYPE_OBJECT):
					_class.set(property.name, json_to_class(load(property["class_name"]),json[key]))
				elif property_value is not Array and property.type == TYPE_OBJECT:
					var innerClassPath : String = ""
					for innerProperty in property_value.get_property_list():
						if innerProperty.has("hint_string") and innerProperty["hint_string"].contains(".gd"):
							innerClassPath = innerProperty["hint_string"]
					_class.set(property.name, json_to_class(load(innerClassPath),json[key])) ## loading class
				elif property_value is Array:
					if property.has("hint_string"):
						var classHint = property["hint_string"]
						if classHint.contains(":"):
							classHint = classHint.split(":")[1] # Assuming format "24/34:Class"
						for obj in convert_json_to_array(value,getGDScript(classHint)):
							_class.get(property.name).append(obj)
				else:
					_class.set(property.name, json[key])
				
			if key == property.hint_string and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE:
				if (property["class_name"] in ["Reference", "Object"] and property["type"] == TYPE_OBJECT):
					_class.set(property.name, json_to_class(json[key], _class.get(key)))
				else:
					_class.set(property.name, json[key])
				
	return _class

static func getGDScript(hint_class : String) -> GDScript:
	for className in ProjectSettings.get_global_class_list():
		if className.class == hint_class:
			return load(className.path)
	return null
	
# Helper function to recursively convert JSON arrays to Godot arrays
static func convert_json_to_array(json_array: Array,castClass : GDScript = null) -> Array:
	var godot_array: Array = []
	for element in json_array:
		if typeof(element) == TYPE_DICTIONARY: ## if it's an dictionary it could contain objects as values
			if castClass == null:
				castClass = getGDScript(element["ScriptName"])
			godot_array.append(json_to_class(castClass, element))  # Assuming each dictionary represents a class instance
		elif typeof(element) == TYPE_ARRAY:
			godot_array.append(convert_json_to_array(element))  # Recursive call for nested arrays
		else:
			godot_array.append(element)
	return godot_array


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
	dictionary["ScriptName"] = _class.get_script().get_global_name() ## this is later to help identify non typed arrays
	var properties: Array = _class.get_property_list()
	for property in properties:
		var property_name = property["name"]
		if property_name == "script": continue
		var property_value = _class.get(property_name)
		if not property_name.is_empty() and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE:
			
			if (property["class_name"] in ["Reference", "Object"] and property["type"] == TYPE_OBJECT):
				dictionary[property.name] = class_to_json(property_value)
			elif property_value is Array:
				# Handle arrays by recursively converting elements if necessary
				dictionary[property_name] = convert_array_to_json(property_value)
			elif property["type"] == TYPE_OBJECT and property_value.get_property_list():
				dictionary[property.name] = class_to_json(property_value)
			else:
				dictionary[property.name] = property_value
		elif not property["hint_string"].is_empty() and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE:
			if (property["class_name"] in ["Reference", "Object"] and property["type"] == TYPE_OBJECT):
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
		#json_array.append() ## Adding className
	return json_array
#endregion
