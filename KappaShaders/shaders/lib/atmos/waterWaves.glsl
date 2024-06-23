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

vec2 waveNoiseCubic(sampler2D tex, vec2 pos) {
    //vec2 size       = textureSize(tex, 0);
    //vec2 coord      = (pos.xy - (0.5 * (1.0 / 256.0)));
        pos        *= 256.0;
    ivec2 location  = ivec2(floor(pos));

    vec2 samples[4]    = vec2[4](
        texelFetch(tex, location                 & 255, 0).xy, texelFetch(tex, (location + ivec2(1, 0)) & 255, 0).xy,
        texelFetch(tex, (location + ivec2(0, 1)) & 255, 0).xy, texelFetch(tex, (location + ivec2(1, 1)) & 255, 0).xy
    );

    vec2 weights    = cubeSmooth(fract(pos));


    return mix(
        mix(samples[0], samples[1], weights.x),
        mix(samples[2], samples[3], weights.x), weights.y
    );
}

#define waterNormalOctaves 4    //[2 3 4 5 6 7 8]
#define waveMode 0  //[0 1]

float waterNoise(vec2 pos) {
    return sqr(1.0-textureBicubic(noisetex, pos/256.0).x);
}

uniform vec3 RWeatherParams;

#if waveMode == 0

float waveGerstener(vec2 pos, float t, float steepness, float amp, float length, vec2 dir) {
    float k     = tau * rcp(length);
    float w     = sqrt(9.81 * k);

    float x     = w * t - k * dot(dir, pos);
        x       = pow((sin(x) * 0.5 + 0.5), steepness);
    float cubicLerp     = 1.0 - saturate(abs(steepness - 1.0));
    return mix(x, cubeSmooth(x), saturate(cubicLerp * sqrt(cubicLerp))) * amp;
}

float waterWaves(vec3 pos, int matID) {
    #ifdef freezeAtmosAnim
        float time = float(atmosAnimOffset) * 0.76;
    #else
        float time  = frameTimeCounter * 0.76;
    #endif

    if (matID == 103) time = 0.0;

    vec2 p      = pos.xz+pos.y*rcp(pi);
        //p      *= 0.5;

    vec2 dir    = normalize(vec2(0.4, 0.8));

    vec2 noise = (waveNoiseCubic(noisetex, (p + dir * time * 0.2) * 0.0008).rg * 2.0 - 1.0);
        p     += noise * 1.3;

    float wave  = 0.0;

    float amp   = 0.06;
    float steep = 0.51;
    float wlength = 2.8;

    const float a = 2.6;
    const mat2 rotation = mat2(cos(a), -sin(a), sin(a), cos(a));
    float noiseAmp = 4.5;

    //p     = rotatePos(p, a*0.3);
    //p    *= 1.5;

    //p.x *= 0.7;

    float total     = 0.0;

    vec2 noiseCoord = (p + dir * time * 0.4) * 0.0007;

    //float distFalloff = (linStep(viewDist, 16.0, 64.0));
    float distFalloff   = 1.0 - exp(-viewDist * rcp(32.0));

    float ampMult   = mix(0.6, 0.9, distFalloff);

    float mult  = 1.0 - distFalloff * 0.9;

    for (uint i = 0; i<waterNormalOctaves; ++i) {
        vec2 noise = waveNoiseCubic(noisetex, noiseCoord).rg * 2.0 - 1.0;

        steep   = mix(steep, sqrt(steep), sqrt(saturate(abs(wave))));

        float temp = waveGerstener(p + noise * noiseAmp + vec2(wave * 0.9, 0.0), time, steep, amp, wlength, dir);
        p += temp * dir * amp * pi;
        wave   -= temp;
        if (i < 2) wave -= waveNoiseCubic(noisetex, (p + noise * noiseAmp * 0.5 + wave) * 0.023 - time * dir * 0.03).r * amp * 0.3;

        time   *= 1.1;
        //amp    *= 0.595;
        amp    *= 0.5 + RWeatherParams.z * 0.1;

        wlength *= 0.63;

        dir    *= rotation;
        noiseCoord *= rotation;
        noiseCoord *= 1.5;
        noiseAmp *= 0.65;
    }

    return (wave - amp) * mult;
}

#elif waveMode == 1

float waterWaves(vec3 pos, int matID) {
    #ifdef freezeAtmosAnim
        float time = float(atmosAnimOffset) * 0.76;
    #else
        float time  = frameTimeCounter*0.76;
    #endif
    
    if (matID == 103) time = 0.0;

    vec2 p      = pos.xz+pos.y*rcp(pi);

    vec2 dir    = normalize(vec2(0.4, 0.8));

    vec2 noise = (waveNoiseCubic(noisetex, (p + dir * time * 0.2) * 0.0005).rg * 2.0 - 1.0);
        p     += noise * 2.75;

    float wave  = 0.0;

    float amp   = 0.08;

    const float a = 1.1;
    const mat2 rotation = mat2(cos(a), -sin(a), sin(a), cos(a));

    vec2 noiseCoord = p * 0.004;
    float distFalloff   = 1.0 - exp(-viewDist * rcp(32.0));

    float mult  = 1.0 - distFalloff * 0.9;

    for (uint i = 0; i<waterNormalOctaves; ++i) {
        float noise = waveNoiseCubic(noisetex, noiseCoord + dir * time * 0.01).r;
            noiseCoord += noise * amp * 0.05 * dir;

        noise = 1.0 - cubeSmooth(1.0 - noise);

        wave   -= noise * amp;

        time   *= 1.55;
        amp    *= 0.55 + RWeatherParams.z * 0.1;

        dir    *= rotation;
        noiseCoord *= 1.55;
    }

    return (wave - amp) * mult;
}

#endif