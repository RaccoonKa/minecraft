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


/* RENDERTARGETS: 0,3,4,15 */
layout(location = 0) out vec4 sceneColor;
layout(location = 1) out vec3 emissionColor;
layout(location = 2) out vec4 gbufferData;
layout(location = 3) out vec2 auxData;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"
#include "/lib/util/colorspace.glsl"

in vec2 uv;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex15;

uniform sampler2D depthtex0;

uniform sampler2D noisetex;

uniform int frameCounter;

uniform float near, far;

uniform vec2 taaOffset;
uniform vec2 pixelSize, viewSize;

uniform vec3 lightDir, lightDirView;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 shadowModelView, shadowProjection;

/* ------ includes ------*/
#define FUTIL_MAT16
#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/frag/bluenoise.glsl"
#include "/lib/frag/gradnoise.glsl"

/* ------ BRDF ------ */

#include "/lib/brdf/fresnel.glsl"
#include "/lib/brdf/labPBR.glsl"

#include "/lib/light/emission.glsl"

bool InsideDownscaleViewport() {
    return clamp(gl_FragCoord.xy, vec2(-1), ceil(viewSize * ResolutionScale) + vec2(1)) == gl_FragCoord.xy;
}

void main() {
    sceneColor      = stex(colortex0);

    float sceneDepth = stex(depthtex0).x;

    auxData         = stex(colortex15).xy;
    auxData.y       = sceneColor.a;

    sceneColor.a    = 0.0;
    emissionColor   = vec3(0);

    gbufferData     = vec4(0.0, 0.0, 1.0, 1.0);

    if (landMask(sceneDepth) && InsideDownscaleViewport()) {
        vec4 tex1       = stex(colortex1);
        vec4 tex2       = stex(colortex2);

        vec3 viewPos    = screenToViewSpace(vec3(uv / ResolutionScale, sceneDepth));
        vec3 viewDir    = -normalize(viewPos);
        vec3 scenePos   = viewToSceneSpace(viewPos);

        vec3 sceneNormal = decodeNormal(tex1.xy);
        vec3 viewNormal = mat3(gbufferModelView) * sceneNormal;

        materialLAB material = decodeSpecularTexture(vec4(unpack2x8(tex2.x), unpack2x8(tex1.a)));

        ivec2 matID     = unpack2x8I(tex2.y);

        vec2 aux        = unpack2x8(tex2.z);    //parallax shadows and wetness

        float albedoLum = mix(avgOf(sceneColor.rgb), maxOf(sceneColor.rgb), 0.71);
            albedoLum   = saturate(albedoLum * sqrt2);

        float emitterLum = saturate(mix(sqr(albedoLum), sqrt(maxOf(sceneColor.rgb)), albedoLum));

        material.emission = pow(material.emission, labEmissionCurve);

        #ifndef ssptAdvancedEmission
            #if ssptEmissionMode == 1
                sceneColor.a    = max(getEmitterBrightness(matID.y) * emitterLum, material.emission);
            #elif ssptEmissionMode == 2
                sceneColor.a    = material.emission;
            #else
                sceneColor.a    = getEmitterBrightness(matID.y) * emitterLum;
            #endif          
        #else
            if (matID.y > 0 || material.emission > 1e-8) {
                emissionColor.rgb   = getEmissionScreenSpace(matID.y, sceneColor.rgb, material.emission, sceneColor.a) / tau;
            }
        #endif
    }

    emissionColor       = clamp16F(emissionColor);

    vec2 lowresCoord    = uv / indirectResScale;
    ivec2 pixelPos      = ivec2(floor(uv * viewSize) / indirectResScale);
        sceneDepth      = texelFetch(depthtex0, pixelPos, 0).x;

    if (landMask(sceneDepth) && saturate(lowresCoord) == lowresCoord) {
        vec2 uv      = saturate(lowresCoord);
        
        vec4 tex1       = stex(colortex1);
        vec3 sceneNormal = decodeNormal(tex1.xy);

        gbufferData     = vec4(sceneNormal * 0.5 + 0.5, sqrt(depthLinear(sceneDepth)));
    }

    sceneColor          = clamp16F(sceneColor);
}