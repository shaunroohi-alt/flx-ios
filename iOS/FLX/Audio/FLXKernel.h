#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct FLXEngine FLXEngine;
enum FLXParameter {
 FLXPlaying, FLXRate, FLXGain, FLXFader, FLXLow, FLXMid, FLXHigh,
 FLXColor, FLXCue, FLXAssign, FLXLoopStart, FLXLoopEnd, FLXLoopEnabled,
 FLXReverse, FLXEffect, FLXDepth, FLXBeats, FLXBPM, FLXParameterCount
};
FLXEngine *FLXCreate(double sampleRate);
void FLXDestroy(FLXEngine *engine);
// Call load only with rendering stopped; the wrapper stops AVAudioEngine first.
int FLXLoad(FLXEngine *, int deck, const float *left, const float *right, int64_t frames, double rate);
void FLXSet(FLXEngine *, int deck, int parameter, double value);
double FLXGet(FLXEngine *, int deck, int parameter);
void FLXSeek(FLXEngine *, int deck, double seconds);
double FLXPosition(FLXEngine *, int deck);
double FLXDuration(FLXEngine *, int deck);
float FLXMeter(FLXEngine *, int deck);
void FLXMaster(FLXEngine *, double crossfader, double master, int splitCue, double cueMix, double cueLevel, int mono);
void FLXRender(FLXEngine *, float *left, float *right, uint32_t frames);
#ifdef __cplusplus
}
#endif
