shader_type spatial;
render_mode unshaded;
uniform sampler2D reflection_texture : filter_linear;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void fragment() {
    vec3 reflected = texture(reflection_texture, vec2(1.0 - UV.x, UV.y)).rgb;
    float edge = smoothstep(0.38, 0.51, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
    float speckle = step(0.996, hash(floor(UV * 1400.0)));
    ALBEDO = reflected * vec3(0.95, 0.98, 0.97) * (1.0 - edge * 0.13) + vec3(speckle * 0.035);
}
