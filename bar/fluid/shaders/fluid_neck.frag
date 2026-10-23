#version 440
// Fluid Island neck: smooth union of the pill capsule and the droplet, drawn
// only outside both bodies so translucent glass never doubles at the junction.
// Rebuild: /usr/lib/qt6/bin/qsb --qt6 -o fluid_neck.frag.qsb fluid_neck.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 bodyBox;      // center.xy, half extent.zw (item pixels)
    vec4 dropBox;
    float bodyRadius;
    float dropRadius;
    float blend;       // smooth-union radius; 0 pinches the neck closed
    vec4 bodyColor0;      // premultiplied PillMaterial gradient stops of each end
    vec4 bodyColor1;
    vec4 bodyColor2;
    vec4 dropColor0;
    vec4 dropColor1;
    vec4 dropColor2;
    vec4 accent;       // premultiplied accent; only its hue is used
    vec4 spans;        // body top y, height; droplet top y, height
    vec4 bands;        // accent band alpha and height: body, droplet
};

float roundedBox(vec2 p, vec4 box, float radius) {
    vec2 q = abs(p - box.xy) - box.zw + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// Exact convex hull of both rounded boxes: the union of the boxes with lerped
// center, extent and radius. Distance to that family is convex in t outside.
float hull(vec2 p) {
    float lo = 0.0;
    float hi = 1.0;
    for (int i = 0; i < 14; ++i) {
        float a = mix(lo, hi, 0.382);
        float b = mix(lo, hi, 0.618);
        float da = roundedBox(p, mix(bodyBox, dropBox, a), mix(bodyRadius, dropRadius, a));
        float db = roundedBox(p, mix(bodyBox, dropBox, b), mix(bodyRadius, dropRadius, b));
        if (da < db) hi = b; else lo = a;
    }
    float t = 0.5 * (lo + hi);
    return roundedBox(p, mix(bodyBox, dropBox, t), mix(bodyRadius, dropRadius, t));
}

float coverage(float d, float aa) {
    return clamp(0.5 - d / aa, 0.0, 1.0);
}

vec4 glass(float y, float top, float height, vec4 c0, vec4 c1, vec4 c2, float bandAlpha, float bandHeight) {
    float t = clamp((y - top) / max(height, 1.0), 0.0, 1.0);
    vec4 base = t < 0.46 ? mix(c0, c1, t / 0.46) : mix(c1, c2, (t - 0.46) / 0.54);
    float wash = 0.035 + bandAlpha * (1.0 - clamp((y - top) / max(bandHeight, 1.0), 0.0, 1.0));
    return vec4(accent.rgb / max(accent.a, 1e-4), 1.0) * wash + base * (1.0 - wash);
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float d1 = roundedBox(p, bodyBox, bodyRadius);
    float d2 = roundedBox(p, dropBox, dropRadius);
    // Unit-gradient SDFs share one pixel footprint; taken in uniform control flow.
    float aa = max(fwidth(d1), 1e-4);
    float k = max(blend, 1e-4);
    float h = max(k - abs(d1 - d2), 0.0) / k;
    float du = min(d1, d2) - h * h * k * 0.25;
    // Fill the complement of each body's antialiased fringe, compensated for
    // its alpha so stacked fringes keep the glass alpha (no backdrop hairline).
    float c1 = coverage(d1, aa);
    float c2 = coverage(d2, aa);
    float neck = min(coverage(du, aa), min((1.0 - c1) / max(1.0 - c1 * bodyColor1.a, 1e-4),
                                           (1.0 - c2) / max(1.0 - c2 * dropColor1.a, 1e-4)));
    if (neck <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    // Smooth-min also inflates convex sides wherever both bodies are near; a
    // meniscus never leaves their convex hull.
    neck *= coverage(hull(p), aa);
    // Each end of the neck carries the material of the body it touches.
    float side = smoothstep(0.0, 1.0, max(d1, 0.0) / max(max(d1, 0.0) + max(d2, 0.0), 1e-4));
    vec4 color = mix(glass(p.y, spans.x, spans.y, bodyColor0, bodyColor1, bodyColor2, bands.x, bands.y),
                     glass(p.y, spans.z, spans.w, dropColor0, dropColor1, dropColor2, bands.z, bands.w),
                     side);
    fragColor = color * neck * qt_Opacity;
}
