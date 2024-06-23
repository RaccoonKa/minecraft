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

/* RENDERTARGETS: 3,7,11 */
layout(location = 0) out vec4 indirectCurrent;
layout(location = 1) out vec4 historyGData;
layout(location = 2) out vec4 indirectHistory;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

const bool colortex7Clear   = false;
const bool colortex11Clear   = false;

in vec2 uv;

flat in vec3 blocklightColor;

uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex7;
uniform sampler2D colortex11;

uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

#ifdef ssptEnabled

uniform int WorldTimeChange;

uniform float far, near;

uniform vec2 pixelSize, viewSize;
uniform vec2 taaOffset;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection, gbufferPreviousModelView;

#define FUTIL_MAT16
#include "/lib/fUtil.glsl"
#include "/lib/util/transforms.glsl"

/* ------ reprojection ----- */
vec3 reproject(vec3 sceneSpace, bool hand) {
    vec3 prevScreenPos = hand ? vec3(0.0) : cameraPosition - previousCameraPosition;
    prevScreenPos = sceneSpace + prevScreenPos;
    prevScreenPos = transMAD(gbufferPreviousModelView, prevScreenPos);
    prevScreenPos = transMAD(gbufferPreviousProjection, prevScreenPos) * (0.5 / -prevScreenPos.z) + 0.5;

    return prevScreenPos;
}

#define colorSampler colortex3
#define gbufferSampler colortex4

#define colorHistorySampler colortex11
#define gbufferHistorySampler colortex7

vec2 FetchHistoryVariance(ivec2 UV) {
    return texelFetch(gbufferHistorySampler, UV, 0).xy;
}

/* ------ ATROUS ------ */

vec4 FetchGbuffer(ivec2 UV) {
    vec4 Val  = texelFetch(gbufferSampler, UV, 0);
    return vec4(Val.rgb * 2.0 - 1.0, sqr(Val.w));
}

vec3 spatialColor(vec2 uv) {
    ivec2 UV    = ivec2(uv * viewSize);

    vec3 totalColor     = texelFetch(colorSampler, UV, 0).rgb;
    float sumWeight     = 1.0;
    float lumaCenter    = getLuma(totalColor);

    vec4 GBuffer        = FetchGbuffer(UV);

	const int r = 2;
	for(int y = -r; y <= r; ++y) {
		for(int x = -r; x <= r; ++x) {
            if (x == 0 && y == 0) continue;

            ivec2 TapUV = UV + ivec2(x, y);

            vec4 GB     = FetchGbuffer(TapUV);

            float depthDelta = distance(GB.w, GBuffer.w) * far;

            if (depthDelta < 2.0) {
                vec3 currentColor = texelFetch(colorSampler, TapUV, 0).rgb;

                float lum       = getLuma(currentColor);

                float distLum   = abs(lumaCenter - lum);
                    distLum     = sqr(distLum) / max(lumaCenter, 0.027);
                    distLum     = clamp(distLum, 0.0, pi);

                float weight    = pow(max0(dot(GBuffer.xyz, GB.xyz)), 8.0) * exp(-depthDelta - sqrt(distLum) * rpi);
                    //weight     *= gaussKernel[abs(x)][abs(y)];

                totalColor     += currentColor * weight;
                sumWeight      += weight;
            }
        }
    }
    totalColor /= sumWeight;

    return totalColor;
}
vec3 spatialColor7x7(vec2 uv, inout vec2 variance, out float maxLum) {
    ivec2 UV    = ivec2(uv * viewSize);

    vec3 totalColor     = texelFetch(colorSampler, UV, 0).rgb;
    float sumWeight     = 1.0;
    float lumaCenter    = getLuma(totalColor);

        maxLum          = lumaCenter;

    vec4 GBuffer        = FetchGbuffer(UV);

	const int r = 3;

	for(int y = -r; y <= r; ++y) {
		for(int x = -r; x <= r; ++x) {
            if (x == 0 && y == 0) continue;

            ivec2 TapUV = UV + ivec2(x, y);

            vec4 GB     = FetchGbuffer(TapUV);

            float depthDelta = distance(GB.w, GBuffer.w) * far;

            if (depthDelta < 2.0) {
                vec3 currentColor = texelFetch(colorSampler, TapUV, 0).rgb;

                float weight    = pow(max0(dot(GBuffer.xyz, GB.xyz)), 2.0);
                float currentLuma = getLuma(currentColor);

                maxLum          = max(maxLum, currentLuma);

                totalColor     += currentColor * weight;
                variance       += vec2(currentLuma * weight, sqr(currentLuma) * sqr(weight));
                sumWeight      += weight;
            }
        }
    }
    totalColor /= sumWeight;
    variance   /= vec2(sumWeight, sqr(sumWeight));

    maxLum  = clamp(maxLum, 0.0, 2.71) * rpi;

    return totalColor;
}

#endif

uniform float isLightningSmooth;

