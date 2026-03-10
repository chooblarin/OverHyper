#include <metal_stdlib>
using namespace metal;

struct TexturedVertex {
    float2 position;
    float2 textureCoordinate;
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

struct ShaderUniforms {
    float2 viewportSize;
    float elapsedTime;
    float totalDuration;
};

float hash11(float value) {
    return fract(sin(value * 127.1) * 43758.5453123);
}

float hash21(float2 value) {
    return fract(sin(dot(value, float2(127.1, 311.7))) * 43758.5453123);
}

float3 sampleSource(texture2d<float> sourceTexture, float2 uv) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);
    return sourceTexture.sample(textureSampler, clamp(uv, 0.0, 1.0)).rgb;
}

float luminance(float3 color) {
    return dot(color, float3(0.299, 0.587, 0.114));
}

float2 barrelDistortion(float2 uv, float amount) {
    float2 centered = (uv * 2.0) - 1.0;
    float radius = dot(centered, centered);
    centered *= 1.0 + (radius * amount);
    return (centered * 0.5) + 0.5;
}

float edgeStrength(
    texture2d<float> sourceTexture,
    float2 uv,
    float2 texelSize
) {
    float3 center = sampleSource(sourceTexture, uv);
    float3 left = sampleSource(sourceTexture, uv - float2(texelSize.x, 0.0));
    float3 right = sampleSource(sourceTexture, uv + float2(texelSize.x, 0.0));
    float3 up = sampleSource(sourceTexture, uv - float2(0.0, texelSize.y));
    float3 down = sampleSource(sourceTexture, uv + float2(0.0, texelSize.y));

    float horizontal = length(right - left);
    float vertical = length(down - up);
    float centerBias = length(center - ((left + right + up + down) * 0.25));

    return horizontal + vertical + (centerBias * 0.5);
}

constant float kCrackedGlassCellJitter = 0.65;
constant float kCrackedGlassAngularSegments = 9.0;

float2 rotate2D(float2 point, float angle) {
    float sine = sin(angle);
    float cosine = cos(angle);
    return float2(
        (cosine * point.x) - (sine * point.y),
        (sine * point.x) + (cosine * point.y)
    );
}

float noise2CrackedGlass(float2 point) {
    float2 integer = floor(point);
    float2 fractional = fract(point);
    fractional = fractional * fractional * (3.0 - (2.0 * fractional));

    float bottom = mix(
        hash21(integer + float2(0.0, 0.0)),
        hash21(integer + float2(1.0, 0.0)),
        fractional.x
    );
    float top = mix(
        hash21(integer + float2(0.0, 1.0)),
        hash21(integer + float2(1.0, 1.0)),
        fractional.x
    );
    return (2.0 * mix(bottom, top, fractional.y)) - 1.0;
}

float noise1CrackedGlass(float value) {
    float integer = floor(value);
    float fractional = fract(value);
    return mix(hash11(integer), hash11(integer + 1.0), fractional);
}

float lowFrequencyNoiseCrackedGlass(float value) {
    float wrapped = fract(value);
    float resolution = 10.0;
    float segmentA = floor(wrapped * resolution);
    float segmentB = segmentA + 1.0;
    float sampleA = noise1CrackedGlass(fmod(segmentA, resolution));
    float sampleB = noise1CrackedGlass(fmod(segmentB, resolution));
    float interpolation = fract(wrapped * resolution);
    return (mix(sampleA, sampleB, interpolation) * 2.0) - 1.0;
}

float atan01CrackedGlass(float2 point) {
    return (atan2(point.y, point.x) / 6.28318530718) + 0.5;
}

float2 wrappedHashCrackedGlass(float2 point) {
    float2 wrapped = fract(point / kCrackedGlassAngularSegments) * kCrackedGlassAngularSegments;
    return float2(
        hash21(wrapped + float2(0.37, 1.79)),
        hash21(wrapped + float2(8.11, 3.17))
    );
}

