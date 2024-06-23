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

/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 sceneColor;
layout(location = 1) out float vpsSigmaStore;

#include "/lib/util/colorspace.glsl"

const bool shadowHardwareFiltering = false;

in vec2 uv;

#ifndef airTransmittanceHQ
flat in vec3 sunColor;
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex3, colortex4;
uniform sampler2D colortex5;

uniform sampler2D depthtex0;

uniform sampler2D noisetex;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

uniform int frameCounter;
uniform int worldTime;

uniform float far, near;
uniform float rainStrength;

uniform vec2 skyCaptureResolution;
uniform vec2 taaOffset;
uniform vec2 pixelSize, viewSize;

uniform vec3 upDir, upDirView;
uniform vec3 sunDir, sunDirView;
uniform vec3 moonDir, moonDirView;
uniform vec3 lightDir;

uniform vec4 daytime;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 shadowModelView, shadowProjection;

/* ------ includes ------*/
#define FUTIL_LINDEPTH
#define FUTIL_ROT2
#include "/lib/fUtil.glsl"
#include "/lib/util/encoders.glsl"

#include "/lib/util/transforms.glsl"
#include "/lib/atmos/air/const.glsl"
#include "/lib/atmos/project.glsl"
#include "/lib/util/bicubic.glsl"
#include "/lib/frag/gradnoise.glsl"

/* ------ SKYBOX ------ */

vec3 sunDisk(vec3 viewDir) {
    vec3 v      = -viewDir;
    vec3 sv     = normalize(sunDirView + v);
    float sun   = dot(sv, v);

    const float size = 0.0055;
    float maxsize = size + 0.0004;
        maxsize  += linStep(sunDir.y, -0.04, 0.04)*0.004;

    float s   = 1.0-linStep(sun, size, maxsize);
        //s    *= 1.0-sstep(sun, 0.004, 0.0059)*0.5;

    float limb = 1.0 - cube(linStep(sun, 0.0, maxsize))*0.8;
        s    *= limb;

    #ifdef airTransmittanceHQ
        return s * sunIllum * 5e3;
    #else
        return s * sunColor * 5e3;
    #endif
}

vec3 moonTexture(vec3 viewDir, vec3 color) {
    vec3 v      = -viewDir;
    vec3 sv     = normalize(moonDirView + v);
    float moon  = dot(sv, v);

    float s   = 1.0-linStep(moon, 0.03, 0.08);

    return color * s * colorSaturation(moonIllum, 0.5) * 6.0;
}

#include "/lib/frag/noise.glsl"

vec3 skyStars(vec3 worldDir) {
    vec3 plane  = worldDir/(worldDir.y+length(worldDir.xz)*0.66);
    float rot   = worldTime*rcp(2400.0);
    plane.x    += rot*0.6;
    plane.yz    = rotatePos(plane.yz, (25.0/180.0)*pi);
    vec2 uv1    = floor((plane.xz)*768)/768;
    vec2 uv2    = (plane.xz)*0.04;

    vec3 starcol = vec3(0.3, 0.78, 1.0);
        starcol  = mix(starcol, vec3(1.0, 0.7, 0.6), noise2D(uv2).x);
        starcol  = normalize(starcol)*(noise2D(uv2*1.5).x+1.0);

    float star  = 1.0;
        star   *= noise2D(uv1).x;
        star   *= noise2D(uv1+0.1).x;
        star   *= noise2D(uv1+0.26).x;

    star        = max(star-0.25, 0.0);
    star        = saturate(star*4.0);

    return star*starcol*0.25*sqrt(daytime.w);
}

/* ------ SHADOWPASS PRECOMPUTION ------ */

#include "/lib/shadowconst.glsl"
#include "/lib/light/warp.glsl"

#include "/lib/offset/random.glsl"


float shadowVPSSigma(sampler2D tex, vec3 scenePos) {    
    vec3 pos        = scenePos + vec3(shadowmapBias) * lightDir;
    float a         = length(pos);
        pos         = transMAD(shadowModelView, pos);
        pos         = projMAD(shadowProjection, pos);

        pos.z      *= 0.2;

    if (pos.z > 1.0) return 0.0;

        pos.z      -= 0.0012*(saturate(a/256.0));

    vec2 posUnwarped = pos.xy;

    float warp      = 1.0;
        pos.xy      = shadowmapWarp(pos.xy, warp);
        pos         = pos * 0.5 + 0.5;

    const uint iterations = 6;

    const float penumbraScale = tan(radians(0.3 * shadowPenumbraScale));

    float penumbraMax   = shadowmapDepthScale * penumbraScale * shadowProjection[0].x;
    float searchRad     = min(0.5 * shadowProjection[0].x, penumbraMax / tau);

    float maxRad        = max(searchRad, 2.0 / shadowmapSize.x / warp);

    float minDepth      = pos.z - maxRad / penumbraMax / tau;
    float maxDepth      = pos.z;

    const uint itSquare = iterations * iterations;
    const float w = 1.0 / float(itSquare);

    float weightSum = 0.0;
    float depthSum  = 0.0;

    float dither    = ditherGradNoiseTemporal();

    for (uint i = 0; i<iterations; ++i) {
        vec2 offset     = R2((i + dither) * 64.0);
            offset      = vec2(cos(offset.x * tau), sin(offset.x * tau)) * sqrt(offset.y);            

        vec2 searchPos  = posUnwarped + offset * searchRad;
            searchPos   = shadowmapWarp(searchPos) * 0.5 + 0.5;

        float depth     = texelFetch(tex, ivec2(searchPos * shadowmapSize), 0).x;
        float weight    = step(depth, pos.z);

            depthSum   += weight * clamp(depth, minDepth, maxDepth);
            weightSum  += weight;
    }
    depthSum   /= weightSum > 0.0 ? weightSum : 1.0;

    float sigma     = weightSum > 0.0 ? (pos.z - depthSum) * penumbraMax : 0.0;

    return max0(sigma) * rcp(warp);
}

