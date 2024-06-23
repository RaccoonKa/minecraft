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

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 skyboxData;

#include "/lib/head.glsl"

uniform sampler2D colortex5;

uniform sampler2D noisetex;
uniform sampler3D depthtex1;

uniform sampler3D colortex1;
uniform sampler3D colortex2;

in vec2 uv;

flat in vec3 skylightColor;
flat in vec3 directLightColor;

flat in vec3 sunDir;
flat in vec3 moonDir;
flat in vec3 cloudLightDir;
flat in vec3 lightDir;

uniform int frameCounter;

uniform float aspectRatio;
uniform float eyeAltitude;
uniform float frameTimeCounter;
uniform float wetness;
uniform float worldAnimTime;

uniform vec2 viewSize, pixelSize;

uniform vec3 cameraPosition;

/*
uniform vec3 upDir, upDirView;
uniform vec3 sunDir, sunDirView;
uniform vec3 moonDir, moonDirView;
*/

uniform vec4 daytime;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;


/* ------ includes ------ */
#define FUTIL_ROT2
#include "/lib/fUtil.glsl"

#include "/lib/frag/bluenoise.glsl"
#include "/lib/frag/gradnoise.glsl"

#include "/lib/atmos/phase.glsl"
#include "/lib/atmos/project.glsl"

#define airmassStepBias 0.33
#include "/lib/atmos/air/const.glsl"
#include "/lib/atmos/air/density.glsl"

#include "/lib/frag/noise.glsl"
#include "/lib/util/bicubic.glsl"

#include "/lib/atmos/clouds/common.glsl"

uniform int isLightning;
uniform float isLightningSmooth;

/* ------ CLOUDS ------ */
vec2 rsi(vec3 pos, vec3 dir, float r) {
    float b     = dot(pos, dir);
    float det   = sqr(b) - dot(pos, pos) + sqr(r);

    if (det < 0.0) return vec2(-1.0);

        det     = sqrt(det);

    return vec2(-b) + vec2(-det, det);
}

vec3 planetCurvePosition(in vec3 x) {
    return vec3(x.x, length(x + vec3(0.0, planetRad, 0.0))-planetRad, x.z);
}

