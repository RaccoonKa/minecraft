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


/* RENDERTARGETS: 0,3,4,14,15 */
layout(location = 0) out vec4 sceneColor;
layout(location = 1) out vec4 emissionColor;
layout(location = 2) out vec4 gbufferData;
layout(location = 3) out vec3 directSunlight;
layout(location = 4) out vec2 auxData;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"
#include "/lib/util/colorspace.glsl"
#include "/lib/shadowconst.glsl"

const bool shadowHardwareFiltering = true;

in vec2 uv;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex15;

uniform sampler2D depthtex0;

uniform sampler2D noisetex;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

uniform int frameCounter;

uniform float near, far;

uniform vec2 taaOffset;
uniform vec2 pixelSize, viewSize;

uniform vec3 lightDir, lightDirView;

uniform vec4 daytime;

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
#include "/lib/light/warp.glsl"
#include "/lib/light/contactShadow.glsl"

struct shadowData {
    vec3 color;
    vec3 subsurfaceScatter;
};

#include "/lib/offset/random.glsl"

vec3 ReadShadowColor(ivec2 Pixel) {
    vec4 Sample = texelFetch(shadowcolor0, Pixel, 0);

    return mix(vec3(1.0), Sample.rgb * 4.0, Sample.a);
}
vec4 GetSampleColor(vec3 Color, float SolidOcclusion, float TranslucentOcclusion, float SharpenAlpha) {
    if (TranslucentOcclusion >= SolidOcclusion) Color = vec3(1.0);

    return mix(vec4(Color * SolidOcclusion, SolidOcclusion), vec4(Color, SolidOcclusion), SharpenAlpha);
}

vec4 GetShadowBilinear(vec3 uv, float SharpenAlpha) {
    ivec2 ShadowRes = ivec2(shadowMapResolution);

    ivec2 SamplePixel = ivec2(uv.xy * ShadowRes - 0.5);

    vec4 OcclusionSamples = textureGather(shadowtex1, uv.xy, uv.z).wzxy;
    vec4 OcclusionSamples_T = textureGather(shadowtex0, uv.xy, uv.z).wzxy;

    vec3[4] ColorSamples = vec3[4](
        ReadShadowColor(SamplePixel + ivec2(0,0)),
        ReadShadowColor(SamplePixel + ivec2(1,0)),
        ReadShadowColor(SamplePixel + ivec2(0,1)),
        ReadShadowColor(SamplePixel + ivec2(1,1))
    );

    vec2 PixelFract = fract(uv.xy * ShadowRes - 0.5);

    vec4 Color0 = mix(GetSampleColor(ColorSamples[0], OcclusionSamples[0], OcclusionSamples_T[0], SharpenAlpha), GetSampleColor(ColorSamples[1], OcclusionSamples[1], OcclusionSamples_T[1], SharpenAlpha), PixelFract.x);
    vec4 Color1 = mix(GetSampleColor(ColorSamples[2], OcclusionSamples[2], OcclusionSamples_T[2], SharpenAlpha), GetSampleColor(ColorSamples[3], OcclusionSamples[3], OcclusionSamples_T[3], SharpenAlpha), PixelFract.x);

    return mix(Color0, Color1, PixelFract.y);
}

vec4 shadowFiltered(vec3 pos, float sigma) {
    float stepsize = rcp(float(shadowMapResolution));
    float dither   = ditherBluenoise();

    vec4 TotalShadow   = vec4(0.0);

    const float minSoftSigma = shadowmapPixel.x * 2.0;

    float softSigma = max(sigma, minSoftSigma);

    float sharpenLerp = saturate(sigma / minSoftSigma);

    vec2 noise  = vec2(cos(dither * pi), sin(dither * pi)) * stepsize;
    
    vec3 colorMin   = vec3(1.0);

    for (uint i = 0; i < shadowFilterIterations; ++i) {
        vec2 offset     = R2((i + dither) * 64.0);
            offset      = vec2(cos(offset.x * tau), sin(offset.x * tau)) * sqrt(offset.y);

            vec4 colorSample = GetShadowBilinear(pos + vec3(offset * softSigma, 0.0), (1.0 - sharpenLerp));

            TotalShadow   += colorSample;
            colorMin    = min(colorMin, colorSample.rgb);
    }
    TotalShadow  /= float(shadowFilterIterations);

    //vec2 sharpenBorders = mix(vec2(0.4, 0.6), vec2(0.0, 1.0), sharpenLerp);
    vec2 sharpenBorders = mix(vec2(0.5, 0.6), vec2(0.0, 1.0), sharpenLerp);

    float sharpenedShadow = linStep(TotalShadow.a, sharpenBorders.x, sharpenBorders.y);

    float colorEdgeWeight = saturate(distance(TotalShadow.a, sharpenedShadow));

    TotalShadow.rgb = mix(TotalShadow.rgb, colorMin, sqrt(colorEdgeWeight));

    return vec4(mix(TotalShadow.rgb * sharpenedShadow, TotalShadow.rgb, saturate((sigma / minSoftSigma) - 1)), sharpenedShadow);
}

