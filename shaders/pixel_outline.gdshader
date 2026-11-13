shader_type canvas_item;
// Runtime outline for pixel sprites (slice §2A): one texel of outline_color
// around every opaque pixel. The quad grows by one texel per side so the
// outline also shows where the art touches the texture edge. Keeps modulate.

uniform vec4 outline_color : source_color = vec4(0.08, 0.05, 0.1, 1.0);

varying vec4 v_modulate;

void vertex() {
	vec2 grow = sign(UV - vec2(0.5));
	VERTEX += grow; // 1 local unit = 1 texel for an unscaled Sprite2D
	UV += grow * TEXTURE_PIXEL_SIZE;
	v_modulate = COLOR;
}

bool in_texture(vec2 uv) {
	return uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
}

void fragment() {
	vec4 c = in_texture(UV) ? texture(TEXTURE, UV) : vec4(0.0);
	if (c.a < 0.5) {
		c = vec4(0.0);
		vec2 offsets[4] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
		for (int i = 0; i < 4; i++) {
			vec2 uv = UV + offsets[i] * TEXTURE_PIXEL_SIZE;
			if (in_texture(uv) && texture(TEXTURE, uv).a > 0.5) {
				c = outline_color;
			}
		}
	}
	COLOR = c * v_modulate;
}
