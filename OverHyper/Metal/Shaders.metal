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
    float rampInStart = uniforms.totalDuration * 0.12;
    float rampInEnd = uniforms.totalDuration * 0.28;
    float rampOutStart = uniforms.totalDuration * 0.62;
    float rampIn = smoothstep(rampInStart, rampInEnd, time);
    float rampOut = 1.0 - smoothstep(rampOutStart, uniforms.totalDuration, time);
    float glitchAmount = rampIn * rampOut;

    float2 uv = in.textureCoordinate;
    float scan = sin((uv.y * 120.0) + (time * 42.0));
    float noise = fract(sin(dot(uv + time, float2(12.9898, 78.233))) * 43758.5453);
    float horizontalOffset = glitchAmount * ((scan * 0.008) + ((noise - 0.5) * 0.012));

    float2 sampleUV = uv;
    sampleUV.x = clamp(sampleUV.x + horizontalOffset, 0.0, 1.0);

    float channelOffset = glitchAmount * 0.006;
    float3 baseColor = sourceTexture.sample(textureSampler, uv).rgb;
    float red = sourceTexture.sample(
        textureSampler,
        float2(clamp(sampleUV.x + channelOffset, 0.0, 1.0), sampleUV.y)
    ).r;
    float green = sourceTexture.sample(textureSampler, sampleUV).g;
    float blue = sourceTexture.sample(
        textureSampler,
        float2(clamp(sampleUV.x - channelOffset, 0.0, 1.0), sampleUV.y)
    ).b;

    float3 glitchColor = float3(red, green, blue);
    float3 finalColor = mix(baseColor, glitchColor, glitchAmount);
    return float4(finalColor, 1.0);
}
