
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

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 indirectCurrent;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex11;

uniform sampler2D depthtex0;

uniform sampler2D noisetex;

uniform sampler3D colortex5;

uniform int frameCounter;

uniform float far, near;

uniform vec2 viewSize;

#include "/lib/frag/bluenoise.glsl"

/* ------ ATROUS ------ */

#include "/lib/offset/gauss.glsl"

#define atrousDepthTreshold 0.001
#define atrousDepthOffset 0.25
#define atrousDepthExp 2.0

#define atrousNormalExponent 16

/*
luma exp: big = sharper     now smol = sharp
luma offset: big = moar min blur
*/

#define atrousLumaExp 4.0
#define atrousLumaOffset 8.0

ivec2 clampTexelPos(ivec2 pos) {
    return clamp(pos, ivec2(0.0), ivec2(viewSize));
}

vec2 temporalBluenoise() {
    ivec3 uv    = ivec3(ivec2(gl_FragCoord.xy) & 255, frameCounter & 7);

    return texelFetch(colortex5, uv, 0).xy;
}

vec2 computeVariance(sampler2D tex, ivec2 pos) {
    float sumMsqr   = 0.0;
    float sumMean   = 0.0;

    for (int i = 0; i<9; i++) {
        ivec2 deltaPos     = kernelO_3x3[i];

        vec3 col    = texelFetch(tex, clampTexelPos(pos + deltaPos), 0).rgb;
        float lum   = getLuma(col);

        sumMsqr    += sqr(lum);
        sumMean    += lum;
    }
    sumMsqr  /= 9.0;
    sumMean  /= 9.0;

    return vec2(abs(sumMsqr - sqr(sumMean)) * rcp(max(sumMean, 1e-20)), sumMean);
}

#define gbufferImage colortex4

vec4 getGbufferData(ivec2 uv) {
    return (texelFetch(gbufferImage, uv, 0) * vec4(vec3(2.0), far)) - vec4(vec3(1.0), 0.0);
}

