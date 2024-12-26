//Copyright 2024 Emerson Rowland
//CC0 License
shader_type spatial;

render_mode depth_prepass_alpha,cull_disabled,diffuse_burley,specular_schlick_ggx;

group_uniforms General;
uniform float alpha_scissor_threshold : hint_range(0,1) = 0.4;
uniform float specular : hint_range(0,1) = 0.4;
uniform float roughness : hint_range(0,1) = 0.85;
uniform float face_tint : hint_range(0.0, 1.0, 0.01) = 0.2;
group_uniforms;

group_uniforms Leaf;
uniform sampler2D Leaf_Texture : source_color,filter_linear_mipmap;
uniform sampler2D Leaf_Texture_Normal : hint_normal,filter_linear_mipmap;
uniform vec2 Leaf_UV_Scale = vec2(1,1);
uniform vec3 Leaf_Tint_Base : source_color = vec3(0.0);
uniform vec3 Leaf_Tint_Highlight : source_color = vec3(1.0);
uniform float Leaf_Tint_Str : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform bool Texture_As_Brightness = true;
uniform float Brightness : hint_range(1.0, 16.0, 0.01) = 8.0;
group_uniforms;

group_uniforms Leaf.Emmision;
uniform vec3 Leaf_Emmisive_Color : source_color = vec3(0.0, 0.0, 0.0);
uniform float Leaf_Emissive_Str : hint_range(0.0, 2.0, 0.01) = 0.0;
uniform sampler2D Leaf_Emmisive_Mask : hint_default_black, filter_linear_mipmap;
group_uniforms;

group_uniforms Trunk;
uniform sampler2D Trunk_Texture : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D Trunk_Texture_Normal : hint_normal,filter_linear_mipmap,repeat_enable;
uniform vec2 Trunk_UV_Scale = vec2(1,1);
uniform vec3 Trunk_Tint : source_color = vec3(0.0);
uniform float Trunk_Tint_Str : hint_range(0.0, 1.0, 0.01) = 0.0;
group_uniforms;

group_uniforms Frost;
uniform bool F_Texture_As_Brightness = true;
uniform float F_Brightness : hint_range(1.0, 16.0, 0.01) = 8.0;
uniform float frost_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float frost_fade : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform vec3 Frost_Color : source_color = vec3(1.0);
group_uniforms;

group_uniforms Wind;
uniform bool Wind_Enable = true;
uniform sampler2D wind_noise : filter_linear_mipmap,repeat_enable;
uniform vec3 wind_color_shift : source_color = vec3(0.0);
uniform float wind_color_strength : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float wind_strength : hint_range(0.0, 1.0, 0.01) = 0.33;
uniform float wind_direction_rads : hint_range(-3.141, 3.141, 0.01) = 0.0;
uniform float sway_multiplier : hint_range(0.0, 4.0, 0.01) = 2.0;
uniform float jitter_multiplier : hint_range(0.0, 4.0, 0.01) = 2.0;
uniform float deform_multiplier : hint_range(0.0, 4.0, 0.01) = 2.0;
uniform float bend_multiplier : hint_range(0.0, 4.0, 0.1) = 2.0;
group_uniforms;

varying mat3 TanBiNorm;
varying vec3 world_normal;
varying float wind_darken;
varying vec3 global_position;

//useful to let texture details push through mix ops
float luminance(vec3 L) {
	return (0.299*L.r + 0.587*L.g + 0.114*L.b);
}

//for wind offsets
float rand3(vec3 input) {
	return fract(sin(dot(input.xyz, vec3(12.9898, 78.233, 45.543))) * 43758.5453123);
}

//for wind bending
//adapted from https://iquilezles.org/articles/noacos/
mat3 vectoralign(vec3 a, vec3 b) {
    vec3  v = cross( b, a );
    float c = dot( b, a );
    float k = 1.0/(1.0+c);
    return mat3(
		vec3(v.x*v.x*k + c,		v.y*v.x*k - v.z,	v.z*v.x*k + v.y),
		vec3(v.x*v.y*k + v.z,	v.y*v.y*k + c,		v.z*v.y*k - v.x),
		vec3(v.x*v.z*k - v.y,	v.y*v.z*k + v.x,	v.z*v.z*k + c)
	);
}

