tool
extends Control

signal user_added_entry(entry_name) # string
signal user_removed_entries(entry_names) # array of strings
signal user_renamed_entry(old_name, new_name) # string
signal user_duplicated_entries(source_entry_names, duplicated_entry_names) # arrays of strings
signal user_copied_entries(entry_names)
signal user_pasted_entries(source_entry_names, source_jList_id, pasted_entry_names) 
signal user_pressed_save(data) # array of strings (equal to entry_names)

export (String) var id = ""
export (String) var entry_duplicate_text = "_duplicate"

export (bool) var only_unique_entries_allowed = true
export (bool) var enable_add_button = true
export (bool) var enable_remove_button = true
export (bool) var enable_rename_button = false
export (bool) var enable_duplicate_button = false
export (bool) var enable_copy_button = false 
export (bool) var enable_paste_button = false 
export (bool) var enable_save_button = false 

export (bool) var update setget update_visible_buttons

func get_data():
	var entry_names = []
	for i in range(item_list.get_item_count()):
		entry_names.append(item_list.get_item_text(i))
	return entry_names

func set_data(entry_names : Array): # Input: Array of strings
	clear()
	for i in range (entry_names.size()):
		item_list.add_item(entry_names[i])

func clear():
	item_list.clear()
	$VBoxContainer/HBoxContainer/LineEdit.text = ""

func add_entry(entry_name : String):
	if only_unique_entries_allowed:
		entry_name = get_unique_entry_name(entry_name)
	item_list.add_item(entry_name)
	emit_signal("user_added_entry", entry_name)
	return entry_name

func remove_entry(entry_name : String):
	var entry_id = get_entry_id(entry_name)
	if entry_id != -1:
		remove_entry_id(entry_id)

func get_size():
	return item_list.get_item_count()#

func revoke_last_user_action(message : String = ""):
	if undo_buffer == null:
		print_debug("jList " + name + ": Can't revoke last user action. Nothing stored in buffer.")
		return
	set_data(undo_buffer)
	undo_buffer = null
		
	if message != "":
		$PopupDialog/Label.text = message
	else:
		$PopupDialog/Label.text = "This action is not allowed!"
	$PopupDialog.popup_centered_minsize()
	
## Internal Code ###############################################################
var item_list

var undo_buffer = null

func _ready():
	update_visible_buttons(true)
	
func _process(delta):
	if $VBoxContainer/HBoxContainer/LineEdit.has_focus() and enable_add_button and  Input.is_action_just_pressed("jList_enter"):
		_on_Add_pressed()

func is_entry_name_unique(entry : String):
	for i in range(get_size()):
		if item_list.get_item_text(i) == entry:
			return true
	return false

func get_entry_id(entry : String):
	for i in range(get_size()):
		if item_list.get_item_text(i) == entry:
			return i
	return -1

func get_unique_entry_name(entry_name : String):
	while is_entry_name_unique(entry_name):
		entry_name = entry_name + entry_duplicate_text
	return entry_name

func rename_entry_id(entry_id : int, new_entry_name : String):
	if entry_id >= get_size():
		print_debug("jList " + name + ": rename_entry(): entry_id out of bounds! Skipping...")
		return
	if only_unique_entries_allowed:
		new_entry_name = get_unique_entry_name(new_entry_name)
	item_list.set_item_text(entry_id, new_entry_name)
	return new_entry_name

func duplicate_entry_id(entry_id : int):
	return add_entry(item_list.get_item_text(entry_id))
	
func remove_entry_id(entry_id : int):
	if entry_id >= get_size():
		print_debug("jList " + name + ": remove_entry_id(): entry_id out of bounds! Skipping...")
		return
	item_list.remove_item(entry_id)

