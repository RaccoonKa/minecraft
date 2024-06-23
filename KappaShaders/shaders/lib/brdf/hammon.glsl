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

/*
    "Hammond? I found a car here and... oh it's a Toyota... and they're dogging."
        ~ Jeremy Clarkson lost in thick fog
*/

float diffuseHammon(vec3 normal, vec3 viewDir, vec3 lightDir, float roughness) {
    float nDotL     = max0(dot(normal, lightDir));

    if (nDotL <= 0.0) return (0.0);

    float nDotV     = max0(dot(normal, viewDir));

    float lDotV     = max0(dot(lightDir, viewDir));

    vec3 halfWay    = normalize(viewDir + lightDir);
    float nDotH     = max0(dot(normal, halfWay));

    float facing    = lDotV * 0.5 + 0.5;

    float singleRough = facing * (0.9 - 0.4 * facing) * ((0.5 + nDotH) * rcp(max(nDotH, 0.02)));
    float singleSmooth = 1.05 * fresnelSchlickInverse(0.0, nDotL) * fresnelSchlickInverse(0.0, max0(nDotV));

    float single    = saturate(mix(singleSmooth, singleRough, roughness) * rpi);
    float multi     = 0.1159 * roughness;

    return saturate((multi + single) * nDotL);
}