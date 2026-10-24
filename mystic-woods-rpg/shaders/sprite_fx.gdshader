shader_type canvas_item;
// Hit flash + hue shift for monster variants (shadow pixels are left untouched).

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float hue_shift = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = COLOR;
	float solid = step(0.6, c.a);
	if (hue_shift != 0.0 && solid > 0.5) {
		vec3 h = rgb2hsv(c.rgb);
		h.x = fract(h.x + hue_shift);
		c.rgb = hsv2rgb(h);
	}
	c.rgb = mix(c.rgb, c.rgb * tint.rgb, solid);
	c.rgb = mix(c.rgb, vec3(1.0), flash * solid);
	COLOR = c;
}
