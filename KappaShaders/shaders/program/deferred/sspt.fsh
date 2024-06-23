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

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 indirectLight;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

#ifndef DIM
flat in mat4x3 lightColor;
#define blocklightColor lightColor[3]
#elif DIM == -1
flat in mat2x3 lightColor;
#define blocklightColor lightColor[1]
#elif DIM == 1
flat in mat3x3 lightColor;
#define blocklightColor lightColor[2]
#endif

#if DIM == -1
    #define NO_DIRECTLIGHT
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex14;
uniform sampler2D colortex15;

uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform sampler2D noisetex;

uniform int frameCounter;

uniform float aspectRatio;
uniform float near, far;
uniform float lightFlip;
uniform float sunAngle;

uniform vec2 skyCaptureResolution;
uniform vec2 pixelSize, viewSize;
uniform vec2 taaOffset;

uniform vec3 upDir;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

/* ------ includes ------*/
#define FUTIL_MAT16
#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/frag/bluenoise.glsl"
#include "/lib/frag/gradnoise.glsl"

#include "/lib/atmos/project.glsl"
#include "/lib/frag/capture.glsl"

#include "/lib/brdf/fresnel.glsl"
#include "/lib/brdf/hammon.glsl"


/* ------ DITHER ------ */

#define HASHSCALE1 .1031
float hash12(vec2 x) {
    vec3 x3  = fract(vec3(x.xyx) * HASHSCALE1);
        x3  += dot(x3, x3.yzx + 19.19);
    return fract((x3.x + x3.y) * x3.z);
}

#define HASHSCALE3 vec3(.1031, .1030, .0973)
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float ditherHashNoise() {
    float noise     = hash12(gl_FragCoord.xy);
        noise   = fract(noise + (frameCounter * 7.0 * rcp(255.0)) *0);

    return noise;
}
float ditherBluenoise2() {
    ivec2 uv = ivec2(fract(gl_FragCoord.xy/256.0)*256.0);
    float noise = texelFetch(noisetex, uv, 0).a;

        noise   = fract(noise + (frameCounter * 7.0 * rcp(255.0)));

    return noise;
}


/* ------ SAMPLE DIST ------ */
/*
//Fermats Spiral and Spheremap functions from raspberry by rutherin https://www.patreon.com/user?u=12731730
vec2 fermatsSpiralGoldenN(float index, float total) {
	float theta = index * goldenAngle;
	return vec2(sin(theta), cos(theta)) * sqrt(index / total);
}
vec2 fermatsSpiralGoldenS(float index, float total) {
	float theta = index * goldenAngle;
	return vec2(sin(theta), cos(theta)) * sqr(index / total);
}

vec3 sphereMap(vec2 a) {
    float phi = a.y * 2.0 * pi;
    float cosTheta = 1.0 - a.x;
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}*/


vec3 genUnitVector(vec2 p) {
    p.x *= tau; p.y = p.y * 2.0 - 1.0;
    return vec3(sincos(p.x) * sqrt(1.0 - p.y * p.y), p.y);
}
vec3 GenerateCosineVectorSafe(vec3 vector, vec2 xy) {
	// Apparently this is actually this simple.
	// http://www.amietia.com/lambertnotangent.html
	// (cosine lobe around vector = lambertian BRDF)
	// This one deals with ther rare case where cosineVector == (0,0,0)
	// Can just normalize it instead if you are sure that won't be a problem
	vec3 cosineVector = vector + genUnitVector(xy);
	float lenSq = dot(cosineVector, cosineVector);
	return lenSq > 0.0 ? cosineVector * inversesqrt(lenSq) : vector;
}


/* ------ SSPT ------ */

#ifdef ssptEnabled

#ifdef ssptFullRangeRT

/*
    Works fully in screenspace.
    Potentially every pixel can be hit. Needs a lot more iterations for results of similar quality.
*/

