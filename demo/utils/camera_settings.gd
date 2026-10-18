class_name CameraSettings
extends Resource

@export_group("Look")
@export var mouse_sensitivity: float = 0.002
@export_range(-89.0, 0.0, 0.5, "suffix:°") var pitch_min_deg: float = -70.0
@export_range(0.0, 89.0, 0.5, "suffix:°") var pitch_max_deg: float = 60.0
@export_range(30.0, 120.0, 0.5, "suffix:°") var fov: float = 75.0

@export_group("Follow")
## Height of the pivot above the target's origin (capsule center).
@export var follow_height: float = 1.0
## Distance from the pivot back to the camera.
@export var follow_distance: float = 3.0
## Time constant in seconds. 0 = snap to the target, higher = lazier.
@export_range(0.0, 0.5, 0.005, "suffix:s") var follow_lag: float = 0.08

@export_group("Collision")
@export_flags_3d_physics var collision_mask: int = 1
## Radius of the sphere swept along the arm.
@export var probe_radius: float = 0.2
## Gap kept between the camera and a wall.
@export var spring_margin: float = 0.2
