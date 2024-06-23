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
====================================================================================================

        License Terms for Academy Color Encoding System Components

        Academy Color Encoding System (ACES) software and tools are provided by the
        Academy under the following terms and conditions: A worldwide, royalty-free,
        non-exclusive right to copy, modify, create derivatives, and use, in source and
        binary forms, is hereby granted, subject to acceptance of this license.

        Copyright © 2015 Academy of Motion Picture Arts and Sciences (A.M.P.A.S.).
        Portions contributed by others as indicated. All rights reserved.

        Performance of any of the aforementioned acts indicates acceptance to be bound
        by the following terms and conditions:

        * Copies of source code, in whole or in part, must retain the above copyright
        notice, this list of conditions and the Disclaimer of Warranty.

        * Use in binary form must retain the above copyright notice, this list of
        conditions and the Disclaimer of Warranty in the documentation and/or other
        materials provided with the distribution.

        * Nothing in this license shall be deemed to grant any rights to trademarks,
        copyrights, patents, trade secrets or any other intellectual property of
        A.M.P.A.S. or any contributors, except as expressly stated herein.

        * Neither the name "A.M.P.A.S." nor the name of any other contributors to this
        software may be used to endorse or promote products derivative of or based on
        this software without express prior written permission of A.M.P.A.S. or the
        contributors, as appropriate.

        This license shall be construed pursuant to the laws of the State of
        California, and any disputes related thereto shall be subject to the
        jurisdiction of the courts therein.

        Disclaimer of Warranty: THIS SOFTWARE IS PROVIDED BY A.M.P.A.S. AND CONTRIBUTORS
        "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
        THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
        NON-INFRINGEMENT ARE DISCLAIMED. IN NO EVENT SHALL A.M.P.A.S., OR ANY
        CONTRIBUTORS OR DISTRIBUTORS, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
        SPECIAL, EXEMPLARY, RESITUTIONARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
        LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
        PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
        LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
        OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
        ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

        WITHOUT LIMITING THE GENERALITY OF THE FOREGOING, THE ACADEMY SPECIFICALLY
        DISCLAIMS ANY REPRESENTATIONS OR WARRANTIES WHATSOEVER RELATED TO PATENT OR
        OTHER INTELLECTUAL PROPERTY RIGHTS IN THE ACADEMY COLOR ENCODING SYSTEM, OR
        APPLICATIONS THEREOF, HELD BY PARTIES OTHER THAN A.M.P.A.S.,WHETHER DISCLOSED OR
        UNDISCLOSED.

====================================================================================================
*/

#define incACESMT

const mat3 AP0_XYZ = mat3(
	0.9525523959, 0.0000000000, 0.0000936786,
	0.3439664498, 0.7281660966,-0.0721325464,
	0.0000000000, 0.0000000000, 1.0088251844
);
const mat3 XYZ_AP0 = mat3(
	 1.0498110175, 0.0000000000,-0.0000974845,
	-0.4959030231, 1.3733130458, 0.0982400361,
	 0.0000000000, 0.0000000000, 0.9912520182
);

const mat3 AP1_XYZ = mat3(
	 0.6624541811, 0.1340042065, 0.1561876870,
	 0.2722287168, 0.6740817658, 0.0536895174,
	-0.0055746495, 0.0040607335, 1.0103391003
);
const mat3 XYZ_AP1 = mat3(
	 1.6410233797, -0.3248032942, -0.2364246952,
	-0.6636628587,  1.6153315917,  0.0167563477,
	 0.0117218943, -0.0082844420,  0.9883948585
);

const mat3 AP0_AP1 = mat3(
	 1.4514393161, -0.2365107469, -0.2149285693,
	-0.0765537734,  1.1762296998, -0.0996759264,
	 0.0083161484, -0.0060324498,  0.9977163014
);
const mat3 AP1_AP0 = mat3(
	 0.6954522414,  0.1406786965,  0.1638690622,
	 0.0447945634,  0.8596711185,  0.0955343182,
	-0.0055258826,  0.0040252103,  1.0015006723
);

//const vec3 AP1_RGB_Y = vec3(AP1_XYZ[1].xyz);
const vec3 AP1_RGB_Y = vec3(0.2722287168, 0.6740817658, 0.0536895174);

