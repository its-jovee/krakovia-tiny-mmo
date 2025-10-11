extends PanelContainer

@onready var rich_text_label: RichTextLabel = $RichTextLabel

func set_content(content: String) -> void:
	print("!!! set_content() called")
	print("!!! Content: ", content)
	print("!!! Content length: ", content.length())
	if rich_text_label:
		print("!!! RichTextLabel found")
		rich_text_label.clear()
		rich_text_label.append_text(content)
		print("!!! Text appended")
		print("!!! RichTextLabel.text: ", rich_text_label.text)
		print("!!! RichTextLabel.visible_ratio: ", rich_text_label.visible_ratio)
	else:
		print("!!! ERROR: RichTextLabel is NULL!")
