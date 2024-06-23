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

/*
    const bool colortex0MipmapEnabled = true;
*/

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 bokehBlur;

#include "/lib/head.glsl"

in vec2 uv;

uniform sampler2D colortex0;

uniform float aspectRatio;
uniform float viewWidth, viewHeight;

uniform vec2 viewSize;


#include "/lib/offset/bokeh.glsl"

void main() {
    bokehBlur   = vec4(0.0, 0.0, 0.0, 1.0);

    #ifdef lensFlareToggle
        vec2 blurCoord  = uv * lensFlareBokehLod;

        if (saturate(blurCoord) != blurCoord) discard;

        for (uint i = 0; i < 50; i++) {
            vec2 bokeh  = pentagonalBokeh50[i];
            vec2 offset = bokeh * vec2(1.0, aspectRatio * anamorphStretch) * 10e-3;

            bokehBlur.rgb += max0(textureLod(colortex0, blurCoord + offset, lensFlareBokehLod).rgb - float(lensFlareThreshold));
        }

        bokehBlur.rgb  /= 50.0;
    #endif

    bokehBlur = clamp16F(bokehBlur);
}