vec3 screenspaceRT(vec3 position, vec3 direction, float noise) {
    const uint maxSteps     = 16;

  	float rayLength = ((position.z + direction.z * far * sqrt3) > -sqrt3 * near) ?
                      (-sqrt3 * near - position.z) / direction.z : far * sqrt3;

    vec3 screenPosition     = viewToScreenSpace(position);
    vec3 endPosition        = position + direction * rayLength;
    vec3 endScreenPosition  = viewToScreenSpace(endPosition);

    vec3 screenDirection    = normalize(endScreenPosition - screenPosition);
        screenDirection.xy  = normalize(screenDirection.xy);

    vec3 maxLength          = (step(0.0, screenDirection) - screenPosition) / screenDirection;
    float stepMult          = minOf(maxLength);
    vec3 screenVector       = screenDirection * stepMult / float(maxSteps);

    vec3 screenPos          = screenPosition + screenDirection * maxOf(pixelSize * pi);

    if (saturate(screenPos.xy) == screenPos.xy) {
        float depthSample   = texelFetch(depthtex0, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = abs(linearSample - currentDepth) / currentDepth;
            if (dist <= 0.1) return vec3(screenPos.xy, depthSample);
        }
    }
    
        screenPos          += screenVector * noise;

    for (uint i = 0; i < maxSteps; ++i) {
        if (saturate(screenPos.xy) != screenPos.xy) break;

        float depthSample   = texelFetch(depthtex0, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = abs(linearSample - currentDepth) / currentDepth;
            if (dist <= 0.1) return vec3(screenPos.xy, depthSample);
        }

        screenPos      += screenVector;
    }

    return vec3(1.1);
}

#else

vec3 screenspaceRT(vec3 position, vec3 direction, float noise) {
    const uint maxSteps     = 10;
    const float stepSize    = tau / float(maxSteps);

    vec3 stepVector         = direction * stepSize;

    vec3 endPosition        = position + stepVector * maxSteps;
    vec3 endScreenPosition  = viewToScreenSpace(endPosition);

    vec2 maxPosXY           = max(abs(endScreenPosition.xy * 2.0 - 1.0), vec2(1.0));
    float stepMult          = minOf(vec2(1.0) / maxPosXY);
        stepVector         *= stepMult;

    // closest texel iteration
    vec3 samplePos          = position;
    
        samplePos          += stepVector / 6.0;
    vec3 screenPos          = viewToScreenSpace(samplePos);

    if (saturate(screenPos.xy) == screenPos.xy) {
        float depthSample   = texelFetch(depthtex0, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = abs(linearSample - currentDepth) / currentDepth;
            if (dist <= 0.1) return vec3(screenPos.xy, depthSample);
        }
    }
    
        samplePos          += stepVector * noise;

    for (uint i = 0; i < maxSteps; ++i) {
        vec3 screenPos      = viewToScreenSpace(samplePos);
            samplePos      += stepVector;
        if (saturate(screenPos.xy) != screenPos.xy) break;

        float depthSample   = texelFetch(depthtex0, ivec2(screenPos.xy * viewSize * ResolutionScale), 0).x;
        float linearSample  = depthLinear(depthSample);
        float currentDepth  = depthLinear(screenPos.z);

        if (linearSample < currentDepth) {
            float dist      = abs(linearSample - currentDepth) / currentDepth;
            if (dist <= 0.1) return vec3(screenPos.xy, depthSample);
        }
    }

    return vec3(1.1);
}

#endif

