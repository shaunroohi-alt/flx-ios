#include "FLXKernel.h"
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <vector>
#include <new>

namespace {
constexpr double pi = 3.14159265358979323846;
double clamp(double v, double lo, double hi) { return std::max(lo, std::min(v, hi)); }
struct Biquad {
 double b0=1,b1=0,b2=0,a1=0,a2=0,z1=0,z2=0;
 void peak(double sr, double hz, double gain) {
  double A=std::pow(10.0,gain/40.0), w=2*pi*hz/sr, alpha=std::sin(w)/1.4, a0=1+alpha/A;
  b0=(1+alpha*A)/a0; b1=-2*std::cos(w)/a0; b2=(1-alpha*A)/a0;
  a1=-2*std::cos(w)/a0; a2=(1-alpha/A)/a0;
 }
 float tick(float x) { double y=b0*x+z1; z1=b1*x-a1*y+z2; z2=b2*x-a2*y; return float(y); }
};
struct Deck {
 std::array<std::atomic<double>, FLXParameterCount> p{};
 std::vector<float> l,r;
 double fileRate=44100, position=0;
 std::atomic<double> seek{-1}, published{0}, duration{0};
 std::atomic<float> meter{0};
 std::array<std::array<Biquad,3>,2> eq;
 std::array<std::vector<float>,2> delay;
 std::array<double,3> lastEQ{{999,999,999}};
 std::array<float,2> filter{{0,0}}, allpass{{0,0}};
 size_t write=0;
 double phase=0, smoothGain=0;
 Deck() {
  p[FLXRate]=1; p[FLXGain]=1; p[FLXFader]=0.8; p[FLXAssign]=2;
  p[FLXBeats]=1; p[FLXBPM]=120;
 }
};
}
struct FLXEngine {
 double sr;
 std::array<Deck,4> decks;
 std::atomic<double> cross{0.5}, master{0.7}, cueMix{0}, cueLevel{0.7};
 std::atomic<int> split{0}, mono{0};
 explicit FLXEngine(double rate):sr(rate) {
  for(auto &d:decks) for(auto &v:d.delay) v.resize(size_t(rate*8)+1,0);
 }
};
extern "C" {
FLXEngine *FLXCreate(double sr) {
 if(!std::isfinite(sr)||sr<8000||sr>192000) return nullptr;
 try {return new FLXEngine(sr);} catch(...) {return nullptr;}
}
void FLXDestroy(FLXEngine *e) {delete e;}
int FLXLoad(FLXEngine *e,int n,const float *l,const float *r,int64_t count,double sr) {
 if(!e||n<0||n>3||!l||!r||count<2||count>16777216||!std::isfinite(sr)||sr<8000||sr>192000) return 0;
 size_t total=size_t(count)*8;
 for(int i=0;i<4;++i) if(i!=n) total+=e->decks[i].l.size()*8;
 if(total>384u*1024u*1024u) return 0;
 try {
  std::vector<float> a(l,l+count), b(r,r+count);
  for(auto &v:a) if(!std::isfinite(v)) v=0;
  for(auto &v:b) if(!std::isfinite(v)) v=0;
  auto &d=e->decks[n]; d.l.swap(a); d.r.swap(b); d.fileRate=sr;
  d.p[FLXPlaying]=0; d.p[FLXLoopEnabled]=0; d.position=0; d.seek=-1;
  d.published=0; d.duration=double(count)/sr; d.smoothGain=0;
  d.filter={0,0};d.allpass={0,0}; d.lastEQ={999,999,999}; d.eq={};
  for(auto &v:d.delay) std::fill(v.begin(),v.end(),0);
  return 1;
 } catch(...) {return 0;}
}
void FLXSet(FLXEngine *e,int n,int p,double v) {
 if(!e||n<0||n>3||p<0||p>=FLXParameterCount||!std::isfinite(v)) return;
 switch(p) {
 case FLXRate:v=clamp(v,0.01,4);break;
 case FLXGain:v=clamp(v,0,4);break;
 case FLXFader:case FLXDepth:v=clamp(v,0,1);break;
 case FLXLow:case FLXMid:case FLXHigh:v=clamp(v,-26,6);break;
 case FLXColor:v=clamp(v,-1,1);break;
 case FLXBeats:v=clamp(v,1.0/16,16);break;
 case FLXBPM:v=clamp(v,30,300);break;
 case FLXAssign:v=clamp(std::round(v),0,2);break;
 case FLXEffect:v=clamp(std::round(v),0,7);break;
 default:break;
 }
 e->decks[n].p[p].store(v,std::memory_order_relaxed);
}
double FLXGet(FLXEngine *e,int n,int p) {return e&&n>=0&&n<4&&p>=0&&p<FLXParameterCount?e->decks[n].p[p].load():0;}
void FLXSeek(FLXEngine *e,int n,double s) {if(e&&n>=0&&n<4&&std::isfinite(s)) e->decks[n].seek=clamp(s,0,e->decks[n].duration.load());}
double FLXPosition(FLXEngine *e,int n) {return e&&n>=0&&n<4?e->decks[n].published.load():0;}
double FLXDuration(FLXEngine *e,int n) {return e&&n>=0&&n<4?e->decks[n].duration.load():0;}
float FLXMeter(FLXEngine *e,int n) {return e&&n>=0&&n<4?e->decks[n].meter.load():0;}
void FLXMaster(FLXEngine *e,double x,double m,int split,double mix,double level,int mono) {
 if(!e||!std::isfinite(x)||!std::isfinite(m)||!std::isfinite(mix)||!std::isfinite(level))return;
 e->cross=clamp(x,0,1);e->master=clamp(m,0,1);e->split=split;e->cueMix=clamp(mix,0,1);e->cueLevel=clamp(level,0,1);e->mono=mono;
}
void FLXRender(FLXEngine *e,float *outL,float *outR,uint32_t frames) {
 if(!e||!outL||!outR)return;
 std::fill_n(outL,frames,0); std::fill_n(outR,frames,0);
 // No allocations, mutexes, file I/O, or Objective-C calls in the render path.
 double x=e->cross.load(), master=e->master.load(), mix=e->cueMix.load(), cueLevel=e->cueLevel.load();
 bool split=e->split.load()!=0, mono=e->mono.load()!=0;
 std::array<std::array<double,FLXParameterCount>,4> p{};
 std::array<float,4> peak{};
 for(int n=0;n<4;n++) {
  auto &d=e->decks[n];for(int k=0;k<FLXParameterCount;k++)p[n][k]=d.p[k].load(std::memory_order_relaxed);
  double s=d.seek.exchange(-1);if(s>=0)d.position=s*d.fileRate;
  for(int k=0;k<3;k++) if(d.lastEQ[k]!=p[n][FLXLow+k]) {
   // Original FLX EQ design; frequency labels are reference endpoints, not proprietary filter coefficients.
   for(auto &ch:d.eq)ch[k].peak(e->sr,k==0?80:(k==1?1000:10000),p[n][FLXLow+k]);
   d.lastEQ[k]=p[n][FLXLow+k];
  }
 }
 for(uint32_t i=0;i<frames;i++) {
  double ml=0,mr=0,cl=0,cr=0;
  for(int n=0;n<4;n++) {
   auto &d=e->decks[n];auto &v=p[n];if(d.l.empty())continue;
   double a=clamp(v[FLXLoopStart]*d.fileRate,0,double(d.l.size()-1));
   double b=clamp(v[FLXLoopEnd]*d.fileRate,0,double(d.l.size()));
   bool loop=v[FLXLoopEnabled]>0&&b>a+1;
   bool play=v[FLXPlaying]>0;
   if(loop&&play&&(d.position>=b||d.position<a)) {
    double length=b-a;d.position=a+std::fmod(std::fmod(d.position-a,length)+length,length);
   }
   if(d.position<0||d.position>=double(d.l.size())) {play=false;d.p[FLXPlaying]=0;d.position=clamp(d.position,0,double(d.l.size()));}
   float s[2]={0,0};
   if(play) {
    size_t idx=size_t(d.position), next=std::min(idx+1,d.l.size()-1);double f=d.position-idx;
    s[0]=float(d.l[idx]+(d.l[next]-d.l[idx])*f);s[1]=float(d.r[idx]+(d.r[next]-d.r[idx])*f);
    d.position+=v[FLXRate]*(v[FLXReverse]>0?-1:1)*d.fileRate/e->sr;
   }
   int assign=int(v[FLXAssign]);double cross=assign==0?std::cos(x*pi/2):(assign==1?std::sin(x*pi/2):1);
   double target=v[FLXFader]*cross;d.smoothGain+=0.002*(target-d.smoothGain);
   int fx=int(v[FLXEffect]);double wet=v[FLXDepth], period=60/v[FLXBPM]*v[FLXBeats];
   d.phase+=1/(e->sr*period);d.phase-=std::floor(d.phase);
   for(int ch=0;ch<2;ch++) {
    float y=s[ch]*float(v[FLXGain]);for(auto &q:d.eq[ch])y=q.tick(y);
    double color=v[FLXColor];
    double hz=color<0?20000*std::pow(0.001,std::abs(color)):20*std::pow(1000,color);
    double coeff=1-std::exp(-2*pi*std::min(hz,e->sr*0.45)/e->sr);
    d.filter[ch]+=float(coeff)*(y-d.filter[ch]);
    if(std::abs(color)>0.01)y=color<0?d.filter[ch]:y-d.filter[ch];
    peak[n]=std::max(peak[n],std::abs(y));
    if(v[FLXCue]>0){if(ch==0)cl+=y;else cr+=y;}
    y*=float(d.smoothGain);
    auto &delay=d.delay[ch];size_t len=delay.size();
    double seconds=period;
    if(fx==3)seconds=0.004+0.003*std::sin(2*pi*d.phase);
    if(fx==5)seconds=0.071+(ch?0.009:0);
    size_t offset=size_t(clamp(seconds*e->sr,1,double(len-1)));
    float delayed=delay[(d.write+len-offset)%len], z=y;
    if(fx==1||fx==2||fx==3||fx==5) {
     if(fx==2)delayed-=d.allpass[ch]*0.8f;
     d.allpass[ch]=delayed;
     delay[d.write]=std::max(-4.f,std::min(4.f,y+delayed*(fx==5?0.78f:0.45f)));
     z=y*float(1-wet)+delayed*float(wet);
    } else {delay[d.write]=y;}
    if(fx==4)z=y*float(1-wet+wet*(d.phase<0.5?1:0));
    if(fx==6) {float ap=-0.6f*y+d.allpass[ch];d.allpass[ch]=y+0.6f*ap;z=y*float(1-wet)+ap*float(wet);}
    if(fx==7){double steps=std::pow(2,16-14*wet);z=float(std::round(y*steps)/steps);}
    if(ch==0)ml+=z;else mr+=z;
   }
   d.write=(d.write+1)%d.delay[0].size();
  }
  ml*=master;mr*=master;if(mono){double m=(ml+mr)/2;ml=m;mr=m;}
  if(split){double cue=((cl+cr)*0.5*(1-mix)+(ml+mr)*0.5*mix)*cueLevel;double m=(ml+mr)*0.5;ml=cue;mr=m;}
  // Emergency hard ceiling; not advertised as the hardware's proprietary peak limiter.
  outL[i]=float(clamp(ml,-1,1));outR[i]=float(clamp(mr,-1,1));
 }
 for(int n=0;n<4;n++){e->decks[n].published=e->decks[n].position/e->decks[n].fileRate;e->decks[n].meter=peak[n];}
}
}
