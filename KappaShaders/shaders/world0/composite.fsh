#version 450 compatibility

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

flat in mat4x3 lightColor;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;

uniform sampler2D noisetex;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

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

uniform vec4 daytime;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;

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

float readCloudShadowmap(sampler2D shadowmap, vec3 position) {
    position    = mat3(shadowModelView) * position;
    position   /= cloudShadowmapRenderDistance;
    position.xy = position.xy * 0.5 + 0.5;

    position.xy /= vec2(1.0, 1.0 + (1.0 / 3.0));

    return texture(shadowmap, position.xy).a;
}
vec3 shadowColorSample(sampler2D tex, vec2 position) {
    vec4 colorSample = texture(shadowcolor0, position);
    return mix(vec3(1.0), colorSample.rgb * 4.0, colorSample.a);
}

/* ------ VOLUMETRIC FOG ------ */

vec2 airPhaseFunction(float cosTheta) {
    return vec2(rayleighPhase(cosTheta), mieCS(cosTheta, airMieG));
}
float airMieBackscatter(float cosTheta, float g) {
    return mieHG(cosTheta, -g * rcp(pi));
}
float airPhaseMist(float cosTheta, float g) {
    g  *= mistMieAnisotropy;
    return mix(mieCS(cosTheta, g), mieHG(cosTheta, -g * rpi), mistMieAnisotropy / 4.0);
}
float fogMistPhase(float cosTheta, float density) {
    return mix(mieCS(cosTheta, pow(airMieG, 1.0 + density)), airMieBackscatter(cosTheta, airMieG), 0.19);
}

uniform vec3 fogDensityCoeff;

#ifdef RFOG_SB_FogWeather
uniform float RW_FOG_GreenShift;
uniform float RW_BIOME_Sandstorm;
uniform float RW_SeaLevelBias;
#else
const float RW_FOG_GreenShift = 0.0;
const float RW_BIOME_Sandstorm = 0.0;
const float RW_SeaLevelBias = 0.0;
#endif

#define fogMistAltitude 120.0   //[30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0 150.0]
#define fogSeaLevel 64.0    //[8.0 16.0 24.0 32.0 40.0 48.0 56.0 64.0 72.0 80.0 88.0 96.0]
#define fogMistFalloff 1.0  //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#ifdef freezeAtmosAnim
    const float fogTime   = float(atmosAnimOffset) * 0.006;
#else
    #ifdef volumeWorldTimeAnim
        float fogTime     = worldAnimTime * 3.6;
    #else
        float fogTime     = frameTimeCounter * 0.006;
    #endif
#endif

float mistDensity(vec3 rPos, float altitude) {
    vec3 wind   = vec3(fogTime, 0.0, fogTime * 0.5);
    float noise = value3D(rPos * 0.03 + wind) + value3D(rPos * 0.06 + wind * pi) * 0.5;

    if (RW_BIOME_Sandstorm > 0.1) noise += cubeSmooth(value3D(rPos * 0.08 + wind * sqrPi)) * 0.3 * RW_BIOME_Sandstorm;

    float mist  = expf(-max0((altitude - (fogSeaLevel + RW_SeaLevelBias)) * 0.01 * fogMistFalloff));
        mist    = sstep(noise * rcp(1.5) - (1.0 - mist) * 0.5, 0.4, 0.7);

        mist   *= sqr(1.0 - linStep(altitude, fogMistAltitude - 15.0 + RW_SeaLevelBias, fogMistAltitude + RW_SeaLevelBias));

    return mist * max(fogDensityCoeff.z, RW_BIOME_Sandstorm * 12);
}

vec3 fogAirDensity(vec3 rPos, float altitude) {
    rPos   += cameraPosition;

    float maxFade = sqr(1.0 - linStep(altitude, 144.0, 256.0));

    vec2 rm     = expf(-max0((altitude - (fogSeaLevel + RW_SeaLevelBias)) * fogFalloffScale));
    //rm.y *= 0;
    float mist  = 0.0;
    if (max(RW_BIOME_Sandstorm, fogDensityCoeff.z) > 1e-5) mist = mistDensity(rPos, altitude);

    return vec3(rm * fogAirScale * fogDensityCoeff.xy * maxFade * fogDensityMult, mist);
}

#define airDensity 1.0
#define fogMinSteps 10
#define fogAdaptiveSteps 12     //[4 6 8 10 12 14 16 18]
#define fogClipDist 512.0       //[256.0 384.0 448.0 512.0 768.0 1024.0]
#define fogMistLightingSteps 2  //[2 4 6 8 10 12]

