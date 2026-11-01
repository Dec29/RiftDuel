shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D main_texture:filter_linear,repeat_enable;
uniform sampler2D disturb_texture:filter_linear,repeat_enable;
uniform sampler2D disturb2_texture:filter_linear,repeat_enable;
uniform sampler2D weight_texture:filter_linear,repeat_enable;
uniform sampler2D dissolve_texture:filter_linear,repeat_enable;
uniform vec4 main_st=vec4(1.,1.,0.,0.);
uniform vec4 disturb_st=vec4(1.,1.,0.,0.);
uniform vec4 disturb2_st=vec4(1.,1.,0.,0.);
uniform vec4 weight_st=vec4(1.,1.,0.,0.);
uniform vec4 dissolve_st=vec4(1.,1.,0.,0.);
uniform vec4 tint=vec4(1.);
uniform vec4 uv_tween=vec4(0.);
uniform vec2 intensity=vec2(0.);
uniform vec2 intensity2=vec2(0.);
uniform vec2 anchor_uv=vec2(.5);
uniform vec2 anchor2_uv=vec2(.5);
uniform bool use_weight=false;
uniform bool use_disturb2=false;
uniform bool use_dissolve=false;
uniform float alpha_control=1.;
uniform float amount=0.;
uniform float border=.1;
uniform float end_fade=1.;
uniform vec2 main_velocity=vec2(0.);
uniform vec2 disturb_velocity=vec2(0.);
instance uniform float source_time=0.;
instance uniform float presentation_gain=1.;
varying vec4 vcolor;
varying vec2 source_uv;
vec4 sample_uv(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.-uv.y));}
void vertex(){vcolor=COLOR;source_uv=UV;}
void fragment(){
 // Original D3D11 weighted/unweighted fragment programs; offsets precede Main ST.
 vec4 scroll=fract(uv_tween*source_time);
 float first=sample_uv(disturb_texture,source_uv*disturb_st.xy+disturb_st.zw+scroll.zw+disturb_velocity*source_time).r;
 vec2 weight=vec2(1.);
 if(use_weight){weight=sample_uv(weight_texture,source_uv*weight_st.xy+weight_st.zw).rg;}
 vec2 uv=source_uv+(vec2(first)-anchor_uv)*intensity*weight;
 if(use_disturb2){float second=sample_uv(disturb2_texture,source_uv*disturb2_st.xy+disturb2_st.zw).r;uv+=(vec2(second)-anchor2_uv)*intensity2*weight;}
 vec4 result=2.*sample_uv(main_texture,uv*main_st.xy+main_st.zw+scroll.xy+main_velocity*source_time)*tint*vcolor;
 result*=1.+alpha_control*(tint.a-1.);
 if(use_dissolve){
  float noise=sample_uv(dissolve_texture,uv*dissolve_st.xy+dissolve_st.zw).r;
  float x=amount+.5;float k=floor(x);float f=x-k;
  float rounded=f<.5?k:(f>.5?k+1.:(mod(k,2.)==0.?k:k+1.));
  result.a=clamp(result.a*clamp((noise-amount+border*(1.-rounded))/max(border,.000001),0.,1.),0.,1.);
 }
 COLOR=vec4(result.rgb,result.a*end_fade*presentation_gain);
}
