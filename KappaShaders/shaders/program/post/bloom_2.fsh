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

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 bloomData;

#include "/lib/head.glsl"

//bloom downsampling method based on chocapic13's shaders
//merge and upsample blurs

uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform vec2 bloomResolution;
uniform vec2 pixelSize;
uniform vec2 viewSize;

in vec2 uv;

#include "/lib/util/bicubic.glsl"

float ExposureGauss() {
    const float scale = 0.25 * 0.25 * 0.25;
    ivec2 startPos  = ivec2(floor(gl_FragCoord.xy));

    if (clamp(uv, vec2(0.0), vec2(scale + pixelSize)) != uv) return 0.0;

    float lumaSum   = 0.0;
    uint samples    = 0;
    float TotalWeight = 0.0;

    #define RAD 4
    #define EXP 0.5

    for (int x = -RAD; x <= RAD; ++x) {
        for (int y = -RAD; y <= RAD; ++y) {
            ivec2 pos   = (startPos + ivec2(x, y));
                pos     = clamp(pos, ivec2(0), ivec2(viewSize * scale)-1);

            float Weight = exp(-(sqr(x) + sqr(y)) * EXP);

            lumaSum += texelFetch(colortex3, ivec2(pos), 0).a * Weight;
            TotalWeight += Weight;
            ++samples;
        }
    }
    lumaSum /= max(TotalWeight, 1);

    return lumaSum;
}

float getLuminance4x4(sampler2D tex, vec2 uv) {
    const float scale = 0.25 * 0.25 * 0.25 * 0.25;
    const uvec2 downsampleScale     = uvec2(4);
    uvec2 UV    = uvec2(ivec2(uv * viewSize) * downsampleScale);

    if (clamp(uv, 0.0, scale) != uv) return 0.0;

    float lumaSum   = 0.0;
    uint samples    = 0;

    for (uint x = 0; x < downsampleScale.x; ++x) {
        for (uint y = 0; y < downsampleScale.y; ++y) {
            uvec2 pos   = (UV + ivec2(x, y));
            lumaSum += texelFetch(tex, ivec2(pos), 0).a;
            ++samples;
        }
    }
    lumaSum /= max(samples, 1);

    return lumaSum;
}


void main() {
	//if (clamp(uv, -0.003, 1.003) != uv) discard;
    vec2 tcoord     = (gl_FragCoord.xy*2.0+0.5)*pixelSize;
    vec2 rscale     = bloomResolution/max(viewSize, bloomResolution);
	bloomData       = vec4(vec3(0), texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0).a);

    bloomData.a     = ExposureGauss();

    if (clamp(uv, vec2(0.1, 0.0), vec2(1.0)) == uv) bloomData.a = getLuminance4x4(colortex3, uv - vec2(0.1, 0.0));

    #ifdef bloomEnabled

	vec2 c 	= uv*max(viewSize, bloomResolution) * rcp(bloomResolution * 0.5);

	if (clamp(c, -pixelSize, 1.0 + pixelSize) == c) {
		bloomData.rgb  += textureBicubic(colortex3, (tcoord+vec2(0.0, 0.5))/2.0).rgb / 4.0;    //1:4

        bloomData.rgb  += textureBicubic(colortex3, tcoord/4.0).rgb / 4.0;    //1:8

        bloomData.rgb  += textureBicubic(colortex3, tcoord/8.0+vec2(0.25*rscale.x+2.0*pixelSize.x, 0.0)).rgb / 4.0;   //1:16

        bloomData.rgb  += textureBicubic(colortex3, tcoord/16.0+vec2(0.375*rscale.x+4.0*pixelSize.x, 0.0)).rgb / 4.0;   //1:32

        bloomData.rgb  += textureBicubic(colortex3, tcoord/32.0+vec2(0.4375*rscale.x+6.0*pixelSize.x, 0.0)).rgb / 4.0;   //1:64

        bloomData.rgb  += textureBicubic(colortex3, tcoord/64.0+vec2(0.46875*rscale.x+8.0*pixelSize.x, 0.0)).rgb / 4.0;   //1:128

        bloomData.rgb  += textureBicubic(colortex3, tcoord/128.0+vec2(0.484375*rscale.x+10.0*pixelSize.x, 0.0)).rgb / 4.0;   //1:256

		bloomData.rgb  /= 7.0;

		//blur 		= texture(colortex3, gl_FragCoord.xy*pixelSize).rgb;
	}

    bloomData   = clamp16F(bloomData);

    #endif
}