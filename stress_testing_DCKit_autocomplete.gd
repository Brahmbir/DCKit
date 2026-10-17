extends Node


func _ready() -> void:
	var autocomplete_stress_cmd := DCDefinition.new(
		"debug_autocomplete_extremely_long_command_name_for_layout_testing",
		func(_ctx: DCContext) -> DCResult:
			return DCResult.ok("Autocomplete stress-test command executed successfully."),
		"A deliberately long command description for testing autocomplete UI layouts, "
		+ "including text clipping, horizontal scrolling, popup sizing, responsive "
		+ "layouts, and how the interface behaves when commands have unusually long names.",
		[
			DCDefinition
			.Param
			.new("extremely_long_parameter_name_for_autocomplete_layout_testing")
			.describe("A deliberately long parameter description used to test text wrapping, "
			+ "tooltip rendering, and layout behavior with unusually long parameter names.")
			.suggest(
				func():
					var suggestions: Array[String] = []
					for i in range(100):
						suggestions.append(
							"extremely_long_autocomplete_suggestion_number_%03d_for_ui_testing" % i
						)
					return suggestions,
			)
		],
		true,
	)

	DCKit.register_def(autocomplete_stress_cmd)

	var test_cases := [
		{
			"name": "autocomplete_test_many_suggestions",
			"count": 200,
			"description": "Tests autocomplete with 200 suggestions.",
		},
		{
			"name": "autocomplete_test_medium_suggestion_list",
			"count": 50,
			"description": "Tests autocomplete with 50 suggestions.",
		},
		{
			"name": "autocomplete_test_short_suggestion_list",
			"count": 5,
			"description": "Tests autocomplete with 5 suggestions.",
		},
		{
			"name": "autocomplete_test_extremely_long_suggestion_names",
			"count": 40,
			"description": "Tests autocomplete with extremely long suggestion names.",
		},
	]

	for test_case in test_cases:
		var command_name: String = test_case["name"]
		var suggestion_count: int = test_case["count"]
		var command_description: String = test_case["description"]

		var test_cmd := DCDefinition.new(
			command_name,
			func(_ctx: DCContext) -> DCResult:
				return DCResult.ok("Executed %s." % command_name),
			command_description,
			[
				DCDefinition
				.Param
				.new("suggestion_query")
				.describe("Select a suggestion to test autocomplete rendering and navigation.")
				.suggest(
					func():
						var suggestions: Array[String] = []
						for i in range(suggestion_count):
							if command_name == "autocomplete_test_extremely_long_suggestion_names":
								suggestions.append(
									"very_long_suggestion_name_%03d_for_autocomplete_stress_testing"
									% i
								)
							else:
								suggestions.append("suggestion_%03d" % i)
						return suggestions,
				)
			],
			true,
		)

		DCKit.register_def(test_cmd)
