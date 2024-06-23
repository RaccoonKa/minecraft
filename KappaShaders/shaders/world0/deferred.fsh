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

#include "/lib/head.glsl"

/* RENDERTARGETS: 3,14 */
layout(location = 0) out vec4 cloudCurrentFrame;
layout(location = 1) out vec2 skylightIntensity;   // Used for lightning flashes

#include "/lib/util/colorspace.glsl"

in vec2 uv;

flat in mat4x3 lightColor;

uniform sampler2D colortex5;

uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform sampler2D noisetex;
uniform sampler3D depthtex1;

uniform sampler3D colortex1;
uniform sampler3D colortex2;

uniform int frameCounter;
uniform int worldTime;

uniform float eyeAltitude;
uniform float far, near;
uniform float frameTimeCounter;
uniform float wetness;
uniform float worldAnimTime;

uniform vec2 pixelSize;
uniform vec2 viewSize;
uniform vec2 taaOffset;
uniform vec2 skyCaptureResolution;

uniform vec3 cameraPosition;
uniform vec3 upDir, upDirView;
uniform vec3 sunDir, sunDirView;
uniform vec3 moonDir, moonDirView;
uniform vec3 lightDir;
uniform vec3 cloudLightDir, cloudLightDirView;

uniform vec4 daytime;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;


/* ------ includes ------*/
#define FUTIL_LINDEPTH
#define FUTIL_D3X3
#define FUTIL_ROT2
#include "/lib/fUtil.glsl"

#include "/lib/util/transforms.glsl"
#include "/lib/atmos/phase.glsl"
#include "/lib/frag/bluenoise.glsl"
#include "/lib/frag/gradnoise.glsl"

#define airmassStepBias 0.33
#include "/lib/atmos/air/const.glsl"
#include "/lib/atmos/air/density.glsl"

#include "/lib/atmos/project.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/bicubic.glsl"

#include "/lib/atmos/clouds/common.glsl"

/*
float bluenoiseLookup1D() {     //surprisingly this works less good with taa
    ivec2 xy    = ivec2(gl_FragCoord.xy) & 255;
    uint z      = frameCounter & 7;

    return texelFetch(colortex2, ivec3(xy, z), 0).x;
}*/

/* ------ cloud system function ------ */

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

uniform vec3 skyColor;
uniform int isLightning;

uniform float isLightningSmooth;


flat in mat4x3 CloudSunlightGradient;
//flat in vec3 CloudNL_Sunlight;
//flat in mat3 CloudNL_Gradient;

vec3 ReadSunlightGradient(vec3 Position, vec3 Direction) {
    float Elevation = Position.y * (1.0 + (cloudLightDir.y / max(1e-8, abs(Direction.y))) * dot(cloudLightDir, Direction) * (1.0 - max0(cloudLightDir.y)));

    vec3 Color  = mix(CloudSunlightGradient[0], CloudSunlightGradient[1], linStep(Elevation, cloudRaymarchMinY, cloudRaymarchMidY));
        Color   = mix(Color, CloudSunlightGradient[2], linStep(Elevation, cloudRaymarchMidY, cloudRaymarchMaxY));
        Color   = mix(Color, CloudSunlightGradient[3], linStep(Elevation, cloudRaymarchMaxY, 12000.0));

    //return mix(CloudSunlightGradient[0], CloudSunlightGradient[1], 0.5);

    return Color;
}
/*
vec3 ReadSunlightGradient_NL(vec3 Position, vec3 Direction) {
    float Elevation = Position.y * (1.0 + (abs(sunDir.y) / max(1e-8, Direction.y)) * dot(sunDir, Direction) * (1.0 - max0(sunDir.y)));

    vec3 Color  = mix(CloudNL_Gradient[0], CloudNL_Gradient[1], linStep(Elevation, CLOUD_NL_ALT, CLOUD_NL_ALT * 2.0));
        Color   = mix(Color, CloudNL_Gradient[2], linStep(Elevation, CLOUD_NL_ALT * 2.0, CLOUD_NL_ALT * 4.0));

    return Color;
}*/

