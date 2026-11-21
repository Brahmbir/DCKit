extends SyntaxHighlighter
## Paints from token roles only: the parser decides what every token is, this class maps roles to
## colours. The controller pushes its analysis through set_analysis(); if nothing was pushed for the
## current text (feedback disabled, signal order) the highlighter analyses the text itself.

enum ColorScheme {
	TOKYO_NIGHT,
	CUBER,
	NORD,
	CATPPUCCIN_MOCHA,
}

const Role := _DCKitNS.Analyzer.Token.Role
const TT := _DCKitNS.Analyzer.Token.Type

@export var palette := ColorScheme.NORD:
	set(value):
		palette = value
		_rebuild_colors()

var color_dict := {
	ColorScheme.TOKYO_NIGHT: {
		"color_command": Color("7DCFFF"),
		"color_ctor_type": Color("E0AF68"),
		"color_string": Color("9ECE6A"),
		"color_number": Color("FF9E64"),
		"color_variable": Color("BB9AF7"),
		"color_var_sigil": Color("D8C8FF"),
		"color_key": Color("73DACA"),
		"color_error": Color("F7768E"),
		"color_default": Color("D8DFF9"),
		"color_comment": Color("565F89"),
	},
	ColorScheme.CUBER: {
		"color_command": Color("4FC3F7"),
		"color_ctor_type": Color("FFD54F"),
		"color_string": Color("69F0AE"),
		"color_number": Color("FFAB40"),
		"color_variable": Color("B388FF"),
		"color_var_sigil": Color("D1C4E9"),
		"color_key": Color("80DEEA"),
		"color_error": Color("FF5252"),
		"color_default": Color("ECEFF1"),
		"color_comment": Color("78909C"),
	},
	ColorScheme.NORD: {
		"color_command": Color("88C0D0"),
		"color_ctor_type": Color("EBCB8B"),
		"color_string": Color("A3BE8C"),
		"color_number": Color("D08770"),
		"color_variable": Color("B48EAD"),
		"color_var_sigil": Color("D8B4E2"),
		"color_key": Color("8FBCBB"),
		"color_error": Color("BF616A"),
		"color_default": Color("ECEFF4"),
		"color_comment": Color("616E88"),
	},
	ColorScheme.CATPPUCCIN_MOCHA: {
		"color_command": Color("89B4FA"),
		"color_ctor_type": Color("F9E2AF"),
		"color_string": Color("A6E3A1"),
		"color_number": Color("FAB387"),
		"color_variable": Color("CBA6F7"),
		"color_var_sigil": Color("E5C8FF"),
		"color_key": Color("94E2D5"),
		"color_error": Color("F38BA8"),
		"color_default": Color("CDD6F4"),
		"color_comment": Color("7F849C"),
	},
}
var _colors := PackedColorArray() # indexed by Role


#region PUBLIC
## Hand over an analysis of the current text (DCAnalysisResult). Ignored when it does not match it.
func set_analysis(result: DCAnalysisResult) -> void:
	_DCKitNS.not_implemented("set_analysis")
	pass


func _rebuild_colors() -> void:
	var c: Dictionary = color_dict[palette]
	_colors.resize(Role.size())
	_colors.fill(c.color_default)
	_colors[Role.COMMAND] = c.color_command
	_colors[Role.CTOR_TYPE] = c.color_ctor_type
	_colors[Role.STRING] = c.color_string
	_colors[Role.NUMBER] = c.color_number
	_colors[Role.VAR_SIGIL] = c.color_var_sigil
	_colors[Role.VAR_NAME] = c.color_variable
	_colors[Role.COMMENT] = c.color_comment
	_colors[Role.KEY] = c.color_key
	_colors[Role.ERROR] = c.color_error
	if get_text_edit() != null:
		clear_highlighting_cache()
