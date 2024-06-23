vec3 GetPlane(float Altitude, vec3 Direction) {
    return  Direction * ((Altitude - eyeAltitude) / Direction.y);
}
float estimateEnergy(float ratio) {
    return ratio / (1.0 - ratio);
}


/* ------ functions ------ */
#include "constants.glsl"

uniform vec3 volumeCloudData;

const float phaseConst  = 1.0 / (tau);

float mieCloud(float cosTheta, float g) {
    float sqrG  = sqr(g);
    float a     = (1.0 - sqrG) * rcp(2.0 + sqrG);
    float b     = (1.0 + sqr(cosTheta)) * rcp((-2.0 * (g * cosTheta)) + 1.0 + sqrG);

    return max((1.5 * (a * b)) + (g * cosTheta), 0.0) * phaseConst;
}

#define CLOUD_boostSilverLining

float KleinNishina(float cosTheta, float g) {
    if (abs(g) < 1e-1) g = sign(g) * 1e-1;
    float e = 1.0;
    for (int i = 0; i < 8; ++i) {
        float gFromE = 1.0 / e - 2.0 / log(2.0 * e + 1.0) + 1.0;
        float deriv = 4.0 / ((2.0 * e + 1.0) * sqr(log(2.0 * e + 1.0))) - 1.0 / sqr(e);
        if (abs(deriv) < 0.00000001) break;
        e = e - (gFromE - g) / deriv;
    }

    return e / (2.0 * pi * (e * (1.0 - cosTheta) + 1.0) * log(2.0 * e + 1.0));
}

float cloudPhaseJP21(float cosTheta, vec3 g, vec3 gMult, float lobeBlend) {
    float x = mieCS(cosTheta, gMult.x * g.x);
    float y = mieCS(cosTheta, -gMult.y * g.y) * volumeCloudData.z;
    #ifndef CLOUD_boostSilverLining
    float z = mieHG(cosTheta, gMult.z * g.z);
    #else
    float z = mieCS(cosTheta, gMult.z * g.z);
    #endif

    return mix(mix(x, z, 0.2), y * 2.16, 1-lobeBlend);

    return mix(mix(x, z, lobeBlend), y * sqrt2, 1-lobeBlend);    //i assume this is more energy conserving than summing them
}

#if 1
float cloudPhaseNew(float cosTheta, vec3 asymmetry) {
    float x = mieHG(cosTheta, asymmetry.x);
    float y = mieHG(cosTheta, -asymmetry.y) * volumeCloudData.z;
    float z = mieCS(cosTheta, asymmetry.z);

    return 0.7 * x + 0.2 * y + 0.1 * z + mieCS(cosTheta, pow(asymmetry.x, mix(0.1, 2e-3, sqr(saturate(asymmetry.z * 1.1))))) * 4e-2;
}
#else
float cloudPhaseNew(float cosTheta, vec3 asymmetry) {
    float x = KleinNishina(cosTheta, asymmetry.x);
    float y = mieHG(cosTheta, -asymmetry.y) * volumeCloudData.z;
    float z = KleinNishina(cosTheta, asymmetry.z);

    return 0.7 * x + 0.2 * y + 0.1 * z;
}
#endif
float cloudPhaseSky(float cosTheta, vec3 asymmetry) {
    float x = mieHG(cosTheta, asymmetry.x);
    float y = mieHG(cosTheta, -asymmetry.y) * volumeCloudData.z;

    return 0.75 * x + 0.25 * y;
}


float cloudPhase(float cosTheta, float g, vec3 gMult) {
    float x = mieCloud(cosTheta, gMult.x * g);
    float y = mieCloud(cosTheta, -gMult.y * g) * volumeCloudData.z;
    float z = mieHG(cosTheta, gMult.z * g) * sqrt2;

    return mix(mix(x, y, 0.25), z, 0.15) + 0.016 * g;    //i assume this is more energy conserving than summing them
}
float cloudSkyPhase(float cosTheta, float g, vec3 gMult) {
    float x = mieHG(cosTheta, gMult.x * g);
    float y = mieCloud(cosTheta, -gMult.y * g) * volumeCloudData.z;
    //float z = mieCloud(cosTheta, gMult.z * g);

    return mix(x, y, 0.19);    //i assume this is more energy conserving than summing them
}

