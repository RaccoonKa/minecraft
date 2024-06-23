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

/* RENDERTARGETS: 0,6 */
layout(location = 0) out vec3 sceneImage;
layout(location = 1) out vec4 temporal;

#include "/lib/head.glsl"
#include "/lib/util/colorspace.glsl"

#define INFO 0  //[0]

#define tonemapOperator ACES_AP1_SRGB   //[ACES_AP1_SRGB ACES_AP1_SRGB_RRT hejlBurgessAP1 tonemapReinhardACES]

/* ------ color grading related settings ------ */
//#define doColorgrading

#define vibranceInt 1.00       //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define saturationInt 1.00     //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define gammaCurve 1.00        //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define brightnessInt 0.00     //[-0.50 -0.45 -0.40 -0.35 -0.30 -0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.5]
#define constrastInt 1.00      //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

#define colorlumR 1.00         //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define colorlumG 1.00         //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define colorlumB 1.00         //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

//#define vignetteEnabled
#define vignetteStart 0.15     //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define vignetteEnd 0.85       //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define vignetteIntensity 0.75 //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define vignetteExponent 1.50  //[0.50 0.75 1.0 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00]

#define PURKINJE_EFFECT
#define purkinjeExponent 1.00   //[0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define purkinjeTintRed 0.60    //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define purkinjeTintGreen 0.70  //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define purkinjeTintBlue 1.00   //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

in vec2 uv;

flat in float exposure;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex10, colortex14;
uniform sampler2D colortex15;

//uniform sampler2D shadowcolor0;
//uniform sampler2D shadowcolor1;

uniform sampler2D depthtex0;

uniform sampler2D noisetex;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int hideGUI;

uniform float aspectRatio;
uniform float rainStrength;
uniform float frameTimeCounter, frameTime;
uniform float nightVision, screenBrightness;
uniform float far, near;

uniform vec2 bloomResolution;
uniform vec2 pixelSize;
uniform vec2 viewSize;

/* ------ tonemapping operators ------ */

#include "/lib/academy/aces.glsl"

vec3 hejlBurgessAP1(vec3 AP1) {

        //AP1    *= 0.75;

    vec3 ACES   = AP1 * AP1_AP0;

    ACES    = max(ACES - 0.004, 0.0);
    ACES    = (ACES * (6.2 * ACES + 0.5)) * rcp(ACES * (6.2 * ACES + 1.7) + 0.06);
    ACES    = pow(ACES, vec3(2.2));     // Revert baked in gamma correction of Hejl-Burgess since we'd want to do it in sRGB instead
    ACES    = ACES * AP0_sRGB;

    return LinearToSRGB(ACES);
}
vec3 tonemapReinhardACES(vec3 AP1) {
    float coeff     = 0.8;
        AP1    *= 4.24;

    vec3 ACES   = AP1 * AP1_AP0;
        ACES    = pow(ACES, vec3(0.96));

    float luma  = dot(ACES, AP0_XYZ[1].xyz);
        
        ACES    = ACES / (ACES + coeff);
        ACES    = saturate(ACES);

    ACES    = ACES * AP0_sRGB;

    return (ACES);
}

/* ------ color grading utilities ------ */

vec3 purkinje(vec3 hdr) {
    const vec3 response  = vec3(0.25, 0.50, 0.25);  // not accurate at all but eh, idc

    const vec3 desatTint = vec3(purkinjeTintRed, purkinjeTintGreen, purkinjeTintBlue);

    vec3 xyz    = hdr * AP1_XYZ + nightVision * 0.15;

    vec3 scotopicLuminance = xyz * (1.33 * (1.0 + (xyz.y + xyz.z) / xyz.x) - 1.68);
        scotopicLuminance = max0(scotopicLuminance);

    float purkinje  = dot((scotopicLuminance * XYZ_AP1), response);

        hdr     = mix(hdr, vec3(purkinje) * desatTint, exp(-75.0 * purkinjeExponent * purkinje));

    vec2 noisecoord = uv*viewSize;
    float anim  = frameTimeCounter * 8.0 * 256.0;

    vec3 noise  = vec3(0.0);
        noise.r = texture(noisetex, floor(noisecoord+anim*1.8)*rcp(256.0)).x;
        noise.g = texture(noisetex, floor(noisecoord+vec2(-anim, anim)*1.2)*rcp(256.0)).x;
        noise.b = texture(noisetex, floor(noisecoord+vec2(anim, -anim)*1.4)*rcp(256.0)).x;

        hdr     = mix(hdr, (noise * 0.5 + 0.5) * hdr, exp(-50.0 * purkinje));

    return hdr;
}

