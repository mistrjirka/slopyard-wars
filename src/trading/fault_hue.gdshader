shader_type canvas_item;
// Hue drift for the damaged display band. Only saturated, lit pixels of the authored
// display_fault art rotate. The horizontal strip is slightly thicker at runtime;
// the vertical column and the rest of the transparent overlay stay unchanged.
render_mode blend_mix;

uniform float hue_shift : hint_range(-0.5, 0.5) = 0.0;
uniform float saturation_floor : hint_range(0.0, 1.0) = 0.25;
uniform float brightness_floor : hint_range(0.0, 1.0) = 0.10;
uniform float band_bottom = 0.859375;
varying vec4 modulation;

void vertex() {
	modulation = COLOR;
}

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
	vec2 source_uv = UV;
	const float band_top = 648.0 / 768.0;
	const float source_bottom = 656.0 / 768.0;
	if (UV.x >= 510.0 / 1024.0 && UV.y >= band_top && UV.y < band_bottom) {
		source_uv.y = mix(band_top, source_bottom, (UV.y - band_top) / (band_bottom - band_top));
	}
	vec4 art = texture(TEXTURE, source_uv) * modulation;
	vec3 rgb = art.rgb;
	vec3 hsv = rgb_to_hsv(rgb);
	float lit = smoothstep(brightness_floor, brightness_floor + 0.25, hsv.z);
	float saturated = smoothstep(saturation_floor, saturation_floor + 0.2, hsv.y);
	hsv.x = fract(hsv.x + hue_shift * lit * saturated);
	// A gentle lime cast keeps the fault greener without tinting dead pixels.
	vec3 shifted = mix(hsv_to_rgb(hsv), vec3(0.60, 1.0, 0.12), 0.18 * lit);
	COLOR = vec4(shifted, art.a);
}
