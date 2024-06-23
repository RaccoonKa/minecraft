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

#define planetRadiusScale 1.0   //[0.02 0.04 0.06 0.08 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define airRayleighMult 1.0 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6 2.8 3.0 3.5 4.0 4.5 5.0]
#define airMieMult 1.0      //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6 2.8 3.0 3.5 4.0 4.5 5.0]
#define airOzoneMult 1.0    //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6 2.8 3.0 3.5 4.0 4.5 5.0]
#define airMistMult 1.0    //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6 2.8 3.0 3.5 4.0 4.5 5.0]

#define airScatterIterations 16     //[8 10 12 14 16 18 20 24 28 32]
#define airmassIterations 8         //[4 6 8 10 12 14 16 18 20 24 28 32]

#define skyIlluminanceMult 1.0 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define skyMultiscatterMult 1.0 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

//#define alternateOzoneDistribution

const float planetRad   = 6371e3 * planetRadiusScale;
const float atmosDepth  = 110e3 * planetRadiusScale;
const float atmosRad    = planetRad + atmosDepth;

const float ozonePeakAlt = 3e4;
const float ozoneFalloff = 6e3;
const float rOzoneFalloff = 1.0 / ozoneFalloff;
const float ozoneFalloffTop = 18e3;
const float rOzoneFalloffTop = 1.0 / ozoneFalloffTop;

const float airMieG         = 0.76;

//const vec3 airRayleighCoeff = vec3(9.11388125e-6, 1.32236310e-5, 3.03829375e-5) * airRayleighMult;
//const vec3 airRayleighCoeff = vec3(9.21388125e-6, 1.22236310e-5, 3.03829375e-5) * airRayleighMult;
const vec3 airRayleighCoeff = vec3(7.48991e-6, 1.07317e-5, 2.47046e-5) * 1.28 * airRayleighMult * vec3(rayleighRedMult, rayleighGreenMult, rayleighBlueMult);   //628 574 466
const vec3 airMieCoeff      = vec3(11e-6) * airMieMult * vec3(mieRedMult, mieGreenMult, mieBlueMult);
const vec3 airOzoneCoeff    = vec3(3.26768136e-7, 3.14953105e-7, 5.43182681e-8) * airOzoneMult * 2.0 * vec3(ozoneRedMult, ozoneGreenMult, ozoneBlueMult);       //Reference: 3.58768136e-7, 3.14953105e-7, 5.43182681e-8

const vec2 scaleHeight      = vec2(8.5e3, 1.2e3);
const vec2 rScaleHeight     = 1.0 / scaleHeight;
const vec2 planetScale      = planetRad * rScaleHeight;

const vec2 illuminanceFalloff = vec2(14e3, 6e3) * pi;

const vec3 sunIllum         = vec3(1.0, 0.973, 0.961) * 128.0 * sunlightIllum * vec3(sunlightRedMult, sunlightGreenMult, sunlightBlueMult);
//const vec3 moonIllum        = vec3(0.73, 0.8, 1.0) * 0.085 * moonlightIllum * vec3(moonlightRedMult, moonlightGreenMult, moonlightBlueMult);
const vec3 moonIllum        = vec3(0.35, 0.45, 1.0) * 0.175 * moonlightIllum * vec3(moonlightRedMult, moonlightGreenMult, moonlightBlueMult);

const mat2x3 airScatterMat  = mat2x3(airRayleighCoeff, airMieCoeff);
const mat3x3 airExtinctMat  = mat3x3(airRayleighCoeff, airMieCoeff * 1.11, airOzoneCoeff);

const vec3 fogMistCoeff     = vec3(1e-2) * airMistMult * vec3(mistRedMult, mistGreenMult, mistBlueMult);
const mat3x3 fogScatterMat  = mat3x3(airRayleighCoeff, airMieCoeff, fogMistCoeff);
const mat3x3 fogExtinctMat  = mat3x3(airRayleighCoeff, airMieCoeff * 1.1, fogMistCoeff);

const vec2 fogFalloffScale  = 1.0 / vec2(8e1, 2e1);
const vec2 fogAirScale      = vec2(100.0, 40.0);