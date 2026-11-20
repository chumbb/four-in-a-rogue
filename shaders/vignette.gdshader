shader_type canvas_item;
// Subtle vignette (Art pass B, GDD §Art direction: no CRT, vignette only).
// Put on a full-screen ColorRect above the canvas and below the UI.
// Radial darkening toward ink, the same maths as apply_vignette() in
// art/ui/make_ui_mocks.py (the approved mocks). Compatibility-safe: no
// screen texture, just an alpha overlay.

uniform vec4 ink : source_color = vec4(0.18, 0.133, 0.184, 1.0); // Resurrect 64 2e222f
uniform float strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	float u = UV.x - 0.5;
	float v = (UV.y - 0.5) * (size.y / size.x) * 0.6;
	float r = sqrt(u * u + v * v) / 0.62;
	float t = smoothstep(0.55, 1.15, r) * strength;
	COLOR = vec4(ink.rgb, t);
}