void vertex() {
	/*  for multimesh need to read global position after generation of MODEL_MATRIX,
	reading NODE_POSITION_WORLD will return the multimesh node position  */
	global_position = MODEL_MATRIX[3].xyz;

	//pre-calcs for world space frost
	TanBiNorm = MODEL_NORMAL_MATRIX * mat3(TANGENT, NORMAL, BINORMAL);
	TanBiNorm[0] = normalize(TanBiNorm[0]);
	TanBiNorm[1] = normalize(TanBiNorm[1]);
	TanBiNorm[2] = normalize(TanBiNorm[2]);
	//for face tint
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);

	wind_darken = 1.0;
	if ( Wind_Enable == true ) {
		//wind effect strength & direction
		float wind_weight = COLOR.r;
		float wind_time = TIME*20.0*wind_strength;
		vec2 wind_direction = vec2(cos(wind_direction_rads),sin(wind_direction_rads)) * -1.0;
		wind_direction = (vec4(wind_direction.x,1.0,wind_direction.y,1.0) * MODEL_MATRIX ).xz;

		//to fix issues when scaling.
		vec3 scale = vec3(length(MODEL_MATRIX[0]), length(MODEL_MATRIX[1]), length(MODEL_MATRIX[2]));
		float mono_scale = length(scale);

		//uv to sample wind per vertex for deform/jitter use global space for wind darkening
		vec2 wind_uv = (global_position.xz + VERTEX.xz + (-wind_direction * wind_time)) * 0.01;
		//uv to sample wind at model global position for sway/bend provides offset for each model too
		vec2 sway_uv = (global_position.xz + (-wind_direction * wind_time)) * 0.01;
		//noise reads with texture lods to smooth out sway/bend and low wind strength
		float wind_gust = textureLod(wind_noise,wind_uv*2.0 / mono_scale,4.0 - 4.0 * wind_strength).r ;
		float sway_gust = textureLod(wind_noise,sway_uv*0.25 / mono_scale,4.0).r ;

		//leaf jitter
		float LeafNoise = mix( sin(rand3(VERTEX.xyz) * (TIME * 5.0 + wind_time + (wind_gust+sway_gust) * 3.0) ) , 0.0, 1.0-COLOR.b) * 0.5;
		vec3 leaf_jitter = vec3(LeafNoise * wind_direction.x,LeafNoise*(rand3(VERTEX)-0.5),LeafNoise * wind_direction.y) * wind_weight;
		//wind sway
		vec2 sway = sway_gust * wind_direction * wind_weight * sway_multiplier;
		//wind deform
		vec2 deform = wind_gust * wind_direction * deform_multiplier * mix(COLOR.r,COLOR.b,wind_strength * 0.5);
		//wind bend
		vec2 bend = wind_direction * (sway_gust -0.25) * wind_weight * wind_strength;

		//tweak with multipliers, adjust for scaling
		deform *= deform_multiplier / mono_scale;
		sway *= sway_multiplier / mono_scale;
		leaf_jitter *= jitter_multiplier / mono_scale;
		bend *= bend_multiplier / mono_scale;

		//apply bend first so other wind efects are not transformed
		vec3 bend_out = normalize(vec3(bend.x,1.0,bend.y));
		VERTEX = vectoralign(vec3(0.0,1.0,0.0),bend_out) * VERTEX;
		NORMAL = vectoralign(vec3(0.0,1.0,0.0),bend_out) * NORMAL;

		//add the remaining wind to the bent vertex
		vec3 wind_vertex = (leaf_jitter + vec3( deform.x + sway.x,0.0,deform.y + sway.y)) * wind_strength;
		VERTEX += wind_vertex;
		wind_darken = (wind_gust + sway_gust) * 0.5;
	}
}

void fragment() {
	//init
	vec2 base_uv = COLOR.b > 0.5 ? UV*Leaf_UV_Scale: UV*Trunk_UV_Scale;
	vec4 leaf_trunk_tex = COLOR.b > 0.5 ? texture(Leaf_Texture,base_uv) : texture(Trunk_Texture,base_uv);
	vec3 leaf_emmisive = COLOR.b > 0.5 ? Leaf_Emmisive_Color * texture(Leaf_Emmisive_Mask,base_uv).rgb : vec3(0.0);
	vec4 leaf_trunk_normal = COLOR.b > 0.5 ? texture(Leaf_Texture_Normal,base_uv) : texture(Trunk_Texture_Normal,base_uv);
	float lumin = COLOR.b > 0.5 ? luminance(leaf_trunk_tex.rgb) : 1.0;
	lumin = clamp(lumin,0.0,1.0);

	//colour tinting
	vec3 leaf_tint = mix(Leaf_Tint_Base,Leaf_Tint_Highlight,COLOR.g);
	float leaf_lumin = Texture_As_Brightness == true ? lumin * Brightness : 1.0;
	leaf_trunk_tex.rgb = (
		COLOR.b > 0.5 ?
		mix(leaf_trunk_tex.rgb,leaf_tint * leaf_lumin,Leaf_Tint_Str) :
		mix(leaf_trunk_tex.rgb,Trunk_Tint,Trunk_Tint_Str)
	);

	//frosting
	vec3 base_normal_aligned = leaf_trunk_normal.xzy * 2.0 - 1.0;
	base_normal_aligned = TanBiNorm * base_normal_aligned;
	float mask = base_normal_aligned.y;
	float frost_str = ((1.0 - frost_amount) * 2.2 - 1.2);
	mask = smoothstep(frost_str,frost_str + frost_fade,mask);
	float frost_lumin = F_Texture_As_Brightness == true ? lumin * F_Brightness : 1.0;
	leaf_trunk_tex.rgb = COLOR.b > 0.5 ? mix(leaf_trunk_tex.rgb,Frost_Color * frost_lumin, mask) : mix(leaf_trunk_tex.rgb,Frost_Color, mask);

	//per face tint
	float face = sin(world_normal.y*16.0);
	leaf_trunk_tex.rgb = COLOR.b < 0.5 ? mix(leaf_trunk_tex.rgb, leaf_trunk_tex.rgb * face,face_tint) : leaf_trunk_tex.rgb;

	//wind darkening
	if (Wind_Enable) {
		leaf_trunk_tex.rgb = COLOR.b < 0.5 ? leaf_trunk_tex.rgb : mix( leaf_trunk_tex.rgb, wind_color_shift, clamp(((wind_darken*4.0-2.0)*wind_color_strength),0.0,1.0) ) ;
	}

	//output
	SPECULAR = specular;
	NORMAL_MAP = leaf_trunk_normal.rgb;
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL; //for foliage specifically, undo inverted normals for backside
	ROUGHNESS = roughness;
	ALBEDO = leaf_trunk_tex.rgb;
	ALPHA = leaf_trunk_tex.a;
	EMISSION = leaf_emmisive.rgb * Leaf_Emissive_Str;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}