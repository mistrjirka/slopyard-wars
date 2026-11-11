shader_type canvas_item;
render_mode blend_mix;

// The Panel's rounded StyleBox supplies geometry and edge alpha; local vertex
// coordinates keep the color wash stable without depending on StyleBox UVs.
uniform vec2 display_size = vec2(1024.0, 768.0);
uniform vec4 primary_color : source_color = vec4(0.15, 0.97, 0.64, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.89, 0.27, 0.98, 1.0);
uniform float strength : hint_range(0.0, 0.3) = 0.12;
varying vec2 local_position;
varying float edge_alpha;

void vertex() {
	local_position = VERTEX;
	edge_alpha = COLOR.a;
}

void fragment() {
	vec2 uv = local_position / max(display_size, vec2(1.0));
	float split = smoothstep(0.2, 0.85, uv.x + 0.08 * sin(uv.y * 10.0));
	vec3 cast = mix(primary_color.rgb, secondary_color.rgb, split);
	float coverage = mix(0.65, 1.0, smoothstep(0.35, 0.9, uv.y));
	COLOR = vec4(cast, edge_alpha * strength * coverage);
}
