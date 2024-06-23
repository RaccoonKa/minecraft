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

#include "/lib/util/colorspace.glsl"

flat out mat2x3 lightColor;

#ifdef skypass
flat out vec3 sky_color;
#endif

#ifdef fogpass
flat out vec3 fogCol;
flat out vec3 fogCol2;
flat out vec3 fogEmissionColor;
#endif

uniform vec3 fogColor;

#define NETHER_AMBIENT_CROSSTALK 0.271

const mat3 CrosstalkMAT = mat3(
    mix(vec3(1.0, 0.0, 0.0), vec3(0.5595088340965042, 0.39845359892109633, 0.04203756698239944), vec3(NETHER_AMBIENT_CROSSTALK)),
    mix(vec3(0.0, 1.0, 0.0), vec3(0.43585871315661756, 0.5003841413971261, 0.06375714544625634), vec3(NETHER_AMBIENT_CROSSTALK)),
    mix(vec3(0.0, 0.0, 1.0), vec3(0.10997368482498855, 0.15247972169325025, 0.7375465934817612), vec3(NETHER_AMBIENT_CROSSTALK))
);

void getColorPalette() {
    lightColor[0]  = netherSkylightColor * pi;
    lightColor[0]  = mix(lightColor[0], linearToAP1(normalize(toLinear(fogColor))) * CrosstalkMAT, 0.9) * 0.45 * pi;

    lightColor[1]  = blackbody(float(blocklightBaseTemp)) * blocklightIllum * blocklightBaseMult;


    #ifdef skypass
        sky_color    = vec3(1.0, 0.15, 0.1)*0.004;
        sky_color   = mix(sky_color, linearToAP1(toLinear(fogColor)) * 0.004, 0.7);
    #endif

    #ifdef fogpass
        fogCol      = linearToAP1(normalize(toLinear(fogColor)));
        fogCol2     = linearToAP1(toLinear(fogColor)) * 0.8;
        fogEmissionColor = blackbody(2500.0) * blocklightIllum * blocklightBaseMult;
    #endif
}