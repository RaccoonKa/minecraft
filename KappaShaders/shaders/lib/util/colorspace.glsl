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

vec3 toLinear(vec3 x){
    vec3 temp = mix(x / 12.92, pow(.947867 * x + .0521327, vec3(2.4)), step(0.04045, x));
    return max(temp, 0.0);
}

vec3 LinearToSRGB(vec3 x){
    return mix(x * 12.92, clamp16F(pow(x, vec3(1./2.4)) * 1.055 - 0.055), step(0.0031308, x));
}

const mat3 CT_sRGB_XYZ = mat3(
	0.4124564, 0.3575761, 0.1804375,
	0.2126729, 0.7151522, 0.0721750,
	0.0193339, 0.1191920, 0.9503041
);
const mat3 CT_D65_D60 = mat3(
	 1.01303,    0.00610531, -0.014971,
	 0.00769823, 0.998165,   -0.00503203,
	-0.00284131, 0.00468516,  0.924507
);

const mat3 CT_AP1_XYZ = mat3(
	 0.6624541811, 0.1340042065, 0.1561876870,
	 0.2722287168, 0.6740817658, 0.0536895174,
	-0.0055746495, 0.0040607335, 1.0103391003
);
const mat3 CT_D60_D65 = mat3(
	 0.987224,   -0.00611327, 0.0159533,
	-0.00759836,  1.00186,    0.00533002,
	 0.00307257, -0.00509595, 1.08168
);
const mat3 CT_XYZ_sRGB = mat3(
	 3.2409699419, -1.5373831776, -0.4986107603,
	-0.9692436363,  1.8759675015,  0.0415550574,
	 0.0556300797, -0.2039769589,  1.0569715142
);

const mat3 CT_sRGB_AP1 = (CT_sRGB_XYZ * CT_D65_D60) * CT_XYZ_AP1;
const mat3 CT_sRGB_AP1_ALBEDO = (CT_sRGB_XYZ) * CT_XYZ_AP1;

const mat3 CT_AP1_sRGB = (CT_AP1_XYZ * CT_D60_D65) * CT_XYZ_sRGB;

vec3 linearToAP1(vec3 x)        { return x * CT_sRGB_AP1; }
vec3 linearToAP1Albedo(vec3 x)  { return x * CT_sRGB_AP1_ALBEDO; }

void convertToPipelineColor(inout vec3 x) {
    x   = toLinear(x) * CT_sRGB_AP1;
    return;
}
void convertToPipelineAlbedo(inout vec3 x) {
    x   = toLinear(x) * CT_sRGB_AP1_ALBEDO;
    return;
}
void convertToDisplayColor(inout vec3 x) {
    x   = LinearToSRGB(x * CT_AP1_sRGB);
    return;
}