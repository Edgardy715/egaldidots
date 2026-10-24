#version 440
// Rebuild: /usr/lib/qt6/bin/qsb --qt6 -o pet_palette.frag.qsb pet_palette.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 bodyColor;
    vec4 shadeColor;
    vec4 lightColor;
    vec4 leafColor;
    vec4 leafShadeColor;
    vec4 blushColor;
    vec4 sparkColor;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec4 pixel = texture(source, qt_TexCoord0);
    if (pixel.a < 0.5) { fragColor = vec4(0.0); return; }
    vec3 rgb = pixel.rgb;
    vec4 mapped = pixel;
    if (distance(rgb, vec3(134.0, 214.0, 196.0) / 255.0) < 0.01) mapped = bodyColor;
    else if (distance(rgb, vec3(85.0, 168.0, 152.0) / 255.0) < 0.01) mapped = shadeColor;
    else if (distance(rgb, vec3(210.0, 245.0, 236.0) / 255.0) < 0.01) mapped = lightColor;
    else if (distance(rgb, vec3(166.0, 214.0, 94.0) / 255.0) < 0.01) mapped = leafColor;
    else if (distance(rgb, vec3(95.0, 154.0, 60.0) / 255.0) < 0.01) mapped = leafShadeColor;
    else if (distance(rgb, vec3(240.0, 148.0, 143.0) / 255.0) < 0.01) mapped = blushColor;
    else if (distance(rgb, vec3(255.0, 211.0, 107.0) / 255.0) < 0.01) mapped = sparkColor;
    fragColor = vec4(mapped.rgb * pixel.a * qt_Opacity, pixel.a * qt_Opacity);
}