vec4 RSky_CloudsReflected(vec3 Direction, float vDotL, float dither, vec3 SkyboxColor) {
    vec4 Result     = vec4(0, 0, 0, 1);

    vec3 sunlight       = directLightColor;
    vec3 skylight       = skylightColor;

    skylight += vec3(0.5, 0.5, 1.0) * 5.0 * max(getLuma(skylight), 0.3) * isLightningSmooth;

    float pFade         = saturate(mieCS(vDotL, 0.5));
        pFade           = mix(pFade, vDotL * 0.5 + 0.5, 1.0 / sqrt2);

    const float eyeAltitude = 64.0;
    vec3 camPos     = vec3(cameraPosition.x, eyeAltitude, cameraPosition.z);
    const uint volumeSamples = 45;

    float eFade         = saturate(mieCS(vDotL, 0.5) / 0.75);

    float vDotUp        = Direction.y;

    // --- volumetric clouds --- //
    #ifdef RSKY_SB_CloudVolume
    bool isBelowVol = true;
    bool visibleVol = Direction.y > 0.0 && isBelowVol || Direction.y < 0.0 && !isBelowVol;

    if (visibleVol) {

        vec2 BS         = rsi(vec3(0.0, planetRad + eyeAltitude, 0.0), Direction, planetRad + cloudRaymarchMinY);
        vec2 TS         = rsi(vec3(0.0, planetRad + eyeAltitude, 0.0), Direction, planetRad + cloudRaymarchMaxY);

        float BDistance = BS.y;
        float TDistance = TS.y;

        vec3 bottom     = Direction * ((cloudRaymarchMinY - eyeAltitude) * rcp(Direction.y));
        vec3 top        = Direction * ((cloudRaymarchMaxY - eyeAltitude) * rcp(Direction.y));

            bottom      = planetCurvePosition(Direction * BDistance);
            top         = planetCurvePosition(Direction * TDistance);

        float airDist   = length(Direction.y < 0.0 ? bottom : top);
            airDist     = min(airDist, cloudVolumeClip);

        vec3 airmass    = getAirmass(vec3(0.0, planetRad + eyeAltitude, 0.0), Direction, airDist, rpi, 3) * rcp(airDist);

        if (Direction.y < 0.0 && isBelowVol || Direction.y > 0.0 && !isBelowVol) {
            bottom      = vec3(0.0);
            top         = vec3(0.0);
        }

        vec3 start      = isBelowVol ? bottom : top;
        vec3 end        = isBelowVol ? top : bottom;

        const float baseLength  = cloudCumulusDepth / float(volumeSamples);
        float stepLength    = length(end - start) * rcp(float(volumeSamples));
        float stepCoeff     = stepLength * rcp(baseLength);
            stepCoeff       = 0.45 + clamp(stepCoeff - 1.1, 0.0, 2.5) * 0.5;

        uint steps          = uint(volumeSamples * stepCoeff);

        vec3 rStep          = (end - start) * rcp(float(steps));
        vec3 rPos           = rStep * dither + start + cameraPosition;
        float rLength       = length(rStep);

        vec3 scattering     = vec3(0.0);
        float transmittance = 1.0;

        vec3 bouncelight    = vec3(0.6, 1.0, 0.8) * sunlight * rcp(pi * 14.0 * sqrt2) * max0(dot(cloudLightDir, vec3(0,1,0)));

        const float sigmaA  = 1.0;
        const float sigmaT  = 0.1;

        for (uint i = 0; i < steps; ++i, rPos += rStep) {
            if (transmittance < 0.025) break;
            if (rPos.y < cloudRaymarchMinY || rPos.y > cloudRaymarchMaxY) continue;

            float dist  = distance(rPos, cameraPosition);
            if (dist > cloudVolumeClip) continue;

            vec2 TypeParameters;
            float density = cloudCumulusShape(rPos, TypeParameters);
            if (density <= 0.0) continue;

            float extinction    = density * sigmaT;
            float stepT         = exp(-extinction * rLength);
            float integral      = (1.0 - stepT) * rcp(sigmaT);

            //float airmassMult = 1.0 + sstep(dist / cloudVolumeClip, 0.5, 1.0) * pi; 
            vec3 atmosFade = expf(-max(airScatterMat * airmass.xy * (dist), 0.0));
            //float atmosFade = exp(-max0(dist * 2e-5));
                atmosFade   = mix(atmosFade, vec3(0.0), sqr(linStep(dist / cloudVolumeClip, 0.5, 1.0)));

            if (maxOf(atmosFade) < 1e-4) {
                scattering     += (SkyboxColor * sigmaT) * (integral * transmittance);
                transmittance  *= stepT;

                continue;
            }

            vec3 stepScatter    = vec3(0.0);

            float lightOD       = cloudVolumeLightOD(rPos, 4);
        
            float skyOD         = cloudVolumeSkyOD(rPos, 3);
            
            float bounceOD      = cube(linStep(rPos.y, cloudRaymarchMinY, cloudRaymarchMinY + cloudCumulusDepth * 0.3)) * max0(rPos.y - cloudRaymarchMinY);

            //const float albedo = 0.85;
            const float scatterMult = 1.0;

            vec2 LayerParams = GetLayerParams(rPos.y, TypeParameters);

            #define albedo LayerParams.x

            float avgTransmittance  = exp(-((LayerParams.y / euler) / sigmaT) * density);
            float bounceEstimate    = estimateEnergy(albedo * (1.0 - avgTransmittance));
            float baseScatter       = albedo * (1.0 - stepT);

            vec3 phaseG         = pow(vec3(0.5, 0.35, 0.9), vec3((1.0 + (lightOD + density * rLength) * sigmaT)));

            float scatterScale  = pow(1.0 + 1.0 * (lightOD) * sigmaT, -1.0 / 1.0) * bounceEstimate;
            float SkyScatterScale = pow(1.0 + 1.0 * skyOD * sigmaT, -1.0 / 1.0) * bounceEstimate;

            stepScatter.x  += baseScatter * cloudPhaseNew(vDotL, phaseG) * scatterScale;
            stepScatter.y  += baseScatter * cloudPhaseSky(vDotUp, phaseG) * SkyScatterScale;

            //stepScatter.x += baseScatter * scatterScale * sigmaT * integral;

            //stepScatter.z  += bounceOD * powder;

            stepScatter     = (sunlight * stepScatter.x) + (skylight * stepScatter.y) + (bouncelight * stepScatter.z);
            stepScatter     = mix(SkyboxColor * sigmaT * integral, stepScatter, atmosFade);
            scattering     += stepScatter * (transmittance);
            #undef albedo

            transmittance  *= stepT;
        }

        transmittance       = linStep(transmittance, cloudTransmittanceThreshold, 1.0);

        Result.rgb    += scattering;
        Result.a *= transmittance;
    }
    #endif

    bool BelowPlane     = true;
    bool PlaneVisible   = false;

    bool IsPlanet   = rsi(vec3(0, planetRad + max(eyeAltitude, 1.0), 0), Direction, planetRad).x <= 0.0;
        //IsPlanet    = IsPlanet && Direction.y > 0.0;

    #ifdef RSKY_SB_CirrocumulusCloud
    PlaneVisible = IsPlanet && BelowPlane || Direction.y < 0.0 && !BelowPlane;

    if (PlaneVisible && (!BelowPlane || Result.a > 1e-10)) {
        vec3 Plane      = GetPlane(CLOUD_PLANE1_ALT, Direction);

        vec2 Sphere     = rsi(vec3(0, planetRad + eyeAltitude, 0), Direction, planetRad + CLOUD_PLANE1_ALT);

        float Distance  = length(Plane);
            Distance    = clamp(eyeAltitude > CLOUD_PLANE1_ALT ? Sphere.x : Sphere.y, 0.0, CLOUD_PLANE1_CLIP);
            Plane       = planetCurvePosition(Direction * Distance);

        vec3 Airmass    = getAirmass(vec3(0, planetRad + eyeAltitude, 0), Direction, Distance, 0.25, 3) / Distance;

        vec3 RPosition  = Plane + cameraPosition;

        vec4 VolumeResult = vec4(0, 0, 0, 1);

        mat2x3 VolumeBounds = mat2x3(
            GetPlane(CLOUD_PLANE1_BOUNDS.x, Direction) + cameraPosition,
            GetPlane(CLOUD_PLANE1_BOUNDS.y, Direction) + cameraPosition
        );

        float RLength   = distance(VolumeBounds[0], VolumeBounds[1]);

        const float SigmaT  = CLOUD_PLANE1_SIGMA;

        if (Distance < CLOUD_PLANE1_CLIP) {
            float Density   = Cloud_Planar1_Shape(RPosition);

            if (Density > 0.0) {
                float extinction    = Density * SigmaT;
                float stepT         = exp(-extinction * RLength);
                float integral      = (1.0 - stepT) * rcp(SigmaT);

                vec3 atmosFade  = expf(-max(airScatterMat * Airmass.xy * Distance, 0.0));
                    atmosFade   = mix(atmosFade, vec3(0.0), sqr(linStep(Distance / CLOUD_PLANE1_CLIP, 0.5, 1.0)));

                if (maxOf(atmosFade) < 1e-4) {
                    //VolumeResult.rgb     += (skyColor * SigmaT) * (integral * VolumeResult.a);
                    //VolumeResult.a  *= stepT;
                } else {
                    float lightOD       = Cloud_Planar1_Light(mix(VolumeBounds[0], RPosition, 1-max0(cloudLightDir.y)), 3);
                    float skyOD         = Cloud_Planar1_Light(VolumeBounds[0], 3, vec3(0.0, 1.0, 0.0));

                        lightOD *= euler; skyOD *= euler;

                    vec2 scattering     = vec2(0);

                    const float albedo = 0.75;
                    const float scatterMult = 1.0;
                    float avgTransmittance  = exp(-(4.0 / SigmaT) * Density);
                    float bounceEstimate    = estimateEnergy(albedo * (1.0 - avgTransmittance));
                    float baseScatter       = albedo * (1.0 - stepT);

                    vec3 phaseG         = pow(vec3(0.7, 0.5, 0.95), vec3(1.0 + (lightOD + Density * RLength) * SigmaT) * vec3(1, 1, 1));
                    vec3 phaseGSky      = pow(vec3(0.6, 0.4, 0.8), vec3(1.0 + (skyOD + Density * RLength) * SigmaT));

                    float scatterScale  = pow(1.0 + 1.0 * (lightOD) * SigmaT, -1.0 / 1.0) * bounceEstimate;
                    float SkyScatterScale = pow(1.0 + 1.0 * skyOD * SigmaT, -1.0 / 1.0) * bounceEstimate;

                    scattering.x  += baseScatter * cloudPhaseNew(vDotL, phaseG) * scatterScale;
                    scattering.y  += baseScatter * cloudPhaseSky(Direction.y, phaseGSky) * SkyScatterScale;

                    //vec3 sunlight = ReadSunlightGradient(RPosition, Direction);

                    VolumeResult.rgb    = (sunlight * scattering.x) + (skylight * scattering.y);
                    VolumeResult.rgb    = mix(SkyboxColor * SigmaT * integral, VolumeResult.rgb, atmosFade);

                    VolumeResult.a     *= stepT;
                }
            }
        }

        VolumeResult = clamp16F(VolumeResult);

        if (BelowPlane) {
            Result.rgb    += VolumeResult.rgb * Result.a;
            Result.a *= VolumeResult.a;
        } else {
            Result.rgb     = Result.rgb * VolumeResult.a + VolumeResult.rgb;
            Result.a *= VolumeResult.a;
        }
    }
    #endif

    // Cirrus/Cirrostratus
    #ifdef RSKY_SB_CirrusCloud
    PlaneVisible = IsPlanet && BelowPlane || Direction.y < 0.0 && !BelowPlane;

    if (PlaneVisible && (!BelowPlane || Result.a > 1e-10)) {
        vec3 Plane      = GetPlane(CLOUD_PLANE0_ALT, Direction);

        vec2 Sphere     = rsi(vec3(0, planetRad + eyeAltitude, 0), Direction, planetRad + CLOUD_PLANE0_ALT);

        float Distance  = length(Plane);
            Distance    = clamp(eyeAltitude > CLOUD_PLANE0_ALT ? Sphere.x : Sphere.y, 0.0, CLOUD_PLANE0_CLIP);
            Plane       = planetCurvePosition(Direction * Distance);

        vec3 Airmass    = getAirmass(vec3(0, planetRad + eyeAltitude, 0), Direction, Distance, 0.25, 3) / Distance;

        vec3 RPosition  = Plane + cameraPosition;

        vec4 VolumeResult = vec4(0, 0, 0, 1);

        mat2x3 VolumeBounds = mat2x3(
            GetPlane(CLOUD_PLANE0_BOUNDS.x, Direction) + cameraPosition,
            GetPlane(CLOUD_PLANE0_BOUNDS.y, Direction) + cameraPosition
        );

        float RLength   = distance(VolumeBounds[0], VolumeBounds[1]);

        const float SigmaT  = CLOUD_PLANE0_SIGMA;

        if (Distance < CLOUD_PLANE0_CLIP) {
            float Density   = Cloud_Planar0_Shape(RPosition);

            if (Density > 0.0) {
                float extinction    = Density * SigmaT;
                float stepT         = exp(-extinction * RLength);
                float integral      = (1.0 - stepT) * rcp(SigmaT);

                vec3 atmosFade  = expf(-max(airScatterMat * Airmass.xy * Distance, 0.0));
                    atmosFade   = mix(atmosFade, vec3(0.0), sqr(linStep(Distance / CLOUD_PLANE0_CLIP, 0.5, 1.0)));

                if (maxOf(atmosFade) < 1e-4) {
                    //VolumeResult.rgb     += (skyColor * SigmaT) * (integral);
                    //VolumeResult.a  *= stepT;
                } else {
                    float lightOD       = Cloud_Planar0_Light(mix(VolumeBounds[0], RPosition, 1-max0(cloudLightDir.y)), 3, cloudLightDir);
                    float skyOD         = Cloud_Planar0_Light(VolumeBounds[0], 3, vec3(0.0, 1.0, 0.0));

                        lightOD *= euler; skyOD *= euler;

                    vec2 scattering     = vec2(0);

                    const float albedo = 0.7;
                    const float scatterMult = 1.0;
                    float avgTransmittance  = exp(-(12.0 / SigmaT) * Density);
                    float bounceEstimate    = estimateEnergy(albedo * (1.0 - avgTransmittance));
                    float baseScatter       = albedo * (1.0 - stepT);

                    vec3 phaseG         = pow(vec3(0.72, 0.5, 0.9), vec3(1.0 + (lightOD + Density * RLength) * SigmaT) * vec3(0.66, 0.5, 0.2));
                    vec3 phaseGSky      = pow(vec3(0.5, 0.35, 0.8), vec3(1.0 + (skyOD + Density * RLength) * SigmaT));

                    float scatterScale  = pow(1.0 + 1.0 * (lightOD) * SigmaT, -1.0 / 1.0) * bounceEstimate;
                    float SkyScatterScale = pow(1.0 + 1.0 * skyOD * SigmaT, -1.0 / 1.0) * bounceEstimate;

                    scattering.x  += baseScatter * cloudPhaseNew(vDotL, phaseG) * scatterScale;
                    scattering.y  += baseScatter * cloudPhaseSky(Direction.y, phaseGSky) * SkyScatterScale;

                    //vec3 sunlight = ReadSunlightGradient(RPosition, Direction);

                    VolumeResult.rgb    = (sunlight * scattering.x) + (skylight * scattering.y);
                    VolumeResult.rgb    = mix(SkyboxColor * SigmaT * integral, VolumeResult.rgb, atmosFade);
                    //VolumeResult.rgb    = VolumeResult.rgb * (VolumeResult.a);

                    VolumeResult.a     *= stepT;
                }
            }
        }

        VolumeResult = clamp16F(VolumeResult);

        if (BelowPlane) {
            Result.rgb    += VolumeResult.rgb * Result.a;
            Result.a *= VolumeResult.a;
        } else {
            Result.rgb     = Result.rgb * VolumeResult.a + VolumeResult.rgb;
            Result.a *= VolumeResult.a;
        }
    }
    #endif

    // NL
    #ifdef RSKY_SB_NoctilucentCloud
    PlaneVisible = IsPlanet && BelowPlane || Direction.y < 0.0 && !BelowPlane;

    if (PlaneVisible && (!BelowPlane || Result.a > 1e-10)) {
        vec3 Plane      = GetPlane(CLOUD_NL_ALT, Direction);

        vec2 Sphere     = rsi(vec3(0, planetRad + eyeAltitude, 0), Direction, planetRad + CLOUD_NL_ALT);

        float Distance  = length(Plane);
            Distance    = clamp(eyeAltitude > CLOUD_NL_ALT ? Sphere.x : Sphere.y, 0.0, CLOUD_NL_CLIP);
            Plane       = planetCurvePosition(Direction * Distance);

        vec3 Airmass    = getAirmass(vec3(0, planetRad + eyeAltitude, 0), Direction, Distance, 0.25, 3) / Distance;

        vec3 RPosition  = Plane + cameraPosition;

        vec4 VolumeResult = vec4(0, 0, 0, 1);

        mat2x3 VolumeBounds = mat2x3(
            GetPlane(CLOUD_NL_BOUNDS.x, Direction) + cameraPosition,
            GetPlane(CLOUD_NL_BOUNDS.y, Direction) + cameraPosition
        );

        float RLength   = distance(VolumeBounds[0], VolumeBounds[1]);

        const float SigmaT  = CLOUD_NL_SIGMA;

        if (Distance < CLOUD_NL_CLIP) {
            float Density   = Cloud_NL_Shape(RPosition);

            if (Density > 0.0) {
                float extinction    = Density * SigmaT;
                float stepT         = exp(-extinction * RLength);
                float integral      = (1.0 - stepT) * rcp(SigmaT);

                vec3 atmosFade  = expf(-max(airScatterMat * Airmass.xy * Distance, 0.0));
                    //atmosFade   = mix(atmosFade, vec3(0.0), sqr(linStep(Distance / CLOUD_NL_CLIP, 0.5, 1.0)));

                if (maxOf(atmosFade) > 1e-4) {
                    const float albedo = 0.75;
                    const float scatterMult = 1.0;
                    float avgTransmittance  = exp(-(24.0 / SigmaT) * Density);
                    float bounceEstimate    = estimateEnergy(albedo * (1.0 - avgTransmittance));
                    float baseScatter       = albedo * (1.0 - stepT);

                    vec3 scattering     = vec3(extinction * RLength) * normalize(airRayleighCoeff);
                    float vDotL         = dot(Direction, sunDir);
                        //scattering     *= mieHG(vDotL, 0.5) /* (cubeSmooth((vDotL * 0.5 + 0.5)))*/;

                    vec3 CloudNL_Sunlight = sunIllum * getAirTransmittance(Direction * Distance + vec3(0,planetRad,0), sunDir, 3);

                    //vec3 sunlight = ReadSunlightGradient_NL(RPosition, Direction);

                    VolumeResult.rgb    = CloudNL_Sunlight * scattering * mix(vec3(0.6, 0.7, 1.0), vec3(1.0), sqrt(Density)) * atmosFade;
                }
            }
        }

        VolumeResult = clamp16F(VolumeResult);

        if (BelowPlane) {
            Result.rgb    += VolumeResult.rgb * Result.a;
        } else {
            Result.rgb     = Result.rgb + VolumeResult.rgb;
        }
    }
    #endif

    return Result;
}