mat3 raytraceIndirectLight(vec3 viewPos, vec3 sceneNormal, vec2 dither, float skyOcclusion, bool hand) {
    vec3 viewNormal     = mat3(gbufferModelView) * sceneNormal;

    vec3 skylight       = vec3(0.0);
    vec3 bouncedLight   = vec3(0.0);
    vec3 emission       = vec3(0.0);

    const float a1 = 1.0 / rho;
    const float a2 = a1 * a1;

    #ifndef NO_DIRECTLIGHT
    vec3 fakeBounceColor = (sunAngle<0.5 ? lightColor[0] : lightColor[2]) * lightFlip;
        fakeBounceColor += lightColor[1];
        fakeBounceColor *= 0.04;
    #endif

    //skyOcclusion        = 1.0;

    #if ssptBounces <= 1

    /*
        Single Bounce 
    */

    vec2 quasirandomCurr = 0.5 + fract(vec2(a1, a2) * frameCounter + 0.5);

    vec2 noiseCurr      = hash22(gl_FragCoord.xy + frameCounter);

    for (uint i = 0; i < ssptSPP; ++i) {
        ++quasirandomCurr;
        noiseCurr      += hash22(vec2(gl_FragCoord.xy + vec2(cos(quasirandomCurr.x), sin(quasirandomCurr.y))));

        vec2 vectorXY   = fract(sqrt(2.0) * quasirandomCurr + noiseCurr);

        vec3 rayDirection   = GenerateCosineVectorSafe(sceneNormal, vectorXY);
            rayDirection    = normalize(mat3(gbufferModelView) * rayDirection);

        if (dot(viewNormal, rayDirection) < 0.0) rayDirection = -rayDirection;

        vec3 hitPosition    = screenspaceRT(viewPos, rayDirection, dither.y);

        float brdf          = clamp(diffuseHammon(viewNormal, -normalize(viewPos), rayDirection, 1.0) / saturate(dot(rayDirection, viewNormal)/pi), 0.0, halfPi);
            //brdf            = saturate(dot(rayDirection, viewNormal)) * sqrt2;

        if (hitPosition.z < 1.0) {
            vec4 albedoSample   = texelFetch(colortex0, ivec2(hitPosition.xy * viewSize * ResolutionScale), 0);

            float emissionFalloff = 1.0 - linStep(distance(screenToViewSpace(hitPosition), viewPos), ssptEmissionDistance / pi, ssptEmissionDistance);
                emissionFalloff = cube(emissionFalloff);

            if (albedoSample.a > 1e-8) {
                #ifndef ssptAdvancedEmission
                emission       += mix(sqr(normalizeSafe(albedoSample.rgb)), normalizeSafe(albedoSample.rgb), sqr(albedoSample.a)) * albedoSample.a * emissionFalloff * brdf * 10;
                #else
                emission       += texelFetch(colortex3, ivec2(hitPosition.xy * viewSize * ResolutionScale), 0).rgb * emissionFalloff;
                #endif
            }

            #ifndef NO_DIRECTLIGHT

            vec3 directLight    = texelFetch(colortex14, ivec2(hitPosition.xy * viewSize * ResolutionScale), 0).rgb * 2.0;
            bouncedLight       += albedoSample.rgb * directLight * brdf;

            #endif

        } else {
            #ifndef DIM

            vec3 worldDir       = mat3(gbufferModelViewInverse) * rayDirection;

            float groundOcclusion = exp(-max0(-worldDir.y) * sqrPi);

            skylight           += mix(fakeBounceColor * pow4(skyOcclusion), texture(colortex5, projectSky(worldDir, 2)).rgb * cube(skyOcclusion), groundOcclusion) * brdf;
            skylight           += minimumAmbientColor * minimumAmbientMult * minimumAmbientIllum * brdf * (groundOcclusion * 0.5 + 0.5);

            #else

            #if DIM == -1
            skylight           += lightColor[0] * brdf;
            #else
            skylight           += lightColor[1] * brdf;
            #endif

            #endif
        }
    }

    #else

    /*
        Multibounce
    */

    for (uint i = 0; i < ssptSPP; ++i) {
        int frameCounterNew     = frameCounter + int(i) * 31;

        vec2 quasirandomCurr = 0.5 + fract(vec2(a1, a2) * frameCounterNew + 0.5);

        vec2 noiseCurr      = hash22(gl_FragCoord.xy + frameCounterNew);

        vec3 contribution   = vec3(1.0);

        vec3 rayDirection   = normalize(viewPos);

        vec3 hitNormal      = viewNormal;
        vec3 hitNormalScene = sceneNormal;

        for (uint n = 0; n < ssptBounces; ++n) {
            ++quasirandomCurr;
            noiseCurr      += hash22(vec2(gl_FragCoord.xy + vec2(cos(quasirandomCurr.x), sin(quasirandomCurr.y))));

            vec2 vectorXY   = fract(sqrt(2.0) * quasirandomCurr + noiseCurr);

            vec3 oldDirection   = rayDirection;

                rayDirection    = GenerateCosineVectorSafe(hitNormalScene, vectorXY);
                rayDirection    = normalize(mat3(gbufferModelView) * rayDirection);

            if (dot(hitNormal, rayDirection) < 0.0) rayDirection = -rayDirection;

            vec3 hitPosition    = screenspaceRT(viewPos, rayDirection, dither.y);

            float brdf          = clamp(diffuseHammon(hitNormal, -oldDirection, rayDirection, 1.0) / saturate(dot(rayDirection, hitNormal)/pi), 0.0, halfPi);
                //brdf            = saturate(dot(rayDirection, viewNormal)) * sqrt2;
                contribution   *= brdf;

            if (hitPosition.z < 1.0) {
                vec4 albedoSample   = texelFetch(colortex0, ivec2(hitPosition.xy * viewSize * ResolutionScale), 0);
                vec4 tex1           = texelFetch(colortex1, ivec2(hitPosition.xy * viewSize * ResolutionScale), 0);
                hitNormalScene      = decodeNormal(tex1.xy);
                hitNormal           = mat3(gbufferModelView) * hitNormalScene;

                float emissionFalloff = 1.0 - linStep(distance(screenToViewSpace(hitPosition), viewPos), ssptEmissionDistance / pi, ssptEmissionDistance);
                    emissionFalloff = cube(emissionFalloff);

                if (albedoSample.a > 1e-8) {
                    #ifndef ssptAdvancedEmission
                    emission       += mix(sqr(normalizeSafe(albedoSample.rgb)), normalizeSafe(albedoSample.rgb), sqr(albedoSample.a)) * albedoSample.a * emissionFalloff * brdf * 10;
                    #else
                    emission       += texelFetch(colortex3, ivec2(hitPosition.xy * viewSize * ResolutionScale), 0).rgb * emissionFalloff;
                    #endif
                }

                #ifndef NO_DIRECTLIGHT

                vec3 directLight    = texelFetch(colortex14, ivec2(hitPosition.xy * viewSize * ResolutionScale), 0).rgb * 2.0;
                bouncedLight       += albedoSample.rgb * directLight * contribution;

                #endif

                contribution       *= albedoSample.rgb;

            } else {
                #ifndef DIM

                vec3 worldDir       = mat3(gbufferModelViewInverse) * rayDirection;

                float groundOcclusion = exp(-max0(-worldDir.y) * sqrPi);

                skylight           += mix(fakeBounceColor * pow4(skyOcclusion), texture(colortex5, projectSky(worldDir, 2)).rgb * cube(skyOcclusion), groundOcclusion) * contribution;
                skylight           += minimumAmbientColor * minimumAmbientMult * minimumAmbientIllum * contribution * (groundOcclusion * 0.5 + 0.5);

                #else

                #if DIM == -1
                skylight           += lightColor[0] * contribution;
                #else
                skylight           += lightColor[1] * contribution;
                #endif

                #endif

                break;
            }
        }
    }

    #endif

    skylight       /= float(ssptSPP);
    bouncedLight   /= float(ssptSPP);
    emission       /= float(ssptSPP);

    emission       *= float(!hand);
    skylight       *= skylightIllum * vec3(skylightRedMult, skylightGreenMult, skylightBlueMult);

    return mat3(skylight, bouncedLight * pi, emission);
}

