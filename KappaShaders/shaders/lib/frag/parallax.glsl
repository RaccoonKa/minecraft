vec4 readTexture(sampler2D tex, vec2 coord, mat2 dCoord) {
    return textureGrad(tex, fract(coord) * vCoordAM.zw + vCoordAM.xy, dCoord[0], dCoord[1]);
}

vec4 textureParallax(sampler2D tex, vec2 coord, mat2 dCoord) {
    return textureGrad(tex, coord, dCoord[0], dCoord[1]);
}

vec4 getParallaxCoord(vec2 coord, mat2 dCoord, out float TexDepth, out float TraceDepth) {
    vec2 parallaxPos    = vCoord * vCoordAM.zw + vCoordAM.xy;
    vec2 rCoord         = vCoord;
    TexDepth = TraceDepth = 1.0;

    float fade          = 1.0 - sstep(vertexDist, 24.0, 48.0);
    //float fade          = 1.0 - sstep(vertexDist, 1.0, 6.0);

    const float minCoord = 1.0/(4096.0);

    if (fade > 0.0) {
        uint ParallaxSamples = uint(pomSamples * fade);
        float rStep = rcp(pomSamples);

        float PrevTexDepth;
        TexDepth = PrevTexDepth = readTexture(normals, vCoord, dCoord).a;
        
        if (viewVec.z < 0.0 && PrevTexDepth < (254.0 / 255.0)) {
            vec3 viewDir = normalize(viewVec);
            vec2 currStep   = viewDir.xy * pomDepth * rcp(1 + -viewDir.z * float(pomSamples));

            #ifdef gSHADOW
                rCoord += currStep;
            #else
                rCoord += currStep * ditherBluenoise();
            #endif

            uint Iteration = 1;
            for (; Iteration <= ParallaxSamples; Iteration++) {
                TraceDepth = 1.0 - float(Iteration) * rStep;
                PrevTexDepth = TexDepth;

                TexDepth = readTexture(normals, rCoord, dCoord).a;
                TexDepth = max(TexDepth, 1.0 - fade);

                if (TexDepth >= TraceDepth) break;

                rCoord += currStep;
            }

            if (rCoord.y < minCoord && readTexture(gtexture, vec2(rCoord.x, minCoord), dCoord).a == 0.0) {
                rCoord.y = minCoord;
                discard;
            }

            float PrevTraceDepth = 1.0 - float(Iteration-1) * rStep;
            float t = (PrevTraceDepth - PrevTexDepth) / max(TexDepth - PrevTexDepth + PrevTraceDepth - TraceDepth, 0.00001);
            TraceDepth = PrevTraceDepth - saturate(t) * rStep;
        }

        parallaxPos     = fract(rCoord) * vCoordAM.zw + vCoordAM.xy;
    }

    return vec4(parallaxPos, rCoord);
}

#ifndef gSHADOW
    float getParallaxShadow(vec3 normal, vec4 parallaxCoord, mat2 dCoord, float height, float dO) {
        float shadow    = 1.0;

        float nDotL     = saturate(dot(normal, lightDir));

        float fade      = 1.0 - sstep(vertexDist, 24.0, 48.0);

        if (fade > 0.01 && nDotL > 0.01) {
            vec3 dir    = tbn * lightDir;
                dir     = dir;
                dir.xy *= 0.3;
                float step = 1.28 / float(pomShadowSamples);

                vec3 baseOffset = step * dir * ditherGradNoiseTemporal();

            baseOffset.z -= dO;

            for (uint i = 0; i < pomShadowSamples; i++) {
                float currZ    = height + dir.z * step * i + baseOffset.z;
                if (currZ > 1) break;

                float heightO  = textureParallax(normals, fract(parallaxCoord.zw + dir.xy * i * step + baseOffset.xy) * vCoordAM.zw + vCoordAM.xy, dCoord).a;
                    
                    shadow *= saturate(1.0 - (heightO - currZ) * 40.0);

                if (shadow < 0.01) break;
            }

            shadow  = mix(1.0, shadow, fade);
        }
        return shadow;
    }

    vec3 apply_slope_normal(in vec2 tex, in mat2 dCoord, in float trace_depth) {
        vec2 tex_size = textureSize(normals, 0);
        vec2 pixel_size = rcp(tex_size);

        vec2 tex_snapped = floor(tex * tex_size) * pixel_size;
        vec2 tex_offset = tex - tex_snapped - 0.5f * pixel_size;
        vec2 step_sign = sign(-viewVec.xy);

        vec2 tex_x = tex_snapped + vec2(pixel_size.x * step_sign.x, 0.0f);
        float height_x = textureParallax(normals, tex_x, dCoord).a;
        bool has_x = trace_depth > height_x && sign(tex_offset.x) == step_sign.x;

        vec2 tex_y = tex_snapped + vec2(0.0f, pixel_size.y * step_sign.y);
        float height_y = textureParallax(normals, tex_y, dCoord).a;
        bool has_y = trace_depth > height_y && sign(tex_offset.y) == step_sign.y;

        if (abs(tex_offset.x) < abs(tex_offset.y)) {
            if (has_y) return vec3(0.0f, step_sign.y, 0.0f);
            if (has_x) return vec3(step_sign.x, 0.0f, 0.0f);
        }
        else {
            if (has_x) return vec3(step_sign.x, 0.0f, 0.0f);
            if (has_y) return vec3(0.0f, step_sign.y, 0.0f);
        }

        float s = step(abs(viewVec.y), abs(viewVec.x));
        return vec3(vec2(1.0f - s, s) * step_sign, 0.0f);
    }

    float linearizePerspectiveDepth(float depth, mat4 projectionMat) {
        return projectionMat[3].z / (projectionMat[2].z + depth * 2.0 - 1.0);
    }

    float delinearizePerspectiveDepth(float depth, mat4 projectionMat) {
        return (-projectionMat[2].z * depth + projectionMat[3].z) * 0.5 / depth + 0.5;
    }
#endif