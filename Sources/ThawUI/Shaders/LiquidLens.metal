#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Signed distance to a rounded rectangle centred on the origin: negative inside, positive outside.
static float roundedRectDistance(float2 p, float2 halfSize, float radius) {
    float2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// A clear lens over the layer, tuned to the system segmented control's lens: no blur, no tint.
// Content is pulled in toward the middle by up to `displacement` at the rim, the outer `edgeBand` points
// are pushed back out by up to `edgeRefraction` for the squeeze at the edge, and red and blue split by up
// to `chroma` points along `chromaAngle` (radians) inside that band. lensRect is x, y, width, height in the
// layer's coordinates. Zero displacement, edge refraction and chroma leave the layer untouched.
[[ stitchable ]] half4 liquidLens(float2 position, SwiftUI::Layer layer, float4 lensRect, float cornerRadius,
                                  float displacement, float edgeRefraction, float edgeBand, float chroma,
                                  float chromaAngle) {
    float2 halfSize = lensRect.zw * 0.5;
    float2 centre = lensRect.xy + halfSize;
    float2 p = position - centre;
    float radius = min(cornerRadius, min(halfSize.x, halfSize.y));
    float distance = roundedRectDistance(p, halfSize, radius);

    half4 original = layer.sample(position);
    if (distance > 1.0) {
        return original;
    }

    // The outward normal, from the distance field, so the straight run of a capsule bends straight up and down.
    float2 e = float2(0.5, 0.0);
    float2 gradient = float2(roundedRectDistance(p + e.xy, halfSize, radius) - roundedRectDistance(p - e.xy, halfSize, radius),
                             roundedRectDistance(p + e.yx, halfSize, radius) - roundedRectDistance(p - e.yx, halfSize, radius));
    float2 normal = length(gradient) > 0.0001 ? normalize(gradient) : float2(0.0);

    // 0 in the middle, 1 at the rim.
    float depth = clamp(1.0 + distance / max(min(halfSize.x, halfSize.y), 1.0), 0.0, 1.0);
    // 0 inside the edge band, 1 at the rim.
    float band = pow(clamp(1.0 + distance / max(edgeBand, 0.5), 0.0, 1.0), 1.5);

    float2 offset = -normal * displacement * depth * depth + normal * edgeRefraction * band;
    float2 source = position + offset;

    float2 split = float2(cos(chromaAngle), sin(chromaAngle));
    float2 fringe = split * chroma * band * dot(normal, split);

    half4 lensed = layer.sample(source);
    lensed.r = layer.sample(source + fringe).r;
    lensed.b = layer.sample(source - fringe).b;

    // Soft edge over about 2 pt.
    float inside = smoothstep(1.0, -1.0, distance);
    return mix(original, lensed, half(inside));
}
