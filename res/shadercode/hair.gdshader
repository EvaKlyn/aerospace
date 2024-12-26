shader_type spatial;

uniform sampler2D _base_color: source_color, hint_default_black;
uniform float _sharpness: hint_range(0.0, 0.99) = 0.0;
uniform float _thinness: hint_range(0.0, 0.99) = 0.0;
uniform float _density: hint_range(0.0, 200) = 15.7;
uniform float _smoothness: hint_range(-1.0, 0.0) = -0.9;
uniform float _blur: hint_range(0.0, 1.0) = 0.6;
uniform float _height: hint_range(-0.3, 0.4) = 0.0;
uniform float _transparency_0: hint_range(0.0, 1.0) = 0.0;
uniform float _spaces: hint_range(-50.0, 0.0) = -25.6;
uniform float _detail: hint_range(0.0, 5.0) = 1.0;
uniform float _transparency_1: hint_range(0.0, 100.0) = 4.1;
uniform float _overlay_shadow: hint_range(0.0, 1.0) = 0.0;
uniform float _overlaypure_color: hint_range(0.0, 1.0) = 0.0;
uniform float _overlay_hue: hint_range(0.0, 1.0) = 0.55;
uniform float _brightness: hint_range(0.0, 2.0) = 0.4;
uniform float _overlay_saturation: hint_range(0.0, 2.0) = 0.9;
uniform sampler2D _shadow_color: source_color, hint_default_black;
uniform float _shadow_size: hint_range(0.1, 1.0) = 0.57;
uniform float _shadow_opacity: hint_range(0.0, 1.0) = 1.0;
uniform float _shadow_transition: hint_range(0.001, 1.0) = 0.001;
uniform float _smooth_shadow: hint_range(0.0, 1.0) = 0.0;
uniform float _rotate_90_degrees: hint_range(0.0, 1.0) = 0.0;
uniform sampler2D _normal_map: hint_normal;
uniform float _normal_strength: hint_range(0.0, 20.0) = 0.15;

uniform sampler2D _highlight_gradient_1;
uniform sampler2D _highlight_gradient_2;

varying float highlight_ramp;
varying vec4 hsv_overlay;
varying vec4 shadow_color;

vec3 mod289(vec3 x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289_vec4(vec4 x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x)
{
	return mod289_vec4(((x*34.0)+10.0)*x);
}

vec4 taylorInvSqrt(vec4 r)
{
	return 1.79284291400159 - 0.85373472095314 * r;
}

vec3 fade(vec3 t) {
	return t*t*t*(t*(t*6.0-15.0)+10.0);
}

// Classic Perlin noise
float cnoise(vec3 P)
{
	vec3 Pi0 = floor(P); // Integer part for indexing
	vec3 Pi1 = Pi0 + vec3(1.0); // Integer part + 1
	Pi0 = mod289(Pi0);
	Pi1 = mod289(Pi1);
	vec3 Pf0 = fract(P); // Fractional part for interpolation
	vec3 Pf1 = Pf0 - vec3(1.0); // Fractional part - 1.0
	vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
	vec4 iy = vec4(Pi0.yy, Pi1.yy);
	vec4 iz0 = Pi0.zzzz;
	vec4 iz1 = Pi1.zzzz;

	vec4 ixy = permute(permute(ix) + iy);
	vec4 ixy0 = permute(ixy + iz0);
	vec4 ixy1 = permute(ixy + iz1);

	vec4 gx0 = ixy0 * (1.0 / 7.0);
	vec4 gy0 = fract(floor(gx0) * (1.0 / 7.0)) - 0.5;
	gx0 = fract(gx0);
	vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
	vec4 sz0 = step(gz0, vec4(0.0));
	gx0 -= sz0 * (step(0.0, gx0) - 0.5);
	gy0 -= sz0 * (step(0.0, gy0) - 0.5);

	vec4 gx1 = ixy1 * (1.0 / 7.0);
	vec4 gy1 = fract(floor(gx1) * (1.0 / 7.0)) - 0.5;
	gx1 = fract(gx1);
	vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
	vec4 sz1 = step(gz1, vec4(0.0));
	gx1 -= sz1 * (step(0.0, gx1) - 0.5);
	gy1 -= sz1 * (step(0.0, gy1) - 0.5);

	vec3 g000 = vec3(gx0.x,gy0.x,gz0.x);
	vec3 g100 = vec3(gx0.y,gy0.y,gz0.y);
	vec3 g010 = vec3(gx0.z,gy0.z,gz0.z);
	vec3 g110 = vec3(gx0.w,gy0.w,gz0.w);
	vec3 g001 = vec3(gx1.x,gy1.x,gz1.x);
	vec3 g101 = vec3(gx1.y,gy1.y,gz1.y);
	vec3 g011 = vec3(gx1.z,gy1.z,gz1.z);
	vec3 g111 = vec3(gx1.w,gy1.w,gz1.w);

	vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
	g000 *= norm0.x;
	g010 *= norm0.y;
	g100 *= norm0.z;
	g110 *= norm0.w;
	vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
	g001 *= norm1.x;
	g011 *= norm1.y;
	g101 *= norm1.z;
	g111 *= norm1.w;

	float n000 = dot(g000, Pf0);
	float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
	float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
	float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
	float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
	float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
	float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
	float n111 = dot(g111, Pf1);

	vec3 fade_xyz = fade(Pf0);
	vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
	vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
	float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x);
	return 2.2 * n_xyz;
}

