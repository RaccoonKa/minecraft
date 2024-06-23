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

flat out mat3x3 lightColor;

void getColorPalette() {
    lightColor[0]  = endSunlightColor * 0.6;

    lightColor[1]  = endSkylightColor * 0.3;

    lightColor[2]  = blackbody(float(blocklightBaseTemp)) * blocklightIllum * blocklightBaseMult * 1.5;
}