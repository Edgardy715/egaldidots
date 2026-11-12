#version 440
// Liquid password beads: the bead layer arrives blurred, and this pass turns
// its alpha field back into a crisp surface, so beads that come close fuse.
// Rebuild after edits: cd bar/lockscreen/shaders && /usr/lib/qt6/bin/qsb --qt6 -o drops.frag.qsb drops.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 ink;
    float threshold;
    float softness;
    float sheen;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    float field = texture(source, qt_TexCoord0).a;
    float a = smoothstep(threshold - softness, threshold + softness, field);
    // Denser centres read a touch brighter: a faint body instead of a flat cutout.
    float body = smoothstep(threshold, 1.0, field);
    vec3 color = mix(ink.rgb, mix(ink.rgb, vec3(1.0), 0.35), body * sheen);
    fragColor = vec4(color * a, a) * ink.a * qt_Opacity;
}
