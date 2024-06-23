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

flat out vec3 skylightColor;
flat out vec3 directLightColor;

flat out vec3 sunDir;
flat out vec3 moonDir;
flat out vec3 cloudLightDir;
flat out vec3 lightDir;

uniform sampler2D colortex5;

uniform int worldTime;

uniform float eyeAltitude;
uniform float sunAngle;
uniform float wetness;

uniform vec2 viewSize;

/*
uniform vec3 sunDir;
uniform vec3 moonDir;
*/

uniform vec4 daytime;

#define airmassStepBias 0.31
#include "/lib/atmos/air/const.glsl"
#include "/lib/atmos/air/density.glsl"
#include "/lib/atmos/project.glsl"

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    uv = gl_MultiTexCoord0.xy;

    // Sun Position Fix from Builderb0y
    float ang   = fract(worldTime / 24000.0 - 0.25);
        ang     = (ang + (cos(ang * pi) * -0.5 + 0.5 - ang) / 3.0) * tau;
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));

    sunDir      = vec3(-sin(ang), cos(ang) * sunRotationData);
    moonDir     = -sunDir;

    cloudLightDir = (worldTime>23000 || worldTime<12900) ? sunDir : moonDir;
    lightDir    = sunAngle < 0.5 ? sunDir : moonDir;

    skylightColor   = texture(colortex5, projectSky(vec3(0.0, 1.0, 0.0), 0)).rgb;

    vec3 airEyePos  = vec3(0.0, planetRad + 1400.0, 0.0);

    directLightColor = (worldTime>23000 || worldTime<12900) ? 
                       getAirTransmittance(airEyePos, sunDir, 6) * sunIllum : 
                       getAirTransmittance(airEyePos, moonDir, 6) * colorSaturation(moonIllum, 0.5) * sqrt2;
}