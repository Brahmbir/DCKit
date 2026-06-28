extends Control

const _SimpleView = preload("./viewer/simple_log_view.gd")
const _ComplexView = preload("./viewer/complex_log_view.gd")


enum Mode { SIMPLE, COMPLEX }

signal mode_changed(new_mode: int)

@export var default_mode: Mode = Mode.SIMPLE

@onready var container: Control = $VBoxContainer/view_holder

var _simple: Control = null
var _complex: Control = null
var _current: Mode = Mode.SIMPLE
var _logger_ref: WeakRef = WeakRef.new()
var _is_set_up: bool = false

func _ready() -> void:
	_current = default_mode
	_activate(_current)

func setup(logger) -> void:
	_logger_ref = weakref(logger)
	_setup_active()
	_is_set_up = true

func set_mode(mode: Mode) -> void:
	if mode == _current: return
	_deactivate(_current)
	_current = mode
	_activate(_current)
	mode_changed.emit(_current)

func toggle_mode() -> void:
	set_mode(Mode.SIMPLE if _current == Mode.COMPLEX else Mode.COMPLEX)

func get_mode() -> Mode: return _current
func is_simple() -> bool: return _current == Mode.SIMPLE
func is_complex() -> bool: return _current == Mode.COMPLEX
func is_set_up() -> bool: return _is_set_up

func _activate(mode: Mode) -> void:
	var view := _build_view(mode)
	_size_view(view)
	container.add_child(view)
	if _logger_ref.get_ref():
		view.setup(_logger_ref.get_ref())

func _deactivate(mode: Mode) -> void:
	match mode:
		Mode.SIMPLE:
			if _simple: _simple.queue_free(); _simple = null
		Mode.COMPLEX:
			if _complex: _complex.queue_free(); _complex = null

func _build_view(mode: Mode) -> Control:
	match mode:
		Mode.SIMPLE:
			_simple = _SimpleView.new()
			return _simple
		Mode.COMPLEX:
			_complex = _ComplexView.new()
			return _complex
			pass
	return Control.new()

func _size_view(view: Control) -> void:
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _setup_active() -> void:
	var logger = _logger_ref.get_ref()
	if not logger: return
	match _current:
		Mode.SIMPLE:
			if _simple: _simple.setup(logger)
		Mode.COMPLEX:
			if _complex: _complex.setup(logger)
