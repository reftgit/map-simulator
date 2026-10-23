extends "res://tests/test_case.gd"
## Safe-area conversion and HUD margins.


func test_iphone_landscape_safe_area() -> void:
	# iPhone 13 Pro landscape: 2532x1170 px, 141 px notch/corner insets left and
	# right, 63 px home indicator. 1440x900 base with "expand" -> 1947.7x900 canvas.
	var window := Vector2i(2532, 1170)
	var viewport := Vector2(2532.0 / 1.3, 900.0)
	var rect := UIController.safe_rect_in_viewport(Rect2i(141, 0, 2250, 1107), window, viewport)
	check_near(rect.position.x, 108.46, 0.05, "left inset")
	check_near(rect.position.y, 0.0, 0.001, "no top inset")
	check_near(rect.end.x, viewport.x - 108.46, 0.05, "right inset")
	check_near(rect.end.y, 851.54, 0.05, "bottom inset")


func test_missing_safe_area_falls_back_to_full_screen() -> void:
	var viewport := Vector2(1440, 900)
	check(UIController.safe_rect_in_viewport(Rect2i(), Vector2i(1440, 900), viewport) == Rect2(Vector2.ZERO, viewport), "empty safe area")
	check(UIController.safe_rect_in_viewport(Rect2i(0, 0, 10, 10), Vector2i.ZERO, viewport) == Rect2(Vector2.ZERO, viewport), "unknown window size")


func test_desktop_hud_uses_edge_margin_only() -> void:
	var hud: UIController = instantiate("res://game/ui/hud.tscn")
	await process_frames(2)
	var safe: Control = hud.get_node("SafeArea")
	var view := hud.get_viewport().get_visible_rect().size
	check_near(safe.get_global_rect().position.x, hud.edge_margin, 0.01, "left margin")
	check_near(safe.get_global_rect().end.x, view.x - hud.edge_margin, 0.01, "right margin")
	check_near(safe.get_global_rect().end.y, view.y - hud.edge_margin, 0.01, "bottom margin")