vec3 RShadow_GetBias(vec3 GeometryNormal, vec3 ShadowPosition, float Distortion) {
    float BiasScale = log2(max(128.0 - shadowMapResolution / 8.0, 4.0)) * 0.35;
    return mat3(shadowProjection) * (mat3(shadowModelView) * GeometryNormal) * Distortion * BiasScale;
}

shadowData getShadowRegular(vec3 scenePos, float sigma, vec3 GeometryNormal) {   
    shadowData data     = shadowData(vec3(1.0), vec3(0.0));
   
    vec3 pos        = scenePos;
    float a         = length(pos);
        pos         = transMAD(shadowModelView, pos);
        pos         = projMAD(shadowProjection, pos);

        pos.z      *= 0.2;

    if (pos.z > 1.0) return data;

        pos.z      -= 0.0012*(saturate(a/256.0));

    vec2 posUnwarped = pos.xy;

    float warp      = 1.0;
        pos.xy      = shadowmapWarp(pos.xy, warp);
        pos         = pos * 0.5 + 0.5;

        pos.z      -= (sigma * warp);

        vec4 shadow     = shadowFiltered(pos, sigma);

        data.color      = shadow.rgb;

    return data;
}

#include "/lib/atmos/phase.glsl"

shadowData getShadowSubsurface(bool diffLit, vec3 scenePos, float sigma, vec3 viewDir, vec3 albedo, float opacity) {
    shadowData data     = shadowData(vec3(1.0), vec3(0.0));

    vec3 pos        = scenePos;
    float a         = length(pos);
        pos         = transMAD(shadowModelView, pos);
        pos         = projMAD(shadowProjection, pos);

        pos.z      *= 0.2;

    if (pos.z > 1.0) return data;

        pos.z      -= 0.0012*(saturate(a/256.0));

    vec2 posUnwarped = pos.xy;

    float warp      = 1.0;
        pos.xy      = shadowmapWarp(pos.xy, warp);
        pos         = pos * 0.5 + 0.5;

    if (diffLit) {
            pos.z      -= (sigma * warp);

            vec4 shadow     = shadowFiltered(pos, sigma);

            data.color      = shadow.rgb;
    }

    if (opacity < (0.5 / 255.0)) return data;

    float bluenoise     = ditherBluenoise();
    float sssRad        = 0.001 * sqrt(opacity);
    vec3 sssShadow      = vec3(0.0);
    
    #define sssLoops 5

    float rStep         = rcp(float(sssLoops));
    float offsetMult    = rStep;
    vec2 noise          = vec2(sin(bluenoise * pi), cos(bluenoise * pi));

    vec3 colorSum       = vec3(0.0);
    
    for (int i = 0; i < sssLoops; i++) {
        vec3 offset         = vec3(noise, -bluenoise) * offsetMult;
        float falloff       = sqr(rcp(1.0 + length(offset)));
            offset.xy      *= rcp(warp);
            offset         *= sssRad;

        float sssShadowTemp = texture(shadowtex1, pos + vec3(offset.xy, offset.z));
            sssShadowTemp  += texture(shadowtex1, pos + vec3(-offset.xy, offset.z));
            sssShadowTemp  *= falloff;

            sssShadow      += vec3(sssShadowTemp);
            offsetMult     += rStep;

        vec4 colorSample = texture(shadowcolor0, pos.xy + offset.xy);
            colorSample.rgb = mix(vec3(1.0), colorSample.rgb * 4.0, colorSample.a);

        colorSum   += colorSample.a > 0.1 ? colorSample.rgb : vec3(1.0);
    }
    colorSum   *= rStep;

    sssShadow   = saturate(sssShadow * rStep * 1.2);

    vec3 albedoNorm     = normalizeSafe(albedo) * (avgOf(albedo) * 0.5 + 0.5);
    vec3 scattering     = mix(albedoNorm * normalizeSafe(albedo), mix(albedoNorm, vec3(0.8), sssShadow * 0.7), sssShadow) * sssShadow;
        scattering     *= mix(mieHG(dot(viewDir, lightDirView), 0.65), 1.2, 0.4);  //eyeballed to look good because idk the accurate version

    data.subsurfaceScatter = (scattering * colorSum) * (sqrt2 * rpi * opacity);

    return data;
}

float readCloudShadowmap(sampler2D shadowmap, vec3 position) {
    position    = mat3(shadowModelView) * position;
    position   /= cloudShadowmapRenderDistance;
    position.xy = position.xy * 0.5 + 0.5;

    position.xy /= vec2(1.0, 1.0 + (1.0 / 3.0));

    return texture(shadowmap, position.xy).a;
}


/* ------ BRDF ------ */

#include "/lib/brdf/fresnel.glsl"
#include "/lib/brdf/hammon.glsl"
#include "/lib/brdf/labPBR.glsl"