#endif


/* ------ FALLBACK ------ */

/*
    SSAO based on BSL Shaders by Capt Tatsu with permission
*/

vec2 offsetDist(float x) {
	float n = fract(x * 8.0) * pi;
    return vec2(cos(n), sin(n)) * x;
}

float getDSSAO(sampler2D depthtex, vec3 sceneNormal, float depth, vec2 uv, float dither) {
    const uint steps = 6;
    const float baseRadius = sqrt2;

    float radius    = baseRadius * (0.75 + abs(1.0-dot(sceneNormal, vec3(0.0, 1.0, 0.0))) * 0.5);

    bool hand       = depth < 0.56;
        depth       = depthLinear(depth);

    float currStep  = 0.2 * dither + 0.2;
	float fovScale  = gbufferProjection[1][1] / 1.37;
	float distScale = max((far - near) * depth + near, 5.0);
	vec2 scale      = radius * vec2(1.0 / aspectRatio, 1.0) * fovScale / distScale;

    float ao = 0.0;

    const float maxOcclusionDist    = tau;
    const float anibleedExp         = 0.71;

    for (uint i = 0; i < steps; ++i) {
		vec2 offset = offsetDist(currStep) * scale;
		float mult  = (0.7 / radius) * (far - near) * (hand ? 1024.0 : 1.0);

		float sampleDepth = depthLinear(texture(depthtex, uv + offset).r);
		float sample0 = (depth - sampleDepth) * mult;
        float antiBleed = 1.0 - rcp(1.0 + max0(distance(sampleDepth, depth) * far - maxOcclusionDist) * anibleedExp);
		float angle = mix(clamp(0.5 - sample0, 0.0, 1.0), 0.5, antiBleed);
		float dist  = mix(clamp(0.25 * sample0 - 1.0, 0.0, 1.0), 0.5, antiBleed);

		sampleDepth = depthLinear(texture(depthtex, uv - offset).r);
		sample0     = (depth - sampleDepth) * mult;
        antiBleed   = 1.0 - rcp(1.0 + max0(distance(sampleDepth, depth) * far - maxOcclusionDist) * anibleedExp);
        angle      += mix(clamp(0.5 - sample0, 0.0, 1.0), 0.5, antiBleed);
        dist       += mix(clamp(0.25 * sample0 - 1.0, 0.0, 1.0), 0.5, antiBleed);
		
		ao         += (clamp(angle + dist, 0.0, 1.0));
		currStep   += 0.2;
    }
	ao *= 1.0 / float(steps);
	
	return ao;
}

