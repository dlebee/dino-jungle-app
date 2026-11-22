shader_type spatial;
// Brings a static (unrigged) dinosaur sculpture to life without bending its sculpted legs:
// body bob and sway, foot shuffle, slow tail swish, head nods, breathing.
// Works in the mesh's own space. The script measures the mesh and fills in the shape uniforms.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform vec4 albedo_color : source_color = vec4(1.0);

uniform int long_axis = 1;        // 0 = body runs along X, 1 = along Z
uniform float center_l = 0.0;     // middle of the body along the long axis
uniform float half_len = 1.0;
uniform float center_w = 0.0;     // middle across the body
uniform float y_min = 0.0;
uniform float height = 1.0;
uniform float head_sign = 1.0;    // which end of the long axis the head is on
uniform float hip = 0.38;         // legs are below this fraction of the height
uniform bool biped = false;
uniform float tail_amp = 1.0;     // swimmers swish harder

uniform float walk_t = 0.0;       // advances with distance walked
uniform float stride = 0.0;       // 0 standing .. 1 full stride
uniform float life_t = 0.0;       // always running (breathing, idle sway)

void vertex() {
	// Gentle "alive" motion for a sculpted pose: the body rises and sways with each step,
	// the tail swishes slowly, the head nods. Legs only shuffle a little at the feet, so the
	// sculpted legs never shear or stretch.
	float l = (long_axis == 0 ? VERTEX.x : VERTEX.z) - center_l;
	float w = (long_axis == 0 ? VERTEX.z : VERTEX.x) - center_w;
	float ln = l / half_len * head_sign;           // +1 at the head, -1 at the tail tip
	float yn = (VERTEX.y - y_min) / height;
	float side = w >= 0.0 ? 1.0 : -1.0;

	// Whole body: a soft bob twice per stride and a small side-to-side weight shift.
	// Feet stay planted (the bob fades out toward the ground).
	float above = smoothstep(0.05, hip, yn);
	float bob = (0.5 - 0.5 * cos(walk_t * 2.0)) * stride * height * 0.04 * above;
	float shift = sin(walk_t) * stride * half_len * 0.02 * above;

	// Feet: a small shuffle, only the lowest part of the legs, and never the tail or head ends.
	float foot = 1.0 - smoothstep(0.0, hip * 0.75, yn);
	float mid = smoothstep(0.9, 0.55, abs(ln));
	float phase = biped ? side * 1.5708 : (side * (ln > 0.0 ? 1.0 : -1.0) > 0.0 ? 0.0 : 3.14159);
	float dl = sin(walk_t + phase) * stride * foot * foot * mid * half_len * 0.09;
	float lift = max(0.0, cos(walk_t + phase)) * stride * foot * foot * mid * height * 0.06;

	// Tail: slow, smooth swish, growing toward the tip.
	float tailw = smoothstep(-0.3, -1.0, ln);
	float sw = sin(life_t * (0.9 + stride * 0.8) * mix(1.0, 1.8, step(1.5, tail_amp)) - ln * 1.6) * tailw * tailw * half_len * (0.08 + 0.03 * stride) * tail_amp;

	// Head and neck: nod with the steps; when standing, look around slowly.
	float headw = smoothstep(0.35, 1.0, ln) * smoothstep(0.3, 0.7, yn);
	float nod = sin(walk_t * 2.0 + 0.6) * stride * headw * height * 0.035 + sin(life_t * 0.8) * headw * height * 0.03;
	float look = sin(life_t * 0.5) * headw * headw * half_len * 0.08 * (1.0 - stride * 0.6);

	// Breathing: chest swells a touch.
	float breath = 1.0 + sin(life_t * 1.8) * 0.008 * smoothstep(0.9, 0.2, abs(ln)) * above;

	float dw = sw + look + shift;
	if (long_axis == 0) {
		VERTEX.x += dl * head_sign;
		VERTEX.z += dw;
		VERTEX.z = center_w + (VERTEX.z - center_w) * breath;
	} else {
		VERTEX.z += dl * head_sign;
		VERTEX.x += dw;
		VERTEX.x = center_w + (VERTEX.x - center_w) * breath;
	}
	VERTEX.y += bob + lift + nod;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo_color;
	ALBEDO = c.rgb;
	ROUGHNESS = 0.85;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