vec3 curl3D(vec3 pos) {
    return texture(depthtex1, fract(pos)).xyz * 2.0 - 1.0;
}
float erosion3D(vec3 pos) {
    return texture(colortex2, fract(pos)).x;
}
float shape3D(vec3 pos) {
    return texture(colortex1, fract(pos)).x;
}

vec2 noise2DCubic(sampler2D tex, vec2 pos) {
        pos        *= 256.0;
    ivec2 location  = ivec2(floor(pos));

    vec2 samples[4]    = vec2[4](
        texelFetch(tex, location                 & 255, 0).xy, texelFetch(tex, (location + ivec2(1, 0)) & 255, 0).xy,
        texelFetch(tex, (location + ivec2(0, 1)) & 255, 0).xy, texelFetch(tex, (location + ivec2(1, 1)) & 255, 0).xy
    );

    vec2 weights    = cubeSmooth(fract(pos));


    return mix(
        mix(samples[0], samples[1], weights.x),
        mix(samples[2], samples[3], weights.x), weights.y
    );
}

vec2 noise2DCubic(vec2 pos) {
    return noise2DCubic(noisetex, pos);
}

float noisePerlinWorleyCubic(sampler2D tex, vec2 pos) {
        pos        *= 256.0;
    ivec2 location  = ivec2(floor(pos));

    float samples[4]    = float[4](
        texelFetch(tex, location                 & 255, 0).z, texelFetch(tex, (location + ivec2(1, 0)) & 255, 0).z,
        texelFetch(tex, (location + ivec2(0, 1)) & 255, 0).z, texelFetch(tex, (location + ivec2(1, 1)) & 255, 0).z
    );

    vec2 weights    = cubeSmooth(fract(pos));


    return mix(
        mix(samples[0], samples[1], weights.x),
        mix(samples[2], samples[3], weights.x), weights.y
    );
}

uniform sampler2D colortex14;

vec4 ReadWeathermap(vec2 Position) {
    Position   /= CLOUDMAP0_DISTANCE;
    Position    = Position * 0.5 + 0.5;
    Position    = saturate(Position);
    Position   *= vec2(WEATHERMAP_RESOLUTION) / viewSize;

    return texture(colortex14, Position);
}

vec4 GetCloudErosion_Layer0(float elevation) {
    float erodeLow  = 1.0 - sstep(elevation, 0.0, 0.22);
    float erodeHigh = sstep(elevation, 0.19, 1.0);
    float fadeLow   = sstep(elevation, 0.0, 0.2);
    float fadeHigh  = 1.0 - sstep(elevation, 0.6, 1.0);

    return vec4(erodeLow * 0.26, erodeHigh * 0.65, fadeLow, fadeHigh);
}
vec4 GetCloudErosion_Layer1(float elevation) {
    float erodeLow  = 1.0 - sstep(elevation, 0.0, 0.32);
    float erodeHigh = sstep(elevation, 0.29, 1.0);
    float fadeLow   = sstep(elevation, 0.0, 0.3);
    float fadeHigh  = 1.0 - sstep(elevation, 0.6, 1.0);

    return vec4(erodeLow * 0.22, erodeHigh * 0.6, fadeLow, fadeHigh);
}

vec4 GetCloudErosion_Anvil(float elevation) {
    float erodeLow  = 1.0 - sstep(elevation, 0.0, 0.13);
    float erodeHigh = sstep(elevation, 0.85, 1.0);
    float fadeLow   = sstep(elevation, 0.0, 0.1);
    float fadeHigh  = 1.0 - sstep(elevation, 0.94, 1.0);

    float AnvilErosion = abs(elevation - 0.6) / (elevation > 0.6 ? 0.4 : 0.6);

    float erodeMid  = 1.0 - linStep(AnvilErosion, 0.0, elevation > 0.6 ? 0.97 : 0.8);
        if (elevation < 0.6) erodeMid = 1.0 - sqr(1.0 - erodeMid);
        else erodeMid = 1.0 - cube(1.0 - erodeMid);

    return vec4(erodeLow * 0.26, erodeHigh * 0.66 + (erodeMid) * 0.7, fadeLow, fadeHigh);
}