/* ------ cloud shadows ------ */

uniform mat4 shadowModelViewInverse;

float generateCloudShadowmap(vec2 uv, vec3 lightDir, float dither) {
    vec3 position   = vec3(uv, 0.0) * 2.0 - 1.0;
        position.xy *= cloudShadowmapRenderDistance;
        position    = mat3(shadowModelViewInverse) * position;
        position.xz += cameraPosition.xz;
        //position    += lightDir * (256.0 - position.y) * rcp(lightDir.y);

    float lightFade = cubeSmooth(sqr(linStep(lightDir.y, 0.1, 0.15)));

    float transmittance = 1.0;

    if (lightFade > 0.0) {
        #ifdef RSKY_SB_CloudVolume
        vec3 bottom     = lightDir * ((cloudRaymarchMinY - position.y) * rcp(lightDir.y));
        vec3 top        = lightDir * ((cloudRaymarchMaxY - position.y) * rcp(lightDir.y));

        vec3 start      = bottom;
        vec3 end        = top;

        uint steps          = 40;

        vec3 rStep          = (end - start) * rcp(float(steps));
        vec3 rPos           = rStep * dither + start + position;
        float rLength       = length(rStep);

        const float sigmaT  = 0.1;

        for (uint i = 0; i < steps; ++i, rPos += rStep) {
            if (transmittance < 0.05) break;

            float fade      = 1.0 - sstep(distance(rPos.xz, cameraPosition.xz), cloudShadowmapRenderDistance * 0.5, cloudShadowmapRenderDistance);
            if (fade < 1e-3) {
                continue;
            }

            float density   = cloudCumulusShape(rPos);

            float extinction = density * sigmaT;
            float stepT     = exp(-extinction * rLength);
                stepT       = mix(1.0, stepT, fade);

            transmittance  *= stepT;
        }
        #endif

        #ifdef RSKY_SB_CirrocumulusCloud
        if (transmittance > 0.05) {
            vec3 Plane     = lightDir * ((CLOUD_PLANE1_ALT - position.y) * rcp(lightDir.y)) + position;

            float fade      = 1.0 - sstep(distance(Plane.xz, cameraPosition.xz), cloudShadowmapRenderDistance * 0.5, cloudShadowmapRenderDistance);
            if (fade > 1e-3) {
                const float SigmaT  = CLOUD_PLANE1_SIGMA;

                float Density   = Cloud_Planar1_Shape(Plane);

                float extinction    = Density * SigmaT;
                float stepT         = exp(-extinction * CLOUD_PLANE1_DEPTH);
                stepT       = mix(1.0, stepT, fade);
                transmittance  *= stepT;
            }
        }
        #endif

        #ifdef RSKY_SB_CirrusCloud
        if (transmittance > 0.05) {
            vec3 Plane     = lightDir * ((CLOUD_PLANE0_ALT - position.y) * rcp(lightDir.y)) + position;


            float fade      = 1.0 - sstep(distance(Plane.xz, cameraPosition.xz), cloudShadowmapRenderDistance * 0.5, cloudShadowmapRenderDistance);
            if (fade > 1e-3) {
                const float SigmaT  = CLOUD_PLANE0_SIGMA;

                float Density   = Cloud_Planar0_Shape(Plane);

                if (Density > 0.0) {
                    float extinction    = Density * SigmaT;
                    float stepT         = exp(-extinction * CLOUD_PLANE0_DEPTH);
                    stepT       = mix(1.0, stepT, fade);
                    transmittance  *= stepT;
                }
            }
        }
        #endif

        transmittance       = linStep(transmittance, 0.05, 1.0);
        float fade      = 1.0 - sstep(distance((lightDir * ((2000.0 - position.y) * rcp(lightDir.y)) + position).xz, cameraPosition.xz), cloudShadowmapRenderDistance * 0.5, cloudShadowmapRenderDistance);
        transmittance       = mix(1.0 - wetness * 0.90, transmittance, fade);
        transmittance       = mix(1.0 - wetness * 0.95, transmittance, lightFade);
    } else {
        transmittance   = 1.0 - wetness * 0.95;
    }

    return transmittance;
}

