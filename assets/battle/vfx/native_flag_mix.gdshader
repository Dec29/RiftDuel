shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform sampler2D main_texture:filter_linear,repeat_enable;
uniform vec4 main_st=vec4(1.,1.,0.,0.);
uniform vec4 tint=vec4(1.);
uniform float cutoff=.39;
uniform float end_fade=1.;
instance uniform float presentation_gain=1.;
varying vec4 vcolor;
void vertex(){vcolor=COLOR;}
void fragment(){
 vec2 at=UV*main_st.xy+main_st.zw;
 vec4 result=texture(main_texture,vec2(at.x,1.-at.y))*vcolor*tint;
 if(result.a<cutoff){discard;}
 // Original SimSpine uses source ONE; its output is already the source blend value.
 COLOR=result*end_fade*presentation_gain;
}
