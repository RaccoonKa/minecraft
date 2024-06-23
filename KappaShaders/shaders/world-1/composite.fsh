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

/* RENDERTARGETS: 0,3,14 */
layout(location = 0) out vec3 sceneColor;
layout(location = 1) out vec4 fogScattering;
layout(location = 2) out vec3 fogTransmittance;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"
#include "/lib/shadowconst.glsl"

const bool shadowHardwareFiltering = true;

in vec2 uv;

flat in mat2x3 lightColor;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;

uniform sampler2D noisetex;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float eyeAltitude;
uniform float far, near;
uniform float frameTimeCounter;
uniform float lightFlip;
uniform float sunAngle;
uniform float rainStrength, wetness;
uniform float worldAnimTime;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform vec2 taaOffset;
uniform vec2 viewSize, pixelSize;

uniform vec3 cameraPosition;
uniform vec3 lightDir, lightDirView;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

/* ------ INCLUDES ------ */
#define FUTIL_MAT16
#define FUTIL_TBLEND
#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"
#include "/lib/frag/bluenoise.glsl"
#include "/lib/frag/gradnoise.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/atmos/air/const.glsl"
#include "/lib/atmos/phase.glsl"
#include "/lib/atmos/waterConst.glsl"
#include "/lib/frag/noise.glsl"

/* ------ SHADOW PREP ------ */
#include "/lib/light/warp.glsl"

/* ------ VOLUMETRIC FOG ------ */

#ifdef freezeAtmosAnim
    const float fogTime   = float(atmosAnimOffset) * 0.006;
#else
    float fogTime     = frameTimeCounter * 0.6;
#endif

vec3 smokeDensity(vec3 rPos, float altitude) {
    #ifdef netherSmokeEnabled
    float smokeFade = sqr(1.0 - linStep(altitude, 128.0, 256.0));
        smokeFade  *= expf(-max0((altitude - 32.0) * 0.015)) * 0.6 + 0.4;

    float smoke     = 0.0;
    float smokeGlowing = 0.0;

    if (smokeFade > 1e-10) {
        vec3 wind   = fogTime * vec3(1.0, -0.9, 0.1);

        vec3 pos    = (rPos + cameraPosition) * 0.03;
            pos    += value3D(pos * 4.0 + wind * 0.5) * 1.5 - 0.75;
            pos    += value3D(pos * 8.0 - wind) - 0.5;

        pos.x *= 0.7;

        float noise     = value3D(pos * 4.0 + wind);
            noise      += value3D(pos * 8.0 + wind * 2 + noise * 0.5) * 0.5;
            //noise      += value3D(pos * 16.0 + wind * 4 + noise * 0.5) * 0.25;
            noise      /= 1.5;

        smoke       = smokeFade - noise;
        float glowProximity = sqrt(sstep(length(rPos), 4.0, 24.0));
        smokeGlowing = saturate((glowProximity * (0.3 + cube(smokeFade) * 0.15) - noise) * pi);
        //smoke      -= 0.1;

        smoke       = cubeSmooth(max0(smoke)) * (smokeFade * 0.5 + 0.5);
        smokeGlowing *= smokeFade;
    }

    return vec3(1.0, smoke, smokeGlowing);
    #else
    return vec3(1.0, 0.0, 0.0);
    #endif
}

flat in vec3 fogCol;
flat in vec3 fogCol2;
flat in vec3 fogEmissionColor;

const vec3 hazeCoeff    = vec3(2e-3) * netherHazeDensity;
const vec3 smokeCoeff   = vec3(3e-2) * netherSmokeDensity;

mat2x3 volumetricFog(vec3 scenePos, vec3 sceneDir, float dither) {
    vec3 startPos   = gbufferModelViewInverse[3].xyz;
    vec3 endPos     = scenePos;
        if (length(endPos) > 192.0) endPos = sceneDir * 192.0;

    float baseStep  = length(endPos - startPos);
    float stepCoeff = saturate(baseStep * rcp(clamp(far, 128.0, 192.0)));

    uint steps      = 8 + uint(stepCoeff * 16.0);

    vec3 rStep      = (endPos - startPos) / float(steps);
    vec3 rPos       = startPos + rStep * dither;
    float rLength   = length(rStep);

    mat3x3 scattering = mat3x3(0.0);
    vec3 transmittance = vec3(1.0);

    const mat2x3 scatterMat   = mat2x3(hazeCoeff, smokeCoeff);
    const mat2x3 extinctMat   = mat2x3(hazeCoeff * 1.1, smokeCoeff);

    uint i = 0;
    do {
        rPos += rStep;
    //for (uint i = 0; i < steps; ++i, rPos += rStep) {
        if (maxOf(transmittance) < 0.01) break;

        float altitude  = rPos.y + eyeAltitude;

        if (altitude > 256.0) continue;

        vec3 density    = smokeDensity(rPos, altitude);

        vec2 stepRho    = density.xy * rLength;
        vec3 od         = extinctMat * stepRho;

        vec3 stepT      = expf(-od);
        vec3 scatterInt = saturate((stepT - 1.0) * rcp(-max(od, 1e-16)));
        vec3 visScatter = transmittance * scatterInt;

        vec3 a          = visScatter * transmittance;

        mat2x3 stepScatter = mat2x3(scatterMat[0] * stepRho.x * a, scatterMat[1] * stepRho.y * a);

        #ifdef netherSmokeEmission
            vec3 smokeEmission = density.z * mix(vec3(1.0, 0.1, 0.0), fogEmissionColor * 0.5, saturate(density.z)) * stepRho.y * a;

            scattering     += mat3x3(stepScatter[0], stepScatter[1], smokeEmission);
        #else
            scattering     += mat3x3(stepScatter[0], stepScatter[1], vec3(0.0));
        #endif

        transmittance  *= stepT;
    } while (++i < steps);

    //vec3 smokeCol       = mix(fogCol, lightColor[1], saturate(scattering[1]));

    vec3 color          = scattering[0] * fogCol2 + scattering[1] * fogCol + scattering[2] * 0.6 * netherSmokeEmissionMult;


    if (color != color) {   //because NaNs on nVidia don't need a logic cause to happen
        color = vec3(0.0);
        transmittance = vec3(1.0);
    }

    return mat2x3(color, saturate(transmittance));
}

