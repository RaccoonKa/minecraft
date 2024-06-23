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

out vec2 uv;

flat out vec3 airIlluminance;
flat out mat2x3 celestialLight;
flat out mat2x3 airIllumMod;

flat out vec3 sunDir;
flat out vec3 moonDir;

uniform int worldTime;

uniform float eyeAltitude, RMoonPhaseOcclusion;

uniform float wetness;

uniform vec2 viewSize;

/*
uniform vec3 sunDir;
uniform vec3 moonDir;
*/

uniform vec4 daytime;

uniform mat4 gbufferModelView;

#include "/lib/atmos/phase.glsl"
#include "/lib/atmos/air/atmosphere.glsl"

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    uv = gl_MultiTexCoord0.xy;

    // Sun Position Fix from Builderb0y
    float ang   = fract(worldTime / 24000.0 - 0.25);
        ang     = (ang + (cos(ang * pi) * -0.5 + 0.5 - ang) / 3.0) * tau;
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));

    sunDir      = vec3(-sin(ang), cos(ang) * sunRotationData);
    moonDir     = -sunDir;

    airIlluminance  = atmosphericScattering(vec3(0.0, 1.0, 0.0), mat2x3(sunDir, moonDir), vec3(0.0), mat2x3(0.0), mat2x3(0.0));

    vec3 airEyePos  = vec3(0.0, planetRad, 0.0);
    celestialLight     = mat2x3(getAirTransmittance(airEyePos, sunDir, 6)  * sunIllum, 
                             getAirTransmittance(airEyePos, moonDir, 6) * avgOf(moonIllum) * RMoonPhaseOcclusion);

    airIllumMod     = mat2x3(celestialLight[0] / sunIllum.r, 
                             celestialLight[1] / moonIllum.b);
}