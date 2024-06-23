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

/* RENDERTARGETS: 0,1,2,4 */
layout(location = 0) out vec4 sceneAlbedo;
layout(location = 1) out vec4 GData0;
layout(location = 2) out vec4 GData1;
layout(location = 3) out vec4 GeoNormals;

#include "/lib/head.glsl"
#include "/lib/util/colorspace.glsl"
#include "/lib/util/encoders.glsl"

#if (defined pomDepthEnabled && defined pomEnabled)
    in vec4 gl_FragCoord;
    layout (depth_greater) out float gl_FragDepth;
#endif

uniform vec2 viewSize;
#include "/lib/downscaleTransform.glsl"

in mat2x2 uv;

in vec4 tint;

flat in vec3 normal;

#ifdef vertexAttributeFix
    /* - */
#endif

#ifdef slopeNormalCalculation
/* - */
#endif

uniform mat4 gbufferProjection;

#if MC_VERSION >= 11700
uniform float alphaTestRef;
#else
#define alphaTestRef 0.1
#endif

#ifdef gTEXTURED
    uniform sampler2D gtexture;
    uniform sampler2D specular;

    #if (MC_VERSION >= 11500 && (defined gBLOCK || defined gENTITY || defined gHAND) && defined vertexAttributeFix)
        #define tbnFix

        #ifdef pomEnabled
            #undef pomEnabled
        #endif
    #endif

    #if (defined normalmapEnabled || defined pomEnabled)
        uniform sampler2D normals;

        //flat in int validAtTangent;

        flat in mat3 tbn;
    #endif
    
    #ifdef normalmapEnabled

        #ifdef tbnFix
        in vec3 vertexPos;
        
        uniform mat4 gbufferModelViewInverse;

        /*
            Based on the solution used in MollyVX by rutherin, and its solution in turn was based on:
            http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-13-normal-mapping
        */

        mat3 manualTBN(vec3 pos, vec2 uv) {

            uv *= textureSize(normals, 0);

            vec3 deltaPos1 = dFdx(pos);
            vec3 deltaPos2 = dFdy(pos);
            vec2 deltaUV1 = dFdx(uv);
            vec2 deltaUV2 = dFdy(uv);

            vec3 deltaPos1Perp   = cross(normal, deltaPos1);
            vec3 deltaPos2Perp   = cross(deltaPos2, normal);

            vec3 tangent   = normalize(deltaPos2Perp * deltaUV1.x + deltaPos1Perp * deltaUV2.x);
            vec3 bitangent = normalize(deltaPos2Perp * deltaUV1.y + deltaPos1Perp * deltaUV2.y);

            return mat3(tangent.x, bitangent.x, normal.x,
                        tangent.y, bitangent.y, normal.y,
                        tangent.z, bitangent.z, normal.z);
        }
        #endif

        vec3 decodeNormalTexture(vec3 ntex, inout float materialAO) {
            if(all(lessThan(ntex, vec3(0.003)))) return normal;

            vec3 nrm    = ntex * 2.0 - (254.0 * rcp(255.0));

            #if normalmapFormat==0
                nrm.z  = sqrt(saturate(1.0 - dot(nrm.xy, nrm.xy)));
                materialAO = ntex.z;
            #elif normalmapFormat==1
                materialAO = length(nrm);
                nrm    = normalize(nrm);
            #endif

            #ifdef tbnFix
            mat3 tbn    = manualTBN(vertexPos, uv[0]);
            #endif

            return normalize(nrm * tbn);
        }
    #endif

    in float vertexDist;
    in vec2 vCoord;
    in vec4 vCoordAM;
    in vec3 viewVec;
#endif

#ifdef gTERRAIN
flat in int foliage;
flat in int matID;
flat in int emissionID;
in vec3 worldPos;
#else
flat in int emitter;
#endif

#ifdef gENTITY
uniform int entityId;

uniform vec4 entityColor;
#endif

uniform vec2 taaOffset;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;

vec3 screenToViewSpace(vec3 screenpos, mat4 projInv, const bool taaAware) {
    screenpos   = screenpos*2.0-1.0;

    #ifdef taaEnabled
        if (taaAware) screenpos.xy -= taaOffset / ResolutionScale;
    #endif

    vec3 viewpos    = vec3(vec2(projInv[0].x, projInv[1].y)*screenpos.xy + projInv[3].xy, projInv[3].z);
        viewpos    /= projInv[2].w*screenpos.z + projInv[3].w;
    
    return viewpos;
}
vec3 screenToViewSpace(vec3 screenpos, mat4 projInv) {    
    return screenToViewSpace(screenpos, projInv, true);
}

vec3 screenToViewSpace(vec3 screenpos) {
    return screenToViewSpace(screenpos, gbufferProjectionInverse);
}

#ifdef directionalLMEnabled
    /* - */
#endif


#ifdef gTEXTURED