vec4 GetCloudErosion_Cauliflower(float elevation) {
    float erodeLow  = 1.0 - sstep(elevation, 0.0, 0.1);
    float erodeHigh = mix(sstep(elevation, 0.2, 1.0), sstep(elevation, 0.7, 1.0), 0.5);
    float fadeLow   = sstep(elevation, 0.0, 0.04);
    float fadeHigh  = 1.0 - sstep(elevation, 0.6, 1.0);

    float erodeMid  = sstep(elevation, 0.07, 0.25);

    return vec4(erodeLow * 0.18, (erodeHigh) * 0.85 + sqrt(erodeMid) * 0.35, fadeLow, fadeHigh);
}

uniform vec2 CloudVolume1Data;

vec2 GetLayerParams(float Elevation, vec2 TypeParameters) {
    //return vec2(0.83, 20.0);
    //float AltocumulusAlpha  = sstep(Elevation, cloudCumulusMaxY, CloudAltocumulusElevation);

    return mix(mix(vec2(0.83, 20.0), vec2(0.80, 33.0), TypeParameters.x), vec2(0.85, 12.0), TypeParameters.y);
}

#define WindDir vec3(1.0, 0.3, 0.4)

float CubeSmoothWithAlpha(float Value, float Alpha) {
    return mix(Value, cubeSmooth(Value), Alpha);
}

#ifdef RSKY_SB_CloudWeather
uniform vec3 RWeatherParams;
#else
const vec3 RWeatherParams = vec3(RSKY_SF_WeatherHumidity, RSKY_SF_WeatherTemperature, RSKY_SF_WeatherTurbulence);
#endif

