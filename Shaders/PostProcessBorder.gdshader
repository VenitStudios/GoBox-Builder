shader_type spatial;
render_mode unshaded;

/*
	Normal/Depth outline shader. Apply to nodes as a next pass shader texture.
	Inspired by Yui Kinomoto @arlez80, lukky_nl (YT), Robin Seibold (YT)
	Uses Sobel Edge detection on a normal and depth texture
	Written by William Li (LoudFlameLava)
	
	MIT License
*/

// Might create an outline at the edge of the viewport

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_linear_mipmap;

uniform float normal_threshold = 0.1;
uniform float depth_threshold = 0.05;
uniform float depth_artifact_correction_coef = 2;
uniform vec3 outline_color: source_color;

const mat3 sobel_y = mat3(
	vec3(1.0, 0.0, -1.0),
	vec3(2.0, 0.0, -2.0),
	vec3(1.0, 0.0, -1.0)
);

const mat3 sobel_x = mat3(
	vec3(1.0, 2.0, 1.0),
	vec3(0.0, 0.0, 0.0),
	vec3(-1.0, -2.0, -1.0)
);

float edge_value_normal(sampler2D normal_tex, vec2 uv, vec2 pixel_size, mat3 sobel) {
	float output = 0.0;
	vec3 normal = texture(normal_tex, uv).rgb;
	vec3 n = texture(NORMAL_TEXTURE, uv + vec2(0.0, -pixel_size.y)).rgb;
	vec3 s = texture(NORMAL_TEXTURE, uv + vec2(0.0, pixel_size.y)).rgb;
	vec3 e = texture(NORMAL_TEXTURE, uv + vec2(pixel_size.x, 0.0)).rgb;
	vec3 w = texture(NORMAL_TEXTURE, uv + vec2(-pixel_size.x, 0.0)).rgb;
	vec3 nw = texture(NORMAL_TEXTURE, uv + vec2(-pixel_size.x, -pixel_size.y)).rgb;
	vec3 ne = texture(NORMAL_TEXTURE, uv + vec2(pixel_size.x, -pixel_size.y)).rgb;
	vec3 sw = texture(NORMAL_TEXTURE, uv + vec2(-pixel_size.x, pixel_size.y)).rgb;
	vec3 se = texture(NORMAL_TEXTURE, uv + vec2(pixel_size.x, pixel_size.y)).rgb;
	
	mat3 error_mat = mat3(
		vec3(length(normal - nw), length(normal - n), length(normal - ne)),
		vec3(length(normal - w), 0.0, length(normal - e)),
		vec3(length(normal - sw), length(normal - s), length(normal - se))
	);
	
	output += dot(sobel[0], error_mat[0]);
	output += dot(sobel[1], error_mat[1]);
	output += dot(sobel[2], error_mat[2]);
	return abs(output);
}

float get_depth(sampler2D depth_tex, vec2 uv, mat4 inv_projection_matrix) {
	float depth_raw = texture(depth_tex, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth_raw);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float depth_linear = -view.z;
	return depth_linear;
}

float edge_value_depth(sampler2D depth_tex, vec2 uv, vec2 pixel_size, mat3 sobel, mat4 inv_projection_matrix){
	float output = 0.0;
	float depth = get_depth(depth_tex, uv, inv_projection_matrix);
	float n = get_depth(depth_tex, uv + vec2(0.0, -pixel_size.y), inv_projection_matrix);
	float s = get_depth(depth_tex, uv + vec2(0.0, pixel_size.y), inv_projection_matrix);
	float e = get_depth(depth_tex, uv + vec2(pixel_size.x, 0.0), inv_projection_matrix);
	float w = get_depth(depth_tex, uv + vec2(-pixel_size.x, 0.0), inv_projection_matrix);
	float ne = get_depth(depth_tex, uv + vec2(pixel_size.x, -pixel_size.y), inv_projection_matrix);
	float nw = get_depth(depth_tex, uv + vec2(-pixel_size.x, -pixel_size.y), inv_projection_matrix);
	float se = get_depth(depth_tex, uv + vec2(pixel_size.x, pixel_size.y), inv_projection_matrix);
	float sw = get_depth(depth_tex, uv + vec2(-pixel_size.x, pixel_size.y), inv_projection_matrix);
	
	mat3 error_mat = mat3(
		vec3((depth - nw)/depth, (depth - n)/depth, (depth - ne)/depth),
		vec3((depth - w)/depth, 0.0, (depth - e)/depth),
		vec3((depth - sw)/depth, (depth - s)/depth, (depth - se)/depth)
	);
	
	output += dot(sobel[0], error_mat[0]);
	output += dot(sobel[1], error_mat[1]);
	output += dot(sobel[2], error_mat[2]);
	return abs(output);
}


void fragment() {
	float has_outline = 0.0;
	vec2 pixel_size = vec2(1.0) / VIEWPORT_SIZE;
	ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV).xyz;
	//ALBEDO = vec3(get_depth(DEPTH_TEXTURE, SCREEN_UV, INV_PROJECTION_MATRIX));
	if (edge_value_normal(NORMAL_TEXTURE, SCREEN_UV, pixel_size, sobel_x) + edge_value_normal(NORMAL_TEXTURE, SCREEN_UV, pixel_size, sobel_y) > normal_threshold){
		ALBEDO = outline_color;
		has_outline += 1.0;
	}
	vec3 normal = texture(NORMAL_TEXTURE, SCREEN_UV).rgb;
	float angle = 1.0 - dot(normalize(normal-vec3(0.5)),  vec3(0.0,0.0,1.0));
	if (edge_value_depth(DEPTH_TEXTURE, SCREEN_UV, pixel_size, sobel_x, INV_PROJECTION_MATRIX) + edge_value_depth(DEPTH_TEXTURE, SCREEN_UV, pixel_size, sobel_y, INV_PROJECTION_MATRIX) > depth_threshold + angle * depth_artifact_correction_coef){
		ALBEDO = outline_color;
		has_outline += 1.0;
	}
	if (has_outline < 0.1){
		ALPHA = 0.0;
	}
}