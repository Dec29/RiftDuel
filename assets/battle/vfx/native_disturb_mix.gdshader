shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform sampler2D main_texture : filter_linear, repeat_enable;
uniform sampler2D disturb_texture : filter_linear, repeat_enable;
uniform vec4 main_st=vec4(1.,1.,0.,0.);
uniform vec4 disturb_st=vec4(1.,1.,0.,0.);
uniform vec4 tint=vec4(1.);
uniform vec2 intensity=vec2(0.);
uniform float end_fade=1.;
uniform vec2 main_velocity=vec2(0.);
uniform vec2 disturb_velocity=vec2(0.);
instance uniform float source_time=0.;
instance uniform float presentation_gain=1.;
varying vec4 vcolor;
varying vec2 source_uv;
void vertex(){vcolor=COLOR;source_uv=UV;}
void fragment(){
 // Source D3D11: uncentred red channel offsets both Main UV axes before Main ST.
 vec2 duv=source_uv*disturb_st.xy+disturb_st.zw+disturb_velocity*source_time;
 float red=texture(disturb_texture,vec2(duv.x,1.-duv.y)).r;
 vec2 uv=(source_uv+red*intensity)*main_st.xy+main_st.zw+main_velocity*source_time;
 vec4 tex=texture(main_texture,vec2(uv.x,1.-uv.y));
 vec4 result=2.*tex*tint*vcolor*tint.a;
 COLOR=vec4(result.rgb,result.a*end_fade*presentation_gain);
}