float cloudCumulusShape(vec3 pos, out vec2 TypeParameters) {
    float altitude  = pos.y;

    vec3 wind       = vec3(cloudTime, 0.0, cloudTime * 0.4);

    vec2 WeathermapUV = pos.xz - cameraPosition.xz;

        pos         = (pos * cloudCumulusScale) + wind;

    vec4 Weathermap = ReadWeathermap(WeathermapUV);

    TypeParameters = vec2(0);

    float altRemapped = saturate((altitude - cloudCumulusAlt) * rcp(cloudCumulusDepth));
    
    float AnvilElevation    = saturate((altitude - cloudCumulusAlt) * rcp(AnvilDepth));

    float AltocumulusAlpha  = sstep(altitude, cloudCumulusMaxY, CloudAltocumulusElevation);

    if (altitude < cloudCumulusMaxY) {
        float Alpha = mix(CurveByCenter(RWeatherParams.z), cubeSmooth(Weathermap.x), saturate(abs(RWeatherParams.z * 2.0 - 1.0)));
        vec2 Params = mix(vec2(1,0), vec2(1.4, 0.3), saturate(Alpha));
        altRemapped = altRemapped * Params.x - Params.y;
    }
    if (altitude > cloudCumulusMaxY) altRemapped = saturate((altitude - CloudAltocumulusElevation) * rcp(CloudAltocumulusDepth));

    vec4 CoverageErosion    = mix(GetCloudErosion_Layer0(altRemapped), GetCloudErosion_Layer1(altRemapped), sqrt(AltocumulusAlpha));

    float CauliflowerAlpha = Weathermap.w;
    CoverageErosion = mix(CoverageErosion, GetCloudErosion_Cauliflower(AnvilElevation), sqrt(sstep(CauliflowerAlpha, 0.0, 0.5)));

    CoverageErosion = mix(CoverageErosion, GetCloudErosion_Anvil(AnvilElevation), Weathermap.z);

    AltocumulusAlpha *= 1.0 - max(Weathermap.z, sstep(CauliflowerAlpha, 0.15, 0.25));
    altRemapped = mix(altRemapped, saturate(AnvilElevation * 2.2), (sstep(CauliflowerAlpha, 0.0, 0.25)));

    altRemapped     = mix(altRemapped, saturate((altitude - cloudCumulusAlt) * rcp(cloudCumulusDepth)), Weathermap.z);

    float localCoverage = mix(0.47, 0.66, Weathermap.x);
        localCoverage   = mix(localCoverage,  mix(0.35, 0.7, Weathermap.y), AltocumulusAlpha);
        localCoverage   = mix(localCoverage, 0.1, sqrt(CauliflowerAlpha));
        localCoverage  *= mix(1.0, 1.2, sstep((1-RWeatherParams.x) + RWeatherParams.y, 1.2, 1.8));
        localCoverage   = mix(localCoverage, mix(0.3, 0.65 * (1.0 - sqr(AnvilElevation) * 0.7), Weathermap.z), Weathermap.z);

    float DynamicBias     = mix(-0.1 * wetness, 0.1, sqrt(Weathermap.z));

    float coverageBias = localCoverage + cloudCumulusCoverageBias + DynamicBias - (Weathermap.z * 0.2 * (AnvilElevation));

    float coverage  = noise2D(pos.xz * (0.24)).z;
        coverage    = mix(coverage, noise2D(pos.xz * 0.11 + coverage * 0.05).x, AltocumulusAlpha * 0.3);
        coverage    = mix(coverage, sqrt(Weathermap.z), (Weathermap.z) * (0.8 + AnvilElevation * 0.2));
        coverage    = max0(coverage - coverageBias) * rcp(1.0 - saturate(coverageBias) * 0.999);

        coverage    = (coverage * CoverageErosion.z * CoverageErosion.w) - CoverageErosion.x - CoverageErosion.y;

        coverage    = saturate(coverage * 1.05);

    if (coverage <= 1e-8) return 0.0;

    float wf1       = sstep(altRemapped, 0.0, 0.33);
    float wfade     = 1.0 - wf1 * mix(0.93, 0.45, AltocumulusAlpha) * mix(1.0, 0.9, CauliflowerAlpha);

    float dfade     = 0.001 + sstep(altRemapped, 0.0, 0.2) * 0.1;
        dfade      += sstep(altRemapped, 0.1, 0.45) * 0.4;
        dfade      += sstep(altRemapped, 0.2, 0.60) * 0.8;
        dfade      += sstep(altRemapped, 0.3, 0.85) * 0.9;
        dfade      /= 0.001 + 0.1 + 0.4 + 0.8 + 0.9;

        dfade      *= mix(1.0, 0.7, AltocumulusAlpha);
        dfade      *= mix(1.0, sqrt(1.0 - cubeSmooth(AnvilElevation)), (Weathermap.z));

    float shape     = coverage;

    float hardness  = sqrt(sstep(altRemapped, 0.26, 0.64));
        hardness    = mix(hardness, 0.0, AltocumulusAlpha);

    float detailScale = max0(1.0 + AltocumulusAlpha * 0.25 - CauliflowerAlpha * 0.85);

    vec3 curl       = curl3D(pos * tau) * (2.0 - AltocumulusAlpha * 1.5 - CauliflowerAlpha * 0.5);
        pos        += wind * 0.3;

    vec3 posCurl    = pos + (curl * 0.15 * (wfade));

        shape      -= (1.0 - shape3D(pos * 3.0 + shape * WindDir * 0.2 * CauliflowerAlpha)) * mix(0.66, 0.45, CauliflowerAlpha);

        posCurl    += shape * WindDir * 0.1;

    if (shape <= 0.0) return 0.0;

        shape      -= (1.0 - erosion3D(posCurl * 20.0)) * 0.17 * detailScale * (1.0 - wf1 * 0.21);

        shape      -= (1.0 - erosion3D((pos + curl * 0.05) * 6.0)) * 0.1 * sqr(1.0 - hardness) * detailScale;

        shape       = saturate(shape);
        #if 1
        shape       = saturate(1.0 - 2.0 * shape);
        shape       = 1.0 - pow(shape, 3.0 - AltocumulusAlpha*2);
        #else
        shape       = 1.0 - pow(1.0 - shape, 3.0 + hardness * 5.0);
        #endif

    float DensityMult   = mix(volumeCloudData.y, CloudVolume1Data.y, AltocumulusAlpha);
        DensityMult     = mix(DensityMult, 1.0, sqrt(Weathermap.z));

    TypeParameters = vec2(AltocumulusAlpha, max(CauliflowerAlpha, Weathermap.z));

    return max(shape * dfade * DensityMult, 0.0);
}
float cloudCumulusShape(vec3 pos) {
    vec2 t = vec2(0);
    return cloudCumulusShape(pos, t);
}

