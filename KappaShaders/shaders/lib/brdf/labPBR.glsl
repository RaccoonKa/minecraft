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

struct materialLAB {
    float roughness;
    float f0;
    float opacity;
    float porosity;
    float emission;

    bool conductor;
    bool conductorComplex;
    mat2x3 eta;
};

#ifndef incCONDUCTOR_ETA
const mat2x3 conductorProperties[8] = mat2x3[8](
    mat2x3(vec3(2.9114,  2.9497,  2.5845),  vec3(3.0893, 2.9318, 2.7670)),     //iron
    mat2x3(vec3(0.18299, 0.42108, 1.3734),  vec3(3.4242, 2.3459, 1.7704)),   //gold
    mat2x3(vec3(1.3456,  0.96521, 0.61722), vec3(7.4746, 6.3995, 5.3031)),   //aluminum
    mat2x3(vec3(3.1071,  3.1812,  2.3230),  vec3(3.3314, 3.3291, 3.1350)),     //chrome
    mat2x3(vec3(0.27105, 0.67693, 1.3164),  vec3(3.6092, 2.6248, 2.2921)),   //copper
    mat2x3(vec3(1.9100,  1.8300,  1.4400),  vec3(3.5100, 3.4000, 3.1800)),     //lead
    mat2x3(vec3(2.3757,  2.0847,  1.8453),  vec3(4.2655, 3.7153, 3.1365)),     //platinum
    mat2x3(vec3(0.15943, 0.14512, 0.13547), vec3(3.9291, 3.1900, 2.3808))   //silver
);

#define incCONDUCTOR_ETA

#endif

materialLAB decodeSpecularTexture(vec4 dataIn) {
    materialLAB material = materialLAB(1.0, 0.02, 0.0, 0.0, 0.0, false, false, mat2x3(1.0));

    material.roughness  = sqr(1.0 - dataIn.r);
    material.f0         = clamp(dataIn.g, 0.02, 0.9);

        dataIn.ba      *= 255.0;

    material.opacity    = linStep(dataIn.b, 65.0, 255.0);
    material.porosity   = dataIn.b <= (64.5) ? linStep(dataIn.b, 0.0, 64.0) : 0.0;
    material.emission   = saturate(dataIn.a <= (254.5) ? linStep(dataIn.a, 0.5, 254.5) : 0.0);

    uint integerF0      = uint(dataIn.g * 255.0);

    material.conductor  = integerF0 >= 230;
    material.conductorComplex = integerF0 <= 237;

    material.eta        = conductorProperties[clamp(int(integerF0 - 230), 0, 7)];
    material.eta[0]     = material.eta[0] * CT_sRGB_AP1_ALBEDO;
    material.eta[1]     = material.eta[1] * CT_sRGB_AP1_ALBEDO;

    return material;
}

#define incLAB