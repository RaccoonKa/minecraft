/*
====================================================================================================

    Copyright (C) 2021 RRe36

    All Rights Reserved unless otherwise explicitly stated.


    By downloading this you have agreed to the license and terms of use.
    These can be found inside the included license-file
    or here: https://rre36.com/copyright-license

    Violating these terms may be penalized with actions according to the Digital Millennium
    Copyright Act (DMCA), the Information Society Directive and/or similar laws
    depending on your country.

====================================================================================================
*/

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 indirectCurrent;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform sampler2D depthtex0;

uniform sampler2D noisetex;

uniform int frameCounter;

uniform float aspectRatio;
uniform float far, near;

uniform vec2 pixelSize, viewSize;
uniform vec2 taaOffset;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"
#include "/lib/util/transforms.glsl"

#include "/lib/frag/bluenoise.glsl"

/*
    SSAO based on BSL Shaders by Capt Tatsu with permission
*/

vec2 offsetDist(float x) {
	float n = fract(x * 8.0) * pi;
    return vec2(cos(n), sin(n)) * x;
}

float getDSSAO(sampler2D depthtex, vec3 sceneNormal, float depth, vec2 coord, float dither) {
    const uint steps = 3;
    const float baseRadius = 1.0 * ResolutionScale;

    float radius    = baseRadius * (0.75 + abs(1.0-dot(sceneNormal, vec3(0.0, 1.0, 0.0))) * 0.5);

    bool hand       = depth < 0.56;
        depth       = depthLinear(depth);

    float currStep  = 0.2 * dither + 0.2;
	float fovScale  = gbufferProjection[1][1] / 1.37;
	float distScale = max((far - near) * depth + near, 5.0);
	vec2 scale      = radius * vec2(1.0 / aspectRatio, 1.0) * fovScale / distScale;

    float ao = 0.0;

    const float maxOcclusionDist    = tau;
    const float anibleedExp         = 0.71;

    for (uint i = 0; i < steps; ++i) {
		vec2 offset = offsetDist(currStep) * scale;
		float mult  = (0.7 / radius) * (far - near) * (hand ? 1024.0 : 1.0);

		float sampleDepth = depthLinear(texture(depthtex, coord + offset).r);
		float sample0 = (depth - sampleDepth) * mult;
        float antiBleed = 1.0 - rcp(1.0 + max0(distance(sampleDepth, depth) * far - maxOcclusionDist) * anibleedExp);
		float angle = mix(clamp(0.5 - sample0, 0.0, 1.0), 0.5, antiBleed);
		float dist  = mix(clamp(0.25 * sample0 - 1.0, 0.0, 1.0), 0.5, antiBleed);

		sampleDepth = depthLinear(texture(depthtex, coord - offset).r);
		sample0     = (depth - sampleDepth) * mult;
        antiBleed   = 1.0 - rcp(1.0 + max0(distance(sampleDepth, depth) * far - maxOcclusionDist) * anibleedExp);
        angle      += mix(clamp(0.5 - sample0, 0.0, 1.0), 0.5, antiBleed);
        dist       += mix(clamp(0.25 * sample0 - 1.0, 0.0, 1.0), 0.5, antiBleed);
		
		ao         += (clamp(angle + dist, 0.0, 1.0));
		currStep   += 0.2;
    }
	ao *= 1.0 / float(steps);
	
	return sqrt(ao);
}

void main() {
    indirectCurrent = stex(colortex3);

    #ifdef ssptEnabled
    #ifdef RINDIRECT_USE_SSAO
    vec2 lowresCoord    = (uv) / indirectResScale / ResolutionScale;
    ivec2 pixelPos      = ivec2(floor(uv * viewSize) / indirectResScale);
    float sceneDepth    = texelFetch(depthtex0, pixelPos, 0).x;

    if (landMask(sceneDepth) && saturate(lowresCoord) == lowresCoord) {
        vec3 sceneNormal    = texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0).xyz * 2.0 - 1.0;
        float ssao  = getDSSAO(depthtex0, sceneNormal, sceneDepth, saturate((uv) / indirectResScale), ditherBluenoise());
        indirectCurrent.rgb *= ssao;
        //indirectCurrent.a   = ssao;
    }
    #endif
    #endif

    indirectCurrent     = clamp16F(indirectCurrent);
}