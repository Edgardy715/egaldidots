#version 440
// Rebuild after edits: cd bar/components/shaders && /usr/lib/qt6/bin/qsb --qt6 -o playdrops.frag.qsb playdrops.frag
// Gota de play: cuatro cápsulas verticales (segmento + radio) unidas con una
// unión suave. Juntas en el centro son una sola esfera; al separarse se
// estiran en cuellos y quedan como columnas líquidas de ecualizador.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 b0; vec4 b1; vec4 b2; vec4 b3; // x, media altura, radio, -
    float goo;                          // radio de la unión suave, en px
    vec4 colorA;
    vec4 colorB;
};

float capsule(vec2 p, vec4 b) {
    vec2 q = vec2(p.x - b.x, max(abs(p.y - itemSize.y * 0.5) - b.y, 0.0));
    return length(q) - b.z;
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float k = max(goo, 1e-3);
    float d = smin(smin(capsule(p, b0), capsule(p, b1), k), smin(capsule(p, b2), capsule(p, b3), k), k);
    float w = max(fwidth(d), 1e-4);
    float a = clamp(0.5 - d / w, 0.0, 1.0);
    vec4 c = mix(colorA, colorB, clamp((qt_TexCoord0.x + qt_TexCoord0.y) * 0.5, 0.0, 1.0));
    fragColor = vec4(c.rgb * c.a, c.a) * a * qt_Opacity;
}
