/*
====================================================================================================

    Copyright (C) 2023 RRe36

    All Rights Reserved unless otherwise explicitly stated.


    By downloading this you have agreed to the license and terms of use.
    These can be found inside the included license-file
    or here: https://rre36.com/copyright-license

    Violating these terms may be penalized with actions according to the Digital Millennium
    Copyright Act (DMCA), the Information Society Directive and/or similar laws
    depending on your country.

====================================================================================================
*/

#include "/lib/head.glsl"

out vec2 uv;

flat out float exposure;
flat out float AvgLuma;
flat out vec2 LumaRange;

uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

uniform float frameTime;
uniform float viewHeight;
uniform float viewWidth;
uniform float nightVision;

uniform vec2 viewSize;

ivec2 tiles   = ivec2(viewSize * cube(0.25) - 1);

#ifdef exposureComplexEnabled

float computeExposureWeighting(vec2 uv) {
    uv  = uv * 2.0 - 1.0;

    float weight    = (1.0 - sqr(uv.x)) * (1.0 - sqr(uv.y));

    return sqr(weight);
}

float ReadLumaTiles(ivec2 UV) {
    UV += ivec2(vec2(0.1 * viewWidth, 0.0));

    return texelFetch(colortex3, UV, 0).a;
}

float getExposureLuma() {
    vec2 averageLuminance   = vec2(0.0);
    int total               = 0;
    float totalWeight       = 0.0;

    vec2 luminanceLimits    = vec2(0.0, 1e8);

    /*
        Get weighted average.
    */

    for (int x = 0; x < tiles.x; ++x) {
        for (int y = 0; y < tiles.y; ++y) {
            float currentLuminance = texelFetch(colortex3, ivec2(x, y), 0).a;

            vec2 uv          = (vec2(x, y) + 0.5) / vec2(tiles);

            float weight        = computeExposureWeighting(uv);

            luminanceLimits     = vec2(max(luminanceLimits.x, currentLuminance), min(luminanceLimits.y, currentLuminance));

            averageLuminance   += vec2(currentLuminance, currentLuminance * weight);
            ++total;
            totalWeight    += weight;
        }
    }
    averageLuminance.x     /= max(total, 1);
    averageLuminance.y     /= max(totalWeight, 1.0);

    //AvgLuma = averageLuminance.y;
    LumaRange = luminanceLimits;

    /*
        Determine distribution above or below average.
    */

    int aboveAverage            = 0;
    vec2 aboveAverageData       = vec2(0.0);
    int belowAverage            = 0;
    vec2 belowAverageData       = vec2(0.0);
    int withinAverage           = 0;
    vec2 withinAverageData      = vec2(0.0);

    luminanceLimits             = vec2(max(luminanceLimits.x, averageLuminance.x * (1.0 + exposureBrightPercentage)),
                                       min(luminanceLimits.y, averageLuminance.x * (1.0 - exposureDarkPercentage)));

    vec2 luminanceThreshold     = vec2(averageLuminance.x);
        luminanceThreshold      = mix(luminanceLimits, luminanceThreshold, vec2(exposureBrightPercentage, exposureDarkPercentage));

    for (int x = 0; x < tiles.x; ++x) {
        for (int y = 0; y < tiles.y; ++y) {
            vec2 uv          = (vec2(x, y) + 0.5) / vec2(tiles);

            float weight        = computeExposureWeighting(uv);

            float currentLuminance = texelFetch(colortex3, ivec2(x, y), 0).a;

            if (currentLuminance > luminanceThreshold.x) {

                ++aboveAverage;
                aboveAverageData   += vec2(currentLuminance * weight, weight);

            } else if (currentLuminance < luminanceThreshold.y) {

                ++belowAverage;
                belowAverageData   += vec2(currentLuminance * weight, weight);

            } else {

                ++withinAverage;
                withinAverageData  += vec2(currentLuminance * weight, weight);

            }
        }
    }

    aboveAverageData.x /= max(aboveAverageData.y, 0.01);
    belowAverageData.x /= max(belowAverageData.y, 0.01);
    withinAverageData.x /= max(withinAverageData.y, 0.01);

    vec3 areaPercentages = vec3(withinAverage, aboveAverage, belowAverage) / max(total, 1);

    float weightedLuma  = withinAverageData.x * areaPercentages.x * exposureAverageWeight;
        weightedLuma   += aboveAverageData.x * areaPercentages.y * exposureBrightWeight;
        weightedLuma   += belowAverageData.x * areaPercentages.z * exposureDarkWeight;
        weightedLuma   /= areaPercentages.x * exposureAverageWeight + areaPercentages.y * exposureBrightWeight + areaPercentages.z * exposureDarkWeight;

    //float weightedLuma  = mix(averageLuminance.y, belowAverageData.x, areaPercentages.y);
    //    weightedLuma    = mix(weightedLuma, aboveAverageData.x, areaPercentages.x);

    AvgLuma = weightedLuma;
    return weightedLuma;
}

