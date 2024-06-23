
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
uniform vec2 viewSize;
#define VERTEX_STAGE
#include "/lib/downscaleTransform.glsl"

out mat2x2 uv;

out float shadowWarp;
out float viewDist;

out vec2 shadowPositionUnwarped;

out vec3 shadowPosition;
out vec3 scenePos;
out vec3 worldPos;
out vec3 viewPos;

out vec4 tint;

flat out int matID;

flat out vec3 normal;

uniform sampler2D noisetex;

uniform float frameTimeCounter;

uniform vec2 taaOffset;

uniform vec3 lightDir;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;

#ifdef gTERRAIN
    out vec3 tangentViewDir;
    flat out mat3 tbn;

    attribute vec4 at_tangent;
    attribute vec4 mc_Entity;
#endif

#include "/lib/shadowconst.glsl"
#include "/lib/light/warp.glsl"

void getShadowmapPos(vec3 scenePos) {  //shadow 2d
    vec3 pos    = scenePos + vec3(shadowmapBias) * lightDir;
    float a     = length(pos);
        pos     = transMAD(shadowModelView, pos);
        pos     = projMAD(shadowProjection, pos);
        pos.z  *= 0.2;
        pos.z  -= 0.0012*(saturate(a/256.0));

    shadowPositionUnwarped = pos.xy;

        shadowWarp    = 1.0;
        pos.xy  = shadowmapWarp(pos.xy, shadowWarp);

    shadowPosition = pos*0.5+0.5;
    return;
}

vec3 blackbody(float temperature){
    vec4 vx = vec4(-0.2661239e9, -0.2343580e6, 0.8776956e3, 0.179910);
    vec4 vy = vec4(-1.1063814, -1.34811020, 2.18555832, -0.20219683);
    float it = rcp(temperature);
    float it2= sqr(it);
    float x = dot(vx, vec4(it * it2, it2, it, 1.0));
    float x2 = sqr(x);
    float y = dot(vy,vec4(x * x2, x2, x, 1.0));
    float z = 1.0 - x - y;
    
    vec3 AP1 = vec3(x * rcp(y), 1.0, z * rcp(y)) * CT_XYZ_AP1;
    return max(AP1, 0.0);
}

#include "/lib/atmos/colorsEnd.glsl"

#ifdef gTERRAIN
    #include "/lib/frag/noise.glsl"

    vec2 rotatePosXY(vec2 pos, const float angle) {
        return vec2(cos(angle)*pos.x + sin(angle)*pos.y, 
                    cos(angle)*pos.y - sin(angle)*pos.x);
    }

    float waterVertexWaves(vec3 pos, const float size) {
        vec3 p  = pos * size;

        float t = frameTimeCounter * pi * 0.5;
        vec3 w  = vec3(t*0.9, t*0.2, t*0.3);

        float wave  = value3D(p + w);
            p.xz    = rotatePosXY(p.xz, 0.4 * pi);
            wave   += value3D(p * 2.0 + w) * 0.5;
            wave   -= 0.75;

        return wave*0.2;
    }
#endif

void main() {
    uv[0]    = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    uv[1]    = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
    uv[1].x  = linStep(uv[1].x, rcp(24.0), 1.0);
    uv[1].y  = linStep(uv[1].y, rcp(16.0), 1.0);

    normal      = mat3(gbufferModelViewInverse)*normalize(gl_NormalMatrix*gl_Normal);
    tint        = gl_Color;

    #ifdef gTERRAIN
        vec3 viewTangent = normalize(gl_NormalMatrix*at_tangent.xyz);
        vec3 viewBinormal = normalize(gl_NormalMatrix*cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
        vec3 tangent = mat3(gbufferModelViewInverse) * viewTangent;
        vec3 binormal = mat3(gbufferModelViewInverse) * viewBinormal;

        tbn     = mat3(tangent.x, binormal.x, normal.x,
                    tangent.y, binormal.y, normal.y,
                    tangent.z, binormal.z, normal.z);
    #endif

    vec4 pos    = gl_Vertex;
        pos     = transMAD(gl_ModelViewMatrix, pos.xyz).xyzz;

    #ifdef gTERRAIN
        tangentViewDir = mat3(gbufferModelViewInverse) * pos.xyz * tbn;
    #endif

        pos.xyz = transMAD(gbufferModelViewInverse, pos.xyz);

    getShadowmapPos(pos.xyz);

    scenePos    = pos.xyz;

    worldPos    = pos.xyz+cameraPosition;

    #ifdef gTERRAIN
        #ifdef waterVertexWavesEnabled
            if (mc_Entity.x == 10001) pos.y += waterVertexWaves(worldPos, 0.55);
        #endif
    #endif

        pos.xyz = transMAD(gbufferModelView, pos.xyz);

        viewPos = pos.xyz;

        pos     = pos.xyzz * diag4(gl_ProjectionMatrix) + vec4(0.0, 0.0, gl_ProjectionMatrix[3].z, 0.0);
        
    #ifdef taaEnabled
        pos.xy += taaOffset*pos.w / ResolutionScale;
    #endif
        
    gl_Position = pos;
    VertexDownscaling(gl_Position);

    getColorPalette();

    #ifdef gTERRAIN
        viewDist   = length(gl_ModelViewMatrix*gl_Vertex);
        //mat ids
        if (mc_Entity.x == 10001) matID = 102;
        else if (mc_Entity.x == 10003) matID = 103;
        else matID = 101;
    #else
        matID = 101;
    #endif
}