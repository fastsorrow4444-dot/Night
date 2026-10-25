shader_type canvas_item;
render_mode unshaded;
uniform float strength = 0.16;
float noise(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
    vec2 uv = UV;
    float edge = smoothstep(0.26, 0.81, length((uv - 0.5) * vec2(1.0, 0.85)));
    float grain = noise(uv * vec2(1440.0, 900.0) + mod(TIME, 10.0));
    COLOR = vec4(vec3(0.01, 0.035, 0.032), edge * 0.38 + grain * strength * 0.15);
}
