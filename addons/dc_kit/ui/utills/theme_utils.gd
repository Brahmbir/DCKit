extends RefCounted

var cnm_theme: Theme = preload("./const_n_margin.theme")

func get_const_n_margin_theme(pixels : int,
		normal_colour : Color,
		highlighted_colour : Color)-> Theme:
	var em := func( scale : float ) -> int : return int(pixels * scale)
	
	var new_theme: Theme = cnm_theme.duplicate()
	
	new_theme.set_color("normal_colour", "Consts", normal_colour)
	new_theme.set_color("highlighted_colour", "Consts", highlighted_colour)

	var margin_presets := {
		"0_25em": 0.25, # 4
		"0_5em": 0.5, # 8
		"0_75em": 0.75, # 12
		"1em": 1.0, # 16
		
		"1_25em": 1.25, # 20
		"0_625em": 0.625, # 10
		"0_125em": 0.125, # 2
	}
	
	const SIDES := ["top", "right", "bottom", "left"]
	for margin_name in margin_presets:
		var value : int = em.call(margin_presets[margin_name])
		for side in SIDES: new_theme.set_constant("margin_" + side, margin_name, value)
	
	var margin_data := {
		"MarginContainer":{},
		"log_info_area": {
			"left": 1.25,
			"right": 0.625,
		},
		"error_cmd_area": {
			"left": 1.25,
			"right": 1.25,
			"top": 0.5,
			"bottom": 1.25,
		},
		"error_root_margin": {
			"left": 0.75,
			"right": 0.5,
			"top": 1,
			"bottom": 1.25,
		},
		"info_clip_margin": {
			"left": 1,
			"right": 0.5,
			"bottom": 0.625,
		},
	}

	for margin_name in margin_data:
		var margins: Dictionary = margin_data[margin_name]
		for side in SIDES: new_theme.set_constant("margin_" + side, margin_name, em.call(margins.get(side, 0)))

	return new_theme

var font_size_theme: Theme = preload("./dev_con_theme.theme")

func get_font_size_theme(pixels : int)-> Theme:
	var em := func( scale : float ) -> int : return int(pixels * scale)
	
	var new_theme: Theme = font_size_theme.duplicate()
	
	new_theme.default_font_size = em.call(0.95)
	new_theme.set_font_size("font_size","Label",em.call(0.95))
	
	
	for property in ["normal_font_size", "bold_font_size", "bold_italics_font_size", "italics_font_size", "mono_font_size"]:
		new_theme.set_font_size(property, "RichTextLabel" ,em.call(0.95))
	
	
	new_theme.set_font_size("font_size","cmd_label",em.call(1.225))
	new_theme.set_font_size("font_size","TextEdit",em.call(1.2))
	new_theme.set_font_size("padding_top","HScrollBar",em.call(0.1))
	
	return new_theme
