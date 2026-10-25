shader_type spatial;
render_mode diffuse_burley;
uniform vec4 concrete_color : source_color = vec4(0.24, 0.29, 0.27, 1.0);
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world_pos.xz;
    vec2 tile = abs(fract(p / 2.0) - 0.5);
    float seam = step(0.492, max(tile.x, tile.y));
    float grain = hash(floor(p * 95.0));
    float stains = hash(floor(p * 1.5));
    ALBEDO = concrete_color.rgb * (0.79 + grain * 0.18 + stains * 0.08) * (1.0 - seam * 0.5);
    ROUGHNESS = 0.86;
}