// Classic Perlin noise, periodic variant
float pnoise(vec3 P, vec3 rep)
{
	vec3 Pi0 = mod(floor(P), rep); // Integer part, modulo period
	vec3 Pi1 = mod(Pi0 + vec3(1.0), rep); // Integer part + 1, mod period
	Pi0 = mod289(Pi0);
	Pi1 = mod289(Pi1);
	vec3 Pf0 = fract(P); // Fractional part for interpolation
	vec3 Pf1 = Pf0 - vec3(1.0); // Fractional part - 1.0
	vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
	vec4 iy = vec4(Pi0.yy, Pi1.yy);
	vec4 iz0 = Pi0.zzzz;
	vec4 iz1 = Pi1.zzzz;

	vec4 ixy = permute(permute(ix) + iy);
	vec4 ixy0 = permute(ixy + iz0);
	vec4 ixy1 = permute(ixy + iz1);

	vec4 gx0 = ixy0 * (1.0 / 7.0);
	vec4 gy0 = fract(floor(gx0) * (1.0 / 7.0)) - 0.5;
	gx0 = fract(gx0);
	vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
	vec4 sz0 = step(gz0, vec4(0.0));
	gx0 -= sz0 * (step(0.0, gx0) - 0.5);
	gy0 -= sz0 * (step(0.0, gy0) - 0.5);

	vec4 gx1 = ixy1 * (1.0 / 7.0);
	vec4 gy1 = fract(floor(gx1) * (1.0 / 7.0)) - 0.5;
	gx1 = fract(gx1);
	vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
	vec4 sz1 = step(gz1, vec4(0.0));
	gx1 -= sz1 * (step(0.0, gx1) - 0.5);
	gy1 -= sz1 * (step(0.0, gy1) - 0.5);

	vec3 g000 = vec3(gx0.x,gy0.x,gz0.x);
	vec3 g100 = vec3(gx0.y,gy0.y,gz0.y);
	vec3 g010 = vec3(gx0.z,gy0.z,gz0.z);
	vec3 g110 = vec3(gx0.w,gy0.w,gz0.w);
	vec3 g001 = vec3(gx1.x,gy1.x,gz1.x);
	vec3 g101 = vec3(gx1.y,gy1.y,gz1.y);
	vec3 g011 = vec3(gx1.z,gy1.z,gz1.z);
	vec3 g111 = vec3(gx1.w,gy1.w,gz1.w);

	vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
	g000 *= norm0.x;
	g010 *= norm0.y;
	g100 *= norm0.z;
	g110 *= norm0.w;
	vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
	g001 *= norm1.x;
	g011 *= norm1.y;
	g101 *= norm1.z;
	g111 *= norm1.w;

	float n000 = dot(g000, Pf0);
	float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
	float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
	float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
	float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
	float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
	float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
	float n111 = dot(g111, Pf1);

	vec3 fade_xyz = fade(Pf0);
	vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
	vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
	float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x);
	return 2.2 * n_xyz;
}