vec3 rgbLuma(vec3 x) {
    return x * vec3(colorlumR, colorlumG, colorlumB);
}

vec3 applyGammaCurve(vec3 x) {
    return pow(x, vec3(gammaCurve));
}

vec3 vibranceSaturation(vec3 color) {
    float lum   = dot(color, lumacoeffAP1);
    float mn    = min(min(color.r, color.g), color.b);
    float mx    = max(max(color.r, color.g), color.b);
    float sat   = (1.0 - saturate(mx-mn)) * saturate(1.0-mx) * lum * 5.0;
    vec3 light  = vec3((mn + mx) / 2.0);

    color   = mix(color, mix(light, color, vibranceInt), saturate(sat));

    color   = mix(color, light, saturate(1.0-light) * (1.0-vibranceInt) / 2.0 * abs(vibranceInt));

    color   = mix(vec3(lum), color, saturationInt);

    return color;
}

vec3 brightnessContrast(vec3 color) {
    return (color - 0.5) * constrastInt + 0.5 + brightnessInt;
}

vec3 vignette(vec3 color) {
    float fade      = length(uv*2.0-1.0);
        fade        = linStep(abs(fade) * 0.5, vignetteStart, vignetteEnd);
        fade        = 1.0 - pow(fade, vignetteExponent) * vignetteIntensity;

    return color * fade;
}

const float gauss9w[9] = float[9] (
     0.0779, 0.12325, 0.0779,
    0.12325, 0.1954,  0.12225,
     0.0779, 0.12325, 0.0779
);

const vec2 gauss9o[9] = vec2[9] (
    vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(-1.0, 1.0),
    vec2(1.0, 0.0), vec2(0.0, 0.0), vec2(-1.0, 0.0),
    vec2(1.0, -1.0), vec2(0.0, -1.0), vec2(-1.0, -1.0)
);

float gauss9Rain(sampler2D tex) {
    float col        = 0.0;

    for (int i = 0; i<9; i++) {
        vec2 bcoord = uv + gauss9o[i]*pixelSize;
        col += texture(tex, bcoord * ResolutionScale).x*gauss9w[i];
    }
    return col;
}

#ifdef showFocusPlane

uniform float centerDepthSmooth;

float depthLinear(float depth) {
    return (2.0*near) / (far+near-depth * (far-near));
}

void getFocusPlane(inout vec3 color) {

    float centerDepth = texture(depthtex0, vec2(0.5 * ResolutionScale)).x;

    #if camFocus == 0 //   Auto
        float focus = centerDepth;
    #elif camFocus == 1 // Manual
        float focus = camManFocDis;
              focus = (far * ( focus - near)) / ( focus * (far - near));
    #elif camFocus == 2 // Manual+
        float focus = screenBrightness * camManFocDis;
              focus = (far * ( focus - near)) / ( focus * (far - near));
    #elif camFocus == 3 // Auto+
        float offset = screenBrightness * 2.0 - 1.0;
        float autoFocus = depthLinear(centerDepth) * far * 0.5;
        float focus = offset > 0.0 ? autoFocus + (offset * camManFocDis) : autoFocus * saturate(offset * 0.9 + 1.1);
              focus = (far * ( focus - near)) / ( focus * (far - near));
    #endif

    if (texture(depthtex0, uv * ResolutionScale).x > focus) color    = mix(color, vec3(0.7, 0.2, 1.0) * 0.8, 0.5);
}
#endif

#include "/lib/util/bicubic.glsl"

#define RExpFilter_Radius 2
#define RExpFilter_Exponent 0.05

flat in float AvgLuma;
flat in vec2 LumaRange;

