#version 440
// Rebuild after edits: cd bar/body/shaders && /usr/lib/qt6/bin/qsb --qt6 -o body.frag.qsb body.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float time;
    float designScale;
    float aaPx;
    float fusionRadius;
    float warm, glow, night, spec, wallMix;
    float outsideOpacity;
    vec4 pill;
    vec4 bulge;
    vec4 drop0; vec4 drop1; vec4 drop2; vec4 drop3;
    vec4 companionBox0; vec2 companionShape0;
    vec4 companionBox1; vec2 companionShape1;
    vec4 companionBox2; vec2 companionShape2;
    vec4 companionBox3; vec2 companionShape3;
    vec4 companionBox4; vec2 companionShape4;
    vec2 lightDir;
    vec2 wallOrigin;
    vec4 wallXform;
    vec4 colA; vec4 colB; vec4 colC; vec4 colBg;
    vec4 colBase;
    vec4 colTop;
    float fillAlpha;
    float pillRadius;
    float water, reading, edgeExposure, shadowExposure;
};
layout(binding = 1) uniform sampler2D wallpaper;

// pillRadius < 0 keeps the stadium; a smaller radius follows the surface corners.
float sdStadium(vec2 p, vec2 b) {
    float r = pillRadius < 0.0 ? b.y : min(min(b.x, b.y), pillRadius);
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}
float companionUnion(float d, vec2 p, vec4 box, vec2 shape) {
    if (box.z <= 0.0 || box.w <= 0.0 || water < 0.5) return d;
    float r = min(shape.x, min(box.z, box.w));
    vec2 q = abs(p - box.xy) - box.zw + vec2(r);
    float drop = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    return shape.y > 0.001 ? smin(d, drop, shape.y) : min(d, drop);
}
float scene(vec2 p) {
    float d = sdStadium(p - pill.xy, pill.zw);
    if (bulge.z > 0.0 && bulge.w > 0.001) d = smin(d, length(p - bulge.xy) - bulge.z, fusionRadius * bulge.w);
    if (drop0.w > (water > 0.5 ? 0.001 : 0.5))
        d = smin(d, length(p - drop0.xy) - drop0.z, fusionRadius * (water > 0.5 ? drop0.w : 1.0));
    if (drop1.w > 0.5) d = smin(d, length(p - drop1.xy) - drop1.z, fusionRadius);
    if (drop2.w > 0.5) d = smin(d, length(p - drop2.xy) - drop2.z, fusionRadius);
    if (drop3.w > 0.5) d = smin(d, length(p - drop3.xy) - drop3.z, fusionRadius);
    d = companionUnion(d, p, companionBox0, companionShape0);
    d = companionUnion(d, p, companionBox1, companionShape1);
    d = companionUnion(d, p, companionBox2, companionShape2);
    d = companionUnion(d, p, companionBox3, companionShape3);
    d = companionUnion(d, p, companionBox4, companionShape4);
    return d;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec3 wall(vec2 p) {
    if (wallMix > 0.5) {
        vec2 uv = (wallOrigin + p) * wallXform.xy + wallXform.zw;
        return texture(wallpaper, clamp(uv, 0.0, 1.0)).rgb * (1.0 - 0.6 * night);
    }
    float asp = itemSize.x / itemSize.y;
    vec2 q = vec2((p.x / itemSize.x) * asp, p.y / itemSize.y);
    float t = time * 0.04;
    vec3 c = colBg.rgb;
    c = mix(c, colA.rgb, 0.9 * exp(-2.6 * length(q - vec2(0.18 * asp + 0.06 * sin(t), 1.05))));
    c = mix(c, colB.rgb, 0.8 * exp(-2.3 * length(q - vec2(0.86 * asp + 0.08 * cos(t * 1.3), 0.05))));
    c = mix(c, colC.rgb, 0.65 * exp(-3.2 * length(q - vec2(0.55 * asp, 0.78 + 0.05 * sin(t * 0.7)))));
    return c * (1.0 - 0.6 * night);
}
void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float d = scene(p);
    // Three stops match PillMaterial, including the reading opacity and darker foot.
    float y = clamp((p.y - pill.y + pill.w) / max(1.0, 2.0 * pill.w), 0.0, 1.0);
    float topA = min(1.0, fillAlpha + 0.08 * reading);
    float botA = min(1.0, fillAlpha + 0.04 * reading);
    vec4 top = vec4(colTop.rgb * topA, topA);
    vec4 mid = vec4(colBase.rgb * fillAlpha, fillAlpha);
    vec4 bot = vec4(colBase.rgb / (1.0 + 0.16 * reading) * botA, botA);
    vec4 tint = y < 0.46 ? mix(top, mid, y / 0.46) : mix(mid, bot, (y - 0.46) / 0.54);
    float grain = (hash(p + (water > 0.5 ? 0.0 : fract(time))) - 0.5) * (2.0 / 255.0);
    if (water > 0.5 && d < -11.0 * designScale) {
        fragColor = vec4(tint.rgb + grain, tint.a) * qt_Opacity;
        return;
    }
    float ds = scene(p - vec2(0.0, (water > 0.5 ? 7.0 : 9.0) * designScale));
    // La transmisión del HTML se convierte en opacidad, cero lejos del cuerpo.
    float shadowA = (water > 0.5 ? 0.32 * 0.72 : 0.5)
        * (1.0 - smoothstep(-6.0 * designScale, 30.0 * designScale, ds));
    float auraI = glow * 0.6 * exp(-max(d, 0.0) / (15.0 * designScale));
    float auraA = 0.5 * auraI;
    vec3 auraRgb = colC.rgb * auraA;
    vec2 e = vec2(0.75 * designScale, 0.0);
    vec2 n = normalize(vec2(scene(p + e.xy) - scene(p - e.xy), scene(p + e.yx) - scene(p - e.yx)) + 1e-6);
    float edge = 1.0 - clamp(-d / (11.0 * designScale), 0.0, 1.0);
    vec3 refr = wall(p + n * edge * edge * 24.0 * designScale);
    // Same tint and transmission as PillMaterial (cardTop -> cardBot at fillAlpha);
    // the compositor blur shows through the core and the rim lenses the wallpaper.
    float yTint = clamp((p.y - pill.y + pill.w) / (0.92 * pill.w), 0.0, 1.0);
    vec3 base = mix(colTop.rgb, colBase.rgb, yTint);
    float rim = water > 0.5 ? edgeExposure : 1.0;
    float lens = 0.55 * pow(edge, 3.0) * rim;
    vec3 glass = base * fillAlpha * (1.0 - lens) + refr * lens;
    float glassA = fillAlpha * (1.0 - lens) + lens;
    if (water > 0.5) {
        glass = tint.rgb * (1.0 - lens) + refr * lens;
        glassA = tint.a * (1.0 - lens) + lens;
    }
    vec3 lc = mix(vec3(0.82, 0.88, 1.0), vec3(1.0, 0.74, 0.48), warm);
    glass += lc * pow(max(dot(n, lightDir), 0.0), 2.0) * pow(edge, 5.0) * spec * rim;
    glass += colB.rgb * max(dot(n, -lightDir), 0.0) * pow(edge, 6.0) * 0.22 * rim;
    glass += colC.rgb * glow * pow(edge, 2.5) * 0.55 * rim;
    float a = clamp(0.5 - d / aaPx, 0.0, 1.0);
    glass += grain;
    vec3 rgb = glass * a + auraRgb * (1.0 - a) * outsideOpacity;
    // Water shadow is independent of aura; its peak stays below Hyprland ignore_alpha.
    float outsideA = water > 0.5 ? min(shadowA, 0.14) * shadowExposure + auraA * outsideOpacity
        : clamp(shadowA + auraA, 0.0, 1.0) * outsideOpacity;
    float alpha = glassA * a + (1.0 - a) * clamp(outsideA, 0.0, 1.0);
    fragColor = vec4(rgb, alpha) * qt_Opacity;
}
