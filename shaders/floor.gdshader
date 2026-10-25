shader_type spatial;
render_mode diffuse_burley;
uniform vec4 concrete_color : source_color = vec4(0.25, 0.26, 0.25, 1.0);
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p=world_pos.xz;
    vec2 slab=fract(p/vec2(3.4,2.8));
    vec2 edge=min(slab,1.0-slab)*vec2(3.4,2.8);
    float distance=min(edge.x,edge.y);
    float joint=1.0-smoothstep(0.002,0.007+fwidth(distance),distance);
    float mottling=noise(p*0.75)*0.10+noise(p*4.0)*0.045+noise(p*55.0)*0.025;
    float oil=smoothstep(0.66,0.90,noise(p*0.45)+noise(p*2.4)*0.12);
    ALBEDO=concrete_color.rgb*(0.87+mottling)*(1.0-joint*0.38)*(1.0-oil*0.12);
    ROUGHNESS=0.88-oil*0.17;
}