float fogMistLightOD(vec3 pos) {
    float stepsize = 12.0;

    const int steps = fogMistLightingSteps;

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += lightDir * stepsize) {

        if(pos.y > fogMistAltitude || pos.y < 0.0) continue;
        
        float density = mistDensity(pos, pos.y);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}

mat2x3 volumetricFog(vec3 scenePos, vec3 sceneDir, bool isSky, float vDotL, float dither, float cave) {
    float topDist    = length(sceneDir * ((256.0 - eyeAltitude) * rcp(sceneDir.y)));
    float bottomDist = length(sceneDir * ((-32.0 - eyeAltitude) * rcp(sceneDir.y)));

    float volumeHull = sceneDir.y > 0.0 ? topDist : bottomDist;

    float endDist   = isSky ? min(volumeHull, fogClipDist) : length(scenePos);
    float startDist = eyeAltitude > 256.0 ? topDist : 1.0;

    vec3 startPos   = eyeAltitude > 256.0 ? sceneDir * startDist : vec3(0.0);
        startPos   += gbufferModelViewInverse[3].xyz;
    vec3 endPos     = isSky ? sceneDir * endDist : scenePos;

    float baseStep  = length(endPos - startPos);
    float stepCoeff = saturate(baseStep * rcp(clamp(far, 256.0, 512.0)));

    uint steps      = fogMinSteps + uint(stepCoeff * fogAdaptiveSteps);

    vec3 rStep      = (endPos - startPos) / float(steps);
    vec3 rPos       = startPos + rStep * dither;
    float rLength   = length(rStep);

    vec3 shadowStartPos = transMAD(shadowModelView, (startPos));
        shadowStartPos  = projMAD(shadowProjection, shadowStartPos);
        shadowStartPos.z *= 0.2;
    vec3 shadowEndPos   = transMAD(shadowModelView, (endPos));
        shadowEndPos    = projMAD(shadowProjection, shadowEndPos);
        shadowEndPos.z *= 0.2;

    vec3 shadowStep = (shadowEndPos - shadowStartPos) / float(steps);
    vec3 shadowPos  = shadowStartPos + shadowStep * dither;

    mat2x3 scattering = mat2x3(0.0);
    vec3 transmittance = vec3(1.0);

    vec3 phase;
        phase.xy    = airPhaseFunction(vDotL);
        phase.z     = airPhaseMist(vDotL, airMieG);
    float phaseIso  = 0.271;  // This is not accurate, dont use it as a reference value

    vec3 sunlight       = (worldTime>23000 || worldTime<12900) ? lightColor[0] : lightColor[2];
        sunlight       *= lightFlip;
        sunlight       *= mix(vec3(1.0), vec3(0.9, 1.25, 1.0), saturate(RW_FOG_GreenShift - 1.0));
        sunlight       *= mix(vec3(1.0), vec3(1.35, 1.4, 1.2) * 1.3, saturate(RW_BIOME_Sandstorm));
    vec3 skylight       = lightColor[1] * cave;
        skylight        = mix(skylight, skylight * 0.5 + maxOf(skylight) * pow(vec3(0.6, 1.0, 0.45), vec3(max(1.0, RW_FOG_GreenShift))), saturate(RW_FOG_GreenShift));

    #ifdef UseLightleakPrevention
        sunlight       *= cave;
    #endif

    float pFade         = saturate(mieHG(vDotL, 0.65));

    uint i = 0;
    do {
        rPos += rStep; shadowPos += shadowStep;
        if (length(rPos) > length(scenePos) && !isSky) break;
    //for (uint i = 0; i < steps; ++i, rPos += rStep, shadowPos += shadowStep) {
        if (maxOf(transmittance) < 0.01) break;

        float altitude  = rPos.y + eyeAltitude;

        if (altitude > 256.0) continue;

        vec3 density    = fogAirDensity(rPos, altitude);

        //if (max3(density) < 1e-32) continue;

        vec3 stepRho    = density * rLength;
        vec3 od         = fogExtinctMat * stepRho;

        vec3 stepT      = expf(-od);
        vec3 scatterInt = saturate((stepT - 1.0) * rcp(-max(od, 1e-16)));
        vec3 visScatter = transmittance * scatterInt;

        #ifdef fogMistAdvanced
            if (density.z > 0.0) {
                float mistLightOD = fogMistLightOD(rPos + cameraPosition);

                float mistLighting  = expf(-stepRho.z) * pow(1.0 + 1.0 * 0.7 * mistLightOD, -1.0 / 0.7);
                    mistLighting    = mix(pi * (1.0 - 0.6 * expf(-density.z * 28.0)), 1.0, pFade);
                    mistLighting    = fogMistPhase(vDotL, mistLightOD);
                phase.z     = mistLighting;
            }
        #else
            if (density.z > 0.0) {
                phase.z     = fogMistPhase(vDotL, density.z) * (2.0 - pFade);
            }
        #endif

        //vec3 sunScatter = fogScatterMat * (stepRho * phase) * visScatter;
        //vec3 skyScatter = fogScatterMat * (stepRho * phaseIso) * visScatter;
        vec3 sunScatter = vec3(0.0);
        vec3 skyScatter = vec3(0.0);

        vec3 currPhase  = phase;

        for (uint j = 0; j < 4; ++j) {
            float n     = float(j);
            float m     = pow(0.5, n);

            phase.y     = mieCS(vDotL, airMieG * m);
            if (density.z > 0.0) phase.z = airPhaseMist(vDotL, airMieG * m);

            sunScatter += fogScatterMat * (stepRho * phase) * visScatter * m;
        }

        skyScatter     += fogScatterMat * (stepRho * phaseIso) * visScatter;

        vec3 shadowCoord = vec3(shadowmapWarp(shadowPos.xy), shadowPos.z) * 0.5 + 0.5;

        float shadow0   = texture(shadowtex0, shadowCoord);

        float shadow    = 1.0;
        vec3 shadowCol  = vec3(1.0);
        
        if (shadow0 < 1.0) {
            shadow      = texture(shadowtex1, shadowCoord);

            if (abs(shadow - shadow0) > 0.1) {
                shadowCol   = shadowColorSample(shadowcolor0, shadowCoord.xy);
            }
        }
        #ifdef cloudShadowsEnabled
        shadow         *= readCloudShadowmap(colortex5, rPos);
        #endif

        scattering[0]  += (sunScatter * shadowCol * transmittance) * shadow;
        scattering[1]  += skyScatter * transmittance;

        transmittance  *= stepT;
    } while (++i < steps);

    vec3 color  = scattering[0] * sunlight + scattering[1] * skylight;

    if (color != color) {   //because NaNs on nVidia don't need a logic cause to happen
        color = vec3(0.0);
        transmittance = vec3(1.0);
    }

    return mat2x3(color, saturate(transmittance));
}