void applyFogData(inout vec3 color, in mat2x3 data) {
    color = color * data[1] + data[0];
}

#include "/lib/atmos/fog.glsl"

/* ------ REFRACTION ------ */
vec3 refract2(vec3 I, vec3 N, vec3 NF, float eta) {     //from spectrum by zombye
    float NoI = dot(N, I);
    float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
    if (k < 0.0) {
        return vec3(0.0); // Total Internal Reflection
    } else {
        float sqrtk = sqrt(k);
        vec3 R = (eta * dot(NF, I) + sqrtk) * NF - (eta * NoI + sqrtk) * N;
        return normalize(R * sqrt(abs(NoI)) + eta * I);
    }
}

/* --- TEMPORAL CHECKERBOARD --- */

#define checkerboardDivider 4
#define ditherPass
#include "/lib/frag/checkerboard.glsl"

void main() {
    sceneColor  = stex(colortex0).rgb;

    vec2 sceneDepth = vec2(stex(depthtex0).x, stex(depthtex1).x);

    vec3 viewPos0   = screenToViewSpace(vec3(uv / ResolutionScale, sceneDepth.x));
    vec3 scenePos0  = viewToSceneSpace(viewPos0);

    vec3 viewPos1   = screenToViewSpace(vec3(uv / ResolutionScale, sceneDepth.y));
    vec3 scenePos1  = viewToSceneSpace(viewPos1);

    vec3 viewDir    = normalize(viewPos0);
    vec3 worldDir   = normalize(scenePos0);

    bool translucent    = sceneDepth.x < sceneDepth.y;

    float cave      = saturate(float(eyeBrightnessSmooth.y) / 240.0);

    #ifdef refractionEnabled
    if (translucent){
        vec4 tex1           = stex(colortex1);
        vec3 sceneNormal    = decodeNormal(tex1.xy);
        vec3 viewNormal     = mat3(gbufferModelView) * sceneNormal;
        //vec3 flatNormal     = normalize(cross(dFdxFine(scenePos0), dFdyFine(scenePos0)));
        vec3 flatNormal     = decodeNormal(unpack2x8(tex1.w));

        //if (clampDIR(flatNormal) != flatNormal)
        flatNormal = clampDIR(flatNormal);

        vec3 flatViewNormal = mat3(gbufferModelView) * flatNormal;

        vec3 normalCorrected = dot(viewNormal, viewDir) > 0.0 ? -viewNormal : viewNormal;

        vec3 refractedDir   = refract2(normalize(viewPos1), normalCorrected, flatViewNormal, rcp(1.33));
        //vec3 refractedDir   = refract(normalize(viewPos1), normalCorrected, rcp(1.33));

        float refractedDist = distance(viewPos0, viewPos1);

        vec3 refractedPos   = viewPos1 + refractedDir * refractedDist;

        vec3 screenPos      = viewToScreenSpace(refractedPos);

        float distToEdge    = maxOf(abs(screenPos.xy * 2.0 - 1.0));
            distToEdge      = sqr(sstep(distToEdge, 0.7, 1.0));

            screenPos.xy    = mix(screenPos.xy, uv / ResolutionScale, distToEdge);

        //vec2 refractionDelta = uv - screenPos.xy;

        float sceneDepthNew = texture(depthtex1, screenPos.xy * ResolutionScale).x;

        if (sceneDepthNew > sceneDepth.x) {
            sceneDepth.y    = sceneDepthNew;
            viewPos1        = screenToViewSpace(vec3(screenPos.xy, sceneDepth.y));
            scenePos1       = viewToSceneSpace(viewPos1);

            sceneColor.rgb  = texture(colortex0, screenPos.xy * ResolutionScale).rgb;
        }
    }
    #endif
    float vDotL     = dot(viewDir, lightDirView);
    float bluenoise = ditherBluenoise();

    vec4 tex2       = stex(colortex2);
    int matID       = unpack2x8I(tex2.y).x;
    bool water      = matID == 102;

    if (translucent && isEyeInWater == 0) {

        if (water) {
            sceneColor  = waterFog(sceneColor, distance(scenePos0, scenePos1), lightColor[1]);
        }

        vec4 translucencyColor  = stex(colortex3);
        vec4 reflectionAux      = stex(colortex4);

        vec3 albedo     = decodeRGBE8(vec4(unpack2x8(reflectionAux.z), unpack2x8(reflectionAux.w)));

        vec3 tint       = sqr(saturate(normalizeSafe(albedo)));

        sceneColor  = blendTranslucencies(sceneColor, translucencyColor, tint);
    }

    sceneColor      = clamp16F(sceneColor);

    fogScattering   = vec4(0.0);
    fogTransmittance = vec3(1.0);

    #ifdef fogVolumeEnabled
    mat2x3 fogData  = mat2x3(vec3(0.0), vec3(1.0));

    if (isEyeInWater == 0) {
        fogData    = volumetricFog(scenePos0, worldDir, bluenoise);
    }

    fogScattering.rgb = fogData[0];
    fogScattering.a = depthLinear(sceneDepth.x);
    fogTransmittance = fogData[1];

    fogScattering       = clamp16F(fogScattering);
    #endif
}