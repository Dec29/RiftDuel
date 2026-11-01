shader_type canvas_item;
render_mode blend_premul_alpha;

// Atlas UVs are in [0, 1]. Native additive slots carry a +2 U marker.
// Ordinary canvas commands remain the same straight-alpha image after premultiplication.
varying float native_additive;
varying float original_composite;
varying float prop_composite;
varying float command_alpha;
varying vec2 composite_uv;
uniform vec2 vfx_ball_center=vec2(-100.);
uniform float vfx_ball_radius=0.;
void vertex() {
    prop_composite=step(7.5,UV.x);
    UV.x-=8.*prop_composite;
    original_composite=step(3.5,UV.x);
    UV.x-=4.*original_composite;
    composite_uv=UV;
    command_alpha=COLOR.a;
    native_additive = step(1.5, UV.x);
    UV.x -= 2.0 * native_additive;
}
void fragment() {
    if(original_composite>0.5){
        float clarity=smoothstep(vfx_ball_radius,vfx_ball_radius+8.,distance(composite_uv*vec2(1280.,720.),vfx_ball_center));
        // Compress accumulated HDR highlights only in the original-effect composite.
        COLOR.rgb/=1.+max(COLOR.r,max(COLOR.g,COLOR.b));
        COLOR.rgb*=command_alpha*clarity;
        COLOR.a*=clarity;
    }else if(prop_composite<0.5){COLOR.rgb *= COLOR.a;}
    COLOR.a *= 1.0 - native_additive;
}