vec4 TexCatmullRom(sampler2D tex, vec2 uv) {   //~5fps
    vec2 res    = ivec2(viewSize);

    vec2 coord  = uv*res;
    vec2 coord1 = floor(coord - 0.5) + 0.5;

    vec2 f      = coord-coord1;

    vec2 w0     = f * (-0.5 + f * (1.0 - (0.5 * f)));
    vec2 w1     = 1.0 + sqr(f) * (-2.5 + (1.5 * f));
    vec2 w2     = f * (0.5 + f * (2.0 - (1.5 * f)));
    vec2 w3     = sqr(f) * (-0.5 + (0.5 * f));

    vec2 w12    = w1+w2;
    vec2 delta12 = w2 * rcp(w12);

    vec2 uv0    = (coord1 - vec2(1.0)) * pixelSize;
    vec2 uv3    = (coord1 + vec2(1.0)) * pixelSize;
    vec2 uv12   = (coord1 + delta12) * pixelSize;

    vec4 col    = vec4(0.0);
        col    += textureLod(tex, vec2(uv0.x, uv0.y), 0)*w0.x*w0.y;
        col    += textureLod(tex, vec2(uv12.x, uv0.y), 0)*w12.x*w0.y;
        col    += textureLod(tex, vec2(uv3.x, uv0.y), 0)*w3.x*w0.y;

        col    += textureLod(tex, vec2(uv0.x, uv12.y), 0)*w0.x*w12.y;
        col    += textureLod(tex, vec2(uv12.x, uv12.y), 0)*w12.x*w12.y;
        col    += textureLod(tex, vec2(uv3.x, uv12.y), 0)*w3.x*w12.y;

        col    += textureLod(tex, vec2(uv0.x, uv3.y), 0)*w0.x*w3.y;
        col    += textureLod(tex, vec2(uv12.x, uv3.y), 0)*w12.x*w3.y;
        col    += textureLod(tex, vec2(uv3.x, uv3.y), 0)*w3.x*w3.y;

    return clamp(col, 0.0, 65535.0);
}

void main() {
    sceneColor      = texture(colortex0, uv);

    float sceneDepth = texture(depthtex0, uv).x;

    vec3 viewPos    = screenToViewSpace(vec3(uv / ResolutionScale, sceneDepth));
    vec3 scenePos   = viewToSceneSpace(viewPos);

    if (!landMask(sceneDepth)) {
        vec3 viewDir    = normalize(viewPos);
        vec3 sceneDir   = normalize(scenePos);

        vec3 sunMoon    = sunDisk(viewDir) + moonTexture(viewDir, sceneColor.rgb) + skyStars(sceneDir);

        float groundOcclusion = exp(-max0(-sceneDir.y) * sqrPi);

        sceneColor.rgb  = textureBicubic(colortex5, projectSky(sceneDir, 0)).rgb;

        #ifdef airTransmittanceHQ
            vec3 transmittance = textureBicubic(colortex5, projectSky(sceneDir, 1)).rgb;
        #else
            float transmittance = cube(linStep(sceneDir.y, -0.02, 0.02));
        #endif

        #if (defined RSKY_SB_CloudVolume || defined RSKY_SB_CirrusCloud || defined RSKY_SB_CirrocumulusCloud || defined RSKY_SB_NoctilucentCloud)
            const float cLOD = sqrt(CLOUD_RENDER_LOD);
            vec2 cloudCoord = (uv / ResolutionScale + taaOffset * 0.5 * pixelSize / ResolutionScale) / cLOD;

            vec4 clouds     = TexCatmullRom(colortex3, cloudCoord);
                //clouds      = texelFetch(colortex3, ivec2(cloudCoord * viewSize), 0);

            sceneColor.rgb  = sceneColor.rgb * clouds.a + clouds.rgb;

            sceneColor.rgb += sunMoon * transmittance * clouds.a;
        #else
            sceneColor.rgb += sunMoon * transmittance;
        #endif

        //sceneColor.rgb = textureBicubic(colortex5, projectSky(sceneDir, 2)).rgb;
    }

    sceneColor      = clamp16F(sceneColor);

    vpsSigmaStore   = 0.0;

    if (landMask(sceneDepth)) {
        vec3 GeometryNormal = texture(colortex4, uv).xyz * 2.0 - 1.0;

        vec3 shadowPosition = scenePos;
        // Based on the approach of Emin in Complementary
            shadowPosition += GeometryNormal * min(0.1 + length(scenePos) / 200.0, 0.5) * (2.0 - max0(dot(GeometryNormal, lightDir))) * log2(max(128.0 - shadowMapResolution * shadowMapDepthScale, euler)) / euler;

        vpsSigmaStore = shadowVPSSigma(shadowtex1, shadowPosition);
    }

    vpsSigmaStore   = clamp16F(vpsSigmaStore);
}