float cloudVolumeLightOD(vec3 pos, const uint steps) {
    float basestep = 22.2;
    float exponent = 2.0;

    float stepsize  = basestep;
    float prevStep  = stepsize;

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        if(pos.y > cloudCumulusMaxY || pos.y < cloudRaymarchMinY) continue;

            prevStep  = stepsize;
            stepsize *= exponent;
        
        float density = cloudCumulusShape(pos);
        if (density <= 0.0) continue;

            od += density * prevStep;
    }

    return od;
}
float cloudVolumeSkyOD(vec3 pos, const uint steps) {
    const vec3 dir = vec3(0.0, 1.0, 0.0);

    float stepsize = (cloudCumulusDepth / float(steps));
        stepsize  *= 1.0-linStep(pos.y, cloudRaymarchMinY, cloudCumulusMaxY) * 0.9;

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > cloudCumulusMaxY || pos.y < cloudRaymarchMinY) continue;
        
        float density = cloudCumulusShape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}

float cloudVolumeLightOD(vec3 pos, const uint steps, float noise) {
    float basestep = 22.2;
    float exponent = 2.0;

    float stepsize  = basestep;
    float prevStep  = stepsize;

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        pos += cloudLightDir * noise * (stepsize - prevStep);

        if(pos.y > cloudRaymarchMaxY || pos.y < cloudRaymarchMinY) continue;

            prevStep  = stepsize;
            stepsize *= exponent;
        
        float density = cloudCumulusShape(pos);
        if (density <= 0.0) continue;

            od += density * prevStep;
    }

    return od;
}
float cloudVolumeSkyOD(vec3 pos, const uint steps, float noise) {
    const vec3 dir = vec3(0.0, 1.0, 0.0);

    float stepsize = (cloudCumulusDepth / float(steps));
        stepsize  *= 1.0-linStep(pos.y, cloudRaymarchMinY, cloudRaymarchMaxY) * 0.9;

        pos += dir * stepsize * noise;

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > cloudRaymarchMaxY || pos.y < cloudRaymarchMinY) continue;
        
        float density = cloudCumulusShape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}


/* ------ cirrus clouds ------ */

uniform vec2 volumeCirrusData;

#ifdef RSKY_SB_CloudWeather
uniform vec2 RW_CirrusData;
#else
const vec2 RW_CirrusData = vec2(RSKY_SF_WeatherCirrusBlend, 1.0 - RSKY_SF_WeatherCirrusBlend) * clamp(0.5 + (RSKY_SF_WeatherHumidity - 0.5) * 1.6 + (RSKY_SF_WeatherTemperature - 0.5), 0.0, 1.0);
#endif

