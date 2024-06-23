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


#define LIGHT_TORCH vec3(1.0, 0.55, 0.18)
#define LIGHT_REDTORCH vec3(1.0, 0.3, 0.1)
#define LIGHT_SOUL vec3(0.26, 0.42, 1.0)
#define LIGHT_FIRE vec3(1.0, 0.45, 0.12)
#define LIGHT_ENDROD vec3(0.76, 0.35, 1.0)

float GetEmissionScale(int ID, float TextureEmission) {
    switch (ID) {
        case 1: return 200;
        case 2: return 160;
        case 3: return 80;
        case 4: return 10;
        case 10: return 120;
        case 11: return 60;
        case 12: return 80;
        case 13: return 20;
    }
    #if ssptEmissionMode == 0
    return 0.0;
    #else
    return 80.0 * TextureEmission;
    #endif
}

vec3 getEmissionScreenSpace(int ID, vec3 albedo, float textureEmission, inout float luma) {
    albedo  = max(albedo, 1e-8);
    vec3 albedoIn   = albedo;

    #if ssptEmissionMode != 2
        float lum   = getLuma(albedo);

        float albedoLum = mix(avgOf(albedo), maxOf(albedo), 0.71);
            albedoLum   = saturate(albedoLum * sqrt2);

        float emitterLum = saturate(mix(sqr(albedoLum), sqrt(maxOf(albedo)), albedoLum) * sqrt2);

        #if ssptEmissionMode == 1
            emitterLum  = max(emitterLum, textureEmission);
        #endif

        albedo  = mix(sqr(normalize(albedo)), normalize(albedo), sqrt(emitterLum)) * emitterLum;
    #else
        albedo   *= textureEmission;
        float emitterLum = textureEmission;
    #endif

        luma     = emitterLum * GetEmissionScale(ID, textureEmission);

    switch (ID) {
        case 1: return albedo * 200;
        case 2: return albedo * 160;
        case 3: return albedo * 80;
        case 4: return albedo * 10;
        case 10: return LIGHT_TORCH * 120 * emitterLum;
        case 11: return LIGHT_SOUL * 60 * emitterLum;
        case 12: return LIGHT_FIRE * 80 * emitterLum;
        case 13: return LIGHT_FIRE * 20 * emitterLum;
    }

    #if ssptEmissionMode == 0
        return vec3(0);
    #elif ssptEmissionMode == 1
        return albedoIn * textureEmission * 80;
    #elif ssptEmissionMode == 2
        return albedo * 80;
    #endif
}

vec3 getEmissionScreenSpace_PostRef(int ID, vec3 albedo, float textureEmission, inout float luma) {
    albedo  = max(albedo, 1e-8);
    vec3 albedoIn   = albedo;

    #if ssptEmissionMode != 2
        float lum   = getLuma(albedo);

        float albedoLum = mix(avgOf(albedo), maxOf(albedo), 0.71);
            albedoLum   = saturate(albedoLum * sqrt2);

        float emitterLum = 0.0;

        #if ssptEmissionMode == 1
            emitterLum  = textureEmission;
        #endif

        albedo  = mix(sqr(normalizeSafe(albedo)), normalizeSafe(albedo), sqrt(emitterLum)) * emitterLum;
    #else
        albedo   *= textureEmission;
        float emitterLum = textureEmission;
    #endif

        luma     = emitterLum * GetEmissionScale(ID, textureEmission);

    switch (ID) {
        case 1: return albedo * 200;
        case 2: return albedo * 160;
        case 3: return albedo * 80;
        case 4: return albedo * 10;
        case 10: return LIGHT_TORCH * 120 * emitterLum;
        case 11: return LIGHT_SOUL * 60 * emitterLum;
        case 12: return LIGHT_FIRE * 80 * emitterLum;
        case 13: return LIGHT_FIRE * 20 * emitterLum;
    }

    #if ssptEmissionMode == 0
        return vec3(0);
    #elif ssptEmissionMode == 1
        return albedoIn * textureEmission * 80;
    #elif ssptEmissionMode == 2
        return albedo * 80;
    #endif
}

#define maxEmission 32.0

float getEmitterBrightness(int ID) {
    switch(ID) {
        case 1: return 32.0 / maxEmission;
        case 2: return 24.0 / maxEmission;
        case 3: return 16.0 / maxEmission;
        case 4: return 2.0 / maxEmission;
        case 10: return 20.0 / maxEmission;
        case 11: return 16.0 / maxEmission;
        case 12: return 16.0 / maxEmission;
        case 13: return 4.0 / maxEmission;
    }

    return 0.0;
}