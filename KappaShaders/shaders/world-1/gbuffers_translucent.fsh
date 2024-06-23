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

/* RENDERTARGETS: 1,2,3,4 */
layout(location = 2) out vec4 translucentColor;
layout(location = 0) out vec4 sceneDataA;
layout(location = 1) out vec4 sceneDataB;
layout(location = 3) out vec4 reflectionAux;

#include "/lib/head.glsl"
#include "/lib/util/colorspace.glsl"
#include "/lib/util/encoders.glsl"

uniform vec2 viewSize;
#include "/lib/downscaleTransform.glsl"

in mat2x2 uv;

in vec3 scenePos;
in vec3 worldPos;
in vec3 viewPos;

in vec4 tint;

flat in int matID;

flat in vec3 normal;

flat in mat2x3 lightColor;

#ifdef gTERRAIN
    in float viewDist;
    flat in mat3 tbn;
    in vec3 tangentViewDir;
#endif

uniform sampler2D gcolor;
uniform sampler2D specular;
uniform sampler2D normals;
uniform sampler2D gaux3;

uniform sampler2D noisetex;

uniform int frameCounter;

uniform float frameTimeCounter;
uniform float lightFlip;
uniform float sunAngle;

uniform vec3 lightDir, lightDirView;

uniform mat4 gbufferModelView;


/* ------ includes ------ */
#define FUTIL_LIGHTMAP
#define FUTIL_ROT2
#include "/lib/fUtil.glsl"

#include "/lib/frag/bluenoise.glsl"
#include "/lib/frag/gradnoise.glsl"


/* ------ TERRAIN ------ */
#ifdef gTERRAIN

vec3 decodeNormalTexture(vec3 ntex) {
    if(all(lessThan(ntex, vec3(0.003)))) return normal;

    vec3 nrm    = ntex * 2.0 - (254.0 * rcp(255.0));

    #if normalmapFormat==0
        nrm.z  = sqrt(saturate(1.0 - dot(nrm.xy, nrm.xy)));
    #elif normalmapFormat==1
        nrm    = normalize(nrm);
    #endif

    return normalize(nrm * tbn);
}

#include "/lib/util/bicubic.glsl"

#include "/lib/atmos/waterWaves.glsl"

#define waterParallaxDepth 2.0

vec3 waterParallax(vec3 pos, vec3 dir) {    //based on spectrum by zombye
    const uint steps    = 8;

    vec3 interval   = inversesqrt(float(steps)) * dir / -dir.y;
    float height    = waterWaves(pos, matID) * waterParallaxDepth;
    float stepSize  = height;
        pos.xz     += stepSize * interval.xz;

    float offset    = stepSize * interval.y;
        height      = waterWaves(pos, matID) * waterParallaxDepth;

    for (uint i = 1; i < steps - 1 && height < offset; ++i) {
        stepSize    = offset - height;
        pos.xz     += stepSize * interval.xz;

        offset     += stepSize * interval.y;
        height      = waterWaves(pos, matID) * waterParallaxDepth;
    }

    if (height < offset) {
        stepSize    = offset - height;
        pos.xz     += stepSize * interval.xz;
    }

    return pos;
}

vec3 waterNormal() {
    vec3 pos        = waterParallax(worldPos, tangentViewDir.xzy);
    //vec3 pos     = worldPos;

    //float dstep   = 0.015 + (1.0 - exp(-viewDist * rcp(32.0))) * 0.045;

    float dstep   = 0.015 + clamp(viewDist * rcp(32.0), 0.0, 2.0) * 0.045;

    vec2 delta;
        delta.x     = waterWaves(pos + vec3( dstep, 0.0, -dstep), matID);
        delta.y     = waterWaves(pos + vec3(-dstep, 0.0,  dstep), matID);
        delta      -= waterWaves(pos + vec3(-dstep, 0.0, -dstep), matID);

    return normalize(vec3(-delta.x, 2.0 * dstep, -delta.y));
}
vec3 waterNormal(out vec3 pos) {
        pos     = waterParallax(worldPos, tangentViewDir.xzy);

    float dstep   = 0.015 + clamp(viewDist * rcp(32.0), 0.0, 2.0) * 0.045;

    vec2 delta;
        delta.x     = waterWaves(pos + vec3( dstep, 0.0, -dstep), matID);
        delta.y     = waterWaves(pos + vec3(-dstep, 0.0,  dstep), matID);
        delta      -= waterWaves(pos + vec3(-dstep, 0.0, -dstep), matID);

    return normalize(vec3(-delta.x, 2.0 * dstep, -delta.y));
}