struct CrackedGlassVoronoiResult {
    float borderDistance;
    float2 centerVector;
    float2 cellID;
};

struct CrackedGlassContext {
    float viewportWidth;
    float aspect;
    float theta;
    float2 uvCenter;
};

struct CrackedGlassSample {
    float3 color;
    float mask;
};

CrackedGlassVoronoiResult crackedGlassVoronoi(float2 point) {
    float2 integer = floor(point);
    float2 fractional = fract(point);
    float2 bestGrid = float2(0.0, 0.0);
    float2 bestVector = float2(0.0, 0.0);
    float minimumDistance = 8.0;

    for (int y = -1; y <= 1; y += 1) {
        for (int x = -1; x <= 1; x += 1) {
            float2 grid = float2(float(x), float(y));
            float2 jitter = kCrackedGlassCellJitter * wrappedHashCrackedGlass(integer + grid);
            float2 relative = grid + jitter - fractional;
            float distanceSquared = dot(relative, relative);

            if (distanceSquared < minimumDistance) {
                minimumDistance = distanceSquared;
                bestVector = relative;
                bestGrid = grid;
            }
        }
    }

    minimumDistance = 8.0;

    for (int y = -2; y <= 2; y += 1) {
        for (int x = -2; x <= 2; x += 1) {
            float2 grid = bestGrid + float2(float(x), float(y));
            float2 jitter = kCrackedGlassCellJitter * wrappedHashCrackedGlass(integer + grid);
            float2 relative = grid + jitter - fractional;

            if (dot(bestVector - relative, bestVector - relative) > 1e-6) {
                float borderDistance = dot(
                    0.5 * (bestVector + relative),
                    normalize(relative - bestVector)
                );
                minimumDistance = min(minimumDistance, borderDistance);
            }
        }
    }

    CrackedGlassVoronoiResult result;
    result.borderDistance = minimumDistance;
    result.centerVector = bestVector;
    result.cellID = integer + bestGrid;
    return result;
}

float2 wrapAngularCellID(float2 cellID) {
    float2 wrapped = fmod(cellID, kCrackedGlassAngularSegments);
    if (wrapped.x < 0.0) {
        wrapped.x += kCrackedGlassAngularSegments;
    }
    if (wrapped.y < 0.0) {
        wrapped.y += kCrackedGlassAngularSegments;
    }
    return wrapped;
}

CrackedGlassContext makeCrackedGlassContext(constant ShaderUniforms &uniforms) {
    CrackedGlassContext context;
    context.viewportWidth = max(uniforms.viewportSize.x, 1.0);
    context.aspect = uniforms.viewportSize.x / max(uniforms.viewportSize.y, 1.0);
    context.theta = uniforms.elapsedTime * 3.14159265359 / 20.0;
    context.uvCenter = (uniforms.viewportSize / context.viewportWidth * 0.5) + float2(-0.2, 0.1);
    return context;
}