/* rec709 primaries */
const mat3 XYZ_sRGB = mat3(
	 3.2409699419, -1.5373831776, -0.4986107603,
	-0.9692436363,  1.8759675015,  0.0415550574,
	 0.0556300797, -0.2039769589,  1.0569715142
);
const mat3 sRGB_XYZ = mat3(
	0.4124564, 0.3575761, 0.1804375,
	0.2126729, 0.7151522, 0.0721750,
	0.0193339, 0.1191920, 0.9503041
);

const mat3 XYZ_P3DCI = mat3(
	 2.7253940305, -1.0180030062, -0.4401631952,
	-0.7951680258,  1.6897320548,  0.0226471906,
	 0.0412418914, -0.0876390192,  1.1009293786
);

/* dci p3, d65 primaries */
const mat3 XYZ_P3D65 = mat3(
	 2.4933963, -0.9313459, -0.4026945,
	-0.8294868,  1.7626597,  0.0236246,
	 0.0358507, -0.0761827,  0.9570140
);
const mat3 P3D65_XYZ = mat3(
	0.4865906, 0.2656683, 0.1981905,
	0.2289838, 0.6917402, 0.0792762,
	0.0000000, 0.0451135, 1.0438031
);

/* bradford chromatic adaptation between aces whitepoint (d60) and srgb whitepoint (d65) */
const mat3 D65_D60 = mat3(
	 1.01303,    0.00610531, -0.014971,
	 0.00769823, 0.998165,   -0.00503203,
	-0.00284131, 0.00468516,  0.924507
);
const mat3 D60_D65 = mat3(
	 0.987224,   -0.00611327, 0.0159533,
	-0.00759836,  1.00186,    0.00533002,
	 0.00307257, -0.00509595, 1.08168
);

const mat3 XYZ_REC2020 = mat3(
	 1.7166511880, -0.3556707838, -0.2533662814,
	-0.6666843518,  1.6164812366,  0.0157685458,
	 0.0176398574, -0.0427706133,  0.9421031212
);
// https://en.wikipedia.org/wiki/Adobe_RGB_color_space
const mat3 XYZ_AdobeRGB = mat3(
      2.04158790381075,  -0.56500697427886,  -0.34473135077833,
     -0.96924363628088,   1.87596750150772, 0.0415550574071756,
    0.0134442806320311, -0.118362392231018,   1.01517499439121
);

// Bradford chromatic adaptation from standard D65 to DCI Cinema White
const mat3 D65_DCI = mat3(
    1.02449672775258,     0.0151635410224164, 0.0196885223342068,
    0.0256121933371582,   0.972586305624413,  0.00471635229242733,
    0.00638423065008769, -0.0122680827367302, 1.14794244517368
);

const mat3 sRGB_AP0 = (sRGB_XYZ * D65_D60) * XYZ_AP0;
const mat3 sRGB_AP1 = (sRGB_XYZ * D65_D60) * XYZ_AP1;

const mat3 AP0_sRGB = (AP0_XYZ * D60_D65) * XYZ_sRGB;
const mat3 AP1_sRGB = (AP1_XYZ * D60_D65) * XYZ_sRGB;

const mat3 AP0_P3D65 = (AP0_XYZ * D60_D65) * XYZ_P3D65;
const mat3 AP1_P3D65 = (AP1_XYZ * D60_D65) * XYZ_P3D65;

const mat3 AP0_P3DCI = ((AP0_XYZ * D60_D65) * XYZ_P3D65) * D65_DCI;
const mat3 AP1_P3DCI = ((AP1_XYZ * D60_D65) * XYZ_P3D65) * D65_DCI;

const mat3 AP0_REC2020 = (AP0_XYZ * D60_D65) * XYZ_REC2020;
const mat3 AP1_REC2020 = (AP1_XYZ * D60_D65) * XYZ_REC2020;

const mat3 AP0_AdobeRGB = (AP0_XYZ * D60_D65) * XYZ_AdobeRGB;
const mat3 AP1_AdobeRGB = (AP1_XYZ * D60_D65) * XYZ_AdobeRGB;

const mat3 sRGB_P3D65 = (sRGB_XYZ) * XYZ_P3D65;