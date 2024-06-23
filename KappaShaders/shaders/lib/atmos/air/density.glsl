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

uniform vec3 airDensityCoeff;

vec3 getAirDensity(float elevation) {
    vec3 density    = vec3(exp(-elevation * rScaleHeight), 0.0);
    
    #ifdef alternateOzoneDistribution
        density.z   = saturate(rcp(cosh((ozonePeakAlt - elevation) * rOzoneFalloff)) * density.x) * 100.0;
    #else
        density.z   = exp(-max(0.0, (ozonePeakAlt - elevation) - planetRad) * rOzoneFalloff);
        density.z  *= exp(-max(0.0, (elevation - ozonePeakAlt) - planetRad) * rOzoneFalloffTop);
    #endif

    return density * airDensityCoeff;
}

#ifndef airmassStepBias
    #define airmassStepBias 0.5
#endif

vec3 getAirmass(vec3 position, vec3 direction, const uint steps) {
    float a = dot(direction, direction);
    float b = 2.0 * dot(direction, position);
    float c = dot(position, position) - sqr(atmosRad);
    float d = sqr(b) - 4.0 * a * c;

    float stepSize  = (-b + sqrt(d)) / (2.0 * a * float(steps));

    vec3 airmass    = vec3(0.0);

    float rayLocation = 0.0;

    vec3 rayPos     = position + direction * stepSize * (airmassStepBias * (max0(direction.y) * 0.5 + 0.5));

    for (uint i = 0; i < steps; ++i, rayLocation += stepSize) {
        if (airmass.y > 1e35) break;
        float elevation = length(rayPos) - planetRad;

        vec3 density    = getAirDensity(elevation);

            airmass    += density * stepSize;

            rayPos     += direction * stepSize;
    }

    return airmass;
}
vec3 getAirmass(vec3 position, vec3 direction, float endDistance, const uint steps) {
    float stepSize  = endDistance / float(steps);

    vec3 airmass    = vec3(0.0);

    float rayLocation = 0.0;

    vec3 rayPos     = position + direction * stepSize * 0.5;

    for (uint i = 0; i < steps; ++i, rayLocation += stepSize) {
        if (airmass.y > 1e35) break;
        float elevation = length(rayPos) - planetRad;

        vec3 density    = getAirDensity(elevation);

            airmass    += density * stepSize;

            rayPos     += direction * stepSize;
    }

    return airmass;
}
vec3 getAirmass(vec3 position, vec3 direction, float endDistance, const float bias, const uint steps) {
    float stepSize  = endDistance / float(steps);

    vec3 airmass    = vec3(0.0);

    float rayLocation = 0.0;

    vec3 rayPos     = position + direction * stepSize * bias;

    for (uint i = 0; i < steps; ++i, rayLocation += stepSize) {
        if (airmass.y > 1e35) break;
        float elevation = length(rayPos) - planetRad;

        vec3 density    = getAirDensity(elevation);

            airmass    += density * stepSize;

            rayPos     += direction * stepSize;
    }

    return airmass;
}

vec3 getAirTransmittance(vec3 position, vec3 direction, const uint steps) {
    return expf(-airExtinctMat * getAirmass(position, direction, steps));
}
vec3 getAirTransmittance(vec3 position, vec3 direction) {
    return expf(-airExtinctMat * getAirmass(position, direction, airmassIterations));
}