CrackedGlassSample renderCrackedGlassSample(
    texture2d<float> sourceTexture,
    constant ShaderUniforms &uniforms,
    CrackedGlassContext context,
    float2 fragCoord
) {
    float2 lensUV = (fragCoord / context.viewportWidth) - context.uvCenter;
    float radius = length(lensUV);

    float2 cylindrical = float2(
        max(0.5, pow(max(radius, 1e-4), 0.1)),
        atan01CrackedGlass(lensUV)
    );
    cylindrical.x += 0.015 * abs(lowFrequencyNoiseCrackedGlass(cylindrical.y));

    float2 frequency = float2(12.0, kCrackedGlassAngularSegments);
    CrackedGlassVoronoiResult voronoiResult = crackedGlassVoronoi(cylindrical * frequency);
    float2 cellID = wrapAngularCellID(voronoiResult.cellID);
    float centerDistance = length(voronoiResult.centerVector);
    float radiusFactor = pow(min(radius, 1.0), 0.12);
    float edgeWidth = mix(0.040, 0.0, radiusFactor);
    float edgeSoftness = mix(0.00045, 0.00008, radiusFactor);
    float edge = smoothstep(edgeWidth, edgeWidth + edgeSoftness, voronoiResult.borderDistance);
    float crackMask = 1.0 - edge;

    float2 rotatedXZ = rotate2D(float2(lensUV.x, -0.2), context.theta);
    float3 world = float3(rotatedXZ.x, lensUV.y, rotatedXZ.y);
    float3 viewDirection = normalize(-world);

    float3 normalOffset = (float3(
        noise1CrackedGlass(cellID.x * 7.0),
        noise1CrackedGlass(cellID.y * 13.0),
        noise1CrackedGlass(27.0 * (cellID.x - cellID.y))
    ) * 2.0) - 1.0;
    float3 surfaceNormal = normalize(float3(0.0, 0.0, 1.0) + (0.1 * normalOffset));
    float3 reflectedDirection = reflect(-viewDirection, surfaceNormal);

    float2 baseUV = fragCoord / uniforms.viewportSize;
    float2 reflectedUV = baseUV
        + float2(reflectedDirection.x / max(context.aspect, 0.0001), -reflectedDirection.y)
        * (0.010 + (0.003 * centerDistance));
    float2 refractionUV = baseUV
        + float2(surfaceNormal.x / max(context.aspect, 0.0001), -surfaceNormal.y)
        * (0.004 + (0.002 * crackMask));
    float3 env = sampleSource(sourceTexture, mix(refractionUV, reflectedUV, 0.38));

    float fresnel = pow(1.0 - saturate(dot(surfaceNormal, -viewDirection)), 3.5);
    float3 lit = env * (0.84 + (0.22 * fresnel));
    lit *= 1.0 - (crackMask * 0.10);
    lit = mix(lit, float3(0.02), crackMask * 0.92);

    CrackedGlassSample sample;
    sample.color = lit;
    sample.mask = crackMask;
    return sample;
}

vertex VertexOut glitchVertexShader(
    const device TexturedVertex *vertices [[buffer(0)]],
    uint vertexID [[vertex_id]]
) {
    VertexOut out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.textureCoordinate = vertices[vertexID].textureCoordinate;
    return out;
}

fragment float4 glitchFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant ShaderUniforms &uniforms [[buffer(0)]]
) {
    float time = uniforms.elapsedTime;
    float freezeEnd = uniforms.totalDuration * 0.08;
    float rampIn = smoothstep(freezeEnd, uniforms.totalDuration * 0.20, time);
    float rampOut = 1.0 - smoothstep(uniforms.totalDuration * 0.72, uniforms.totalDuration, time);
    float glitchAmount = rampIn * rampOut;
    float pulse = smoothstep(
        uniforms.totalDuration * 0.16,
        uniforms.totalDuration * 0.26,
        time
    ) * (1.0 - smoothstep(
        uniforms.totalDuration * 0.28,
        uniforms.totalDuration * 0.46,
        time
    ));
    float peakAmount = saturate((glitchAmount * 0.58) + (pulse * 0.26));

    float2 uv = in.textureCoordinate;
    float lineDensity = max(uniforms.viewportSize.y / 18.0, 1.0);
    float bandIndex = floor(uv.y * 28.0);
    float bandNoise = hash21(float2(bandIndex, floor(time * 24.0)));
    float thinBand = step(0.74, hash21(float2(floor(uv.y * lineDensity), floor(time * 42.0))));
    float electricWave = sin((uv.y * 210.0) - (time * 18.0));
    float sliceOffset = (bandNoise - 0.5) * 0.12 * peakAmount;
    float waveOffset = electricWave * 0.005 * peakAmount;
    float burstOffset = thinBand * 0.038 * pulse * (hash11(floor(time * 34.0)) - 0.5);
    float horizontalOffset = sliceOffset + waveOffset + burstOffset;

    float2 sampleUV = uv;
    sampleUV.x = clamp(sampleUV.x + horizontalOffset, 0.0, 1.0);

    float channelOffset = (0.005 + (pulse * 0.008)) * peakAmount;
    float3 baseColor = sampleSource(sourceTexture, uv);
    float red = sampleSource(
        sourceTexture,
        float2(
            sampleUV.x + channelOffset,
            clamp(sampleUV.y - (0.001 * peakAmount), 0.0, 1.0)
        )
    ).r;
    float green = sampleSource(sourceTexture, sampleUV).g;
    float blue = sampleSource(
        sourceTexture,
        float2(
            sampleUV.x - channelOffset,
            clamp(sampleUV.y + (0.001 * peakAmount), 0.0, 1.0)
        )
    ).b;

    float3 glitchColor = float3(red, green, blue);
    float scanline = 0.92 + (0.08 * sin((uv.y * uniforms.viewportSize.y * 1.22) - (time * 34.0)));
    float grain = (hash21((uv * uniforms.viewportSize) + float2(time * 83.0, time * 41.0)) - 0.5)
        * (0.05 * peakAmount);
    float3 neonTint = float3(0.025, 0.12, 0.14) * peakAmount;
    float3 magentaEdge = float3(0.12, 0.02, 0.11) * thinBand * peakAmount;
    float glow = pulse * 0.11;
    float vignette = 1.0 - (distance(uv, float2(0.5, 0.5)) * 0.10 * glitchAmount);

    float3 styledColor = glitchColor;
    styledColor *= scanline;
    styledColor += neonTint + magentaEdge + grain;
    styledColor = max(styledColor, glitchColor * (1.0 + glow));
    styledColor *= vignette;

    float3 finalColor = mix(baseColor, styledColor, peakAmount);
    return float4(saturate(finalColor), 1.0);
}

