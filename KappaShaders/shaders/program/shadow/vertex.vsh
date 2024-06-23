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

out float skyOcclusion;

out float warp;

out vec3 scenePos;
out vec3 worldPos;

out vec4 tint;

flat out int matID;

flat out vec3 normal;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

#include "/lib/light/warp.glsl"

uniform vec3 cameraPosition;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

#ifdef pomEnabled
    #if (defined normalmapEnabled || defined pomEnabled)
        flat out mat3 tbn;
        in vec4 at_tangent;
    #endif

    #if (MC_VERSION >= 11500 && defined vertexAttributeFix)
        #define tbnFix
    #endif

    out float vertexDist;
    out vec2 vCoord;
    out vec4 vCoordAM;
    out vec3 viewVec;

    #ifdef tbnFix
        out vec3 vertexPos;
    #endif
#endif

#ifdef windEffectsEnabled
    #include "/lib/vertex/wind.glsl"

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
    uv    = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;

    tint        = gl_Color;

    normal      = normalize(gl_NormalMatrix*gl_Normal);

    vec4 pos    = gl_Vertex;
        pos     = gl_ModelViewMatrix * pos;

        pos.xyz = transMAD(shadowModelViewInverse, pos.xyz);

        scenePos   = pos.xyz;
        worldPos   = pos.xyz+cameraPosition;

    float slmap  = linStep((gl_TextureMatrix[1]*gl_MultiTexCoord1).y, rcp(16.0), 1.0);

    skyOcclusion    = slmap;

    #ifdef windEffectsEnabled
        bool windLod    = length(pos.xz) < 64.0;

        if (windLod) {
            bool topvert    = (gl_MultiTexCoord0.t < mc_midTexCoord.t);

            float occlude   = sqr(slmap)*0.9+0.1;

            #ifdef waterVertexWavesEnabled
                if (mc_Entity.x == 10001) pos.y += waterVertexWaves(worldPos, 0.55);
            #endif

            if (mc_Entity.x == 10021 || (mc_Entity.x == 10022 && topvert) || (mc_Entity.x == 10023 && topvert) || mc_Entity.x == 10024) {
                vec2 wind_offset = vertexWindEffect(worldPos, 0.18, 1.0)*occlude;

                if (mc_Entity.x == 10021) pos.xyz += wind_offset.xyy*0.4;
                else if (mc_Entity.x == 10023 || (mc_Entity.x == 10024 && !topvert)) pos.xz += wind_offset*0.5;
                else pos.xz += wind_offset;
            }
        }
    #endif

        pos.xyz = transMAD(shadowModelView, pos.xyz);

        pos     = gl_ProjectionMatrix * pos;

        pos.xy  = shadowmapWarp(pos.xy, warp);
        pos.z  *= 0.2;

    gl_Position = pos;

    //mat ids
    if (mc_Entity.x == 10001) matID = 102;
    else if (mc_Entity.x == 10003) matID = 103;
    else matID = 1;

    #ifdef pomEnabled
        //vec3 viewNormal = normalize(gl_NormalMatrix*gl_Normal);
        vec3 viewTangent = normalize(gl_NormalMatrix*at_tangent.xyz);
        vec3 viewBinormal = normalize(gl_NormalMatrix*cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);

        mat3 viewtbn = mat3(
            viewTangent.x, viewBinormal.x, normal.x,
            viewTangent.y, viewBinormal.y, normal.y,
            viewTangent.z, viewBinormal.z, normal.z);

        vec2 coordMid   = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
        vec2 coordNMid  = uv - coordMid;

        vCoordAM.zw     = abs(coordNMid) * 2.0;
        vCoordAM.xy     = min(uv, coordMid - coordNMid);

        vCoord          = sign(coordNMid) * 0.5 + 0.5;
        viewVec         = viewtbn * (gl_ModelViewMatrix * gl_Vertex).xyz;

        vec3 viewPos = transMAD(gbufferModelView, scenePos);
        vertexDist   = length(viewPos);
    #endif
}