vec3 rotate_around_axis(vec3 p, vec3 axis, float angle)
{
	float costheta = cos(angle);
	float sintheta = sin(angle);
	vec3 r;

	r.x = ((costheta + (1.0 - costheta) * axis.x * axis.x) * p.x) +
		(((1.0 - costheta) * axis.x * axis.y - axis.z * sintheta) * p.y) +
		(((1.0 - costheta) * axis.x * axis.z + axis.y * sintheta) * p.z);

	r.y = (((1.0 - costheta) * axis.x * axis.y + axis.z * sintheta) * p.x) +
		((costheta + (1.0 - costheta) * axis.y * axis.y) * p.y) +
		(((1.0 - costheta) * axis.y * axis.z - axis.x * sintheta) * p.z);

	r.z = (((1.0 - costheta) * axis.x * axis.z - axis.y * sintheta) * p.x) +
		(((1.0 - costheta) * axis.y * axis.z + axis.x * sintheta) * p.y) +
		((costheta + (1.0 - costheta) * axis.z * axis.z) * p.z);

	return r;
}

vec3 vector_rotate_axis_angle(vec3 vector_in, vec3 center, vec3 axis, float angle, vec3 rotation, float invert)
{
	return (length(axis) != 0.0) ?
			rotate_around_axis(vector_in - center, normalize(axis), angle * invert) + center :
			vector_in;
}

// Noise
uint rot(uint x, uint k)
{
	return (((x) << (k)) | ((x) >> (32u - (k))));
}

void final(inout uint a, inout uint b, inout uint c)
{
	c ^= b;
	c -= rot(b, 14u);
	a ^= c;
	a -= rot(c, 11u);
	b ^= a;
	b -= rot(a, 25u);
	c ^= b;
	c -= rot(b, 16u);
	a ^= c;
	a -= rot(c, 4u);
	b ^= a;
	b -= rot(a, 14u);
	c ^= b;
	c -= rot(b, 24u);
}

uint hash_uint2(uint kx, uint ky)
{
	uint a, b, c;
	a = b = c = uint(0xdeadbeef) + (2u << 2u) + 13u;

	b += ky;
	a += kx;
	final(a, b, c);

	return c;
}

float hash_uint2_to_float(uint kx, uint ky)
{
	return float(hash_uint2(kx, ky)) / float(0xFFFFFFFF);
}

float hash_vec2_to_float(vec2 k)
{
	return hash_uint2_to_float(floatBitsToUint(k.x), floatBitsToUint(k.y));
}

vec3 random_vec3_offset(float seed)
{
	return vec3(100.0 + hash_vec2_to_float(vec2(seed, 0.0)) * 100.0,
				100.0 + hash_vec2_to_float(vec2(seed, 1.0)) * 100.0,
				100.0 + hash_vec2_to_float(vec2(seed, 2.0)) * 100.0);
}

float noise_scale3(float result)
{
	return 0.9820 * result;
}

float snoise(vec3 p)
{
	float r = pnoise(p, vec3(0.0));
	return (isinf(r)) ? 0.0 : noise_scale3(r);
}

float noise(vec3 p)
{
	return 0.5 * snoise(p) + 0.5;
}

float fractal_noise(vec3 p, float octaves, float roughness)
{
	float fscale = 1.0;
	float amp = 1.0;
	float maxamp = 0.0;
	float sum = 0.0;
	octaves = clamp(octaves, 0.0, 15.0);
	int n = int(octaves);
	for (int i = 0; i <= n; i++) {
		float t = noise(fscale * p);
		sum += t * amp;
		maxamp += amp;
		amp *= clamp(roughness, 0.0, 1.0);
		fscale *= 2.0;
	}
	float rmd = octaves - floor(octaves);
	if (rmd != 0.0) {
		float t = noise(fscale * p);
		float sum2 = sum + t * amp;
		sum /= maxamp;
		sum2 /= maxamp + amp;
		return (1.0 - rmd) * sum + rmd * sum2;
	}
	else {
		return sum / maxamp;
	}
}