uniform int frameCounter;

uniform sampler2D noisetex;

#ifdef pomEnabled
    uniform vec3 lightDir;
    #include "/lib/frag/gradnoise.glsl"
    #include "/lib/frag/bluenoise.glsl"
    #include "/lib/frag/parallax.glsl"
#endif
#endif


#ifdef gTERRAIN

#include "/lib/util/bicubic.glsl"

#define normalStep 0.002

uniform float frameTimeCounter;
uniform float wetness, RW_BIOME_Dryness;
uniform float rainStrength;

float puddleWaves(vec2 pos) {
    float noise     = texture(noisetex, pos + vec2(frameTimeCounter * puddleRippleSpeed) * vec2(0.3, 0.1)).z;
        noise      += texture(noisetex, pos * 1.8 + vec2(frameTimeCounter * puddleRippleSpeed) * vec2(-0.1, -0.4)).z * 0.5;

    noise *= 0.5;

    return noise;
}

void getWetness(inout float wetnessOut, inout vec3 normalOut, inout vec2 material, in float height) {
    vec2 pos    = worldPos.xz * 0.02;

    float intensity = sstep(normal.y, 0.5, 0.9) * sstep(uv[1].y, 0.8, 0.95) * saturate(1.0 - RW_BIOME_Dryness);

    if (min(wetness, intensity) <= 1e-2) return;

    #if wetnessMode == 0
    float noise = texture(noisetex, pos).z;
        noise  += textureBicubic(noisetex, pos * 0.2).x * 0.5;
        noise  /= 1.5;
        noise  += (1.0 - height) * 0.15;
        noise  -= saturate(1.0 - normal.y);
        noise  -= saturate(1.0 - sqrt(wetness) * 1.3) * 0.55;
        noise  *= intensity;
    #else
    float noise = intensity;
    #endif

    vec3 flatNormal = normal;

    vec2 delta;
        delta.x     = puddleWaves(pos * 11.0 + vec2( normalStep, -normalStep));
        delta.y     = puddleWaves(pos * 11.0 + vec2(-normalStep,  normalStep));
        delta      -= puddleWaves(pos * 11.0 + vec2(-normalStep, -normalStep));

    flatNormal  = mix(flatNormal, normalize(vec3(-delta.x, 2.0 * normalStep, -delta.y)), 0.02 * sstep(noise, 0.55, 0.62) * rainStrength);

    normalOut   = mix(normalOut, flatNormal, sstep(noise, 0.5, 0.57));

    wetnessOut     = sqr(linStep(noise, 0.35, 0.57));

    material.x  = mix(material.x, 1.0, wetnessOut);
    material.y  = max(material.y, 0.04 * wetnessOut);

    wetnessOut     = sqr(linStep(noise, 0.3, 0.565));
}

#endif

