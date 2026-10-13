class_name _DCKitNS
extends RefCounted

const Connector = preload("./utils/connector.gd")

const Core = preload("./core/_namespace.gd")
const Analyzer = preload("./core/analyzer/_namespace.gd")
const Executor = preload("./core/executor/_namespace.gd")

const Registries = preload("./core/registries/_namespace.gd")

const UI = preload("./ui/_namespace.gd")

static func not_implemented(function_name: String) -> void:
	push_warning("'%s' is not implemented." % function_name)