#include "/lib/frag/noise.glsl"

vec3 getIceAlbedo(vec3 pos) {
    pos    *= 1.0;
    float baseLayer     = value3D(pos * 0.5);
        baseLayer      += value3D(pos * 2.0 + baseLayer * 0.25) * 0.5;
        baseLayer      += value3D(pos * 5.0 + baseLayer * 0.5) * 0.25;
        baseLayer      += sqr(value3D(pos * 10.0 + baseLayer * 0.75)) * 0.125;

        baseLayer       = cubeSmooth(saturate(baseLayer / 1.875));

    vec3 albedo     = mix(vec3(0.022, 0.035, 0.07), vec3(0.029, 0.045, 0.08) * 3.0, baseLayer);

    return albedo;
}

#endif

/* ------ BRDF ------ */
#include "/lib/brdf/fresnel.glsl"
#include "/lib/brdf/hammon.glsl"

vec4 packReflectionAux(vec3 directLight, vec3 albedo) {
    vec4 lightRGBE  = encodeRGBE8(directLight);
    vec4 albedoRGBE = encodeRGBE8(albedo);

    return vec4(pack2x8(lightRGBE.xy),
                pack2x8(lightRGBE.zw),
                pack2x8(albedoRGBE.xy),
                pack2x8(albedoRGBE.zw));
}

void main() {
    if (OutsideDownscaleViewport()) discard;
    vec4 sceneColor = texture(gcolor, uv[0]);
    if (sceneColor.a<0.02) discard;
        sceneColor.rgb *= tint.rgb;

    vec3 sceneNormal  = normal;
    vec2 lmap   = uv[1];
    vec4 specularData = vec4(0.0);

    #ifdef normalmapEnabled
        vec4 normalTex      = texture(normals, uv[0]);
    #else
        vec4 normalTex      = vec4(0.5, 0.5, 1.0, 1.0);
    #endif

    specularData = texture(specular, uv[0]);

    convertToPipelineAlbedo(sceneColor.rgb);

    vec3 albedo     = sceneColor.rgb;

    #ifdef gTERRAIN
        if (matID == 102) {
            sceneColor  = vec4(0.01, 0.03, 0.1, 0.11);
            albedo      = vec3(1.0);
            sceneNormal = waterNormal();
        }
        #ifdef customIceEnabled
        else if (matID == 103) {
            vec3 parallaxPos = worldPos;
            sceneNormal = waterNormal(parallaxPos);
            sceneColor = vec4(getIceAlbedo(parallaxPos), 0.92);
            hue      = normalize(sceneColor.rgb);
            specularData.xy = vec2(0.008, 0.06);
        }
        #endif 
        else {
            sceneNormal = decodeNormalTexture(texture(normals, uv[0]).rgb);
        }
    #endif

    vec3 indirectLight  = lightColor[0];

    vec3 emission       = pow6(lmap.x) * sqr(tint.a) * lightColor[1] * rpi;

    sceneColor.rgb     *= indirectLight + emission;

    translucentColor    = clamp16F(sceneColor);

    sceneDataA.xy   = encodeNormal(sceneNormal);
    sceneDataA.z    = pack2x8(lmap);
    sceneDataA.w    = pack2x8(encodeNormal(normal));

    reflectionAux   = packReflectionAux(vec3(1.0), albedo);

    sceneDataB.x    = pack2x8(specularData.xy);
    sceneDataB.y    = pack2x8(ivec2(matID, 0));
    sceneDataB.z    = 0.0;
    sceneDataB.w    = 1.0;
}