void main() {
    skyboxData      = texture(colortex5, uv);

    vec2 projectionUV   = fract(uv * vec2(1.0, 3.0));

    uint index      = uint(floor(uv.y * 3.0));

    if (index == 2) {
        // Clear Sky Capture
        vec3 direction  = unprojectSky(projectionUV);

        vec3 skyColor   = texture(colortex5, projectionUV / vec2(1.0, 3.0)).rgb;

        skyColor *= cube(linStep(1.02 + direction.y, 0.5, 1.0)) * 0.8 + 0.2;

        #if (defined RSKY_SB_CloudVolume || defined RSKY_SB_CirrusCloud || defined RSKY_SB_CirrocumulusCloud || defined RSKY_SB_NoctilucentCloud)
            #ifdef cloudReflectionsToggle
            vec4 cloudData      = RSky_CloudsReflected(direction, dot(direction, cloudLightDir), ditherBluenoiseStatic(), skyColor);

            skyColor    = skyColor * cloudData.a + cloudData.rgb;
            #endif        
        #endif

            skyboxData.rgb  = skyColor;
            //skyboxData = vec3(1,0,0);
    }

    #ifdef cloudShadowsEnabled
    vec2 shadowmapCoord     = uv * vec2(1.0, 1.0 + (1.0/3.0));

    if (saturate(shadowmapCoord) == shadowmapCoord) {
        #if (defined RSKY_SB_CloudVolume || defined RSKY_SB_CirrusCloud || defined RSKY_SB_CirrocumulusCloud)
            skyboxData.a    = generateCloudShadowmap(shadowmapCoord, lightDir, ditherBluenoiseStatic());
        #endif
    }
    #endif

    skyboxData      = clamp16F(skyboxData);
}