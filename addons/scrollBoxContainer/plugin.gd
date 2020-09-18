tool
extends EditorPlugin


func _enter_tree():
	add_custom_type("ScrollBoxContainer", "Container", preload("scrollBoxContainer.gd"), get_editor_interface().get_base_control().get_icon("Container", "EditorIcons"))


func _exit_tree():
	remove_custom_type("ScrollBoxContainer")
