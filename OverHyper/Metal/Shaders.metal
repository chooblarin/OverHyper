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
