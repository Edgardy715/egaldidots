#version 440
// Fluid Island droplet cut: removes the part of a droplet lying inside the
// receiving pill, so translucent glass never stacks while they are joined.
// Uses the same rounded-box SDF as fluid_neck.frag. Both edges antialias over
// each other, so the complement is compensated for the pill's own alpha:
// a pill fringe c*a under a droplet fringe x*a stays at a when
// x = (1 - c) / (1 - c*a); plain 1 - c lets the backdrop show as a hairline.
// Rebuild: /usr/lib/qt6/bin/qsb --qt6 -o fluid_cut.frag.qsb fluid_cut.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 bodyBox;      // center.xy, half extent.zw (item pixels)
    float bodyRadius;
    float bodyAlpha;   // glass alpha of the receiving pill
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 q = abs(p - bodyBox.xy) - bodyBox.zw + bodyRadius;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - bodyRadius;
    float inside = clamp(0.5 - d / max(fwidth(d), 1e-4), 0.0, 1.0);
    float outside = (1.0 - inside) / max(1.0 - inside * bodyAlpha, 1e-4);
    fragColor = texture(source, qt_TexCoord0) * outside * qt_Opacity;
}