fragment float4 crtBurstFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant ShaderUniforms &uniforms [[buffer(0)]]
) {
    float time = uniforms.elapsedTime;
    float rampIn = smoothstep(uniforms.totalDuration * 0.10, uniforms.totalDuration * 0.24, time);
    float rampOut = 1.0 - smoothstep(uniforms.totalDuration * 0.55, uniforms.totalDuration, time);
    float burstAmount = rampIn * rampOut;

    float2 uv = in.textureCoordinate;
    float2 distortedUV = barrelDistortion(uv, 0.085 * burstAmount);
    float2 centered = distortedUV - 0.5;
    float2 convergenceOffset = centered * (0.018 * burstAmount);

    float3 baseColor = sampleSource(sourceTexture, uv);
    float red = sampleSource(sourceTexture, distortedUV + convergenceOffset).r;
    float green = sampleSource(sourceTexture, distortedUV).g;
    float blue = sampleSource(sourceTexture, distortedUV - convergenceOffset).b;

    float scanline = 0.88 + (0.12 * sin((uv.y * uniforms.viewportSize.y * 1.35) - (time * 18.0)));
    float apertureMask = 0.94 + (0.06 * sin((uv.x * uniforms.viewportSize.x * 0.65) + (time * 11.0)));
    float vignette = 1.0 - (distance(uv, float2(0.5, 0.5)) * 0.34 * burstAmount);
    float bloom = burstAmount * 0.18;

    float3 crtColor = float3(red, green, blue);
    crtColor *= scanline * apertureMask;
    crtColor += float3(0.03, 0.08, 0.04) * burstAmount;
    crtColor = max(crtColor, float3(red, green, blue) * (1.0 + bloom));
    crtColor *= vignette;

    float3 finalColor = mix(baseColor, crtColor, burstAmount);
    return float4(saturate(finalColor), 1.0);
}

