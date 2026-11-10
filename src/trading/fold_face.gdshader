/*
Portions adapted from https://github.com/chuspeeism/iphone-duo
MIT License

Copyright (c) 2026 jadon7

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
shader_type canvas_item;
render_mode blend_mix;

uniform vec4 source_rect = vec4(0.0, 0.0, 1.0, 1.0);
// Physical coordinates always run from hinge (0) to moving edge (1).
uniform vec2 panel_size = vec2(497.6, 700.0);
uniform float angle : hint_range(0.0, 3.141593) = 0.0;
uniform bool backside = false;
uniform bool stationary = false;
// Live display bounds within the FULL snapshot, distinct from the physical body UV.
uniform vec4 screen_rect = vec4(0.04, 0.03, 0.92, 0.82);
uniform float blur_texels = 56.0;
uniform float darken = 0.55;
varying vec2 projected_position;
varying vec4 vertex_color;
// Exact depth ratios from the MIT reference's rotateHinge/model screen planes.
const float INNER_Z = 0.24948 / 7.89935;
const float OUTER_Z = -0.27463 / 7.89935;
const float AXIS_Z = 0.275454 / 7.89935;

// x: constant depth denominator, y: projection numerator, z: plane-axis offset.
vec3 projection_terms(float theta) {
	float distance = panel_size.x * 5.0;
	float axis = AXIS_Z * panel_size.x;
	float plane = (backside ? INNER_Z : OUTER_Z) * panel_size.x;
	float reference_z = mix(2.0 * AXIS_Z - OUTER_Z, INNER_Z, (1.0 - cos(theta)) * 0.5) * panel_size.x;
	if (stationary) {
		return vec3(distance - INNER_Z * panel_size.x, distance - INNER_Z * panel_size.x, 0.0);
	}
	return vec3(distance - axis + cos(theta) * (plane - axis), distance - reference_z, plane - axis);
}

void vertex() {
	vertex_color = COLOR;
	float theta = stationary ? 0.0 : angle;
	vec3 terms = projection_terms(theta);
	float away = UV.x * panel_size.x;
	float perspective = terms.y / (terms.x - sin(theta) * away);
	projected_position = vec2(cos(theta) * away + sin(theta) * terms.z, (UV.y - 0.5) * panel_size.y) * perspective;
	VERTEX = projected_position + vec2(0.0, panel_size.y * 0.5);
}

void fragment() {
	float theta = stationary ? 0.0 : angle;
	vec3 terms = projection_terms(theta);
	// Invert the same offset slab-plane homography as the chassis mesh.
	float denominator = terms.y * cos(theta) + projected_position.x * sin(theta);
	float away = (projected_position.x * terms.x - terms.y * sin(theta) * terms.z) / (abs(denominator) < 0.00001 ? 0.00001 : denominator);
	float depth = (terms.x - sin(theta) * away) / terms.y;
	vec2 physical = vec2(away / panel_size.x, 0.5 + projected_position.y * depth / panel_size.y);
	if (backside) { physical.x = 1.0 - physical.x; }
	vec2 body_uv = source_rect.xy + physical * source_rect.zw;
	vec4 body = texture(TEXTURE, body_uv);
	vec4 tex = body;
	bool on_display = all(greaterThan(body_uv, screen_rect.xy)) && all(lessThan(body_uv, screen_rect.xy + screen_rect.zw));
	if (on_display && !stationary) {
		// Reference's fixed front-view ray, anchored at the hinge, only on the
		// display. Body/bezel/rounded alpha stay attached to the rotating plane.
		float hinge_x = sin(theta) * terms.z * terms.y / terms.x;
		vec2 front = vec2((projected_position.x - hinge_x) / panel_size.x, 0.5 + projected_position.y / panel_size.y);
		if (backside) { front.x += 1.0; }
		vec2 uv = source_rect.xy + front * source_rect.zw;
		vec2 low = max(source_rect.xy, screen_rect.xy);
		vec2 high = min(source_rect.xy + source_rect.zw, screen_rect.xy + screen_rect.zw);
		float edge = clamp((uv.x - (backside ? high.x : low.x)) / ((backside ? low.x : high.x) - (backside ? high.x : low.x)), 0.0, 1.0);
		float motion = smoothstep(0.0, 1.0, backside ? (3.141592654 - theta) / 1.570796327 : theta / 1.570796327);
		float radius = blur_texels * motion * pow(edge, 1.35);
		vec3 sum = vec3(0.0);
		float total = 0.0;
		for (int y = -2; y <= 2; y++) {
			for (int x = -2; x <= 2; x++) {
				float wx = x == 0 ? 6.0 : (abs(x) == 1 ? 4.0 : 1.0);
				float wy = y == 0 ? 6.0 : (abs(y) == 1 ? 4.0 : 1.0);
				vec2 tap = uv + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * radius;
				bool covered = all(greaterThanEqual(tap, low)) && all(lessThanEqual(tap, high));
				sum += (covered ? texture(TEXTURE, clamp(tap, low, high)).rgb : vec3(0.0)) * wx * wy;
				total += wx * wy;
			}
		}
		tex.rgb = sum / total;
		tex.rgb *= 1.0 - min(1.0, darken * 2.0 * motion * pow(clamp((edge - 0.2) / 0.8, 0.0, 1.0), 1.35));
	}
	// Never use projected screen sampling for silhouette coverage.
	COLOR = vec4(tex.rgb, body.a) * vertex_color;
}
