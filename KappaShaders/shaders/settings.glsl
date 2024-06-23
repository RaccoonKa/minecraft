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


/* ------ ATMOSPHERE ------ */
#define rainbowsEnabled
#define volumeWorldTimeAnim

    /* --- COEFFICIENTS --- */
    #define rayleighRedMult 1.00    //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define rayleighGreenMult 1.00  //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define rayleighBlueMult 1.00   //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

    #define mieRedMult 1.00         //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define mieGreenMult 1.00       //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define mieBlueMult 1.00        //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

    #define ozoneRedMult 1.00       //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define ozoneGreenMult 1.00     //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define ozoneBlueMult 1.00      //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

    #define mistRedMult 1.00        //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define mistGreenMult 1.00      //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define mistBlueMult 1.00       //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

    /* --- CLOUDS --- */
    #define CLOUD_RENDER_LOD 3.0    //[5.0 4.0 3.0 2.0 1.0]
    #define cloudTemporalUpscaleEnabled
    //#define cloudTemporalUpscaleMode 0  //[0 1 2]
    #define cloudReflectionsToggle
    //#define cloudShadowsEnabled

    #define RSKY_SB_CloudVolume
    #define RSKY_SB_CloudV_DirectDither
    #define RSKY_SB_CloudV_AmbientDither
    #define RSKY_SB_CloudV_HQMultiscatter
    #define cloudLocalCoverage

    #define RSKY_SB_CirrusCloud
    #define RSKY_SB_CirrocumulusCloud
    #define RSKY_SB_NoctilucentCloud


    #define RSKY_SB_CloudWeather
    #define RSKY_SF_WeatherHumidity 0.5     //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
    #define RSKY_SF_WeatherTemperature 0.5  //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
    #define RSKY_SF_WeatherTurbulence 0.5   //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
    #define RSKY_SF_WeatherCirrusBlend 0.5  //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

    /* --- FOG --- */
    #define fogVolumeEnabled
    //#define fogMistAdvanced
    #define fogDensityMult 1.0      //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
    #define mistMieAnisotropy 0.8   //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]
    #define fogSmoothingEnabled
    //#define fogSmoothingPassEnabled

    #define RFOG_SB_FogWeather

    /* --- SKY --- */
    #define airTransmittanceHQ
    //#define ATMOS_BelowHorizon
    #define ATMOS_RenderPlanet
    #define PLANET_BOUNCELIGHT

    /* --- WATER --- */
    #define waterVolumeEnabled
    #define waterDensity 1.0        //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

    /* --- DIMENSIONS --- */
    #define netherSmokeEnabled
    #define netherSmokeDensity 1.0  //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
    #define netherSmokeEmission
    #define netherSmokeEmissionMult 1.0      //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
    #define netherHazeDensity 1.0   //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

    #define endSmokeGlow
    #define endSmokeGlowDynamic
    #define endSmokeGlowStrength 1.0    //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]


/* ------ LIGHTING ------ */
//#define directionalLMEnabled
//#define UseLightleakPrevention

    /* --- COLORS --- */
    #define sunlightIllum 1.0       //[0.1 0.2 0.3 0.4 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0 3.5 4.0]
    #define sunlightRedMult 1.00    //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define sunlightGreenMult 1.00  //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define sunlightBlueMult 1.00   //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

    #define moonlightIllum 1.0      //[0.1 0.2 0.3 0.4 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0 3.5 4.0]
    #define moonlightRedMult 1.00   //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define moonlightGreenMult 1.00 //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define moonlightBlueMult 1.00  //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

    #define skylightIllum 1.0       //[0.1 0.2 0.3 0.4 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0 3.5 4.0]
    #define skylightRedMult 1.00    //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define skylightGreenMult 1.00  //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
    #define skylightBlueMult 1.00   //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

    #define blocklightIllum 1.0     //[0.1 0.2 0.3 0.4 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0 3.5 4.0]
    #define blocklightBaseTemp 3400 //[1000 1200 1400 1600 1800 2000 2200 2400 2600 2800 3000 3200 3400 3600 3800 4000 4200 4400 4600 4800 5000]
    #define minimumAmbientIllum 1.0 //[0.0 0.1 0.2 0.3 0.4 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0 3.5 4.0]

    /* --- DIRECT LIGHT --- */
    #define shadowVPSEnabled
    #define shadowPenumbraScale 1.0         //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6 2.8 3.0]
    #define contactShadowsEnabled
    #define shadowFilterIterations 15    //[6 9 12 15 18 21 24 27 30]
    #define subsurfaceScatteringEnabled
    #define subsurfaceScatterMode 2     //[0 1 2 3]

    /* --- INDIRECT LIGHT --- */
    #define indirectResReduction 2  //[4 3 2 1]
    #define ssptEnabled
    //#define ssptFullRangeRT
    #define ssptSPP 2               //[1 2 3 4 5 6]
    #define ssptBounces 1           //[1 2 3 4 5 6]
    #define ssptLightmapBlend 1.0   //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
    #define ssptEmissionDistance 8.0   //[2.0 4.0 6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0 22.0 24.0 26.0 28.0 30.0 32.0]
    #define ssptEmissionMode 0      //[0 1 2] 0-hardcoded only, 1-hardcoded+lab, 2-lab only
    #define ssptAdvancedEmission      //A bit slower but does provide hardcoded colors for some emitters, enable this to get a more similar color response to KappaPT
    #define labEmissionCurve 1.0    //[1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0]

    #define RINDIRECT_USE_SSAO
    //#define textureAoEnabled

    #define maxFrames 256.0     //[16.0 32.0 64.0 128.0 192.0 256.0 384.0 512.0 768.0 1024.0]
    #define minAccumMult 1.0    //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0] Accumulation Weight Mult
    #define ADAPT_STRENGTH 1.0  //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5] Adaptive Strength

    #define SVGF_FILTER
    #define SVGF_RAD 1              //[1 2 3] Filter Radius
    #define SVGF_STRICTNESS 1.0     //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0] Luminance Strictness
    #define SVGF_NORMALEXP 1.0      //[0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]


