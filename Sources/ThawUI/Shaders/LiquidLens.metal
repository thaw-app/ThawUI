#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Signed distance to a rounded rectangle centred on the origin: negative inside, positive outside.
static float roundedRectDistance(float2 p, float2 halfSize, float radius) {
    float2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// Bends the layer under a rounded-rect lens: magnified in the middle, pulled outward near the rim and
// squeezed hard in a 4 pt band at the edge, with the red and blue channels split mostly in that band, and frosted: slightly blurred
// and brightened, as the system lens is.
// lensRect is x, y, width, height in the layer's coordinates. Zero magnification change, refraction,
// chroma and frost leave the layer untouched.
[[ stitchable ]] half4 liquidLens(float2 position, SwiftUI::Layer layer, float4 lensRect,
                                  float cornerRadius, float magnification, float refraction, float chroma,
                                  float frost) {
    float2 halfSize = lensRect.zw * 0.5;
    float2 centre = lensRect.xy + halfSize;
    float2 p = position - centre;
    float radius = min(cornerRadius, min(halfSize.x, halfSize.y));
    float distance = roundedRectDistance(p, halfSize, radius);

    half4 original = layer.sample(position);
    if (distance > 1.0) {
        return original;
    }

    // 1 at the rim, 0 once a third of the short side in.
    float band = max(min(halfSize.x, halfSize.y) * 0.66, 1.0);
    float rim = clamp(1.0 + distance / band, 0.0, 1.0);
    rim = rim * rim;

    // The edge band: the last 4 pt before the rim, where content is squeezed hard and the colours split.
    float edge = clamp(1.0 + distance / 4.0, 0.0, 1.0);
    edge = pow(edge, 1.5);

    float2 bent = p / max(magnification, 0.01) * (1.0 + refraction * rim + 1.6 * refraction * edge);
    float2 direction = length(p) > 0.001 ? normalize(p) : float2(0.0);
    float2 fringe = direction * chroma * (0.3 * rim + edge);

    float2 source = centre + bent;
    half4 lensed = layer.sample(source);
    lensed.r = layer.sample(source + fringe).r;
    lensed.b = layer.sample(source - fringe).b;

    // Frost: average a small cross of samples about 1 pt out, then lift toward white.
    float spread = 1.0 * frost;
    half4 blurred = (layer.sample(source + float2(spread, 0.0)) + layer.sample(source - float2(spread, 0.0))
                     + layer.sample(source + float2(0.0, spread)) + layer.sample(source - float2(0.0, spread))) * 0.25h;
    lensed.rgb = mix(lensed.rgb, blurred.rgb, half(0.4 * frost));
    lensed.rgb = mix(lensed.rgb, half3(lensed.a), half(0.06 * frost));

    // Soft edge over about 1.5 pt so the outline doesn't alias.
    float inside = smoothstep(0.75, -0.75, distance);
    return mix(original, lensed, half(inside));
}
