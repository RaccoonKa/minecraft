#if MODE == 0
// Vertex Shader

#include "/lib/head.glsl"

out vec2 uv;

uniform vec2 viewSize;

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    uv = gl_MultiTexCoord0.xy;
    uv *= viewSize / vec2(WEATHERMAP_RESOLUTION);
}

#else
// Fragment Shader

/* RENDERTARGETS: 14 */
layout(location = 0) out vec4 WeathermapOut;

#include "/lib/head.glsl"

uniform sampler2D noisetex;

in vec2 uv;

uniform float worldAnimTime, wetness, RW_BIOME_Sandstorm, RW_BIOME_Dryness;
uniform vec2 viewSize;
uniform vec3 cameraPosition;

#ifdef RSKY_SB_CloudWeather
uniform vec3 RWeatherParams;
#else
const vec3 RWeatherParams = vec3(RSKY_SF_WeatherHumidity, RSKY_SF_WeatherTemperature, RSKY_SF_WeatherTurbulence);
#endif

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

#include "/lib/atmos/clouds/constants.glsl"

float GetCloudmap_Layer0(vec2 Position) {
    Position   *= CLOUDMAP0_DISTANCE;
    Position   += cameraPosition.xz;

    vec2 wind   = vec2(cloudTime, cloudTime * 0.4);

    Position    = (Position * cloudCumulusScale) + wind;

    float LocalCoverage = noisePerlinWorleyCubic(noisetex, Position * 0.046 + wind * 0.03 + vec2(0.13, 0.34));
        LocalCoverage   = linStep(LocalCoverage - wetness * 0.15, 0.35, 0.66);

    float WeatherDrive  = OneMinus(sqr(RWeatherParams.x * RWeatherParams.y));

    return sqr(LocalCoverage) * WeatherDrive;
}
float GetCloudmap_Layer1(vec2 Position, float LowerLayer) {
    Position   *= CLOUDMAP0_DISTANCE;
    Position   += cameraPosition.xz;

    vec2 wind   = vec2(cloudTime, cloudTime * 0.45);

    Position    = (Position * cloudCumulusScale / 10) + wind;

    LowerLayer *= 1.0 - max0(RWeatherParams.z - 0.5 + (1.0 - RWeatherParams.y) * 0.5);

    float LocalCoverage = noisePerlinWorleyCubic(noisetex, Position * 0.035 + wind * 0.02 + vec2(-.03, 0.09));
        LocalCoverage   = mix(LocalCoverage, noisePerlinWorleyCubic(noisetex, Position * 0.06 + wind * 0.01 + vec2(0.33, 0.84)), 0.4);
        LocalCoverage   = linStep(LocalCoverage + (0.5 - LowerLayer) * 0.1 - wetness * 0.1, 0.35, 0.65);

    float WeatherDrive  = OneMinus(sqr(RWeatherParams.x * (1.0 - RWeatherParams.y)));

    return LocalCoverage * WeatherDrive;
}
float GetCloudmap_Anvil(vec2 Position) {
    Position   *= CLOUDMAP0_DISTANCE;
    float distanceFactor    = 1.0 - sstep(length(Position), 1e3, 6e3);
    Position   += cameraPosition.xz;

    vec2 wind   = vec2(cloudTime, cloudTime * 0.45);

    Position    = (Position * cloudCumulusScale) + wind;

    float LocalCoverage = noisePerlinWorleyCubic(noisetex, Position * 0.035 + wind * 0.05 + vec2(0.71, 0.34)).x;
        LocalCoverage   = mix(LocalCoverage, noisePerlinWorleyCubic(noisetex, Position * 0.1 + wind * 0.002 + vec2(0.17, 0.64)), 0.35);
        LocalCoverage   = linStep((LocalCoverage - distanceFactor * 0.1), 0.3, 0.6) * wetness * OneMinus(RW_BIOME_Sandstorm);
        //LocalCoverage  *= sstep(noise2DCubic(noisetex, Position * 0.00 + wind * 0.03 + vec2(0.03, 0.51)).x, 0.3, 0.5);

    return LocalCoverage;
}
float GetCloudmap_Cauliflower(vec2 Position) {
    Position   *= CLOUDMAP0_DISTANCE;
    float distanceFactor    = 1.0 - sstep(length(Position), 5e2, 2e4 * (1.0 - wetness * 0.5));
    Position   += cameraPosition.xz;

    vec2 wind   = vec2(cloudTime, cloudTime * 0.45);

    Position    = (Position * cloudCumulusScale) + wind;

    float LocalCoverage = noisePerlinWorleyCubic(noisetex, Position * 0.05 + wind * 0.07 + vec2(0.71, 0.34)).x;
        LocalCoverage  *= mix(1.0, noisePerlinWorleyCubic(noisetex, Position * 0.01 + wind * 0.005 + vec2(0.17, 0.64)), 0.8);
        LocalCoverage   = linStep((sqrt(LocalCoverage) - sqr(distanceFactor) * 0.1) + wetness * 0.15, 0.58, 0.63);
        //LocalCoverage  *= sstep(noise2DCubic(noisetex, Position * 0.00 + wind * 0.03 + vec2(0.03, 0.51)).x, 0.3, 0.5);
        //LocalCoverage  *= saturate(RWeatherParams.z * -2.0 + 1.0);

    return cubeSmooth(sqrt(LocalCoverage)) * cubeSmooth(saturate(RWeatherParams.z * -2.0 + 1.0));
}

/*
vec4 ReadWeathermap(vec2 Position) {
    Position   /= CLOUDMAP0_DISTANCE;
    Position    = Position * 0.5 + 0.5;
    Position    = saturate(Position);
    Position   *= WEATHERMAP_RESOLUTION / viewSize;

    return texture(colortex14, Position);
}*/

void main() {
    WeathermapOut   = vec4(0);
    if (saturate(uv) == uv) {
        vec2 Position   = uv * 2.0 - 1.0;

        WeathermapOut.x = GetCloudmap_Layer0(Position);
        WeathermapOut.y = GetCloudmap_Layer1(Position, WeathermapOut.x);

        //WeathermapOut.z = max0((1.0 - WeathermapOut.x) - (WeathermapOut.y));
        //WeathermapOut.z = sstep(WeathermapOut.z, 0.3, 0.6);
        WeathermapOut.z = GetCloudmap_Anvil(Position);
        WeathermapOut.w = GetCloudmap_Cauliflower(Position);

        WeathermapOut.y *= saturate(1.0 - (WeathermapOut.w));
    }
}


#endif