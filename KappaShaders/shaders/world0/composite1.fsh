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

/* RENDERTARGETS: 12,13 */
layout(location = 0) out vec4 reflectionCapture;
layout(location = 1) out vec4 captureScenePos;

const bool colortex12Clear   = false;
const bool colortex13Clear   = false;

#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform sampler2D colortex12;
uniform sampler2D colortex13;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform float far;

uniform vec2 taaOffset;
uniform vec2 skyCaptureResolution;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;

const vec2 viewSize     = vec2(1024.0, 512.0);
const vec2 pixelSize    = 1.0 / viewSize;

#define FUTIL_MAT16
#define FUTIL_TBLEND
#include "/lib/fUtil.glsl"
#include "/lib/util/transforms.glsl"

#include "/lib/frag/capture.glsl"

vec3 reprojectCapture(vec3 position) {
    vec4 pos    = vec4(position, 1.0)*2.0-1.0;
        pos     = gbufferProjectionInverse*pos;
        pos    /= pos.w;
        pos     = gbufferModelViewInverse*pos;

    vec4 ppos   = pos + vec4(cameraPosition-previousCameraPosition, 0.0);

    return (ppos.xyz/ppos.w)*0.5+0.5;
}

float screenToViewSpace(float depth, mat4 projectionInverse) {
	depth = depth * 2.0 - 1.0;
	return projectionInverse[3].z / (projectionInverse[2].w * depth + projectionInverse[3].w);
}
float screenToViewSpace(float depth) {
    return screenToViewSpace(depth, gbufferProjectionInverse);
}

vec4 encodeCapturePositionData(vec3 scenePos, vec3 cameraPosition) {
    vec4 A  = encodeRGBE8(clamp16F(scenePos + far));
    vec4 B  = encodeRGBE8(clamp16F(fract((cameraPosition + 16000.0) / 32000.0) * 32000.0));

    return vec4(pack2x8(A.xy), pack2x8(A.zw), pack2x8(B.xy), pack2x8(B.zw));
}

mat2x3 decodeCapturePositionData(vec4 data) {
    vec4 A  = vec4(unpack2x8(data.x), unpack2x8(data.y));
    vec4 B  = vec4(unpack2x8(data.z), unpack2x8(data.w));

    return mat2x3(decodeRGBE8(A) - far, decodeRGBE8(B));
}

void main() {
    reflectionCapture   = stex(colortex12);
    captureScenePos     = stex(colortex13);

    vec3 captureDirection   = projectSphere(uv);

    #ifdef reflectionCaptureEnabled

    vec3 viewDirection  = mat3(gbufferModelView) * captureDirection;

    vec3 screenPosition = viewToScreenSpace(viewDirection);

    if (captureScenePos != captureScenePos) captureScenePos = vec4(0.0);

    if (clamp(screenPosition.xy, pixelSize, 1.0 - pixelSize) == screenPosition.xy && viewDirection.z < 0.0) {
        vec3 depthSample    = vec3(texture(depthtex0, screenPosition.xy * ResolutionScale).x, texture(depthtex1, screenPosition.xy * ResolutionScale).x, texture(depthtex2, screenPosition.xy * ResolutionScale).x);

        if (depthSample.y == depthSample.z) {
            reflectionCapture.a     = depthSample.x;

            if (reflectionCapture.a < 1.0) {
                reflectionCapture.rgb   = texture(colortex0, screenPosition.xy * ResolutionScale).rgb;

                vec3 viewPos        = screenToViewSpace(vec3(screenPosition.xy, depthSample.x));
                vec3 scenePos       = viewToSceneSpace(viewPos);

                captureScenePos.rgb = scenePos;
                captureScenePos.a   = 0.0;
            } else {
                reflectionCapture.rgb = vec3(0);
                reflectionCapture.a = 1.0;
                captureScenePos.a   = 0.0;
            }
        }
    } else {

        vec3 scenePos       = captureScenePos.rgb;

        vec3 cameraPosDelta = cameraPosition - previousCameraPosition;
        float distanceTraveled = length(cameraPosDelta);

        vec3 reprojected    = scenePos + cameraPosDelta;

        vec2 screenMovementDirection = unprojectSphere(normalize(reprojected)) - unprojectSphere(normalize(scenePos));
        vec2 screenMovementOffset   = normalize(screenMovementDirection) / length(scenePos) * distanceTraveled;
            screenMovementOffset   /= vec2(tau, pi) * pi;

        if (distanceTraveled < 1e-2) {
            //captureScenePos.xyz = reprojected;
            captureScenePos.w   = clamp16F(stex(colortex13).a + distanceTraveled);
        } else {
            //vec2 sphereCoord    = unprojectSphere(normalize(reprojected));
            vec2 sphereCoord    = fract(uv + screenMovementOffset);
            ivec2 spherePixel   = ivec2(sphereCoord * viewSize);

            //vec3 newScene       = texelFetch(colortex13, ivec2(uv * viewSize), 0).rgb + cameraPosDelta;

            //vec2 newSphereCoord    = unprojectSphere(normalize(newScene));
            //ivec2 newSpherePixel   = ivec2(newSphereCoord * viewSize);

            reflectionCapture   = texelFetch(colortex12, spherePixel, 0);
            float reflectionDepth = texelFetch(colortex12, spherePixel, 0).a;

            //reflectionCapture.rgb = mix(reflectionCapture.rgb, skybox, sstep(captureScenePos.w, 16.0, 32.0));

            captureScenePos.xyz = texelFetch(colortex13, spherePixel, 0).rgb + cameraPosDelta;
            captureScenePos.xyz = reprojected;

            captureScenePos.w   = clamp16F(texelFetch(colortex13, spherePixel, 0).a + distanceTraveled);

            if ((distanceTraveled > 24.0 || distance(sphereCoord, uv) > 0.16) ||
                length(captureScenePos.rgb) > far ||
                reflectionDepth == 1.0
                ) reflectionCapture.a = 1.0;
        }
    }

    if (reflectionCapture.a == 1.0 || reflectionCapture.a == 0.0) {
        reflectionCapture.rgb   = vec3(0);
        reflectionCapture.a     = 1.0;
        captureScenePos.rgb     = captureDirection * far;
        captureScenePos.w       = 0.0;
    }

    captureScenePos     = clamp(captureScenePos, -65535.0, 65535.0);

    if (clamp16F(reflectionCapture) != reflectionCapture) reflectionCapture = vec4(0.0, 0.0, 0.0, 1.0);

    reflectionCapture   = clamp16F(reflectionCapture);

    #else

    reflectionCapture   = clamp16F(vec4(0, 0, 0, 1.0));

    #endif
}