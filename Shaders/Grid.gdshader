shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float line_width : hint_range(0.0, 1.0) = 0.04;
uniform float grid_size : hint_range(0.0, 10.0) = 1.0;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);



void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 grid_pos = mod(world_pos.xz + grid_size * 0.5, grid_size) / grid_size - 0.5;
	grid_pos = abs(grid_pos) * 2.0;
	float line = min(step(line_width, grid_pos.x), step(line_width, grid_pos.y));
	ALBEDO = mix(line_color.rgb, fill_color.rgb, line) + vec3(length(world_pos) * 2.0);
	ALPHA = min(0.25, mix(line_color.a, fill_color.a, line) / (length(world_pos) * length(world_pos) * 32.0));
}