vec3 fauxPorosity(vec3 albedo, float wetness, float porosity) {
    //wetness = 1.0;
    vec3 wetAlbedo      = colorSaturation(pow(clamp(albedo, 1e-4, 1.0), vec3(1.5 + getLuma(albedo) * 0.5)), 0.85);
        //wetAlbedo       = albedo;
    float frcBounced    = 0.7 * porosity;
        wetAlbedo      = (1.0 - frcBounced) * wetAlbedo / max(vec3(1e-4), 1.0 - frcBounced * wetAlbedo);

    return mix(albedo, wetAlbedo, wetness);
}


#include "/lib/light/emission.glsl"

bool InsideDownscaleViewport() {
    return clamp(gl_FragCoord.xy, vec2(-1), ceil(viewSize * ResolutionScale) + vec2(1)) == gl_FragCoord.xy;
}

void main() {
    sceneColor      = stex(colortex0);
    directSunlight  = vec3(1.0);

    float sceneDepth = stex(depthtex0).x;

    auxData         = stex(colortex15).xy;
    auxData.y       = sceneColor.a;

    sceneColor.a    = 0.0;
    emissionColor   = vec4(0,0,0,1);

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

        #if subsurfaceScatterMode <= 1
            bool isSSS          = matID.x == 2 || matID.x == 4;
            float sssOpacity    = float(matID.x == 2 || matID.x == 4);
        #elif subsurfaceScatterMode == 2
            bool isSSS          = matID.x == 2 || matID.x == 4 || material.opacity > 1e-2;
            float sssOpacity    = max(float(matID.x == 2 || matID.x == 4), material.opacity);
        #elif subsurfaceScatterMode == 3
            bool isSSS          = material.opacity > 1e-2;
            float sssOpacity    = material.opacity;
        #endif

        vec2 aux        = unpack2x8(tex2.z);    //parallax shadows and wetness

        sceneColor.rgb  = fauxPorosity(sceneColor.rgb, aux.y, material.porosity);

        float diffuse   = diffuseHammon(viewNormal, viewDir, lightDirView, material.roughness);

        #ifdef contactShadowsEnabled
        if (diffuse > 0.0) diffuse *= getContactShadow(depthtex0, viewPos, ditherBluenoise(), sceneDepth, dot(viewNormal, viewDir), lightDirView);
        #endif

        #if subsurfaceScatterMode == 0
        if (isSSS) diffuse  = mix(diffuse, diffuse * 0.7 + 0.3 / pi, sssOpacity);
        #endif
        
            diffuse    *= aux.x;

        shadowData shadow   = shadowData(vec3(1.0), vec3(0.0));

        bool diffuseLit = diffuse > 0.0;

        #ifdef shadowVPSEnabled
        float shadowSigma   = stex(colortex3).x;
        #else
        const float shadowSigma = 0.001 * shadowPenumbraScale;
        #endif

        //vec3 shadowPosition     = scenePos + lightDir * shadowmapBias * sqrt(length(scenePos) / 128.0);
        //    shadowPosition     += lightDir * shadowmapBias * (1.0 - max0(dot(sceneNormal, lightDir)));

        vec3 GeometryNormal = texture(colortex4, uv).xyz * 2.0 - 1.0;

        vec3 shadowPosition = scenePos;
            shadowPosition += GeometryNormal * min(0.1 + length(scenePos) / 200.0, 0.5) * (2.0 - max0(dot(sceneNormal, lightDir))) * log2(max(128.0 - shadowMapResolution * shadowMapDepthScale, euler)) / euler;

        #if subsurfaceScatterMode != 0
            if (isSSS) shadow   = getShadowSubsurface(diffuseLit, shadowPosition, shadowSigma, viewDir, stex(colortex0).rgb, sssOpacity);
            else if (diffuseLit) shadow = getShadowRegular(shadowPosition, shadowSigma, sceneNormal);
        #else
            if (diffuseLit) shadow = getShadowRegular(shadowPosition, shadowSigma, sceneNormal);
        #endif

        directSunlight  = (diffuse) * shadow.color + shadow.subsurfaceScatter;

        #ifdef cloudShadowsEnabled
        directSunlight *= readCloudShadowmap(colortex5, scenePos);
        #endif

        #ifdef UseLightleakPrevention
            directSunlight *= sstep(unpack2x8(tex1.z).y, 0.1, 0.2);
        #endif

        directSunlight  = saturate(directSunlight * 0.5);

        material.emission = pow(material.emission, labEmissionCurve);

        #ifndef ssptAdvancedEmission
            float albedoLum = mix(avgOf(sceneColor.rgb), maxOf(sceneColor.rgb), 0.71);
                albedoLum   = saturate(albedoLum * sqrt2);

            float emitterLum = saturate(mix(sqr(albedoLum), sqrt(maxOf(sceneColor.rgb)), albedoLum));

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

        if (matID.y == 30) {
            emissionColor.rgb = vec3(0.6, 0.5, 1.0) * (0.3 + daytime.x * 1.5 + daytime.y * 64.0 + daytime.z * 1.5);
            sceneColor.a = emissionColor.b;
        }
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