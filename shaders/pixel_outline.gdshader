shader_type canvas_item;
// Runtime outline for pixel sprites (slice §2A): one texel of outline_color
// around every opaque pixel. The quad grows by one texel per side so the
// outline also shows where the art touches the texture edge. Keeps modulate.
// M6f (Sean, 2026-11-24): `tint` darkens special Goobs (eye shines stay
// white); `glint` sweeps a white shine across legendary Goobs.

uniform vec4 outline_color : source_color = vec4(0.08, 0.05, 0.1, 1.0);
uniform float tint = 1.0;
uniform bool glint = false;
// Off for Control rects (inspect): there 1 local unit isn't 1 texel.
uniform bool grow = true;

const float GLINT_CYCLE = 2.5; // seconds between sweeps
const float GLINT_SWEEP = 0.45; // seconds one sweep takes

varying vec4 v_modulate;

void vertex() {
	if (grow) {
		vec2 dir = sign(UV - vec2(0.5));
		VERTEX += dir; // 1 local unit = 1 texel for an unscaled Sprite2D
		UV += dir * TEXTURE_PIXEL_SIZE;
	}
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
	} else {
		if (any(lessThan(c.rgb, vec3(0.99)))) {
			c.rgb *= tint;
		}
		if (glint) {
			// A diagonal streak (texel x + y) crossing the 32 px Goob.
			vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
			float u = mod(TIME, GLINT_CYCLE) / GLINT_SWEEP;
			float d = abs(texel.x + texel.y - (-12.0 + u * 76.0));
			float k = u > 1.0 ? 0.0 : (d < 1.0 ? 0.75 : (d < 2.0 ? 0.4 : 0.0));
			c.rgb = mix(c.rgb, vec3(1.0), k);
		}
	}
	COLOR = c * v_modulate;
}
