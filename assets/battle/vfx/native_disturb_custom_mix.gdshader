shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform sampler2D main_texture:filter_linear,repeat_enable;
uniform sampler2D dissolve_texture:filter_linear,repeat_enable;
uniform sampler2D disturb_texture:filter_linear,repeat_enable;
uniform sampler2D weight_texture:filter_linear,repeat_enable,hint_default_white;
uniform vec4 main_st=vec4(1.,1.,0.,0.);
uniform vec4 dissolve_st=vec4(1.,1.,0.,0.);
uniform vec4 disturb_st=vec4(1.,1.,0.,0.);
uniform vec4 weight_st=vec4(1.,1.,0.,0.);
uniform vec4 tint=vec4(1.);
uniform float amount=0.;
uniform float border=.1;
uniform int channel=0;
uniform int disturb_channel=0;
uniform int dissolve_channel=0;
uniform float opacity=1.;
uniform float premultiply=5.;
uniform vec2 intensity=vec2(0.);
uniform float disturb_scale=1.;
uniform float disturb_dissolve=0.;
uniform vec2 main_speed=vec2(0.);
uniform vec2 dissolve_speed=vec2(0.);
uniform vec2 disturb_speed=vec2(0.);
uniform vec2 main_velocity=vec2(0.);
uniform vec2 disturb_velocity=vec2(0.);
uniform float end_fade=1.;
instance uniform float presentation_gain=1.;
instance uniform float source_time=0.;
varying vec4 vcolor;
vec4 source_sample(sampler2D image,vec2 at){return texture(image,vec2(at.x,1.-at.y));}
float noise_value(vec4 value,int component){return component==0?value.r:(component==1?value.g:(component==2?value.b:value.a));}
float coverage(float noise,float threshold,float width){
 float x=threshold+.5;float k=floor(x);float f=x-k;
 float rounded=f<.5?k:(f>.5?k+1.:(mod(k,2.)==0.?k:k+1.));
 return clamp((noise-threshold+width*(1.-rounded))/max(width,.000001),0.,1.);
}
void vertex(){vcolor=COLOR;}
void fragment(){
 vec2 main_uv=UV*main_st.xy+main_st.zw+fract((main_speed+main_velocity)*source_time);
 vec2 dissolve_uv=UV*dissolve_st.xy+dissolve_st.zw+fract((dissolve_speed+disturb_velocity)*source_time);
 vec2 disturb_uv=UV*disturb_st.xy+disturb_st.zw+fract(disturb_speed*source_time);
 vec2 weight_uv=UV*weight_st.xy+weight_st.zw;
 vec2 delta=source_sample(weight_texture,weight_uv).rg*noise_value(source_sample(disturb_texture,disturb_uv),disturb_channel)*intensity;
 vec4 tex=source_sample(main_texture,main_uv+delta*disturb_scale);
 if(channel>0){float value=channel==1?tex.r:(channel==2?tex.g:(channel==3?tex.b:tex.a));tex=vec4(value);}
 vec4 result=2.*tex*tint*vcolor;
 float noise=noise_value(source_sample(dissolve_texture,dissolve_uv+delta*disturb_dissolve),dissolve_channel);
 float alpha=clamp(result.a*opacity*coverage(noise,amount,border),0.,1.)*end_fade*presentation_gain;
 vec3 rgb=result.rgb;
 if(premultiply<1.5){rgb*=2.*alpha;}
 // These audited CustomData materials use source SRC_ALPHA / destination ONE_MINUS_SRC_ALPHA.
 COLOR=vec4(rgb*alpha,alpha);
}
