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

#ifdef cloudPass
    const float eyeAltitude = 800.0;
#else
    uniform float eyeAltitude;
#endif

uniform float rainStrength;
uniform float wetness, RW_BIOME_Sandstorm, RMoonPhaseOcclusion;

uniform vec3 sunDir;
uniform vec3 moonDir;

uniform vec4 daytime;

uniform sampler2D gaux2;

flat out mat4x3 lightColor;

#ifdef cloudPass
    #define airmassStepBias 0.25

    flat out mat4x3 CloudSunlightGradient;
    uniform int worldTime;
    uniform vec3 cloudLightDir;

    //flat out vec3 CloudNL_Sunlight;
    //flat out mat3 CloudNL_Gradient;

    #define NOANIM
    #include "/lib/atmos/clouds/constants.glsl"
#else
    #define airmassStepBias 0.35
#endif

#include "/lib/atmos/air/const.glsl"
#include "/lib/atmos/air/density.glsl"
#include "/lib/atmos/project.glsl"

void getColorPalette() {
    #ifdef cloudPass
        vec3 airEyePos = vec3(0.0, planetRad + 650.0, 0.0);

        vec4 altitudeSteps      = vec4(mix(vec3(cloudRaymarchMinY), vec3(cloudRaymarchMaxY), vec3(0.05, 0.5, 0.95)), 7000.0) + vec4(planetRad);

        vec3 IllumColor         = (worldTime>23000 || worldTime<12900) ? sunIllum : colorSaturation(moonIllum, 0.5) * sqrt2 * RMoonPhaseOcclusion;

        CloudSunlightGradient   = mat4x3(
            getAirTransmittance(vec3(0,altitudeSteps.x,0), cloudLightDir, 6) * IllumColor,
            getAirTransmittance(vec3(0,altitudeSteps.y,0), cloudLightDir, 6) * IllumColor,
            getAirTransmittance(vec3(0,altitudeSteps.z,0), cloudLightDir, 6) * IllumColor,
            getAirTransmittance(vec3(0,altitudeSteps.w,0), cloudLightDir, 4) * IllumColor
        );

        /*
        vec3 CloudNL_Dir    = normalizeSafe(vec3(sunDir.x, 0.0, sunDir.z));
            //CloudNL_Dir     = normalize(CloudNL_Dir + vec3(0,rpi,0));

        CloudNL_Sunlight = sunIllum * getAirTransmittance(CloudNL_Dir * CLOUD_NL_ALT * 2.0 + vec3(0,planetRad, 0), sunDir, 4);

        CloudNL_Gradient   = mat3(
            getAirTransmittance(vec3(0,planetRad + CLOUD_NL_ALT,0), sunDir, 4) * sunIllum,
            getAirTransmittance(vec3(0,planetRad + CLOUD_NL_ALT * 2.0,0), sunDir, 4) * sunIllum,
            getAirTransmittance(vec3(0,planetRad + CLOUD_NL_ALT * 2.0,0) + CloudNL_Dir * CLOUD_NL_ALT, sunDir, 4) * sunIllum
        );*/

    #else
        vec3 airEyePos = vec3(0.0, planetRad + eyeAltitude, 0.0);
    #endif

    lightColor[0]  = getAirTransmittance(airEyePos, sunDir, 6) * sunIllum;

    #if !(defined cloudPass || defined skyboxPass)
    //vec3 WeatherMult = mix(vec3(1.0 - wetness * 0.95), vec3(0.9, 0.95, 0.7), saturate(RW_BIOME_Sandstorm));
        lightColor[0] *= mix(vec3(1.0 - wetness * 0.95), vec3(0.82, 0.8, 0.6), saturate(RW_BIOME_Sandstorm));
    #endif
    
    #ifdef cloudPass
        lightColor[1]  = texture(gaux2, projectSky(vec3(0.0, 1.0, 0.0), 0)).rgb * pi * 0.25;
    #else
        lightColor[1]  = texture(gaux2, projectSky(vec3(0.0, 1.0, 0.0), 0)).rgb * pi * skylightIllum;
    #endif

    #ifdef desatRainSkylight
        lightColor[1]   = colorSaturation(lightColor[1], 1.0 - rainStrength * 0.8);
        lightColor[1] *= 1.0 - rainStrength * 0.4;
    #endif

    lightColor[1] *= vec3(skylightRedMult, skylightGreenMult, skylightBlueMult);

    #ifdef cloudPass
        lightColor[2]  = getAirTransmittance(airEyePos, moonDir, 6) * colorSaturation(moonIllum, 0.5) * sqrt2 * RMoonPhaseOcclusion;
    #else
        lightColor[2]  = getAirTransmittance(airEyePos, moonDir, 6) * moonIllum * RMoonPhaseOcclusion;
    #endif
        
    #ifndef skipBlocklight
        lightColor[3]  = blackbody(float(blocklightBaseTemp)) * blocklightIllum * blocklightBaseMult * 1.5;
    #endif
}