float Cloud_Planar0_Shape(vec3 pos) {   // Cirrus/Cirrostratus
    float altitude  = pos.y;
    float altRemapped = saturate((altitude - CLOUD_PLANE0_BOUNDS.x) / CLOUD_PLANE0_DEPTH);

    float erodeLow  = 1.0 - sstep(altRemapped, 0.0, 0.35);
    float erodeHigh = sstep(altRemapped, 0.42, 1.0);
    float fadeLow   = sstep(altRemapped, 0.0, 0.2);
    float fadeHigh  = 1.0 - sstep(altRemapped, 0.6, 1.0);

    vec3 wind       = vec3(cloudTime, 0.0, -cloudTime * 0.2) * 0.5;

    pos.xz         /= 1.0 + distance(cameraPosition.xz, pos.xz) * 0.000005;

        pos         = (pos * 4e-5) + wind;

    vec3 curl = curl3D(pos * 0.3 * vec3(0.7, 1.0, 1.0)) * 0.5 + 0.5;

    float curlLength = length(curl) / length(vec3(1));

    curl = cubeSmooth(curl);

    float coverageBias = 0.52 + CLOUD_PLANE0_COVERAGE - RW_CirrusData.y * 0.3;

        pos += curl * vec3(1.1, 0.2, 0.3) * 1.0;

    float coverage  = (sqr(saturate(curlLength)));
        coverage   += (noise2D(pos.xz * 0.05 + vec2(0.36, 0.48)).z) * 0.3;

        coverage   /= 1.3;

        coverage    = (coverage - coverageBias) * rcp(1.0 - saturate(coverageBias) * 0.999);

        coverage    = (coverage * fadeLow * fadeHigh) - erodeLow * 0.3 - erodeHigh * 0.6;

        coverage    = saturate(coverage * 1.05);

    if (coverage <= 1e-8) return 0.0;

    float shape     = coverage;
    float slope     = sqrt(saturate(shape));

    //if (slope <= 1e-12) return 0.0;

        pos.xz += shape * 0.1;
        pos.y  -= sqr(shape) * cloudCirrusScale * 250.0;

        shape  -= value3D(pos * 32.0 + curl * 2) * 0.1 * slope;

        //pos.xz     += shape * 0.1;

        //slope     = sqrt(1.0 - saturate(shape));

        shape  -= value3D((pos * 64.0 + wind + curl * 32)) * 0.075;

    if (shape <= 0.0) return 0.0;

        slope   = (1.0 - saturate(shape));

        pos.xz -= shape * 0.1;

        shape  -= value2D((pos * 288.0 + wind + curl * 64).xz) * 0.035;

        shape   = max0(shape);
        //shape   = (shape) * (shape);
        shape   = (sqr(shape) * sqrt(curlLength));

    return max(shape * volumeCirrusData.y, 0.0);
}


float Cloud_Planar0_Light(vec3 pos, const uint steps, vec3 dir) {
    float stepsize = (CLOUD_PLANE0_DEPTH / float(steps));
        stepsize  *= 1.0 - linStep(pos.y, CLOUD_PLANE0_BOUNDS.x, CLOUD_PLANE0_BOUNDS.y) * 0.9;

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > CLOUD_PLANE0_BOUNDS.y || pos.y < CLOUD_PLANE0_BOUNDS.x) continue;
        
        float density = Cloud_Planar0_Shape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float Cloud_Planar0_Light(vec3 pos, const uint steps, float noise) {
    float stepsize = (CLOUD_PLANE0_DEPTH / float(steps));

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        if(pos.y > CLOUD_PLANE0_BOUNDS.y || pos.y < CLOUD_PLANE0_BOUNDS.x) continue;
        
        float density = Cloud_Planar0_Shape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float Cloud_Planar0_Light(vec3 pos, const uint steps, vec3 dir, float noise) {
    float stepsize = (CLOUD_PLANE0_DEPTH / float(steps));
        stepsize  *= 1.0 - linStep(pos.y, CLOUD_PLANE0_BOUNDS.x, CLOUD_PLANE0_BOUNDS.y) * 0.9;

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > CLOUD_PLANE0_BOUNDS.y || pos.y < CLOUD_PLANE0_BOUNDS.x) continue;
        
        float density = Cloud_Planar0_Shape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}

vec4 Cloud1Dynamics = vec4(0,1,0,0);

