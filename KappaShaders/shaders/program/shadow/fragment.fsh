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

layout(location = 0) out vec4 data0;
layout(location = 1) out vec4 data1;

#if (defined pomEnabled && defined pomDepthEnabled)
    in vec4 gl_FragCoord;
    layout (depth_greater) out float gl_FragDepth;
#endif


#define shadowmapTextureMipBias 0   //[1 2 3 4]

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"
#include "/lib/util/colorspace.glsl"
#include "/lib/shadowconst.glsl"

#define gSHADOW

in float skyOcclusion;

in vec2 uv;

in float warp;

in vec3 scenePos;
in vec3 worldPos;

in vec4 tint;

flat in int matID;

flat in vec3 normal;

uniform sampler2D gtexture;

uniform sampler2D noisetex;

uniform int blockEntityId;

uniform float frameTimeCounter;
uniform float alphaTestRef;

uniform vec3 cameraPosition;
uniform vec3 lightDir;

#if (defined pomEnabled && defined pomDepthEnabled)
    uniform float near;
    uniform float far;
    uniform sampler2D normals;

    in float vertexDist;
    in vec2 vCoord;
    in vec4 vCoordAM;
    in vec3 viewVec;

    flat in mat3 tbn;

    #include "/lib/frag/parallax.glsl"

    float linearizeOrthoDepth(float depth) {
        return (depth * 2.0 - 1.0) * (far - near) + near;
    }

    float delinearizeOrthoDepth(float depth) {
        return ((depth - near) / (far - near)) * 0.5 + 0.5;
    }
#endif

#define FUTIL_MAT16
#include "/lib/fUtil.glsl"

/* ------ caustics ------ */

#include "/lib/util/bicubic.glsl"

const float viewDist = 0.0;

#include "/lib/atmos/waterConst.glsl"

#include "/lib/atmos/waterWaves.glsl"

vec3 waterNormal(vec3 position, float dstep, int matID) {
        dstep       = max(dstep, 0.015);

    vec2 delta;
        delta.x     = waterWaves(position + vec3( dstep, 0.0, -dstep), matID);
        delta.y     = waterWaves(position + vec3(-dstep, 0.0,  dstep), matID);
        delta      -= waterWaves(position + vec3(-dstep, 0.0, -dstep), matID);

    return normalize(vec3(-delta.x, 2.0 * dstep, -delta.y));
}

float projectedCaustic(vec3 pos, vec3 normal, vec3 lightDir) {
    vec3 dPdx   = dFdx(pos);
    vec3 dPdy   = dFdy(pos);

    float num   = dotSelf(dPdx) * dotSelf(dPdy);

    vec3 refractLight = refract(-lightDir, normal, rcp(1.33));
        dPdx   += 2.0 * dFdx(refractLight);
        dPdy   += 2.0 * dFdy(refractLight);

    float denom = dotSelf(dPdx) * dotSelf(dPdy);

    return sqrt(num * rcp(denom));
}

void main() {
    if (blockEntityId == 10201) discard;

    #if (defined pomEnabled && defined pomDepthEnabled)
        gl_FragDepth = gl_FragCoord.z;
    #endif

    if (matID == 102 || matID == 103) { 
        vec3 waves      = waterNormal(worldPos, rcp(shadowMapResolution) * warp, matID);
        vec3 refractLight = refract(lightDir, waves, rcp(1.33));
        float caustic   = projectedCaustic(scenePos, waves, lightDir);
        data0           = vec4(caustic * 0.25, 1.0, 1.0, 1.0);
    } else {
        #if (defined pomEnabled && defined pomDepthEnabled)
            mat2 dCoord = mat2(dFdx(uv), dFdy(uv));

            float TexDepth = 1.0, TraceDepth = 1.0;
            vec4 parallaxCoord  = getParallaxCoord(uv, dCoord, TexDepth, TraceDepth);

            // TODO: Apply shadowmapTextureMipBias!
            data0 = textureParallax(gtexture, parallaxCoord.xy, dCoord);
        #else
            data0 = texture(gtexture, uv, -shadowmapTextureMipBias);
        #endif

        if (data0.a<0.1) discard;
            data0.rgb  *= tint.rgb;

        #if (defined pomEnabled && defined pomDepthEnabled)
            float pomDist = (1.0 - TraceDepth) * rcp(normalize(-viewVec).z);
            float depth = linearizeOrthoDepth(gl_FragCoord.z);
            gl_FragDepth = delinearizeOrthoDepth(depth + pomDist * pomDepth);
        #endif

        data0.rgb       = linearToAP1Albedo(toLinear(data0.rgb));
    }

    data1.xy    = encodeNormal(normal);
    data1.z     = pack2x8(skyOcclusion, float(matID) / 255.0);
    data1.a     = 1.0;
}