shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform sampler2D main_texture:filter_linear,repeat_enable;
uniform sampler2D dissolve_texture:filter_linear,repeat_enable;
uniform sampler2D dissolve2_texture:filter_linear,repeat_enable;
uniform vec4 main_st=vec4(1.,1.,0.,0.);
uniform vec4 dissolve_st=vec4(1.,1.,0.,0.);
uniform vec4 dissolve2_st=vec4(1.,1.,0.,0.);
uniform vec4 tint=vec4(1.);
uniform float amount=0.;
uniform float amount2=0.;
uniform float border=.1;
uniform float border2=.1;
uniform float end_fade=1.;
instance uniform float presentation_gain=1.;
varying vec4 vcolor;
varying vec2 source_uv;
float coverage(float noise,float threshold,float width){
 float x=threshold+.5;float k=floor(x);float f=x-k;
 float rounded=f<.5?k:(f>.5?k+1.:(mod(k,2.)==0.?k:k+1.));
 return clamp((noise-threshold+width*(1.-rounded))/max(width,.000001),0.,1.);
}
void vertex(){vcolor=COLOR;source_uv=UV;}
void fragment(){
 vec2 uv=source_uv*main_st.xy+main_st.zw;
 vec2 d1=source_uv*dissolve_st.xy+dissolve_st.zw;
 vec2 d2=source_uv*dissolve2_st.xy+dissolve2_st.zw;
 float a=coverage(texture(dissolve_texture,vec2(d1.x,1.-d1.y)).r,amount,border);
 float b=coverage(texture(dissolve2_texture,vec2(d2.x,1.-d2.y)).r,amount2,border2);
 vec4 result=2.*vcolor*tint*texture(main_texture,vec2(uv.x,1.-uv.y));
 float alpha=clamp(a*b*result.a,0.,1.)*end_fade*presentation_gain;
 COLOR=vec4(result.rgb*alpha,alpha);
}
