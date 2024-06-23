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

#include "const.glsl"
#include "density.glsl"

vec2 rsi(vec3 pos, vec3 dir, float r) {
    float b     = dot(pos, dir);
    float det   = sqr(b) - dot(pos, pos) + sqr(r);

    if (det < 0.0) return vec2(-1.0);

        det     = sqrt(det);

    return vec2(-b) + vec2(-det, det);
}

vec2 airPhaseFunction(float cosTheta) {
    return vec2(rayleighPhase(cosTheta), mieCS(cosTheta, airMieG));
}

float OrenNayar(vec3 v, vec3 l, vec3 n, float r) {
    float NdotL = dot(n,l);
    float NdotV = dot(n,v);
    
    float t = max(NdotL,NdotV);
    float g = max(.0, dot(v - n * NdotV, l - n * NdotL));
    float c = g/max(t, 1e-8) - g*t;
    
    float a = .285 / (r+.57) + .5;
    float b = .45 * r / (r+.09);

    return max(0., NdotL) * ( b * c + a);
}
float GGX (vec3 v, vec3 l, vec3 n, float r, float F0) {
  r*=r;
  
  vec3 h = l + v;
  float hn = inversesqrt(dot(h, h));

  float dotLH = clamp(dot(h,l)*hn,0.,1.);
  float dotNH = clamp(dot(h,n)*hn,0.,1.);
  float dotNL = clamp(dot(n,l),0.,1.);
  
  float denom = (dotNH * r - dotNH) * dotNH + 1.;
  float D = r / max(3.141592653589793 * denom * denom, 1e-8);
  float F = F0 + (1. - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
  float k2 = .25 * r;

  return dotNL * D * F / max(dotLH*dotLH*(1.0-k2)+k2, 1e-8);
}

vec3 atmosphericScattering(vec3 direction, mat2x3 lightDirection, vec3 illuminance, mat2x3 illuminanceMod, mat2x3 celestialLight) {
    vec3 position   = vec3(0.0, max(eyeAltitude, 1.0) + planetRad, 0.0);

    vec2 airDist    = rsi(position, direction, atmosRad);
    #ifdef ATMOS_BelowHorizon
    vec2 planetDist = rsi(position, direction, planetRad - 3e3);
    #else
    vec2 planetDist = rsi(position, direction, planetRad);
    #endif

    //if (eyeAltitude < 0.0) planetDist = planetDist.yx;
    bool isPlanet = planetDist.y >= 0.0;

    vec2 dist   = vec2(0.0);
        dist.x  = isPlanet && planetDist.x < 0.0 ? planetDist.y : max(airDist.x, 0.0);
        dist.y  = isPlanet && planetDist.x > 0.0 ? planetDist.x : airDist.y;

    float stepSize  = (dist.y - dist.x) / airScatterIterations;

    float rayLocation = dist.x;

    vec3 rayPos     = position + direction * (dist.x + stepSize * 0.5);

    vec3 airmass  = vec3(0.0);

    vec2 cosTheta = vec2(dot(direction, lightDirection[0]), dot(direction, lightDirection[1]));
    vec4 airPhase = vec4(airPhaseFunction(cosTheta.x), airPhaseFunction(cosTheta.y));
    const float phaseIso = 0.25 * pi;

    mat2x3 sunScattering    = mat2x3(0.0);
    mat2x3 moonScattering   = mat2x3(0.0);
    vec3 multiScattering    = vec3(0.0);

    vec3 transmittance      = vec3(1.0);
    vec3 bouncedLight       = vec3(0.0);

    vec2 illuminanceIntensity = vec2(0.0);

    #define PLANETLIGHT_SCALE 0.8

    vec3 planetLight        = ((celestialLight[0] + celestialLight[1]) * rpi) * vec3(0.19);

    float bouncePhase       = cube(saturate(dot(direction, vec3(0, -1, 0)) + 1.0)) * 0.75;

    #ifdef ATMOS_RenderPlanet
        vec2 surfaceDist = rsi(position, direction, planetRad);
        bool isSurface = surfaceDist.y >= 0.0;

        vec3 surfaceNormal = normalizeSafe(position + max0(surfaceDist.x) * direction);

        #define PLANET_ROUGHNESS 0.6

        vec2 lambert   = saturate(vec2(dot(surfaceNormal, lightDirection[0]), dot(surfaceNormal, lightDirection[1]))) * rpi;
            lambert.x  = OrenNayar(-direction, lightDirection[0], surfaceNormal, PLANET_ROUGHNESS) / sqrt3;
            lambert.x  += GGX(-direction, lightDirection[0], surfaceNormal, PLANET_ROUGHNESS, 0.04);
            //lambert.y  = OrenNayar(-direction, lightDirection[1], surfaceNormal, PLANET_ROUGHNESS) / sqrt3;
            lambert.y  += GGX(-direction, lightDirection[1], surfaceNormal, PLANET_ROUGHNESS, 0.04);

        vec3 planetColor = isSurface ? ((celestialLight[0] * lambert.x + celestialLight[1] * lambert.y) + illuminance * tau) * mix(normalizeSafe(illuminance) * 0.35, vec3(0.33), 0.75) * 1.41 : vec3(0.0);
    #else
        const vec3 planetColor = vec3(0);
    #endif   

    for (uint i = 0; i < airScatterIterations; ++i) {
        if (airmass.y > 1e35) break;
        float elevation = length(rayPos) - planetRad;

        vec3 density    = getAirDensity(elevation) * stepSize;

        /*if (rayPos.y > planetRad)*/ illuminanceIntensity += saturate(exp(-max0(elevation) / illuminanceFalloff)) * stepSize;
        //else illuminanceIntensity += exp(-abs(elevation * 4.0) / illuminanceFalloff) * stepSize;

            airmass    += density;

        vec3 stepOpticalDepth = airExtinctMat * density;

        vec3 stepTransmittance = saturate(expf(-stepOpticalDepth));
        vec3 stepTransmittedFraction = saturate((stepTransmittance - 1.0) / -stepOpticalDepth);
        vec3 visScattering  = transmittance * stepTransmittedFraction;

        vec3 sunAirmass = getAirmass(rayPos, lightDirection[0], airmassIterations);
        vec3 moonAirmass = getAirmass(rayPos, lightDirection[1], airmassIterations);

        vec3 sunlightAtten = exp(-airExtinctMat * sunAirmass) * visScattering;
        vec3 moonlightAtten = exp(-airExtinctMat * moonAirmass) * visScattering;

        sunScattering[0]   += sunlightAtten * density.x;
        sunScattering[1]   += sunlightAtten * density.y;

        moonScattering[0]  += moonlightAtten * density.x;
        moonScattering[1]  += moonlightAtten * density.y;

        multiScattering    += (airScatterMat * density.xy) * visScattering;

        #ifdef PLANET_BOUNCELIGHT
        bouncedLight += (airScatterMat * density.xy) * visScattering * saturate(exp(-max0(elevation) * 3e-5));
        #endif

        rayPos     += direction * stepSize;

        transmittance *= stepTransmittance;
    }

    illuminanceIntensity    = max0(illuminanceIntensity / atmosDepth);

    //return vec3(illuminanceIntensity.xyy);

    sunScattering[0]   *= airPhase.x;
    sunScattering[1]   *= airPhase.y;

    moonScattering[0]  *= airPhase.z;
    moonScattering[1]  *= airPhase.w;

    vec3 sunColor   = airScatterMat[0] * sunScattering[0] + airScatterMat[1] * sunScattering[1];
        sunColor   *= sunIllum;

    vec3 moonColor  = airScatterMat[0] * moonScattering[0] + airScatterMat[1] * moonScattering[1];
        moonColor  *= avgOf(moonIllum) * RMoonPhaseOcclusion;

    vec2 illumPhase = mix(airPhase.xz, vec2(1.0), 0.5);

    vec3 multiIllum = getLuma(illuminance) * pow(normalize(illuminance), vec3(rpi)) * illuminanceIntensity.x * halfPi;
        multiIllum += illuminance.z * illuminanceIntensity.y / halfPi;
        multiIllum *= illuminanceMod[0] * illumPhase.x + illuminanceMod[1] * illumPhase.y;
        //multiIllum *= direction.x > 0.0 ? 1.0 : 0.0;

    vec3 multiColor = multiScattering * (illuminance * sqrt2 * skyIlluminanceMult + multiIllum * skyMultiscatterMult) * phaseIso;
    //if (isSurface) multiColor *= 0.0; 

        bouncedLight *= planetLight * bouncePhase;

    //return bouncedLight;
    #ifdef ATMOS_RenderPlanet
    planetColor *= transmittance;
    #endif
    

    return sunColor + moonColor + multiColor + planetColor * PLANETLIGHT_SCALE + bouncedLight * PLANETLIGHT_SCALE;
}