/* ------ TERRAIN ------ */
#define normalmapEnabled
#define normalmapFormat 0       //[0 1]
//#define vertexAttributeFix
#define wetnessMode 0           //[0 1 2]
#define puddleRippleSpeed 1.0   //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define windEffectsEnabled
#define windIntensity 1.0  //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define refractionEnabled

    /* ------ PARALLAX ------ */
    //#define pomEnabled
    #define pomSamples 32   //[8 16 32 64 128 256 512]
    #define pomShadowSamples 16     //[4 8 16 32 64]
    #define pomDepth 0.25   //[0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

    //#define slopeNormalCalculation
    //#define pomDepthEnabled
    #define slopeNormalStrength 0.024f

    /* ------ REFLECTIONS ------ */
    //#define resourcepackReflectionsEnabled
    #define specularHighlightsEnabled
    #define roughReflectionsEnabled
    #define roughReflectionSamples 4    //[2 3 4 5 6 7 8]

    #define screenspaceReflectionsEnabled
    //#define reflectionCaptureEnabled

    #define roughnessThreshold 0.7      //[0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
    #define skyOcclusionThreshold 0.9   //[0.5 0.6 0.7 0.8 0.9 1.0]


/* ------ CAMERA ------ */
#define anamorphStretch 1.00    //[0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50]

    /* --- BLOOM --- */
    #define bloomEnabled
    #define bloomIntensity 1.0      //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
    #define bloomyFog

    /* --- DEPTH OF FIELD --- */
    //#define DoFToggle
    #define DoFQuality 1    //[0 1 2]
    #define DoFChromaDispersion

    #define camFocus 0 // [0 1 2 3]
    #define camManFocDis 5 // [0.1 0.2 0.3 0.4 0.5 0.7 0.9 1 1.1 1.2 1.3 1.4 1.5 1.6 1.8 1.9 2 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3 4 5 6 7 8 9 10 12 14 16 24 32 40 48 56 64 72 80 88 96 104 112 120 128 136 144 152 160 168 176 184 192 200 208 216 224 232 240 248 256]
    //#define showFocusPlane

    /* --- EXPOSURE --- */
    #define LOCAL_EXPOSURE
    //#define LOCAL_EXPOSURE_DEMO
    #define exposureDecay 1.0           //[0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.5 3.0 4.0]
    #define autoExposureBias 0.0
    #define exposureBias 1.0            //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
    #define exposureDarkClamp 1.0       //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.5 4.0 5.0 6.0 8.0 10.0 15.0 20.0]
    #define exposureBrightClamp 1.0     //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.5 4.0 5.0 6.0]
    
    #define exposureComplexEnabled
    #define exposureBrightPercentage 0.6    //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]
    #define exposureDarkPercentage 0.5      //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]
    #define exposureBrightWeight 0.1        //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
    #define exposureDarkWeight 1.0          //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
    #define exposureAverageWeight 1.0       //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]

    //#define manualExposureEnabled
    #define manualExposureValue 14.0     //[0.1 0.3 0.5 1.0 1.5 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 12.0 14.0 16.0 18.0 20.0 25.0 30.0 40.0 50.0]
    

    /* --- LENS FLARE --- */
    //#define lensFlareToggle
    #define lensFlareBokehLod 2
    #define lensFlareThreshold 35   //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1 2 3 4 5 6 8 10 12 14 16 18 20 25 30 35 40 45 50 60 70 80 90]

    /* --- MOTIONBLUR --- */
    #define motionblurToggle
    #define motionblurSamples 8     //[4 6 8 10 12 14 16 18 20]
    #define motionblurScale 1.0     //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]


/* --- POST --- */
#define taaEnabled
#define imageSharpenEnabled
#define TAAU_FXAA_PostPass


/* --- MISC --- */
//#define freezeAtmosAnim
#define atmosAnimOffset 0     //[0 50 100 150 200 250 300 350 400 450 500 600 700 800 900 1000]