vec4 noise_texture_3d(vec3 co,
	float scale,
	float detail,
	float roughness)
{
	vec3 p = co * scale;
	vec3 rep = vec3(0.0);

	float value = fractal_noise(p, detail, roughness);
	return vec4(value,
				fractal_noise(p + random_vec3_offset(3.0), detail, roughness),
				fractal_noise(p + random_vec3_offset(4.0), detail, roughness),
				1.0);
}
// Noise end

vec4 brightness_contrast(vec4 col, float brightness, float contrast)
{
	float a = 1.0 + contrast;
	float b = brightness - contrast * 0.5;

	vec4 outcol;
	outcol.r = max(a * col.r + b, 0.0);
	outcol.g = max(a * col.g + b, 0.0);
	outcol.b = max(a * col.b + b, 0.0);
	outcol.a = col.a;
	return outcol;
}

float rgbtobw(vec4 color)
{
	vec3 factors = vec3(0.2126, 0.7152, 0.0722);
	return dot(color.rgb, factors);
}

vec3 normal_map_mix(float strength, vec3 newnormal, in vec3 orinormal)
{
	return normalize(mix(orinormal, newnormal, max(strength, 0.0)));
}

float map_range(float value, float from_left, float from_right, float to_left, float to_right) {
	float clamp_value = clamp(value, from_left, from_right);
	return (clamp_value - from_left) / (from_right - from_left) * (to_right - to_left) + to_left;
}

void rgb_to_hsv(vec4 rgb, out vec4 outcol)
{
	float cmax, cmin, h, s, v, cdelta;
	vec3 c;

	cmax = max(rgb[0], max(rgb[1], rgb[2]));
	cmin = min(rgb[0], min(rgb[1], rgb[2]));
	cdelta = cmax - cmin;

	v = cmax;
	if (cmax != 0.0) {
		s = cdelta / cmax;
	}
	else {
		s = 0.0;
		h = 0.0;
	}

	if (s == 0.0) {
		h = 0.0;
	}
	else {
		c = (vec3(cmax) - rgb.xyz) / cdelta;

		if (rgb.x == cmax) {
			h = c[2] - c[1];
		}
		else if (rgb.y == cmax) {
			h = 2.0 + c[0] - c[2];
		}
		else {
			h = 4.0 + c[1] - c[0];
		}

		h /= 6.0;

		if (h < 0.0) {
			h += 1.0;
		}
	}

	outcol = vec4(h, s, v, rgb.w);
}

void hsv_to_rgb(vec4 hsv, out vec4 outcol)
{
	float i, f, p, q, t, h, s, v;
	vec3 rgb;

	h = hsv[0];
	s = hsv[1];
	v = hsv[2];

	if (s == 0.0) {
		rgb = vec3(v, v, v);
	}
	else {
		if (h == 1.0) {
			h = 0.0;
		}

		h *= 6.0;
		i = floor(h);
		f = h - i;
		rgb = vec3(f, f, f);
		p = v * (1.0 - s);
		q = v * (1.0 - (s * f));
		t = v * (1.0 - (s * (1.0 - f)));

		if (i == 0.0) {
			rgb = vec3(v, t, p);
		}
		else if (i == 1.0) {
			rgb = vec3(q, v, p);
		}
		else if (i == 2.0) {
			rgb = vec3(p, v, t);
		}
		else if (i == 3.0) {
			rgb = vec3(p, q, v);
		}
		else if (i == 4.0) {
			rgb = vec3(t, p, v);
		}
		else {
			rgb = vec3(v, p, q);
		}
	}

	outcol = vec4(rgb, hsv.w);
}

vec4 composite_hue_saturation_value(
	vec4 color, float hue, float saturation, float value, float factor)
{
	vec4 hsv;
	rgb_to_hsv(color, hsv);

	hsv.x = fract(hsv.x + hue + 0.5);
	hsv.y = hsv.y * saturation;
	hsv.z = hsv.z * value;

	vec4 result;
	hsv_to_rgb(hsv, result);
	result.rgb = max(result.rgb, vec3(0.0));

	return mix(color, result, factor);
}


//void vertex() {
//}