float SampleExposureTilesSmooth(vec2 uv) {
    ivec2 tiles = ivec2(viewSize * pow4(0.25));
    ivec2 UV    = ivec2(uv * tiles - 0.5);

    vec2 FractUV    = fract(uv * tiles - 0.5);
    /*
    float Total = texelFetch(colortex3, UV, 0).a;
    float TotalWeight = 1.0;
    
    for (int x = -0; x <= RExpFilter_Radius; ++x) {
        for (int y = -0; y <= RExpFilter_Radius; ++y) {
            if (x == 0 && y == 0) continue;
            ivec2 Offset        = ivec2(x, y);
            ivec2 CurrentUV     = clamp(UV + Offset, ivec2(0), tiles-1);

            vec2 NewUV          = vec2(CurrentUV - 0.5 / tiles);

            float Weight        = exp(-distance(uv * tiles, NewUV));
                Weight          = saturate(length(FractUV));

            Total              += texelFetch(colortex3, CurrentUV, 0).a * Weight;
            TotalWeight        += Weight;
        }
    }
    */


    vec2 LumaLimits = vec2(AvgLuma * 0.25, AvgLuma * euler);

    float Range     = max(abs(LumaRange.x - LumaRange.y) / max(AvgLuma, 1e-8), 1e-8);

    float Total = textureBicubic(colortex3, uv * pow4(0.25) + vec2(0.1, 0.0)).a;
        //Total = clamp(Total, LumaLimits.x, LumaLimits.y);

    float TotalWeight = 1.0;
/*
    for (int x = -RExpFilter_Radius; x <= RExpFilter_Radius; ++x) {
        for (int y = -RExpFilter_Radius; y <= RExpFilter_Radius; ++y) {
            if (x == 0 && y == 0) continue;
            ivec2 Offset        = ivec2(x, y) / tiles;

            vec2 NewUV          = vec2(uv + Offset);

            float Weight        = exp(-(x*x + y*y) * 0.5);
                //Weight          = saturate(length(FractUV));

            Total              += clamp(textureBicubic(colortex3, NewUV * pow4(0.25) + vec2(0.1, 0.0)).a, LumaLimits.x, LumaLimits.y) * Weight;
            TotalWeight        += Weight;
        }
    }*/

    //return textureBicubic(colortex3, uv * sqr(0.25)).a;

    //return AvgLuma;
    //vec2 InverseWeights = Total > AvgLuma ? vec2(0.87, 0.73) : vec2(0.6, 0.4);
    vec2 InverseWeights = vec2(0.87, 0.73);
    return mix(Total, AvgLuma, mix(InverseWeights.x, InverseWeights.y, sqr(1.0 / (1.0 + abs(Total - AvgLuma) / Range))));
}

float CalculateExposure(vec2 uv) {
    #if DIM == -1
    const float exposureLowClamp    = 0.1 * exposureDarkClamp;
    const float exposureHighClamp   = 8.0 * exposureBrightClamp;
    #elif DIM == 1
    const float exposureLowClamp    = 0.1 * exposureDarkClamp;
    const float exposureHighClamp   = 20.0 * exposureBrightClamp;
    #else
    const float exposureLowClamp    = 0.08 * exposureDarkClamp;
    const float exposureHighClamp   = 40.0 * exposureBrightClamp;
    #endif

    float TiledLuminance = SampleExposureTilesSmooth(uv);

    const float K   = 14.0;
    const float cal = exp2(autoExposureBias) * K / 100.0;

    const float minExposure     = exp2(autoExposureBias) / exposureHighClamp;
    const float maxExposure     = exp2(autoExposureBias) / exposureLowClamp;

    const float a   = cal / minExposure;
    const float b   = a - cal / maxExposure;

    //float lum   = getExposureLuma();
    float lastExp       = clamp(texelFetch(colortex6, ivec2(uv * viewSize), 0).a, 0.0, 65535.0);

    float targetExp     = cal / (a - b * exp(-TiledLuminance / b));

    //return targetExp;

    float decaySpeed    = targetExp < lastExp ? 0.075 : 0.05;

    #ifdef LOCAL_EXPOSURE_DEMO
        return uv.x > 0.5 ? exposure : mix(lastExp, targetExp, saturate(decaySpeed * exposureDecay * (frameTime / 0.033)));
    #endif

    return mix(lastExp, targetExp, saturate(decaySpeed * exposureDecay * (frameTime / 0.033)));
}

vec3 RFilmEmulation(vec3 LinearCV) {	
    #if DIM == -1
    const vec3 RFilmToeSlope = vec3(1.08, 1.21, 1.29) * 1.56;
    const vec3 RFilmToeRolloff = vec3(1.6, 1.5, 1.35);
    const float ToeLength = 0.35;
    #else
	const vec3 RFilmToeSlope = vec3(1.28, 1.21, 1.19) * 1.04;
    const vec3 RFilmToeRolloff = vec3(2.0, 1.8, 1.5);
    const float ToeLength = 0.29;
    #endif

	const vec3 RFilmMidSlope = vec3(1.12, 1.11, 1.14);
	const vec3 RFilmMidGain = vec3(1.04, 1.0, 1.02) * 1.1;
	
	const vec3 RFilmWhiteRolloff = vec3(1.3, 1.7, 2.4);
	//float3 ShoulderSlope = float3(1.0f, 1.0f, 1.0f);
	const float MidPoint = 0.52;
	
	
	vec3 ToeColor = LinearCV * RFilmToeSlope;
	vec3 MidColor = (LinearCV - MidPoint) * RFilmMidSlope + MidPoint;
	
	vec3 ToeAlpha = 1.0 - saturate(LinearCV / ToeLength);
	ToeAlpha = pow(ToeAlpha, RFilmToeRolloff);
	
	vec3 FinalColor = mix(MidColor * RFilmMidGain, ToeColor, ToeAlpha);
	
	FinalColor *= 1.0 / (1.0 + max(FinalColor - MidPoint, 0.0) * RFilmWhiteRolloff * 0.04);
	
	return FinalColor;
}

