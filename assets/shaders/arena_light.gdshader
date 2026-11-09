shader_type canvas_item;
uniform bool reduced_motion = false;
uniform bool low_effects = false;
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	if (!low_effects) {
	float left_fire = exp(-length((UV-vec2(0.075,0.37))*vec2(8.0,5.0)));
	float right_fire = exp(-length((UV-vec2(0.94,0.57))*vec2(8.0,5.0)));
	float clock = reduced_motion ? 0.0 : TIME;
	float flicker = 0.75+0.12*sin(clock*3.7)+0.08*sin(clock*7.1);
	vec3 warmth = vec3(0.25,0.10,0.025)*(left_fire+right_fire)*flicker;
	float moon = exp(-length((UV-vec2(0.48,0.08))*vec2(3.0,4.0)));
	art.rgb += warmth+vec3(0.025,0.04,0.052)*moon;
	}
	COLOR = art;
}
