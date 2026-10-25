shader_type canvas_item;
render_mode unshaded;
void fragment() {
    float shade = mix(0.97, 0.0, smoothstep(0.28, 0.83, UV.x));
    COLOR = vec4(0.035, 0.065, 0.066, shade);
}
