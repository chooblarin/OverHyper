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

struct GlitchUniforms {
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
    constant GlitchUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);

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
    float3 baseColor = sourceTexture.sample(textureSampler, uv).rgb;
    float red = sourceTexture.sample(
        textureSampler,
        float2(clamp(sampleUV.x + channelOffset, 0.0, 1.0), clamp(sampleUV.y - 0.001 * peakAmount, 0.0, 1.0))
    ).r;
    float green = sourceTexture.sample(textureSampler, sampleUV).g;
    float blue = sourceTexture.sample(
        textureSampler,
        float2(clamp(sampleUV.x - channelOffset, 0.0, 1.0), clamp(sampleUV.y + 0.001 * peakAmount, 0.0, 1.0))
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
    finalColor = saturate(finalColor);
    return float4(finalColor, 1.0);
}