vec4 cloudSystem(vec3 Direction, float vDotL, float dither, float lightNoise, vec3 SkyboxColor, out float skylightIntensity) {
    vec4 Result     = vec4(0, 0, 0, 1);
    skylightIntensity = 0.0;

    vec3 sunlight       = (worldTime>23000 || worldTime<12900) ? lightColor[0] : lightColor[2];
    vec3 skylight       = lightColor[1];

    //skylight += vec3(0.5, 0.5, 1.0) * 5.0 * max(getLuma(skylight), 0.3) * isLightningSmooth;

    float pFade         = saturate(mieCS(vDotL, 0.5));
        pFade           = mix(pFade, vDotL * 0.5 + 0.5, 1.0 / sqrt2);
    //float pFade         = vDotL * 0.5 + 0.5;

    float eFade         = saturate(mieCS(vDotL, 0.5) / 0.75);

    float vDotUp        = Direction.y;

    // --- volumetric clouds --- //
    #ifdef RSKY_SB_CloudVolume
    float within    = sstep(eyeAltitude, cloudRaymarchMinY - 75.0, cloudRaymarchMinY) * (1.0 - sstep(eyeAltitude, cloudRaymarchMaxY, cloudRaymarchMaxY + 75.0));
    bool isBelowVol = eyeAltitude < cloudRaymarchMidY;
    bool visibleVol = Direction.y > 0.0 && isBelowVol || Direction.y < 0.0 && !isBelowVol;

    if (visibleVol || within > 0.0) {

        vec2 BS         = rsi(vec3(0.0, planetRad + eyeAltitude, 0.0), Direction, planetRad + cloudRaymarchMinY);
        vec2 TS         = rsi(vec3(0.0, planetRad + eyeAltitude, 0.0), Direction, planetRad + cloudRaymarchMaxY);

        float BDistance = !isBelowVol ? BS.x : BS.y;
        float TDistance = !isBelowVol ? TS.x : TS.y;

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
            start       = mix(start, gbufferModelViewInverse[3].xyz, within);
            end         = mix(end, Direction * 6e4, within);

        const float baseLength  = cloudCumulusDepth / RSKY_SI_CloudV_Samples;
        float stepLength    = length(end - start) * rcp(float(RSKY_SI_CloudV_Samples));
        float stepCoeff     = stepLength * rcp(baseLength);
            stepCoeff       = 0.45 + clamp(stepCoeff - 1.1, 0.0, 5.0) * 0.5;
            stepCoeff       = mix(stepCoeff, 10.0, sqr(within));

        uint steps          = uint(RSKY_SI_CloudV_Samples * stepCoeff);

        vec3 rStep          = (end - start) * rcp(float(steps));
        vec3 rPos           = rStep * dither + start + cameraPosition;
        float rLength       = length(rStep);

        vec3 scattering     = vec3(0.0);
        float transmittance = 1.0;

        vec3 bouncelight    = vec3(0.6, 1.0, 0.8) * sunlight * rcp(pi * 14.0 * sqrt2) * max0(dot(cloudLightDir, upDir));

        const float sigmaA  = 1.0;
        const float sigmaT  = 0.1;

        for (uint i = 0; i < steps; ++i, rPos += rStep) {
            if (transmittance < cloudTransmittanceThreshold) break;
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

            #ifdef RSKY_SB_CloudV_DirectDither
                float lightOD       = cloudVolumeLightOD(rPos, 6, lightNoise);
            #else
                float lightOD       = cloudVolumeLightOD(rPos, 6);
            #endif
            
            #ifdef RSKY_SB_CloudV_AmbientDither
                float skyOD         = cloudVolumeSkyOD(rPos, 4, lightNoise);
            #else
                float skyOD         = cloudVolumeSkyOD(rPos, 4);
            #endif
            
            float bounceOD      = cube(linStep(rPos.y, cloudRaymarchMinY, cloudRaymarchMinY + cloudCumulusDepth * 0.3)) * max0(rPos.y - cloudRaymarchMinY);

            //vec3 sunlight   = getAirTransmittance(rPos + vec3(0, planetRad, 0), cloudLightDir, 6) * ((worldTime>23000 || worldTime<12900) ? sunIllum : moonIllum);
            vec3 sunlight   = ReadSunlightGradient(rPos, Direction);

            #ifdef RSKY_SB_CloudV_HQMultiscatter
                //const float albedo = 0.83;
                const float scatterMult = 1.0;

                vec2 LayerParams = GetLayerParams(rPos.y, TypeParameters);

                #define albedo LayerParams.x

                //float scatterEnergy = 0.0;
                for (uint j = 0; j < 8; ++j) {
                    float n     = float(j);
                    float p     = pow(0.5, n);
                    float td    = sigmaT * p;

                    //scatterEnergy      += p;

                    float avgTransmittance  = exp(-(LayerParams.y) * density * p);
                    float energyEstimate    = 1.0 + estimateEnergy(albedo * (1.0 - avgTransmittance));

                    vec3 scattering     = pow(1.0 + scatterMult * vec3(lightOD, skyOD, bounceOD) * td, vec3(-1.0 / scatterMult)) * energyEstimate;
                    vec3 asymmetry      = pow(vec3(0.5, 0.35, 0.9), vec3((1.0 + (lightOD + density * rLength) * td)));
                    vec3 asymmetrySky   = pow(vec3(0.5, 0.35, 0.9), vec3((1.0 + (skyOD + density * rLength) * td)));

                    stepScatter += scattering * vec3(cloudPhaseNew(vDotL, asymmetry), cloudPhaseSky(Direction.y, asymmetrySky), cloudPhaseSky(-Direction.y, asymmetry)) * p;
                }
                //float avgTransmittance  = exp(-pi * 10.0 * density);
                //float energyEstimate    = (1.0 + estimateEnergy(albedo * (1.0 - avgTransmittance))) / scatterEnergy;

                skylightIntensity += mix(0.0, stepScatter.y * (albedo * (1.0 - stepT)), avgOf(atmosFade)) * transmittance;

                stepScatter     = (sunlight * stepScatter.x) + (skylight * stepScatter.y * 4.0) + (bouncelight * stepScatter.z);
                stepScatter    *= albedo * (1.0 - stepT);
                scattering     += mix(SkyboxColor * sigmaT * integral, stepScatter, atmosFade) * (transmittance);

                #undef albedo
            #else
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
            #endif

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
    BelowPlane   = eyeAltitude < CLOUD_PLANE1_ALT;
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
                    #ifdef CLOUD_PLANE1_DITHERED_LIGHT
                    float lightOD       = Cloud_Planar1_Light(mix(VolumeBounds[0], RPosition, 1-max0(cloudLightDir.y)), 3, dither.x);
                    float skyOD         = Cloud_Planar1_Light(VolumeBounds[0], 3, vec3(0.0, 1.0, 0.0), dither.x);
                    #else
                    float lightOD       = Cloud_Planar1_Light(mix(VolumeBounds[0], RPosition, 1-max0(cloudLightDir.y)), 3);
                    float skyOD         = Cloud_Planar1_Light(VolumeBounds[0], 3, vec3(0.0, 1.0, 0.0));
                    #endif

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

                    vec3 sunlight = ReadSunlightGradient(RPosition, Direction);

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
    BelowPlane   = eyeAltitude < CLOUD_PLANE0_ALT;
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
                    #ifdef CLOUD_PLANE0_DITHERED_LIGHT
                    float lightOD       = Cloud_Planar0_Light(mix(VolumeBounds[0], RPosition, 1-max0(cloudLightDir.y)), 3, dither.x);
                    float skyOD         = Cloud_Planar0_Light(VolumeBounds[0], 3, vec3(0.0, 1.0, 0.0), dither.x);
                    #else
                    float lightOD       = Cloud_Planar0_Light(mix(VolumeBounds[0], RPosition, 1-max0(cloudLightDir.y)), 3);
                    float skyOD         = Cloud_Planar0_Light(VolumeBounds[0], 3, vec3(0.0, 1.0, 0.0));
                    #endif

                    lightOD *= euler; skyOD *= euler;

                    vec2 scattering     = vec2(0);

                    const float albedo = 0.7;
                    const float scatterMult = 1.0;
                    float avgTransmittance  = exp(-(12.0 / SigmaT) * Density);
                    float bounceEstimate    = estimateEnergy(albedo * (1.0 - avgTransmittance));
                    float baseScatter       = albedo * (1.0 - stepT);

                    vec3 phaseG         = pow(vec3(0.72, 0.5, 0.9), vec3(1.0 + (lightOD + Density * RLength) * SigmaT) * vec3(1));
                    vec3 phaseGSky      = pow(vec3(0.5, 0.35, 0.8), vec3(1.0 + (skyOD + Density * RLength) * SigmaT));

                    float scatterScale  = pow(1.0 + 1.0 * (lightOD) * SigmaT, -1.0 / 1.0) * bounceEstimate;
                    float SkyScatterScale = pow(1.0 + 1.0 * skyOD * SigmaT, -1.0 / 1.0) * bounceEstimate;

                    scattering.x  += baseScatter * cloudPhaseNew(vDotL, phaseG) * scatterScale;
                    scattering.y  += baseScatter * cloudPhaseSky(Direction.y, phaseGSky) * SkyScatterScale;

                    vec3 sunlight = ReadSunlightGradient(RPosition, Direction);

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
    BelowPlane   = eyeAltitude < CLOUD_NL_ALT;
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

/* --- TEMPORAL CHECKERBOARD --- */

#define checkerboardDivider 9
#define ditherPass
#include "/lib/frag/checkerboard.glsl"

void main() {
    cloudCurrentFrame   = vec4(0.0, 0.0, 0.0, 1.0);
    skylightIntensity   = vec2(0.0, 1.0);

    #if (defined RSKY_SB_CloudVolume || defined RSKY_SB_CirrusCloud || defined RSKY_SB_CirrocumulusCloud || defined RSKY_SB_NoctilucentCloud)

    #ifdef cloudTemporalUpscaleEnabled
        const float cLOD    = sqrt(CLOUD_RENDER_LOD)*3.0;
    #else
        const float cLOD    = sqrt(CLOUD_RENDER_LOD);
    #endif

    vec2 cloudCoord = uv * cLOD;

    if (clamp(cloudCoord, -pixelSize * cLOD, 1.0 + pixelSize * cLOD) == cloudCoord) {
        cloudCoord  = saturate(cloudCoord);

        float depth = depthMax3x3(depthtex2, cloudCoord * ResolutionScale, pixelSize * cLOD);

        if (!landMask(depth)) {
            #ifdef cloudTemporalUpscaleEnabled
            int frame       = (frameCounter) % 9;
            ivec2 offset    = temporalOffset9[frame];
            ivec2 pixel     = ivec2(floor(cloudCoord * viewSize * rcp(cLOD/3.0) + offset));
            cloudCoord      = vec2(pixel) / 3.0 / viewSize * cLOD;

            float dither    = ditherBluenoiseCheckerboard(vec2(offset));
            float noise     = ditherGradNoiseCheckerboard(vec2(offset));
            #else
            float dither    = ditherBluenoiseTemporal();
            float noise     = ditherGradNoiseTemporal();
            #endif

            vec3 viewPos    = screenToViewSpace(vec3(cloudCoord, 1.0), false);
            vec3 viewDir    = normalize(viewPos);
            vec3 scenePos   = viewToSceneSpace(viewPos);
            vec3 worldDir   = normalize(scenePos);

            vec3 skyColor   = textureBicubic(colortex5, projectSky(worldDir, 0)).rgb;

            cloudCurrentFrame = cloudSystem(worldDir, dot(viewDir, cloudLightDirView), dither, noise, skyColor, skylightIntensity.x);
        }
    }

    skylightIntensity.x /= pi;
    skylightIntensity.y = getLuma(lightColor[1]) / 64.0;
    #endif

    cloudCurrentFrame   = clamp16F(cloudCurrentFrame);
}