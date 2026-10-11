class_name SafeArea
extends RefCounted
## Converts the OS "safe area" (notch, Dynamic Island, home indicator, rounded corners) into
## insets in viewport (canvas) units, so UI can stay clear of them.


## All of `window_size` and `safe` are in physical pixels; `viewport_size` is in canvas units.
## Returns Vector4(left, top, right, bottom).
static func insets(window_size: Vector2, safe: Rect2, viewport_size: Vector2) -> Vector4:
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Vector4.ZERO
	var sx := viewport_size.x / window_size.x
	var sy := viewport_size.y / window_size.y
	return Vector4(
		maxf(0.0, safe.position.x) * sx,
		maxf(0.0, safe.position.y) * sy,
		maxf(0.0, window_size.x - safe.end.x) * sx,
		maxf(0.0, window_size.y - safe.end.y) * sy)


## Insets for the current window. Only phones/tablets report meaningful safe areas; on desktop
## the "safe area" is the whole desktop minus the taskbar, which would be wrong for a window.
static func current(viewport: Viewport) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	return insets(
		Vector2(DisplayServer.window_get_size()),
		Rect2(DisplayServer.get_display_safe_area()),
		viewport.get_visible_rect().size)
