shader_type canvas_item;
render_mode blend_mix;

// A brief blown-out display with sparse broken scanlines, not a colored grid.
// The rounded Panel supplies its geometry and edge alpha.
uniform vec2 display_size = vec2(1024.0, 768.0);
varying vec2 local_position;
varying float edge_alpha;

void vertex() {
	local_position = VERTEX;
	edge_alpha = COLOR.a;
}

void fragment() {
	float row = floor(local_position.y / 2.0);
	float tick = floor(TIME * 18.0);
	float noise = fract(sin(row * 12.9898 + tick * 78.233) * 43758.5453);
	float start = fract(sin(row * 39.346) * 47453.5453) * 0.7;
	float x = local_position.x / max(display_size.x, 1.0);
	vec3 color = vec3(1.0);
	if (noise > 0.975 && x > start) {
		color = noise > 0.9875 ? vec3(0.1, 1.0, 0.35) : vec3(1.0, 0.04, 0.8);
	}
	COLOR = vec4(color, edge_alpha);
}