#else

float getExposureLuma() {
    float averageLuminance  = 0.0;
    int total = 0;
    float totalWeight   = 0.0;
    vec2 luminanceLimits    = vec2(0.0, 1e8);

    for (int x = 0; x < tiles.x; ++x) {
        for (int y = 0; y < tiles.y; ++y) {
            float currentLuminance = texelFetch(colortex3, ivec2(x, y), 0).a;

            luminanceLimits     = vec2(max(luminanceLimits.x, currentLuminance), min(luminanceLimits.y, currentLuminance));

            vec2 uv          = vec2(x, y) / vec2(tiles);

            float weight        = 1.0 - linStep(length(uv * 2.0 - 1.0), 0.25, 0.75);
                weight          = cubeSmooth(weight) * 0.9 + 0.1;

            averageLuminance   += currentLuminance * weight;
            ++total;
            totalWeight    += weight;
        }
    }
    averageLuminance   /= max(totalWeight, 1);

    AvgLuma = averageLuminance;

    LumaRange = luminanceLimits;

    return averageLuminance;
}

#endif

float temporalExp() {

    /*
    #if DIM == -1
    const float maxExposure = 30.0;
    const float minExposure = 60.0;
    #elif DIM == 1
    const float maxExposure = 5.0;
    const float minExposure = 30.0;
    #else
    const float maxExposure = 0.16;
    const float minExposure = 80.0;
    #endif
    */

    #if DIM == -1
    const float exposureLowClamp    = 0.1 * exposureDarkClamp;
    const float exposureHighClamp   = 8.0 * exposureBrightClamp;
    #elif DIM == 1
    const float exposureLowClamp    = 0.1 * exposureDarkClamp;
    const float exposureHighClamp   = 20.0 * exposureBrightClamp;
    #else
    const float exposureLowClamp    = 0.08 * exposureDarkClamp;
    const float exposureHighClamp   = 40.0 * exposureBrightClamp;
    #endif

    const float K   = 14.0;
    const float cal = exp2(autoExposureBias) * K / 100.0;

    const float minExposure     = exp2(autoExposureBias) / exposureHighClamp;
    const float maxExposure     = exp2(autoExposureBias) / exposureLowClamp;

    const float a   = cal / minExposure;
    const float b   = a - cal / maxExposure;

    float lum   = getExposureLuma();
    float lastExp       = clamp(texelFetch(colortex6, ivec2(viewSize * 0.6), 0).a, 0.0, 65535.0);

    float targetExp     = cal / (a - b * exp(-lum / b));

    float decaySpeed    = targetExp < lastExp ? 0.075 : 0.05;

    return mix(lastExp, targetExp, saturate(decaySpeed * exposureDecay * (frameTime / 0.033)));

    /*
    float expCurr   = clamp(texelFetch(colortex6, ivec2(0), 0).a, 0.0, 65535.0);
    float expTarg   = getExposureLuma();
        expTarg     = 1.0 / clamp(expTarg, exposureLowClamp * exposureDarkClamp * rcp(nightVision + 1.0), exposureHighClamp * exposureBrightClamp);
        expTarg     = log2(expTarg * rcp(6.25));    //adjust this
        expTarg     = 1.2 * pow(2.0, expTarg);

    float adaptBaseSpeed = expTarg < expCurr ? 0.075 : 0.05;

    return mix(expCurr, expTarg, adaptBaseSpeed * exposureDecay * (frameTime * rcp(0.033)));
    */
}

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    uv = gl_MultiTexCoord0.xy;

    exposure  = temporalExp();
}