void fragment() {
	float temp_f0, temp_f1, temp_f2;
	vec4 color_0, color_1;

	// highlight
	vec2 uv_fy = vec2(UV.x, 1.0 - UV.y);
	vec3 rot_uv;
	rot_uv = vector_rotate_axis_angle(vec3(uv_fy, 0.0), vec3(0.0), vec3(0.0, 0.0, 1.0), 90, vec3(0.0), 1.0);
	vec2 final_uv = mix(uv_fy, rot_uv.xy, _rotate_90_degrees); // here is mix color origin
	vec4 bc_noise_color;
	color_0 = noise_texture_3d(vec3(final_uv.x), _spaces, _detail, 1.0);
	bc_noise_color = brightness_contrast(color_0, _height, _transparency_1);
	color_0 = noise_texture_3d(vec3(final_uv.x), _density, 0.0, 0.0);
	temp_f0 = color_0.r;
	color_1 = brightness_contrast(color_0, _height, _smoothness);
	temp_f0 = rgbtobw(color_1);
	temp_f0 += -0.5 + final_uv.y;
	vec4 vec_0 = VIEW_MATRIX * vec4(0.0, -1.0, 0.0, 0.0);
	temp_f1 = (-vec_0.z - 0.3) * 0.25;
	temp_f0 -= temp_f1;
	vec4 g1 = texture(_highlight_gradient_1, vec2(temp_f0, 0.5));
	vec4 g2 = texture(_highlight_gradient_2, vec2(temp_f0, 0.5));
	color_0 = mix(g1, g2, _blur);
	temp_f2 = rgbtobw(color_0);
	temp_f0 = rgbtobw(bc_noise_color);
	temp_f1 = map_range(temp_f0, _sharpness, 1.0, 1.0, 0.1);
	temp_f0 = clamp(temp_f2 * temp_f1 - _overlay_shadow, 0.0, 1.0);
	highlight_ramp = clamp((temp_f0 - _thinness) / (1.0 - _thinness), 0.0, 1.0);
	NORMAL = normal_map_mix(_normal_strength, texture(_normal_map, UV).rgb, NORMAL);

	hsv_overlay = vec4(0.0);
	hsv_overlay = composite_hue_saturation_value(vec4(1.0, 0.0, 0.0, 1.0), _overlay_hue, _overlay_saturation, _brightness, 1.0);

	ALBEDO = texture(_base_color, UV).rgb;
	vec4 base_color = vec4(ALBEDO, 1.0);
	shadow_color = texture(_shadow_color, UV);
}

void light() {
	vec4 color_0, color_1;
	float temp_f0, temp_f1;
	vec4 base_color = vec4(ALBEDO, 1.0);
	float light_shadow_rate = map_range(dot(NORMAL, LIGHT), -1.0, 1.0, 0.0, 1.0) * ATTENUATION;
	vec4 color = vec4((light_shadow_rate * (vec4(LIGHT_COLOR, 1.0)) * base_color).rgb, 1.0);
	vec4 mix_base_color;
	mix_base_color = mix(color, base_color, 0.5);
	color_0 = mix_base_color + hsv_overlay;
	color_1 = mix(color_0, hsv_overlay, _overlaypure_color);
	temp_f0 = clamp(highlight_ramp, 0.0, 1.0);
	color_0 = mix(mix_base_color, color_1, temp_f0);
	vec4 light_part;
	light_part = mix(color_0, hsv_overlay, _transparency_0);

	temp_f0 = clamp(_shadow_size + _shadow_transition, 0.0, 1.0);
	float map_shadow_rate = map_range(light_shadow_rate, _shadow_size, temp_f0, 0.0, 1.0);
	color_0 = mix(mix_base_color, shadow_color, _shadow_opacity);
	color_1 = brightness_contrast(vec4(vec3(light_shadow_rate), 1.0), 0.0, -0.5);
	color_1 *= color_0;
	vec4 shadow_part;
	shadow_part = mix(color_1, mix_base_color, _smooth_shadow);

	color_0 = mix(shadow_part, light_part, map_shadow_rate);
	DIFFUSE_LIGHT += color_0.rgb / ALBEDO;
}