fragment float4 shockwaveFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant ShaderUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.textureCoordinate;
    float3 baseColor = sampleSource(sourceTexture, uv);
    float time = uniforms.elapsedTime;

    float progress = saturate(
        (time - (uniforms.totalDuration * 0.12))
        / (uniforms.totalDuration * 0.68)
    );
    float waveProgress = pow(progress, 0.78);
    float active = smoothstep(0.0, 0.05, progress) * (1.0 - smoothstep(0.94, 1.0, progress));

    float aspect = uniforms.viewportSize.x / max(uniforms.viewportSize.y, 1.0);
    float2 centered = (uv - 0.5) * float2(aspect, 1.0);
    float distanceFromCenter = length(centered);
    float waveRadius = waveProgress * 1.10;
    float radiusDelta = distanceFromCenter - waveRadius;
    float compression = exp(-pow(radiusDelta / 0.050, 2.0) * 9.0) * active;
    float trailingEnvelope = exp(-max(radiusDelta, 0.0) * 6.5) * active;
    float trailingPhase = sin((radiusDelta * 58.0) - (time * 10.0));
    float banding = sin((distanceFromCenter * 24.0) - (time * 5.0));
    float trailingRipples = max(trailingPhase, 0.0) * trailingEnvelope * 0.42;
    float innerRipples = max(banding, 0.0)
        * exp(-pow((radiusDelta + 0.05) / 0.16, 2.0) * 4.5)
        * active
        * 0.20;
    float2 direction = distanceFromCenter > 0.0001 ? normalize(centered) : float2(0.0, 0.0);
    float turbulence = sin((centered.y * 30.0) + (time * 8.0))
        * cos((centered.x * 24.0) - (time * 6.0))
        * 0.008
        * active;
    float2 refractionOffset = direction * ((compression * 0.095) + (trailingRipples * 0.028));
    refractionOffset += float2(turbulence / aspect, turbulence * 0.45);
    float channelOffset = ((compression * 0.010) + (trailingRipples * 0.004));

    float2 sampleUV = uv + float2(refractionOffset.x / aspect, refractionOffset.y);
    float red = sampleSource(
        sourceTexture,
        sampleUV + float2(channelOffset / aspect, 0.0)
    ).r;
    float green = sampleSource(sourceTexture, sampleUV).g;
    float blue = sampleSource(
        sourceTexture,
        sampleUV - float2(channelOffset / aspect, 0.0)
    ).b;

    float3 refracted = float3(red, green, blue);
    float highlight = saturate((compression * 1.45) + (trailingRipples * 0.45));
    refracted += float3(0.10, 0.20, 0.28) * highlight;
    refracted += float3(0.04, 0.06, 0.10) * innerRipples;
    refracted *= 1.0 + (highlight * 0.30);

    float3 finalColor = mix(baseColor, refracted, saturate((compression * 1.9) + (trailingRipples * 0.8) + (innerRipples * 0.35)));
    return float4(saturate(finalColor), 1.0);
}

fragment float4 crackedGlassFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant ShaderUniforms &uniforms [[buffer(0)]]
) {
    float time = uniforms.elapsedTime;
    float duration = uniforms.totalDuration;
    float2 uv = in.textureCoordinate;
    float3 baseColor = sampleSource(sourceTexture, uv);
    CrackedGlassContext context = makeCrackedGlassContext(uniforms);
    float hold = 1.0 - smoothstep(duration * 0.80, duration, time);
    float snapProgress = saturate((time - (duration * 0.03)) / (duration * 0.09));
    float2 fragCoord = uv * uniforms.viewportSize;
    float2 lensUV = (fragCoord / context.viewportWidth) - context.uvCenter;
    float radius = length(lensUV);
    float fractureFront = smoothstep(-0.02, 0.028, snapProgress - (radius * 1.28));
    float reveal = fractureFront * hold;

    if (reveal <= 0.0001) {
        return float4(baseColor, 1.0);
    }

    CrackedGlassSample centerSample = renderCrackedGlassSample(
        sourceTexture,
        uniforms,
        context,
        fragCoord + 0.5
    );
    float3 crackedColor;

    if (centerSample.mask < 0.015) {
        crackedColor = centerSample.color;
    } else {
        float3 accumulated = centerSample.color;
        accumulated += renderCrackedGlassSample(
            sourceTexture,
            uniforms,
            context,
            fragCoord + float2(0.25, 0.25)
        ).color;
        accumulated += renderCrackedGlassSample(
            sourceTexture,
            uniforms,
            context,
            fragCoord + float2(0.75, 0.25)
        ).color;
        accumulated += renderCrackedGlassSample(
            sourceTexture,
            uniforms,
            context,
            fragCoord + float2(0.25, 0.75)
        ).color;
        crackedColor = accumulated * 0.25;
    }
    float compositeAmount = saturate(reveal * 0.94);
    float3 finalColor = mix(baseColor, crackedColor, compositeAmount);
    return float4(saturate(finalColor), 1.0);
}

