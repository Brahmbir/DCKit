extends RefCounted

var font_size_theme: Theme = preload("./dev_con_theme.theme")

func get_dckit_theme(pixels : int,
		normal_colour : Color,
		highlighted_colour : Color)-> Theme:
	var em := func( scale : float ) -> int : return int(pixels * scale)
	
	var new_theme: Theme = font_size_theme.duplicate()
	
	new_theme.set_color("normal_colour", "Consts", normal_colour)
	new_theme.set_color("highlighted_colour", "Consts", highlighted_colour)
	
	new_theme.default_font_size = em.call(0.95)
	new_theme.set_font_size("font_size","Label",em.call(0.95))
	
	
	for property in ["normal_font_size", "bold_font_size", "bold_italics_font_size", "italics_font_size", "mono_font_size"]:
		new_theme.set_font_size(property, "RichTextLabel" ,em.call(0.95))
	
	
	new_theme.set_font_size("font_size","cmd_label",em.call(1.125))
	new_theme.set_font_size("font_size","TextEdit",em.call(1.1))
	new_theme.set_font_size("padding_top","HScrollBar",em.call(0.1))
	
	return new_theme
