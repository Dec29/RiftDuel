shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D main_texture : filter_linear, repeat_enable;
uniform sampler2D mask_texture : filter_linear, repeat_enable;
uniform sampler2D add_texture : filter_linear, repeat_enable;
uniform vec4 main_st = vec4(1.,1.,0.,0.);
uniform vec4 add_st = vec4(1.,1.,0.,0.);
uniform vec4 tint = vec4(1.);
uniform float add_factor = 1.;
uniform float end_fade = 1.;
instance uniform float presentation_gain = 1.;
varying vec4 vcolor;
varying vec2 source_uv;
void vertex(){vcolor=COLOR;source_uv=UV;}
void fragment(){
 // Original D3D11 program: Mask shares Main UV; only Add has a separate ST.
 vec2 uv=source_uv*main_st.xy+main_st.zw;
 vec2 auv=source_uv*add_st.xy+add_st.zw;
 vec4 main_sample=texture(main_texture,vec2(uv.x,1.-uv.y));
 float mask_alpha=texture(mask_texture,vec2(uv.x,1.-uv.y)).a;
 vec4 added=texture(add_texture,vec2(auv.x,1.-auv.y));
 vec4 result=(main_sample+2.*added*mask_alpha*add_factor)*(2.*vcolor*tint);
 COLOR=vec4(result.rgb,clamp(result.a,0.,1.)*end_fade*presentation_gain);
}
