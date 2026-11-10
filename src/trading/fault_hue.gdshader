shader_type canvas_item;
// Hue drift for the damaged display band. Only saturated, lit pixels of the authored
// display_fault art rotate; the dead background, the art's geometry and its alpha are
// preserved so the rainbow can breathe without recolouring anything else.
render_mode blend_mix;

uniform float hue_shift : hint_range(-0.5, 0.5) = 0.0;
uniform float saturation_floor : hint_range(0.0, 1.0) = 0.25;
uniform float brightness_floor : hint_range(0.0, 1.0) = 0.10;

vec3 rgb_to_hsv(vec3 color) {
	float high = max(color.r, max(color.g, color.b));
	float low = min(color.r, min(color.g, color.b));
	float delta = high - low;
	float hue = 0.0;
	if (delta > 0.00001) {
		if (high == color.r) {
			hue = mod((color.g - color.b) / delta, 6.0);
		} else if (high == color.g) {
			hue = (color.b - color.r) / delta + 2.0;
		} else {
			hue = (color.r - color.g) / delta + 4.0;
		}
		hue /= 6.0;
	}
	float saturation = high <= 0.00001 ? 0.0 : delta / high;
	return vec3(hue, saturation, high);
}

vec3 hsv_to_rgb(vec3 hsv) {
	vec3 ramp = abs(mod(hsv.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0);
	return hsv.z * mix(vec3(1.0), clamp(ramp - 1.0, 0.0, 1.0), hsv.y);
}

void fragment() {
	// COLOR already holds the sampled art multiplied by the node's modulate.
	vec3 rgb = COLOR.rgb;
	vec3 hsv = rgb_to_hsv(rgb);
	float lit = smoothstep(brightness_floor, brightness_floor + 0.25, hsv.z);
	float saturated = smoothstep(saturation_floor, saturation_floor + 0.2, hsv.y);
	hsv.x = fract(hsv.x + hue_shift * lit * saturated);
	COLOR = vec4(hsv_to_rgb(hsv), COLOR.a);
}
