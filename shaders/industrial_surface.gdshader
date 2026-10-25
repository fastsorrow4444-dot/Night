shader_type spatial;
uniform vec4 paint_color : source_color = vec4(0.3,0.35,0.36,1.0);
uniform float metal_amount = 0.0;
varying vec3 surface_pos;
varying vec3 object_normal;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
    vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { surface_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;object_normal=NORMAL; }
void fragment() {
    float grain=noise(surface_pos*38.0);
    float age=noise(surface_pos*2.5);
    float corner=1.0-max(abs(object_normal.x),max(abs(object_normal.y),abs(object_normal.z)));
    float wear=smoothstep(0.08,0.24,corner)*smoothstep(0.38,0.68,grain)*metal_amount;
    vec3 paint=paint_color.rgb*(0.93+grain*0.05+age*0.035);
    ALBEDO=mix(paint,vec3(0.37,0.38,0.36),wear*0.6);
    METALLIC=metal_amount*(0.18+wear*0.5);
    ROUGHNESS=mix(0.86,0.42,wear);
}
