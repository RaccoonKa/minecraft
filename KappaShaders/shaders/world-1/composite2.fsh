#version 430 compatibility

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

/* RENDERTARGETS: 3,14 */
layout(location = 0) out vec3 fogScattering;
layout(location = 1) out vec3 fogTransmittance;

#include "/lib/head.glsl"
#include "/lib/util/colorspace.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

uniform sampler2D colortex3;
uniform sampler2D colortex14;

uniform sampler2D depthtex0;

uniform float near, far;
uniform vec2 pixelSize, viewSize;

#define FUTIL_MAT16
#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"

/* ------ FOG ------ */
#include "/lib/offset/gauss.glsl"

ivec2 clampTexelPos(ivec2 pos) {
    return clamp(pos, ivec2(0.0), ivec2(viewSize));
}

mat2x3 sampleFogSpatial(vec2 uv, const float LOD) {
    ivec2 pixelCoordUnscaled = ivec2(uv * viewSize);

    vec2 newCoord       = uv / LOD;
    ivec2 pixelCoord    = ivec2(newCoord * viewSize);

    ivec2 pos           = ivec2(uv * viewSize);

    vec3 centerScatter  = texelFetch(colortex3, pixelCoord, 0).rgb;
    vec3 centerTransmittance = texelFetch(colortex14, pixelCoord, 0).rgb;

    float centerDepth   = depthLinear(texelFetch(depthtex0, pixelCoordUnscaled, 0).x) * far;

    float totalWeight   = 1.0;
    vec3 totalScatter   = centerScatter * totalWeight;
    vec3 totalTrans     = centerTransmittance * totalWeight;

    for (int i = 0; i<9; i++) {
        ivec2 deltaPos      = kernelO_3x3[i] * 4;
        if (i == 4) continue;

        ivec2 samplePos     = pixelCoordUnscaled + deltaPos;
        ivec2 samplePosScaled = ivec2(vec2(samplePos) / LOD);

        bool valid          = all(greaterThanEqual(samplePos, ivec2(0))) && all(lessThan(samplePos, ivec2(viewSize)));

        if (!valid) continue;

        vec3 currentScatter = texelFetch(colortex3, clampTexelPos(samplePosScaled), 0).rgb;
        vec3 currentTrans   = texelFetch(colortex14, clampTexelPos(samplePosScaled), 0).rgb;
        float currentDepth  = depthLinear(texelFetch(depthtex0, samplePos, 0).x) * far;

        float depthDelta    = abs(currentDepth - centerDepth) * 64.0;

        float weight        = exp(-depthDelta);

        //accumulate stuff
        totalScatter   += currentScatter * weight;
        totalTrans     += currentTrans * weight;

        totalWeight    += weight;
    }

    totalScatter   /= max(totalWeight, 1e-16);
    totalTrans     /= max(totalWeight, 1e-16);

    return mat2x3(totalScatter, totalTrans);
}

void main() {
    #ifdef fogSmoothingPassEnabled
        mat2x3 fogData      = sampleFogSpatial(uv, 1.0);
    #else
        mat2x3 fogData      = mat2x3(texture(colortex3, uv).rgb, texture(colortex14, uv).rgb);
    #endif

    fogScattering       = clamp16F(fogData[0]);
    fogTransmittance    = fogData[1];
}