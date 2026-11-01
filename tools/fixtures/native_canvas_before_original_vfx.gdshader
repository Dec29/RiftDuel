shader_type canvas_item;
render_mode blend_premul_alpha;

// Atlas UVs are in [0, 1]. Native additive slots carry a +2 U marker.
// Ordinary canvas commands remain the same straight-alpha image after premultiplication.
varying float native_additive;
void vertex() {
    native_additive = step(1.5, UV.x);
    UV.x -= 2.0 * native_additive;
}
void fragment() {
    COLOR.rgb *= COLOR.a;
    COLOR.a *= 1.0 - native_additive;
}