vec3 noise2DCubic3(sampler2D tex, vec2 pos) {
        pos        *= 256.0;
    ivec2 location  = ivec2(floor(pos));

    vec3 samples[4]    = vec3[4](
        texelFetch(tex, location                 & 255, 0).xyz, texelFetch(tex, (location + ivec2(1, 0)) & 255, 0).xyz,
        texelFetch(tex, (location + ivec2(0, 1)) & 255, 0).xyz, texelFetch(tex, (location + ivec2(1, 1)) & 255, 0).xyz
    );

    vec2 weights    = cubeSmooth(fract(pos));


    return mix(
        mix(samples[0], samples[1], weights.x),
        mix(samples[2], samples[3], weights.x), weights.y
    );
}

float Cloud_Planar1_Shape(vec3 pos) {   // Cirrocumulus
    float altitude      = pos.y;
    float altRemapped = saturate((altitude - CLOUD_PLANE1_BOUNDS.x) / CLOUD_PLANE1_DEPTH);

    float erodeLow  = 1.0 - sstep(altRemapped, 0.0, 0.35);
    float erodeHigh = sstep(altRemapped, 0.42, 1.0);
    float fadeLow   = sstep(altRemapped, 0.0, 0.19);
    float fadeHigh  = 1.0 - sstep(altRemapped, 0.6, 1.0);

    vec3 wind       = vec3(cloudTime, 0.0, cloudTime*0.4);

    pos.xz         /= 1.0 + distance(cameraPosition.xz, pos.xz) * 0.00002;
    pos            *= 0.0004;
    pos            += wind * 7;

    vec3 sample0    = noise2DCubic3(noisetex, pos.xz * 0.013 + vec2(0.31, -0.19)).xyz;
    vec3 curl   = curl3D(pos * 0.1);

    pos.xz         += sample0.xy * 0.2;

    float CoverageBias = saturate(0.18 + CLOUD_PLANE1_COVERAGE - RW_CirrusData.x * 0.2);

    pos        += curl * 0.2;

    float coverage  = noise2D(pos.xz*0.4 + vec2(-0.15, 0.58) * vec2(1.0, 0.6)).b;
        coverage   += noise2D(pos.xz*0.1 * vec2(1.0, 0.4) + vec2(0.35, -0.45)).b * 0.5;

        coverage   /= 1.0 + 0.5;

        coverage   *= sstep(sample0.z, 0.3, 0.68);

        coverage    = (coverage - CoverageBias) * rcp(1.0 - saturate(CoverageBias) * 0.9999);

        coverage    = (coverage * fadeLow * fadeHigh) - erodeLow * 0.26 - erodeHigh * 0.6;

        //coverage    = saturate(coverage * 1.0);
        
    if (coverage <= 0.0) return 0.0;

    float dfade     = 0.001 + sstep(altRemapped, 0.0, 0.2) * 0.1;
        dfade      += sstep(altRemapped, 0.1, 0.45) * 0.4;
        dfade      += sstep(altRemapped, 0.2, 0.60) * 0.8;
        dfade      += sstep(altRemapped, 0.3, 0.85) * 0.9;
        dfade      /= 0.001 + 0.1 + 0.4 + 0.8 + 0.9;

    float shape     = coverage;

        pos.x      += shape * 0.1;

    float n1        = (1-shape3D(pos * 3.0)) * 0.13;
        shape      -= n1;   //pos -= n1 * 1.0;

        shape      -= (1-erosion3D(pos * 12.0 + curl * 3)) * 0.074;

    if (shape <= 0.0) return 0.0;

        //shape  -= value3D((pos * 128.0 + wind + curl * 32)) * 0.05;

        shape    = max0(shape);
        //shape    = cubeSmooth((shape));

        shape     = sqr(shape);
        //shape   = 1.0 - pow(1.0 - saturate(shape), 1.0 + altRemapped * 3.0);
        shape   = cubeSmooth(shape);

        //shape *= dfade * 0.7 + 1.0;

    return max(shape * Cloud1Dynamics.y, 0.0);
}