void main() {
    vec3 sceneHDR   = stex(colortex0).rgb;

    #ifdef bloomEnabled
        vec2 cres       = max(viewSize, bloomResolution);

        float bloomInt = 0.13 / mix(max(exposure, 1.0), 1.0, 0.31);

        #if DIM == -1
            bloomInt  *= 1.3;
        #elif DIM == 1
            bloomInt  *= 1.5;
        #endif

            bloomInt   *= bloomIntensity;

        if (isEyeInWater == 1) bloomInt = mix(bloomInt, 1.0, 0.4);

        vec3 bloom  = textureLod(colortex3, uv/cres*bloomResolution*0.5, 0).rgb * 4.0;
        
        #ifdef bloomyFog
        #ifdef fogVolumeEnabled
        bloomInt    = mix(0.9, bloomInt, avgOf(textureLod(colortex14, uv * ResolutionScale, 0).xyz));
        #endif
        #endif

        sceneHDR    = mix(sceneHDR, bloom, saturate(bloomInt));

        if (rainStrength > 0.0) {
            float rint      = gauss9Rain(colortex15);
            bool rain       = rint > 0.0;

            if (rain) sceneHDR = mix(sceneHDR, bloom * 1.4, rint * 0.5);
        }
    #else
        if (rainStrength > 0.0) {
            float rint      = gauss9Rain(colortex15);
            bool rain       = rint > 0.0;

            if (rain) sceneHDR = mix(sceneHDR, sceneHDR * 1.4, rint * 0.5);
        }
    #endif

    #ifndef DIM
    #ifdef PURKINJE_EFFECT
        sceneHDR    = purkinje(sceneHDR);
    #endif
    #endif

    //vec2 skyUV  = uv * vec2(aspectRatio * 1.5, 1.0) * 2.0;
    //if (saturate(skyUV) == skyUV) sceneHDR = texture(colortex5, skyUV).aaa;

    //sceneHDR    = mix(sceneHDR, texelFetch(colortex3, ivec2(uv * viewSize * 0.25 * 0.25 * 0.25), 0).aaa, 0.5);
    
    #ifdef LOCAL_EXPOSURE
    float exposure = CalculateExposure(uv);
    #endif

    #ifdef manualExposureEnabled
        sceneHDR   *= rcp(manualExposureValue);
    #else
        sceneHDR   *= exposure * exposureBias;
    #endif

    #if DIM == -1
        sceneHDR  *= 0.66;
    #elif DIM == 1
        sceneHDR  *= 1.0;
    #endif

        //if (saturate(skyUV) == skyUV) sceneHDR = texture(colortex5, skyUV).aaa;

    #ifdef showFocusPlane
    if (hideGUI == 0) getFocusPlane(sceneHDR);
    #endif

    #ifdef doColorgrading
        sceneHDR    = vibranceSaturation(sceneHDR);
        sceneHDR    = rgbLuma(sceneHDR);
    #endif

    #ifdef vignetteEnabled
        sceneHDR    = vignette(sceneHDR);
    #endif

        sceneHDR    = RFilmEmulation(sceneHDR);

    vec3 sceneLDR   = tonemapOperator(sceneHDR);
    
    #if DEBUG_VIEW==5
        sceneLDR    = sqrt(sceneHDR);
    #endif

    #ifdef doColorgrading
        sceneLDR    = brightnessContrast(sceneLDR);
        sceneLDR    = applyGammaCurve(saturate(sceneLDR));
    #endif

    sceneImage      = saturate(sceneLDR);

    //sceneImage = vec3(texture(colortex3, uv / 4.0).a / 16.0);

    temporal        = stex(colortex6);
    temporal.a      = exposure;

    temporal        = clamp16F(temporal);
}