void main() {
    indirectLight   = vec4(0.0);

    vec2 lowresCoord    = uv / indirectResScale;
    ivec2 pixelPos      = ivec2(floor(uv * viewSize) / indirectResScale);
    float sceneDepth    = texelFetch(depthtex0, pixelPos, 0).x;

    if (landMask(sceneDepth) && saturate(lowresCoord) == lowresCoord) {
        vec2 uv      = saturate(lowresCoord);

        vec3 viewPos    = screenToViewSpace(vec3(uv / ResolutionScale, sceneDepth), true);
        vec3 viewDir    = -normalize(viewPos);

        vec4 tex1       = texelFetch(colortex1, pixelPos, 0);
        vec3 sceneNormal = decodeNormal(tex1.xy);
        vec3 viewNormal = mat3(gbufferModelView) * sceneNormal;
        vec2 lightmaps  = saturate(unpack2x8(tex1.z));

        #ifndef NO_DIRECTLIGHT
            #ifndef DIM
            vec3 directCol      = (sunAngle<0.5 ? lightColor[0] : lightColor[2]) * lightFlip;
            #elif DIM == 1
            vec3 directCol      = lightColor[0];
            #endif
        #endif

        vec4 tex2       = texelFetch(colortex2, pixelPos, 0);
        int matID       = unpack2x8I(tex2.y).x;

        #ifdef ssptEnabled
            bool hand   = sceneDepth < texelFetch(depthtex2, pixelPos, 0).x;

            mat3 ssptResult     = raytraceIndirectLight(viewPos, sceneNormal, vec2(ditherBluenoise2(), ditherHashNoise()), lightmaps.y, hand);

            float lightmapFade  = saturate(1.0 - mix(maxOf(ssptResult[2]), avgOf(ssptResult[2]), 0.41));
            lightmapFade     = 1.0 - saturate(max(stex(colortex0).a, 0.9 * (float(matID == 5) + float(matID == 6))));

            #ifndef NO_DIRECTLIGHT
            indirectLight.rgb   = ssptResult[0] + ssptResult[1] * directCol + ssptResult[2] * maxOf(blocklightColor) * euler;
            #else
            indirectLight.rgb   = ssptResult[0] + ssptResult[2] * maxOf(blocklightColor) * euler;
            #endif

            indirectLight.a     = lightmapFade * pow5(lightmaps.x) * sqr(stex(colortex15).y) * ssptLightmapBlend;
        #else

            float VAO           = stex(colortex15).y;

            #ifdef RINDIRECT_USE_SSAO
                float ao        = getDSSAO(depthtex0, sceneNormal, sceneDepth, uv, ditherBluenoise());
                    ao         *= VAO;
            #else
                float ao        = VAO;
            #endif

            float groundOcclusion = exp(-max0(sceneNormal.y + 1.0) * 0.71) + 0.31;

            #ifndef DIM
            vec3 fakeBounceColor = directCol;
                fakeBounceColor *= 0.066;

            vec3 indirectColor  = fakeBounceColor * pow4(lightmaps.y) * groundOcclusion;
                indirectColor  += lightColor[1] * cube(lightmaps.y) / sqrt2;
                indirectColor  += minimumAmbientColor * minimumAmbientMult * minimumAmbientIllum;
            #else

                #if DIM == -1
                vec3 indirectColor = lightColor[0];
                #else
                vec3 indirectColor = lightColor[1];
                #endif

            #endif

            float lmap          = pow5(lightmaps.x);

            indirectLight.rgb   = indirectColor * ao;
            indirectLight.rgb  += lmap * sqr(VAO) * blocklightColor / pi;
            indirectLight.rgb  += cube(linStep(lmap, 0.1, 0.61)) * sqr(VAO) * blocklightColor / halfPi;
            indirectLight.a     = 1.0;
        #endif
    }

    indirectLight   = clamp16F(indirectLight);
}