fragment float4 neonEdgeFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant ShaderUniforms &uniforms [[buffer(0)]]
) {
    float time = uniforms.elapsedTime;
    float rampIn = smoothstep(uniforms.totalDuration * 0.08, uniforms.totalDuration * 0.20, time);
    float rampOut = 1.0 - smoothstep(uniforms.totalDuration * 0.55, uniforms.totalDuration, time);
    float edgeAmount = rampIn * rampOut;

    float2 uv = in.textureCoordinate;
    float3 baseColor = sampleSource(sourceTexture, uv);
    float2 texelSize = 1.0 / max(uniforms.viewportSize, float2(1.0, 1.0));
    float edge = edgeStrength(sourceTexture, uv, texelSize * 1.3);
    float halo = edgeStrength(sourceTexture, uv, texelSize * 2.8);
    float edgeMask = smoothstep(0.10, 0.34, edge) * edgeAmount;
    float haloMask = smoothstep(0.08, 0.24, halo) * edgeAmount * 0.55;

    float fastTime = time * 8.5;
    float waveA = sin((uv.y * 34.0) - fastTime);
    float waveB = sin(((uv.x + uv.y) * 18.0) + (fastTime * 1.25));
    float waveC = cos((uv.x * 41.0) - (uv.y * 23.0) + (fastTime * 0.92));
    float waveD = sin((distance(uv, float2(0.5, 0.5)) * 52.0) - (fastTime * 1.6));
    float neonMixA = 0.5 + (0.5 * waveA);
    float neonMixB = 0.5 + (0.5 * waveB);
    float neonMixC = 0.5 + (0.5 * waveC);
    float pulse = 0.5 + (0.5 * waveD);

    float3 cyan = float3(0.00, 1.00, 1.00);
    float3 magenta = float3(1.00, 0.00, 0.82);
    float3 violet = float3(0.44, 0.10, 1.00);
    float3 electricBlue = float3(0.00, 0.56, 1.00);
    float3 acidPink = float3(1.00, 0.16, 0.62);

    float3 gradientA = mix(cyan, magenta, neonMixA);
    float3 gradientB = mix(violet, electricBlue, neonMixB);
    float3 gradientC = mix(acidPink, cyan, neonMixC);
    float3 edgeColor = mix(gradientA, gradientB, 0.5 + (0.5 * sin((uv.x * 15.0) + (fastTime * 0.75))));
    edgeColor = mix(edgeColor, gradientC, pulse * 0.45);
    edgeColor *= 1.0 + (pulse * 0.22);

    float3 darkenedBase = mix(baseColor, baseColor * 0.10, edgeAmount * 0.92);
    float3 glow = edgeColor * edgeMask * (2.5 + (pulse * 0.35));
    float3 outerGlow = edgeColor * haloMask * (1.05 + (pulse * 0.20));
    float noise = (hash21((uv * uniforms.viewportSize * 0.6) + float2(time * 57.0, time * 31.0)) - 0.5)
        * 0.04 * edgeAmount;

    float3 finalColor = darkenedBase + glow + outerGlow;
    finalColor += float3(noise);
    finalColor += edgeColor * (luminance(baseColor) * 0.08 * edgeAmount);

    return float4(saturate(mix(baseColor, finalColor, edgeAmount)), 1.0);
}
