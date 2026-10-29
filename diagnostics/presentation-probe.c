#define _GNU_SOURCE
#include <wayland-client.h>
#include <wayland-egl.h>
#include <EGL/egl.h>
#include <GL/gl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "xdg-shell-client-protocol.h"
#include "presentation-time-client-protocol.h"
static struct wl_display *display;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct wl_surface *surface;
static struct xdg_wm_base *wm;
static struct wp_presentation *presentation;
static EGLDisplay ed;
static EGLSurface es;
static int egl_mode,ready,done,frames,fullscreen,timer_mode;
static double started;
static int width=320,height=160;
static struct slot {struct wl_buffer *buf;uint32_t *pixels;int busy;} slots[3];
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9;}
static void ping(void*d,struct xdg_wm_base*w,uint32_t s){xdg_wm_base_pong(w,s);}
static const struct xdg_wm_base_listener wml={.ping=ping};
static void clockid(void*d,struct wp_presentation*p,uint32_t c){printf("CLOCK,%u\n",c);}
static const struct wp_presentation_listener pl={.clock_id=clockid};
static void global(void*d,struct wl_registry*r,uint32_t name,const char*i,uint32_t v){
 if(!strcmp(i,wl_compositor_interface.name))compositor=wl_registry_bind(r,name,&wl_compositor_interface,4);
 else if(!strcmp(i,wl_shm_interface.name))shm=wl_registry_bind(r,name,&wl_shm_interface,1);
 else if(!strcmp(i,xdg_wm_base_interface.name)){wm=wl_registry_bind(r,name,&xdg_wm_base_interface,1);xdg_wm_base_add_listener(wm,&wml,0);}
 else if(!strcmp(i,wp_presentation_interface.name)){presentation=wl_registry_bind(r,name,&wp_presentation_interface,1);wp_presentation_add_listener(presentation,&pl,0);}
}
static void removed(void*d,struct wl_registry*r,uint32_t n){}
static const struct wl_registry_listener rl={global,removed};
static void configured(void*d,struct xdg_surface*s,uint32_t serial){xdg_surface_ack_configure(s,serial);ready=1;}
static const struct xdg_surface_listener xl={configured};
static void topconf(void*d,struct xdg_toplevel*t,int32_t w,int32_t h,struct wl_array*a){if(fullscreen&&w>0&&h>0){width=w;height=h;}}
static void closed(void*d,struct xdg_toplevel*t){done=1;}
static const struct xdg_toplevel_listener tl={.configure=topconf,.close=closed};
static void released(void*d,struct wl_buffer*b){((struct slot*)d)->busy=0;}
static const struct wl_buffer_listener bl={released};
static void syncout(void*d,struct wp_presentation_feedback*f,struct wl_output*o){}
static void presented(void*d,struct wp_presentation_feedback*f,uint32_t hi,uint32_t lo,uint32_t ns,uint32_t refresh,uint32_t shi,uint32_t slo,uint32_t flags){
 printf("P,%.9f,%u,%llu,%u\n",(double)(((uint64_t)hi<<32)|lo)+ns/1e9,refresh,(unsigned long long)(((uint64_t)shi<<32)|slo),flags);wp_presentation_feedback_destroy(f);
}
static void discarded(void*d,struct wp_presentation_feedback*f){printf("D,%.9f\n",now());wp_presentation_feedback_destroy(f);}
static const struct wp_presentation_feedback_listener pfl={syncout,presented,discarded};
static void draw(void);
static void framed(void*d,struct wl_callback*c,uint32_t ms){wl_callback_destroy(c);printf("F,%.9f,%u\n",now(),ms);if(now()-started>=10)done=1;else draw();}
static const struct wl_callback_listener fl={framed};
static void draw(void){
 if(!timer_mode){struct wl_callback*c=wl_surface_frame(surface);wl_callback_add_listener(c,&fl,0);}
 if(presentation){struct wp_presentation_feedback*f=wp_presentation_feedback(presentation,surface);wp_presentation_feedback_add_listener(f,&pfl,0);}
 ++frames;
 if(egl_mode){
  glViewport(0,0,width,height);glClearColor(.08f,.12f,.2f,1);glClear(GL_COLOR_BUFFER_BIT);
  glEnable(GL_SCISSOR_TEST);glScissor((frames*4)%(width-32),0,32,height);glClearColor(.2f,.8f,.5f,1);glClear(GL_COLOR_BUFFER_BIT);glDisable(GL_SCISSOR_TEST);
  if(!eglSwapBuffers(ed,es)){fprintf(stderr,"eglSwapBuffers error %x\n",eglGetError());done=1;}
 }else{
  struct slot*s=0;for(int i=0;i<3;i++)if(!slots[i].busy){s=&slots[i];break;}
  if(!s){fprintf(stderr,"no free shm buffer\n");done=1;return;}
  int x=(frames*4)%(width-32);for(int y=0;y<height;y++)for(int col=0;col<width;col++)s->pixels[y*width+col]=(col>=x&&col<x+32)?0xff33cc80:0xff141f33;
  s->busy=1;wl_surface_attach(surface,s->buf,0,0);wl_surface_damage(surface,0,0,width,height);wl_surface_commit(surface);
 }
}
int main(int argc,char**argv){
 setbuf(stdout,0);egl_mode=argc>1&&!strcmp(argv[1],"egl");fullscreen=getenv("PROBE_FULLSCREEN")!=NULL;timer_mode=getenv("PROBE_TIMER")!=NULL;display=wl_display_connect(0);if(!display)return 2;
 struct wl_registry*r=wl_display_get_registry(display);wl_registry_add_listener(r,&rl,0);wl_display_roundtrip(display);
 if(!compositor||!wm||!shm)return 3;
 surface=wl_compositor_create_surface(compositor);struct xdg_surface*xs=xdg_wm_base_get_xdg_surface(wm,surface);xdg_surface_add_listener(xs,&xl,0);
 struct xdg_toplevel*top=xdg_surface_get_toplevel(xs);xdg_toplevel_add_listener(top,&tl,0);xdg_toplevel_set_title(top,egl_mode?"COSMIC test: EGL (10 seconds)":"COSMIC test: SHM (10 seconds)");xdg_toplevel_set_app_id(top,"cosmic-diagnostic-probe");
 if(fullscreen)xdg_toplevel_set_fullscreen(top,NULL);else{xdg_toplevel_set_min_size(top,width,height);xdg_toplevel_set_max_size(top,width,height);}wl_surface_commit(surface);while(!ready&&wl_display_dispatch(display)>=0){}
 if(egl_mode){
  ed=eglGetDisplay((EGLNativeDisplayType)display);EGLint major,minor,n;
  if(!eglInitialize(ed,&major,&minor)||!eglBindAPI(EGL_OPENGL_API))return 4;
  EGLint attr[]={EGL_SURFACE_TYPE,EGL_WINDOW_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_BIT,EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_NONE};EGLConfig config;
  if(!eglChooseConfig(ed,attr,&config,1,&n)||!n)return 5;
  struct wl_egl_window*win=wl_egl_window_create(surface,width,height);es=eglCreateWindowSurface(ed,config,(EGLNativeWindowType)win,0);EGLContext ctx=eglCreateContext(ed,config,EGL_NO_CONTEXT,0);
  if(!eglMakeCurrent(ed,es,es,ctx))return 6;
  fprintf(stderr,"GL renderer: %s; GL version: %s\n",glGetString(GL_RENDERER),glGetString(GL_VERSION));eglSwapInterval(ed,timer_mode?0:1);
 }else{
  for(int i=0;i<3;i++){size_t size=width*height*4;int fd=memfd_create("cosmic-probe",MFD_CLOEXEC);ftruncate(fd,size);slots[i].pixels=mmap(0,size,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);struct wl_shm_pool*p=wl_shm_create_pool(shm,fd,size);slots[i].buf=wl_shm_pool_create_buffer(p,0,width,height,width*4,WL_SHM_FORMAT_XRGB8888);wl_buffer_add_listener(slots[i].buf,&bl,&slots[i]);wl_shm_pool_destroy(p);close(fd);}
 }
 started=now();fprintf(stderr,"START %s %s %dx%d %.9f\n",egl_mode?"EGL":"SHM",timer_mode?"timer":"callbacks",width,height,started);
 if(timer_mode){
  double next=started;
  while(!done&&now()-started<10){
   if(wl_display_roundtrip(display)<0)break;
   draw();wl_display_flush(display);next+=.016680289;
   struct timespec target={.tv_sec=(time_t)next,.tv_nsec=(long)((next-(time_t)next)*1e9)};
   clock_nanosleep(CLOCK_MONOTONIC,TIMER_ABSTIME,&target,0);
  }
 }else{draw();while(!done&&wl_display_dispatch(display)>=0){}}
 fprintf(stderr,"END frames=%d elapsed=%.3f\n",frames,now()-started);wl_display_disconnect(display);return 0;
}