void main() {
    if (OutsideDownscaleViewport()) discard;
    vec3 normalOut  = normal;
    vec2 lmap   = uv[1];
    vec4 specularData = vec4(0.0);
    float parallaxShadow = 1.0;
    float materialAO    = 1.0;
    float wetnessVal    = 0.0;

    #if (defined pomDepthEnabled && defined pomEnabled)
        gl_FragDepth = gl_FragCoord.z;
    #endif

    const int MipBias = int(-clamp((1.0 / ResolutionScale) - 1.0, 0.0, 2.0));


    #ifdef gTEXTURED
        vec4 sceneColor   = texture(gtexture, uv[0], MipBias);
        //if (sceneColor.a<0.1) discard;

        #ifdef normalmapEnabled
            vec4 normalTex      = texture(normals, uv[0], MipBias);
        #else
            vec4 normalTex      = vec4(0.5, 0.5, 1.0, 1.0);
        #endif

        #ifdef pomEnabled
            //bool normalCheck    = all(equal(normalTex, vec4(0.0)));
            
            //if (normalCheck) {    // breaks with zero alpha POM
            //    specularData    = texture(specular, coord[0]);
            //    if (sceneColor.a < 0.1) discard;
            //} else {
            mat2 dCoord         = mat2(dFdx(uv[0]), dFdy(uv[0]));

            float TexDepth = 1.0, TraceDepth = 1.0;
            vec4 parallaxCoord  = getParallaxCoord(uv[0], dCoord, TexDepth, TraceDepth);
            float dO = max0(TexDepth - TraceDepth);

            const vec2 slopeThreshold = vec2(float(3 * 64) / pomSamples, 255.0 - float(3 * 64) / pomSamples);
            float dOT = max0(dO - slopeThreshold.x / 255.0) / (255.0 / slopeThreshold.y);

            sceneColor = textureParallax(gtexture, parallaxCoord.xy, dCoord);
            if (sceneColor.a < alphaTestRef) discard;

            #ifdef pomDepthEnabled
                float f = max(normalize(-viewVec).z, 0.00001);
                float pomDist = (1.0 - TraceDepth) * rcp(f);
                float depth = linearizePerspectiveDepth(gl_FragCoord.z, gbufferProjection);
                gl_FragDepth = delinearizePerspectiveDepth(depth + pomDist * pomDepth, gbufferProjection);
            #endif

            normalTex = textureParallax(normals, parallaxCoord.xy, dCoord);
            
            #if (defined normalmapEnabled && defined slopeNormalCalculation)
                if (dO >= slopeNormalStrength)
                    normalTex.rgb = apply_slope_normal(parallaxCoord.xy, dCoord, TraceDepth) * 0.5f + 0.5f;
            #endif
            
            parallaxShadow  = getParallaxShadow(normalOut, parallaxCoord, dCoord, normalTex.a, dO);

            specularData = textureParallax(specular, parallaxCoord.xy, dCoord);
            //}

            #ifdef normalmapEnabled
                normalOut   = decodeNormalTexture(normalTex.rgb, materialAO);
            #endif
        #else
            #ifdef gENTITY
                if (entityId == 1300) {
                    sceneColor.a = step(0.1, tint.a);
                }
            #endif

            if (sceneColor.a<0.1) discard;

            #ifdef normalmapEnabled
                normalOut   = decodeNormalTexture(normalTex.rgb, materialAO);
            #endif

                specularData = texture(specular, uv[0], MipBias);
        #endif

        sceneColor.rgb *= tint.rgb;
        
        #ifdef gTERRAIN
            sceneColor.a  = tint.a;

            #if wetnessMode != 2
            if (wetness > 1e-2) getWetness(wetnessVal, normalOut, specularData.xy, normalTex.w);
            #endif

            #if (defined normalmapEnabled && defined directionalLMEnabled)
            if(lmap.x > 0.001) {
                vec3 viewPos    = screenToViewSpace(vec3(gl_FragCoord.xy/viewSize/ResolutionScale, gl_FragCoord.z));

                vec3 dirLM_T    = normalize(dFdx(viewPos));
                vec3 dirLM_B    = normalize(dFdy(viewPos));
                vec3 dirLM_N    = cross(dirLM_T, dirLM_B);

                float dirLM     = 1.0;
                vec3 viewNormal = mat3(gbufferModelView) * normalOut;
                vec2 lmDeriv    = vec2(dFdx(lmap.x), dFdy(lmap.x)) * 256.0;
                vec3 lmDir      = normalize(vec3(lmDeriv.x * dirLM_T + 0.0005 * dirLM_N + lmDeriv.y * dirLM_B));

                float lmDiff    = clamp(dot(viewNormal, lmDir), -1.0, 1.0) * lmap.x;
                if (abs(lmDiff) > 0) lmDiff = pow(abs(lmDiff), mix(0.25, 1.0, lmap.x)) * sign(lmDiff);
                if (length(lmDeriv) > 0.001) dirLM = pow(lmap.x, 1.0 - lmDiff);
                lmap.x = mix(lmap.x, saturate(min(dirLM, lmap.x)), sqr(sstep(lmap.x, 0.125, 0.5)));
                //lmap.x = saturate(lmDiff);
            }
            #endif

        #else
            sceneColor.a  = 1.0;
        #endif

        #ifdef gENTITY
            sceneColor.rgb = mix(sceneColor.rgb, entityColor.rgb, entityColor.a);
        #endif
    #else
        vec4 sceneColor   = tint;
        if (sceneColor.a<0.01) discard;
            sceneColor.a  = 1.0;

        if (minOf(sceneColor.rgb) < 0.01) lmap.xy = vec2(0.0);
    #endif

        convertToPipelineAlbedo(sceneColor.rgb);

    #ifndef gTERRAIN
        #ifdef gNODIFF
        int matID = 2;
        #else
        int matID = 1;
        #endif

        int emissionID = 0;

        if (emitter == 1) emissionID = 2;
    #endif

    #ifdef gENTITY
        if (entityId == 1300) {
            sceneColor.rgb = vec3(0.6, 0.5, 1.0);
            sceneColor.a = 1.0;
            emissionID = 30;
        }
        if (entityId == 999) discard;
    #endif

    //if (isnan3(sceneColor.rgb) || isinf3(sceneColor.rgb)) sceneColor.r = 100.0;

    sceneAlbedo     = drawbufferClamp(sceneColor);

    GData0.xy   = encodeNormal(normalOut);
    GData0.z    = pack2x8(lmap);
    GData0.w    = pack2x8(specularData.zw);

    GData1.x    = pack2x8(specularData.xy);
    GData1.y    = pack2x8(ivec2(matID, emissionID));
    GData1.z    = pack2x8(saturate(parallaxShadow), wetnessVal);
    GData1.w    = materialAO;

    GeoNormals.xyz = normal * 0.5 + 0.5;
}