vec4 atrousSVGF(sampler2D tex, vec2 uv, const int size) {
    ivec2 pos           = ivec2(uv * viewSize);

    vec4 centerData     = getGbufferData(pos);

    vec4 centerColor    = texelFetch(tex, pos, 0);
    float centerLuma    = getLuma(centerColor.rgb);

    //return centerColor;

    vec2 variance       = computeVariance(tex, pos);

    float pixelAge      = texelFetch(colortex11, pos, 0).a*0+1;
    float normalExpMult = mix(0.5, 1.0, pixelAge);

    float sigmaL        = rcp(mix(rho, sqrt2, sqrt(pixelAge)) + atrousLumaExp * variance.x);
    float maxLumDelta   = mix(halfPi, pi, sqrt(pixelAge));

    vec4 total          = centerColor;
    float totalWeight   = 1.0;

    //float sizeMult      = size > 2 ? (fract(ditherBluenoise() + float(size) / euler) + 0.5) * float(size) : float(size);
    //    sizeMult        = mix(float(size), sizeMult, cube(pixelAge));

    //ivec2 jitter        = ivec2(temporalBluenoise() - 0.5) * size;

    for (int i = 0; i<9; i++) {
        ivec2 deltaPos      = kernelO_3x3[i];
        if (deltaPos.x == 0 && deltaPos.y == 0) continue;

        ivec2 samplePos     = pos + deltaPos * size;

        bool valid          = all(greaterThanEqual(samplePos, ivec2(0))) && all(lessThan(samplePos, ivec2(viewSize)));

        if (!valid) continue;

        vec4 currentData    = getGbufferData(samplePos);

        float depthDelta    = abs(currentData.w - centerData.w) * atrousDepthExp;

        float weight = pow(max(0.0, dot(currentData.xyz, centerData.xyz)), atrousNormalExponent * normalExpMult);

        //if (weight < 1e-20) continue;

        vec4 currentColor   = texelFetch(tex, clampTexelPos(samplePos), 0);
        float currentLuma   = getLuma(currentColor.rgb);

        float lumaDelta     = abs(centerLuma - currentLuma) / clamp(variance.y, 1e-2, 2e4);

            weight         *= exp(-depthDelta - sigmaL * clamp(lumaDelta, 0.0, maxLumDelta));

        //accumulate stuff
        total       += currentColor * weight;

        totalWeight += weight;
    }

    //compensate for total sampling weight
    total *= rcp(max(totalWeight, 1e-25));

    return total;
}
/*
mat2x3 computeVarianceRGB(sampler2D tex, ivec2 pos) {
    vec3 sumMsqr  = vec3(0.0);
    vec3 sumMean  = vec3(0.0);

    for (int i = 0; i<9; i++) {
        ivec2 deltaPos     = kernelO_3x3[i];
        //float weight        = kernelW_5x5[i];

        vec3 col    = texelFetch(tex, clampTexelPos(pos + deltaPos), 0).rgb;

        sumMsqr   += sqr(col);
        sumMean   += col;
    }
    sumMsqr /= 9.0;
    sumMean /= 9.0;

    return mat2x3(abs(sumMsqr - sqr(sumMean)) * rcp(max(sumMean, vec3(1e-20))), sumMean);
}
vec4 atrousSVGFRGB(sampler2D tex, vec2 uv, const int size) {
    ivec2 pos           = ivec2(uv * viewSize);

    vec4 centerData     = getGbufferData(pos);

    vec4 centerColor    = texelFetch(tex, pos, 0);
    float centerLuma    = getLuma(centerColor.rgb);

    //return centerColor;

    mat2x3 variance     = computeVarianceRGB(tex, pos);

    float pixelAge      = texelFetch(colortex11, pos, 0).a;
    float normalExpMult = mix(0.5, 1.0, pixelAge);

    vec3 sigmaL         = rcp(mix(pi, 0.71, (pixelAge)) + atrousLumaExp * variance[0]);
    float maxLumDelta   = mix(0.71, euler, (pixelAge));

    vec4 total          = centerColor;
    vec3 totalWeight    = vec3(1.0);

    //return total;

    //float sizeMult      = size > 2 ? (fract(ditherBluenoise() + float(size) / euler) + 0.5) * float(size) : float(size);
    //    sizeMult        = mix(float(size), sizeMult, cube(pixelAge));

    ivec2 jitter        = ivec2(temporalBluenoise() - 0.5) * size;

    for (int i = 0; i<9; i++) {
        ivec2 deltaPos      = kernelO_3x3[i];
        if (deltaPos.x == 0 && deltaPos.y == 0) continue;

        ivec2 samplePos     = pos + deltaPos * size + jitter;

        bool valid          = all(greaterThanEqual(samplePos, ivec2(0))) && all(lessThan(samplePos, ivec2(viewSize)));

        if (!valid) continue;

        vec4 currentData    = getGbufferData(samplePos);

        float depthDelta    = abs(currentData.w - centerData.w) * atrousDepthExp;

        vec3 weight         = vec3(pow(max(0.0, dot(currentData.xyz, centerData.xyz)), atrousNormalExponent * normalExpMult));

        //if (weight < 1e-20) continue;

        vec4 currentColor   = texelFetch(tex, clampTexelPos(samplePos), 0);
        float currentLuma   = getLuma(currentColor.rgb);

        vec3 colorDelta     = abs(centerColor.rgb - currentColor.rgb) / clamp(variance[1], 1e-2, 2e2);

            weight         *= exp(-depthDelta - sigmaL * clamp(colorDelta, 0.0, maxLumDelta));

        //accumulate stuff
        total.rgb      += currentColor.rgb * weight;
        total.a        += currentColor.a * avgOf(weight); 

        totalWeight += weight;
    }

    //compensate for total sampling weight
    total.rgb  *= rcp(max(totalWeight, 1e-25));
    total.a    *= rcp(max(avgOf(totalWeight), 1e-25));

    return total;
}*/


void main() {
    vec2 lowresCoord    = uv / indirectResScale;
    ivec2 pixelPos      = ivec2(floor(uv * viewSize) / indirectResScale);
    indirectCurrent     = vec4(0.0);

    if (saturate(lowresCoord) == lowresCoord) {
        #ifdef SVGF_FILTER
            if (landMask(texelFetch(depthtex0, pixelPos, 0).x)) indirectCurrent = clamp16F(atrousSVGF(colortex3, uv, iterationSize));
            else indirectCurrent = clamp16F(stex(colortex3));
        #else
            indirectCurrent = clamp16F(stex(colortex3));
        #endif
    }
}