void main() {
    historyGData    = vec4(1.0);
    indirectHistory = vec4(0.0);
    indirectCurrent = vec4(stex(colortex3).rgb, 0);

    #ifdef ssptEnabled

    vec2 lowresCoord    = uv / indirectResScale;
    ivec2 pixelPos      = ivec2(floor(uv * viewSize) / indirectResScale);
    float sceneDepth    = texelFetch(depthtex0, pixelPos, 0).x;

    #ifdef DIM
    const int WorldTimeChange = 0;
    #endif

    if (landMask(sceneDepth) && saturate(lowresCoord) == lowresCoord) {
        vec2 uv         = saturate(lowresCoord);
        vec2 scaledUv   = uv * indirectResScale;


        vec3 viewPos    = screenToViewSpace(vec3(uv / ResolutionScale, sceneDepth), false);
        vec3 scenePos   = viewToSceneSpace(viewPos);

        bool hand       = sceneDepth < texelFetch(depthtex2, pixelPos, 0).x;

        float currentDistance   = saturate(length(scenePos) / far);

        vec3 reprojection   = reproject(scenePos, false);

        bool offscreen      = saturate(reprojection.xy) != reprojection.xy;

        vec2 scaledReprojection = reprojection.xy * indirectResScale * ResolutionScale;

        vec4 historyGbuffer = texture(gbufferHistorySampler, scaledReprojection.xy);
            historyGbuffer.rgb = historyGbuffer.rgb * 2.0 - 1.0;
            historyGbuffer.a = sqr(historyGbuffer.a);

        vec3 cameraMovement = mat3(gbufferModelView) * (cameraPosition - previousCameraPosition);

        vec3 rtLight    = vec3(0.0);
        float samples   = 0.0;
        float variance  = 0.0;
        vec2 varianceData = vec2(0);

        vec2 lightmapSource = unpack2x8(texelFetch(colortex1, pixelPos, 0).z);

        float lightmap  = pow5(lightmapSource.x);

        if (offscreen || WorldTimeChange == 1) {
            rtLight     = spatialColor7x7(scaledUv, varianceData, variance);
            samples     = 1.0;
        } else {
            vec4 PreviousLight  = vec4(0);
            vec3 PreviousAux    = vec3(0);

            float previousLightmap = 0.0;

            // Sample History
            ivec2 repPixel  = ivec2(floor(scaledReprojection.xy * viewSize - vec2(0.5)));
            vec2 subpix     = fract(scaledReprojection.xy * viewSize - vec2(0.5) - repPixel);

            const ivec2 offset[4] = ivec2[4](
                ivec2(0, 0),
                ivec2(1, 0),
                ivec2(0, 1),
                ivec2(1, 1)
            );

            float weight[4]     = float[4](
                (1.0 - subpix.x) * (1.0 - subpix.y),
                subpix.x         * (1.0 - subpix.y),
                (1.0 - subpix.x) * subpix.y,
                subpix.x         * subpix.y
            );

            float sumWeight     = 0.0;

            for (uint i = 0; i < 4; ++i) {
                ivec2 UV            = repPixel + offset[i];

                float depthDelta    = distance(sqr(texelFetch(gbufferHistorySampler, UV, 0).a), currentDistance) - abs(cameraMovement.z / far);
                bool depthRejection = (depthDelta / abs(currentDistance)) < 0.1;

                if (depthRejection) {
                    PreviousLight  += clamp16F(texelFetch(colorHistorySampler, UV, 0)) * weight[i];
                    PreviousAux    += texelFetch(gbufferHistorySampler, UV, 0).xyz * weight[i];
                    sumWeight      += weight[i];
                }
            }

            if (sumWeight > 1e-3) {
                PreviousLight      /= sumWeight;
                PreviousAux        /= sumWeight;

                float frames        = min(PreviousLight.a + 1.0, maxFrames);
                float alphaColor    = max(0.01 * minAccumMult, 1.0 / frames);
                float alphaVariance = max(0.02 * minAccumMult, 1.0 / frames);

                float adaptDelta    = sqr(max0(abs(lightmap - PreviousAux.z) - (1.0 / 1024.0)) / avgOf(vec2(lightmap, PreviousAux.z) + 5e-3));

                float rejection     = 1.0 / (1.0 + adaptDelta);
                    rejection       = saturate(1.0 - rejection);
                    rejection       = saturate(0.71 * rejection * ADAPT_STRENGTH);
                    rejection       = max(rejection, saturate(isLightningSmooth * cube(linStep(lightmapSource.y, 0.1, 0.95)) * 2.0) * 0.9 * (1.0 - lightmap));

                    alphaColor      = max(rejection, alphaColor);
                    alphaVariance   = max(rejection, alphaVariance);

                    //frames          = floor(frames * (1.0 - rejection));

                vec3 CurrentLight   = spatialColor(scaledUv);

                float currentLuma   = getLuma(CurrentLight);
                vec2 currentVariance = vec2(currentLuma, sqr(currentLuma));
                    varianceData    = mix(PreviousAux.xy, currentVariance, alphaVariance);

                rtLight             = mix(PreviousLight.rgb, CurrentLight, alphaColor);
                variance            = sqrt(max0(varianceData.y - sqr(varianceData.x))) / max(varianceData.x, 1e-8);
                variance           *= max(1.0 + rejection * sqrt2, 4.0 / frames);
                samples             = frames;

                lightmap            = mix(PreviousAux.z, lightmap, max(0.2, 1.0 / frames));
            } else {
                rtLight     = spatialColor7x7(scaledUv, varianceData, variance);
                samples     = 1.0;
            }
        }

        indirectCurrent.rgb = rtLight + texture(colorSampler, scaledUv).a * blocklightColor / tau;

        //indirectCurrent = vec4(lightmap.xxx, 1.0);

        indirectHistory     = clamp16F(vec4(rtLight, samples));
        historyGData        = saturate(vec4(varianceData, lightmap, sqrt(currentDistance)));

    }

    #endif

    indirectCurrent     = clamp16F(indirectCurrent);
    indirectHistory     = clamp16F(indirectHistory);
}