float Cloud_Planar1_Light(vec3 pos, const uint steps, float noise) {
    float stepsize = (CLOUD_PLANE1_DEPTH / float(steps));

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        if(pos.y > CLOUD_PLANE1_BOUNDS.y || pos.y < CLOUD_PLANE1_BOUNDS.x) continue;
        
        float density = Cloud_Planar1_Shape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float Cloud_Planar1_Light(vec3 pos, const uint steps, vec3 dir, float noise) {
    float stepsize = (CLOUD_PLANE1_DEPTH / float(steps));
        stepsize  *= 1.0 - linStep(pos.y, CLOUD_PLANE1_BOUNDS.x, CLOUD_PLANE1_BOUNDS.y) * 0.9;

    float od = 0.0;

    pos += cloudLightDir * noise * stepsize;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > CLOUD_PLANE1_BOUNDS.y || pos.y < CLOUD_PLANE1_BOUNDS.x) continue;
        
        float density = Cloud_Planar1_Shape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float Cloud_Planar1_Light(vec3 pos, const uint steps) {
    float stepsize = (CLOUD_PLANE1_DEPTH / float(steps));

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += cloudLightDir * stepsize) {

        if(pos.y > CLOUD_PLANE1_BOUNDS.y || pos.y < CLOUD_PLANE1_BOUNDS.x) continue;
        
        float density = Cloud_Planar1_Shape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}
float Cloud_Planar1_Light(vec3 pos, const uint steps, vec3 dir) {
    float stepsize = (CLOUD_PLANE1_DEPTH / float(steps));
        stepsize  *= 1.0 - linStep(pos.y, CLOUD_PLANE1_BOUNDS.x, CLOUD_PLANE1_BOUNDS.y) * 0.9;

    float od = 0.0;

    for(uint i = 0; i < steps; ++i, pos += dir * stepsize) {

        if(pos.y > CLOUD_PLANE1_BOUNDS.y || pos.y < CLOUD_PLANE1_BOUNDS.x) continue;
        
        float density = Cloud_Planar1_Shape(pos);
        if (density <= 0.0) continue;

            od += density * stepsize;
    }

    return od;
}

float Cloud_NL_Shape(vec3 pos) {
    float altitude  = pos.y;
    float altRemapped = saturate((altitude - CLOUD_NL_BOUNDS.x) / CLOUD_NL_DEPTH);

    float erodeLow  = 1.0 - sstep(altRemapped, 0.0, 0.35);
    float erodeHigh = sstep(altRemapped, 0.42, 1.0);
    float fadeLow   = sstep(altRemapped, 0.0, 0.2);
    float fadeHigh  = 1.0 - sstep(altRemapped, 0.6, 1.0);

    vec3 wind       = vec3(cloudTime * 0.4, cloudTime * 0.05, cloudTime * 0.7) * 0.6;

    pos.xz         /= 1.0 + distance(cameraPosition.xz, pos.xz) * 0.000002;

        pos         = (pos * 5e-6) + wind;

    vec3 curl = curl3D(pos * 0.3 * vec3(0.7, 1.0, 1.0));

    float curlLength = length(curl) / length(vec3(1));

    float coverageBias = 0.05 + RWeatherParams.y * 0.35;

        pos += curl * 0.65 + wind * 9;

    float coverage  = (1.0 - curlLength * 0.7);

        coverage   *= cube(1-abs(noise2D(pos.xz * 0.06).z * 2.0 - 1.0)) * 0.7 + 0.3;
        coverage   *= cube(1-abs(noise2D(pos.xz * 0.2).z * 2.0 - 1.0)) * 0.5 + 0.5;
        coverage   *= sqr(1-abs(noise2D(pos.xz * 0.8).z * 2.0 - 1.0)) * 0.25 + 0.75;

        coverage    = (coverage - coverageBias) * rcp(1.0 - saturate(coverageBias) * 0.999);

        coverage    = (coverage * fadeLow * fadeHigh) - erodeLow * 0.3 - erodeHigh * 0.6;

        coverage    = saturate(coverage * 1.05);

    if (coverage <= 1e-8) return 0.0;

    float shape     = coverage;

        shape   = max0(shape);
        shape   = sqr(shape);
        shape   = cubeSmooth(shape);

    return max(shape, 0.0);
}