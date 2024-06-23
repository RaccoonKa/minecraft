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

#ifndef DIM
    #define rtaoSkySample
#elif DIM == -1
    #define NOSHADOWMAP
#endif

#define ResolutionScale 0.75     //[0.25 0.5 0.75 1.0]

#define DEBUG_VIEW 0    //[0 1 2 3 4 5 6 7] 0-off, 1-whiteworld, 2-indirect light, 4-albedo, 5-hdr, 6-reflections, 7 reflection capture
//#define DEBUG_WITH_ALBEDO
//#define RTAO_NOSKYMAP

//#define deffNAN
//#define compNAN

#define blocklightBaseMult tau

#define netherSkylightColor vec3(1.0, 0.23, 0.08)
#define endSkylightColor vec3(0.4, 0.2, 1.0)
#define endSunlightColor vec3(0.5, 0.3, 1.0)
#define minimumAmbientColor vec3(0.7, 0.7, 1.0)
#define minimumAmbientMult 0.005

#define cloudShadowmapRenderDistance 8e3
#define cloudShadowmapResolution 512

#define WEATHERMAP_RESOLUTION 512

//#define shadowcompCaustics

const float indirectResScale = sqrt(1.0 / indirectResReduction);