/* ------ WATER VOLUME ------ */
#define waterVolMinSteps 3
#define waterVolAdaptiveSteps 9     //[2 4 6 8 10 12]
#define waterVolClipDist 48.0       //[16.0 24.0 32.0 40.0 48.0 56.0 64.0]

mat2x3 volumetricWater(vec3 scenePos, vec3 startPos0, vec3 worldDir, bool isSky, float vDotL, float dither, float cave) {
    float endDist   = isSky ? waterVolClipDist : length(scenePos);

    vec3 startPos   = startPos0;
    vec3 endPos     = isSky ? startPos0 + worldDir * waterVolClipDist : scenePos;
        if (distance(startPos, endPos) > waterVolClipDist) endPos = startPos0 + waterVolClipDist * worldDir;

    float baseStep  = length(endPos - startPos);
    float stepCoeff = saturate(baseStep / waterVolClipDist);
        //if (isEyeInWater == 1) stepCoeff = 1.0;

    uint steps      = waterVolMinSteps + uint(stepCoeff * waterVolAdaptiveSteps);

    vec3 rStep      = (endPos - startPos) / float(steps);
    vec3 rPos       = startPos + rStep * dither;
    float rLength   = length(rStep);

    vec3 shadowStartPos = transMAD(shadowModelView, (startPos));
        shadowStartPos  = projMAD(shadowProjection, shadowStartPos);
        shadowStartPos.z *= 0.2;
    vec3 shadowEndPos   = transMAD(shadowModelView, (endPos));
        shadowEndPos    = projMAD(shadowProjection, shadowEndPos);
        shadowEndPos.z *= 0.2;

    vec3 shadowStep = (shadowEndPos - shadowStartPos) / float(steps);
    vec3 shadowPos  = shadowStartPos + shadowStep * dither;

    mat2x3 scattering = mat2x3(0.0);
    vec3 transmittance = vec3(1.0);

    float phase     = mieHG(vDotL, 0.7);
    float phaseIso  = 0.25 * rcp(pi);
        phase       = mix(phase, phaseIso, 0.3);

    vec3 sunlight       = (worldTime>23000 || worldTime<12900) ? lightColor[0] : lightColor[2];
        sunlight       *= lightFlip;
    vec3 skylight       = lightColor[1] * cave * rpi;

    #ifdef UseLightleakPrevention
        sunlight       *= cave;
    #endif

    uint i = 0;
    do {
        rPos += rStep; shadowPos += shadowStep;
        if (length(rPos) > length(scenePos) && !isSky) break;
    //for (uint i = 0; i < steps; ++i, rPos += rStep, shadowPos += shadowStep) {
        if (distance(startPos, rPos) > waterVolClipDist) continue;
        if (maxOf(transmittance) < 0.01) break;

        float altitude  = rPos.y + eyeAltitude;

        float stepRho   = rLength * waterDensity;

        vec3 shadowCoord = vec3(shadowmapWarp(shadowPos.xy), shadowPos.z) * 0.5 + 0.5;

        float shadow0   = texture(shadowtex0, shadowCoord);

        float shadow    = 1.0;
        vec3 shadowCol  = vec3(1.0);
        
        if (shadow0 < 1.0) {
            shadow      = texture(shadowtex1, shadowCoord);

            if (abs(shadow - shadow0) > 0.1) {
                shadowCol   = shadowColorSample(shadowcolor0, shadowCoord.xy);
            }
        }
        #ifdef cloudShadowsEnabled
        shadow         *= readCloudShadowmap(colortex5, rPos);
        #endif

        scattering[0]  += (shadowCol * transmittance) * shadow;
        scattering[1]  += transmittance;

        transmittance  *= expf(-waterAttenCoeff * stepRho);

    } while (++i < steps);

    vec3 attenMul   = (1.0 - expf(-waterAttenCoeff * rLength)) * rcp(waterAttenCoeff);

    scattering[0]  *= waterScatterCoeff * attenMul * phase;
    scattering[1]  *= waterScatterCoeff * attenMul;

    vec3 color  = scattering[0] * sunlight + scattering[1] * skylight;

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

    float cave      = sqr(saturate(float(eyeBrightnessSmooth.y) / 240.0));

    vec4 tex2       = stex(colortex2);
    int matID       = unpack2x8I(tex2.y).x;

    #ifdef refractionEnabled
    if (translucent && matID != 100){
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

    bool water      = matID == 102;

    if (translucent) {

        if (water && isEyeInWater == 0) {
            #ifdef waterVolumeEnabled
            mat2x3 waterVol     = volumetricWater(scenePos1, scenePos0, normalize(scenePos1), false, vDotL, bluenoise, cave);
            applyFogData(sceneColor.rgb, waterVol);
            #else
            sceneColor  = waterFog(sceneColor, distance(scenePos0, scenePos1), lightColor[1]);
            #endif
        }

        vec4 translucencyColor  = stex(colortex3);
        vec4 reflectionAux      = stex(colortex4);

        vec3 albedo     = decodeRGBE8(vec4(unpack2x8(reflectionAux.z), unpack2x8(reflectionAux.w)));

        vec3 tint       = sqr(saturate(normalizeSafe(albedo)));

        sceneColor  = blendTranslucencies(sceneColor, translucencyColor, tint);
    }

    sceneColor      = drawbufferClamp(sceneColor);

    fogScattering   = vec4(0.0);
    fogTransmittance = vec3(1.0);

    #if (defined fogVolumeEnabled || defined waterVolumeEnabled)

    const float fogLOD      = 1.0;

    vec2 fogCoord           = uv * fogLOD;

    if (clamp(fogCoord, -pixelSize * fogLOD, 1.0 + pixelSize * fogLOD) == fogCoord) {
        fogCoord            = saturate(fogCoord);

        int frame       = (frameCounter) % checkerboardDivider;
        ivec2 offset    = temporalOffset4[frame];
        ivec2 pixel     = ivec2(floor(fogCoord * viewSize));
        fogCoord        = vec2(pixel) / viewSize;

        float bluenoise = ditherBluenoiseCheckerboard(vec2(offset));

        float sceneDepth = texelFetch(depthtex0, pixel, 0).x;

        vec3 viewPos0   = screenToViewSpace(vec3(fogCoord / ResolutionScale, sceneDepth));
        vec3 scenePos0  = viewToSceneSpace(viewPos0);

        vec3 viewDir    = normalize(viewPos0);
        vec3 worldDir   = normalize(scenePos0);

        float vDotL     = dot(viewDir, lightDirView);
        bool isSky      = !landMask(sceneDepth);

        mat2x3 fogData  = mat2x3(vec3(0.0), vec3(1.0));

        if (isEyeInWater == 1) {
            #ifdef waterVolumeEnabled
            fogData = volumetricWater(scenePos0, gbufferModelViewInverse[3].xyz, worldDir, isSky, vDotL, bluenoise, cave);
            #endif
        } else {
            #ifdef fogVolumeEnabled
            fogData    = volumetricFog(scenePos0, worldDir, isSky, vDotL, bluenoise, cave);
            #endif
        }

        fogScattering.rgb = fogData[0];
        fogScattering.a = depthLinear(sceneDepth);
        fogTransmittance = fogData[1];
    }

    fogScattering       = clamp16F(fogScattering);

    #endif
}