func update_visible_buttons(newvar):
	$VBoxContainer/HBoxContainer/Add.visible = enable_add_button
	$VBoxContainer/HBoxContainer/Remove.visible = enable_remove_button
	$VBoxContainer/HBoxContainer/Rename.visible = enable_rename_button
	$VBoxContainer/HBoxContainer/Duplicate.visible = enable_duplicate_button
	$VBoxContainer/HBoxContainer/Copy.visible = enable_copy_button
	$VBoxContainer/HBoxContainer/Paste.visible = enable_paste_button
	$VBoxContainer/HBoxContainer/Save.visible = enable_save_button
	update = false


## Button Signals ##############################################################
func _enter_tree():
	item_list = $VBoxContainer/ItemList
	if owner != self:
		if id == "":
			randomize()
			id = String(randi())
		jListManager.register_jList(self)

func _exit_tree():
	jListManager.deregister_jList(self)

func _on_Add_pressed():
	if $VBoxContainer/HBoxContainer/LineEdit.text == "":
		return
	undo_buffer = get_data()
	add_entry($VBoxContainer/HBoxContainer/LineEdit.text)
	$VBoxContainer/HBoxContainer/LineEdit.text = ""
	emit_signal("user_added_entry", $VBoxContainer/HBoxContainer/LineEdit.text)

func _on_Remove_pressed():
	if item_list.get_selected_items().size() == 0:
		return
	undo_buffer = get_data()
	var removed_entries = []
	while item_list.get_selected_items().size() != 0:
		removed_entries.append(item_list.get_item_text(item_list.get_selected_items()[0]))
		remove_entry_id(item_list.get_selected_items()[0])
	
	emit_signal("user_removed_entries", removed_entries)

func _on_Rename_pressed():
	var new_text = $VBoxContainer/HBoxContainer/LineEdit.text
	if item_list.get_selected_items().size() != 1:
		return
	var entry_id = item_list.get_selected_items()[0]
	var old_text = item_list.get_item_text(entry_id)
	if new_text == "":
		return
	if new_text == old_text:
		return
	undo_buffer = get_data()
	rename_entry_id(entry_id, new_text)
	emit_signal("user_renamed_entry", old_text, new_text)
	$VBoxContainer/HBoxContainer/LineEdit.text = ""

func _on_Duplicate_pressed():
	if  item_list.get_selected_items().size() == 0:
		return
	undo_buffer = get_data()
	var source_entry_ids = item_list.get_selected_items()
	var source_entry_names = []
	var duplicated_entry_names = []
	for entry_id in source_entry_ids:
		source_entry_names.append(item_list.get_item_text(entry_id))
		duplicated_entry_names.append(duplicate_entry_id(entry_id))
	
	emit_signal("user_duplicated_entries", source_entry_names, duplicated_entry_names)

func _on_Copy_pressed(): # stores the current entry_names into the global buffer
	if  item_list.get_selected_items().size() == 0:
		return
	undo_buffer = get_data()
	var source_entry_names = []
	var source_entry_ids = item_list.get_selected_items()
	for entry_id in source_entry_ids:
		source_entry_names.append(item_list.get_item_text(entry_id))
	jListManager.set_buffer(self, source_entry_names)
	emit_signal("user_copied_entries", source_entry_names)

func _on_Paste_pressed(): # Adds entry_names from global buffer into jList.
	var source_entry_names = jListManager.get_buffer()
	if source_entry_names == null:
		return
	undo_buffer = get_data()
	var pasted_entry_names = []
	for source_entry in source_entry_names:
		pasted_entry_names.append(add_entry(source_entry))
	emit_signal("user_pasted_entries", source_entry_names, jListManager.get_buffer_source_jList_id(), pasted_entry_names)


func _on_Save_pressed():
	emit_signal("user_pressed_save", get_data())
	

func _on_ItemList_item_activated(index):
	$VBoxContainer/HBoxContainer/LineEdit.text = item_list.get_item_text(index)

func _on_PopupDiaglog_Okay_pressed():
	$PopupDialog.hide()
	
	
