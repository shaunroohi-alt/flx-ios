#include "../FLX/Audio/FLXKernel.h"
#include <cassert>
#include <cmath>
#include <iostream>
#include <limits>
#include <memory>
#include <thread>
#include <vector>

using Engine=std::unique_ptr<FLXEngine,decltype(&FLXDestroy)>;
Engine make(){return Engine(FLXCreate(44100),FLXDestroy);}
std::vector<float> tone(size_t size,double hz=440){std::vector<float>v(size);for(size_t i=0;i<size;i++)v[i]=float(0.2*std::sin(6.283185307179586*hz*double(i)/44100));return v;}
void load(FLXEngine *e,int n){auto v=tone(44100);assert(FLXLoad(e,n,v.data(),v.data(),v.size(),44100));}
void render(FLXEngine *e,size_t frames=512){std::vector<float>l(frames),r(frames);FLXRender(e,l.data(),r.data(),uint32_t(frames));for(size_t i=0;i<frames;i++){assert(std::isfinite(l[i])&&std::isfinite(r[i]));assert(std::abs(l[i])<=1&&std::abs(r[i])<=1);}}
double energy(const std::vector<float>&v){double s=0;for(float x:v)s+=x*x;return s;}
int main(){
 int checks=0;
 {auto e=make();render(e.get());assert(FLXPosition(e.get(),0)==0);checks++;}
 {auto e=make();load(e.get(),0);FLXSet(e.get(),0,FLXPlaying,1);render(e.get(),4410);assert(std::abs(FLXPosition(e.get(),0)-0.1)<1e-8);checks++;
 FLXSet(e.get(),0,FLXPlaying,0);render(e.get(),4410);assert(std::abs(FLXPosition(e.get(),0)-0.1)<1e-8);checks++;
 FLXSet(e.get(),0,FLXRate,2);FLXSet(e.get(),0,FLXPlaying,1);render(e.get(),4410);assert(std::abs(FLXPosition(e.get(),0)-0.3)<1e-8);checks++;
 FLXSeek(e.get(),0,0.5);FLXSet(e.get(),0,FLXRate,1);FLXSet(e.get(),0,FLXReverse,1);render(e.get(),4410);assert(std::abs(FLXPosition(e.get(),0)-0.4)<1e-8);checks++;}
 {auto e=make();load(e.get(),0);FLXSet(e.get(),0,FLXPlaying,1);FLXSet(e.get(),0,FLXLoopStart,0.2);FLXSet(e.get(),0,FLXLoopEnd,0.3);FLXSet(e.get(),0,FLXLoopEnabled,1);FLXSeek(e.get(),0,0.2);render(e.get(),11025);assert(std::abs(FLXPosition(e.get(),0)-0.25)<1e-5);checks++;
 FLXSet(e.get(),0,FLXReverse,1);render(e.get(),11025);assert(FLXPosition(e.get(),0)>=0.1999&&FLXPosition(e.get(),0)<=0.3001);checks++;}
 {auto e=make();load(e.get(),0);FLXSet(e.get(),0,FLXPlaying,1);render(e.get(),50000);assert(FLXGet(e.get(),0,FLXPlaying)==0);assert(FLXPosition(e.get(),0)==1);checks++;}
 {auto e=make();auto mono=tone(4410);assert(FLXLoad(e.get(),0,mono.data(),mono.data(),mono.size(),22050));FLXSet(e.get(),0,FLXPlaying,1);render(e.get(),4410);assert(std::abs(FLXPosition(e.get(),0)-0.1)<1e-8);checks++;}
 {auto e=make();load(e.get(),0);FLXSet(e.get(),0,FLXPlaying,1);FLXSet(e.get(),0,FLXAssign,0);FLXMaster(e.get(),1,1,0,0,1,0);std::vector<float>l(4096),r(4096);FLXRender(e.get(),l.data(),r.data(),4096);assert(energy(l)<1e-20);checks++;
 FLXSet(e.get(),0,FLXAssign,2);FLXRender(e.get(),l.data(),r.data(),4096);assert(energy(l)>1);checks++;}
 {auto e=make();load(e.get(),0);FLXSet(e.get(),0,FLXPlaying,1);FLXSet(e.get(),0,FLXFader,0);FLXSet(e.get(),0,FLXCue,1);FLXMaster(e.get(),0.5,1,1,0,1,0);std::vector<float>l(4096),r(4096);FLXRender(e.get(),l.data(),r.data(),4096);assert(energy(l)>1);assert(energy(r)==0);checks++;}
 {auto e=make();for(int i=0;i<4;i++){load(e.get(),i);FLXSet(e.get(),i,FLXPlaying,1);FLXSet(e.get(),i,FLXGain,4);FLXSet(e.get(),i,FLXFader,1);}render(e.get(),4096);checks++;}
 for(int fx=1;fx<=7;fx++){auto e=make();load(e.get(),0);FLXSet(e.get(),0,FLXPlaying,1);FLXSet(e.get(),0,FLXEffect,fx);FLXSet(e.get(),0,FLXDepth,0.7);FLXSet(e.get(),0,FLXBeats,0.0625);for(int b=0;b<80;b++)render(e.get());checks++;}
 {auto e=make();load(e.get(),0);FLXSet(e.get(),0,FLXRate,std::numeric_limits<double>::quiet_NaN());assert(FLXGet(e.get(),0,FLXRate)==1);FLXSet(e.get(),0,FLXHigh,50);assert(FLXGet(e.get(),0,FLXHigh)==6);FLXSeek(e.get(),0,-999);render(e.get());assert(FLXPosition(e.get(),0)==0);assert(!FLXLoad(e.get(),4,nullptr,nullptr,1,44100));checks++;}
 {auto e=make();load(e.get(),0);FLXSet(e.get(),0,FLXPlaying,1);FLXSet(e.get(),0,FLXLoopEnd,1);FLXSet(e.get(),0,FLXLoopEnabled,1);
 std::thread controls([&]{for(int i=0;i<10000;i++){FLXSet(e.get(),0,FLXColor,std::sin(i*0.01));FLXSet(e.get(),0,FLXLow,(i%32)-26);FLXSeek(e.get(),0,(i%100)*0.01);}});
 for(int i=0;i<500;i++){render(e.get(),128);}controls.join();checks++;}
 std::cout<<"PASS: "<<checks<<" DSP scenarios (portable kernel only; not an iOS build).\n";
}
