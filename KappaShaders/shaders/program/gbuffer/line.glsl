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

#if MODE==0

uniform vec2 viewSize;
#define VERTEX_STAGE
#include "/lib/downscaleTransform.glsl"

out vec4 tint;

uniform vec2 taaOffset;

in vec3 vaNormal;
in vec3 vaPosition;
in vec4 vaColor;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

const float VIEW_SHRINK = 1.0 - (1.0 / 256.0);
const mat4 VIEW_SCALE = mat4(
    VIEW_SHRINK, 0.0, 0.0, 0.0,
    0.0, VIEW_SHRINK, 0.0, 0.0,
    0.0, 0.0, VIEW_SHRINK, 0.0,
    0.0, 0.0, 0.0, 1.0
);

void main() {

    /*
        Mirrors "rendertype_lines"
    */

    vec4 linePosStart = projectionMatrix * VIEW_SCALE * modelViewMatrix * vec4(vaPosition, 1.0);
    vec4 linePosEnd = projectionMatrix * VIEW_SCALE * modelViewMatrix * vec4(vaPosition + vaNormal, 1.0);

    vec3 ndc1 = linePosStart.xyz / linePosStart.w;
    vec3 ndc2 = linePosEnd.xyz / linePosEnd.w;

    vec2 lineScreenDirection = normalize((ndc2.xy - ndc1.xy) * viewSize);
    vec2 lineOffset = vec2(-lineScreenDirection.y, lineScreenDirection.x) * 2.5 / viewSize;

    if (lineOffset.x < 0.0) lineOffset *= -1.0;

    if (gl_VertexID % 2 == 0) gl_Position = vec4((ndc1 + vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
    else gl_Position = vec4((ndc1 - vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);

    #ifdef taaEnabled
        gl_Position.xy += taaOffset * gl_Position.w / ResolutionScale;
    #endif

    VertexDownscaling(gl_Position);

    tint = vaColor;
}
#else

/* RENDERTARGETS: 0,1,2,4 */
layout(location = 0) out vec4 sceneAlbedo;
layout(location = 1) out vec4 GData0;
layout(location = 2) out vec4 GData1;
layout(location = 3) out vec4 GeoNormals;

#include "/lib/util/colorspace.glsl"
#include "/lib/util/encoders.glsl"

uniform vec2 viewSize;
#include "/lib/downscaleTransform.glsl"

in vec4 tint;

void main() {
    if (OutsideDownscaleViewport()) discard;
    vec4 sceneColor   = saturate(tint) * 0.99 + 0.01;
        sceneColor.a  = 1.0;

        convertToPipelineAlbedo(sceneColor.rgb);

    sceneAlbedo     = drawbufferClamp(sceneColor);

    GData0.xy   = encodeNormal(vec3(0,1,0));
    GData0.zw   = vec2(0);

    GData1      = vec4(0);
    GeoNormals.xyz = vec3(0.5,1,0.5);
}
#endif