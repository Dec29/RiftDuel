shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform sampler2D main_texture : filter_linear, repeat_enable;
uniform sampler2D dissolve_texture : filter_linear, repeat_enable;
instance uniform float source_time=0.;
uniform vec4 uv_tween=vec4(0.);
uniform vec4 main_st = vec4(1.,1.,0.,0.);
uniform vec4 dissolve_st = vec4(1.,1.,0.,0.);
uniform vec4 tint = vec4(1.);
uniform float amount = 0.;
uniform float end_fade = 1.;
instance uniform float presentation_gain = 1.;
uniform float border = 0.1;
uniform int mode = 0;
uniform int channel = 0;
uniform float premultiply = 5.;
varying vec4 vcolor;
varying vec2 source_uv;
void vertex(){ vcolor = COLOR; source_uv = UV; }
void fragment(){
 vec2 uv = fract(source_uv * main_st.xy + main_st.zw + uv_tween.xy*source_time);
 vec4 tex = texture(main_texture, vec2(uv.x, 1.-uv.y));
 if(channel==1){tex=vec4(tex.r);} else if(channel==2){tex=vec4(tex.g);} else if(channel==3){tex=vec4(tex.b);} else if(channel==4){tex=vec4(tex.a);}
 vec4 col=vcolor*tint;
 vec3 rgb=2.*col.rgb*tex.rgb;
 float alpha=clamp(2.*col.a*tex.a,0.,1.);
 if(mode>0){
  vec2 duv=fract(source_uv*dissolve_st.xy+dissolve_st.zw+uv_tween.zw*source_time);
  float d=texture(dissolve_texture,vec2(duv.x,1.-duv.y)).r;
  float coverage;
  if(mode==2){
   coverage=clamp((d-(1.-vcolor.a)+vcolor.a*border)/max(border,0.000001),0.,1.);
   rgb=2.*vcolor.rgb*tex.rgb;
   alpha=clamp(coverage*tex.a*tint.a,0.,1.);
  }else{
   // Source shader round_ne: exact ties use even rounding.
   float x=amount+0.5;
   float k=floor(x); float fraction=x-k;
   float rounded=fraction<0.5?k:(fraction>0.5?k+1.:(mod(k,2.)==0.?k:k+1.));
   coverage=clamp((d-amount+border*(1.-rounded))/max(border,0.000001),0.,1.);
   alpha=clamp(coverage*2.*col.a*tex.a,0.,1.);
  }
 }else if(premultiply<1.5){rgb*=alpha*2.;}
 COLOR=vec4(rgb,alpha*end_fade*presentation_gain);
}
