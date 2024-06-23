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

/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 sceneColor;
layout(location = 1) out vec4 BloomTileImage;

#include "/lib/head.glsl"

in vec2 uv;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform sampler2D noisetex;

uniform float frameTime;
uniform float viewWidth, viewHeight;

uniform vec2 viewSize, pixelSize;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferProjection;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;


/* ------ functions ------ */
float ditherBluenoiseStatic() {
    ivec2 uv = ivec2(fract(gl_FragCoord.xy/256.0)*256.0);
    float noise = texelFetch(noisetex, uv, 0).a;

    return noise;
}

vec2 ClipUV_AABB(vec2 Value, vec2 MinBounds, vec2 MaxBounds, out bool HasClipped) {
    vec2 pClip = 0.5 * (MaxBounds + MinBounds);
    vec2 eClip = 0.5 * (MaxBounds - MinBounds);
    vec2 vClip = Value - pClip;
    vec2 vUnit = vClip / eClip;
    vec2 aUnit = abs(vUnit);
    float maUnit = maxOf(aUnit);
    HasClipped = maUnit > 1.0;
    return HasClipped ? pClip + vClip / maUnit : Value;
}

vec3 RenderMotionblur(float Depth, vec2 ViewUV, bool Hand, vec2 ObjectVelocity) {
    const uint TargetSamples = motionblurSamples;

    float Dither    = ditherBluenoiseStatic();

    vec4 CurrentFragmentPosition = vec4(ViewUV, Depth, 1.0) * 2.0 - 1.0;
    vec4 CurrentPosition = gbufferProjectionInverse * CurrentFragmentPosition;
        CurrentPosition = gbufferModelViewInverse * CurrentPosition;
        CurrentPosition /= CurrentPosition.w;
    if (!Hand) CurrentPosition.xyz += cameraPosition;

    vec4 PreviousPosition = CurrentPosition;
    if (!Hand) PreviousPosition.xyz -= previousCameraPosition;
        PreviousPosition = gbufferPreviousModelView * PreviousPosition;
        PreviousPosition = gbufferPreviousProjection * PreviousPosition;
        PreviousPosition /= PreviousPosition.w;

    float BlurScale = 0.15 * motionblurScale * min(rcp(frameTime * 30.0), 2.0);

    vec2 Velocity   = (CurrentFragmentPosition - PreviousPosition).xy;
    if (Hand) Velocity *= 0.15;

    float VelocityLength = length(Velocity);
    vec2 VelocityDirection = VelocityLength > 1e-8 ? normalize(Velocity) : vec2(0.0);
    if (VelocityLength > euler) Velocity = VelocityDirection * euler;

        Velocity   *= BlurScale / float(TargetSamples);

    vec2 BlurUV = ViewUV + Velocity * Dither;
        BlurUV -= Velocity * TargetSamples * 0.5;

    vec3 BlurColor  = vec3(0.0);
    uint Weight = 0;

    for (uint i = 0; i < TargetSamples; ++i, BlurUV += Velocity) {
        bool HasClipped = false;
        vec2 ClippedUV = ClipUV_AABB(BlurUV, pixelSize, 1.0 - pixelSize, HasClipped);
        float AbyssDistance = HasClipped ? distance(BlurUV, ClippedUV) : 0.0;
        bool AbyssTermination = Dither > (1.01 / (1.0 + AbyssDistance));

        if (!AbyssTermination) {
            BlurColor  += textureLod(colortex0, ClippedUV, 0).rgb;
            ++Weight;
        } else {
            BlurColor  += textureLod(colortex0, ViewUV, 0).rgb;
            ++Weight;
            break;
        }
    }
    BlurColor  /= float(Weight);

    return BlurColor;
}

void main() {
    sceneColor  = stexLod(colortex0, 0);

    #ifdef motionblurToggle
    float sceneDepth = texture(depthtex1, uv * ResolutionScale).x;

    bool hand = sceneDepth < texture(depthtex2, uv * ResolutionScale).x;

    sceneColor.rgb = RenderMotionblur(sceneDepth, uv, hand, vec2(0.0));
    #endif

    #ifdef lensFlareToggle
        sceneColor.rgb += textureLod(colortex3, uv * 0.5, 0).rgb;
    #endif

    sceneColor  = clamp16F(sceneColor);

    BloomTileImage  = vec4(0);
}