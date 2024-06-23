#version 430 compatibility

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

#include "/lib/head.glsl"
uniform vec2 viewSize;
#define VERTEX_STAGE
#include "/lib/downscaleTransform.glsl"

out vec2 uv;

#ifndef airTransmittanceHQ
    uniform float eyeAltitude;

    uniform vec3 sunDir;
    uniform vec3 moonDir;

    uniform vec4 daytime;

    flat out vec3 sunColor;

    #include "/lib/atmos/air/const.glsl"
    #include "/lib/atmos/air/density.glsl"
#endif

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    uv = gl_MultiTexCoord0.xy;

    #ifndef FULLRES_PASS
    VertexDownscaling(gl_Position, uv);
    #endif

    #ifndef airTransmittanceHQ
        sunColor = getAirTransmittance(vec3(0.0, planetRad + eyeAltitude, 0.0), sunDir, 6) * sunIllum;
    #endif
}