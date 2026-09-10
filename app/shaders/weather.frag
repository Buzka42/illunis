#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// A bounded translucent pass AFTER the catalog, BEFORE the instrument.
// Bundled density textures, no background readback or ray march.
uniform vec2 uSize;
uniform vec2 uPrincipal;
uniform float uFocal;
uniform float uAzimuth;
uniform vec3 uSunDir;
uniform float uDayness;
uniform float uMoonLight;
uniform float uTime;
uniform float uPixelScale;
uniform float uCoverage;
uniform float uCumulus;
uniform float uRain;
uniform float uFog;
uniform float uSnow;
uniform float uCirrus;
uniform sampler2D uStratusTexture;
uniform sampler2D uCumulusTexture;
uniform sampler2D uCirrusTexture;
out vec4 fragColor;

float hash21(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}
vec2 cloudUV(vec2 p) {
  // Mirrored repetition keeps sampled edges continuous even when generated
  // opposite edges are not numerically identical. Inset avoids edge texels.
  return clamp(abs(fract(p * 0.5) * 2.0 - 1.0), vec2(0.0004), vec2(0.9996));
}
float cloudDensity(vec2 p) {
  vec2 uv = cloudUV(p);
  float low = 0.0;
  if (uCirrus < 0.999) {
    if (uCumulus < 0.999) low = texture(uStratusTexture, uv).r * (1.0 - uCumulus);
    if (uCumulus > 0.001) low += texture(uCumulusTexture, uv).r * uCumulus;
  }
  if (uCirrus > 0.001) return mix(low, texture(uCirrusTexture, cloudUV(p * 0.72 + 0.31)).r, uCirrus);
  return low;
}
vec3 rayDir(vec2 frag) {
  vec2 q = vec2(frag.x - uPrincipal.x, uPrincipal.y - frag.y) / uFocal;
  float r2 = dot(q, q), s = 4.0 / (4.0 + r2);
  return normalize(vec3(cos(uAzimuth), 0, sin(uAzimuth)) * q.x * s
      + vec3(0, q.y * s, 0)
      + vec3(sin(uAzimuth), 0, -cos(uAzimuth)) * (4.0 - r2) / (4.0 + r2));
}
float rainLayer(vec2 uv, float layer) {
  uv.x += uv.y * 0.13;
  uv.y -= uTime * (0.32 + layer * 0.18);
  vec2 grid = uv * vec2(145.0 - layer * 30.0, 38.0 + layer * 12.0);
  vec2 cell = floor(grid), f = fract(grid);
  float seed = hash21(cell + layer * 73.0);
  float x = abs(f.x - mix(0.2, 0.8, seed));
  float width = mix(0.016, 0.030, layer);
  float streak = (1.0 - smoothstep(width, width * 2.0, x))
      * smoothstep(0.1, 0.25, f.y) * (1.0 - smoothstep(0.55, 0.9, f.y));
  return streak * step(1.0 - uRain * 0.18, seed);
}
float snowLayer(vec2 uv, float layer) {
  uv.y -= uTime * (0.035 + layer * 0.024);
  uv.x += sin(uTime * 0.22 + uv.y * 3.0 + layer * 7.0) * 0.015;
  vec2 grid = uv * (65.0 - layer * 19.0);
  vec2 cell = floor(grid), f = fract(grid);
  float seed = hash21(cell + layer * 103.0);
  vec2 center = vec2(0.25 + seed * 0.5, 0.25 + hash21(cell + 19.0) * 0.5);
  float r = length(f - center);
  float radius = mix(0.035, 0.073, layer);
  return (1.0 - smoothstep(radius * 0.25, radius, r))
      * step(1.0 - uSnow * 0.12, seed);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec3 d = rayDir(frag);
  bool ground = d.y < 0.0;
  vec3 rgb = vec3(0.0);
  float alpha = 0.0;
  // Cloud coordinates are world directions, so a pager yaw looks through
  // the same cloud bank. Coverage changes thresholds, never random seeds.
  if (!ground && uCoverage > 0.001) {
    vec2 p = d.xz / sqrt(d.y + 0.24) * 0.85 + vec2(0.31, 0.47);
    p = mix(p * vec2(0.58, 1.8), p, uCumulus);
    float n = cloudDensity(p);
    float edge = mix(0.70, 0.02, uCoverage);
    float shape = smoothstep(edge, edge + 0.35, n);
    alpha = shape * mix(0.82, 0.97, uCoverage) * mix(1.0, 0.58, uCirrus);
    alpha = mix(alpha, 1.0, smoothstep(0.96, 1.0, uCoverage));
    float horizonHaze = 1.0 - smoothstep(0.0, 0.18, d.y);
    alpha = mix(alpha, max(alpha, uCoverage), horizonHaze);
    float sunFacing = pow(max(dot(d, uSunDir), 0.0), 10.0);
    // Fine opacity structure carries the volume; broad high-contrast fake
    // shadows made the previous field look like blurred low-res blobs.
    float relief = 0.82 + n * 0.25;
    vec3 daylight = vec3(0.67, 0.71, 0.76) * relief;
    daylight += vec3(0.22, 0.20, 0.16) * sunFacing * (1.0 - shape) * 0.7;
    float sunset = (1.0 - smoothstep(0.0, 0.24, abs(uSunDir.y)))
        * smoothstep(-0.12, 0.02, uSunDir.y);
    daylight = mix(daylight, vec3(0.78, 0.51, 0.36) * relief,
        sunset * sunFacing * 0.55 * (1.0 - uCoverage * 0.6));
    daylight = mix(daylight, vec3(0.64, 0.68, 0.73), horizonHaze);
    vec3 night = vec3(0.032, 0.042, 0.060) + vec3(0.10, 0.115, 0.14) * uMoonLight;
    rgb = mix(night, daylight, uDayness) * alpha;
  }
  // Fog follows optical path length. It gathers at the horizon and dies
  // rapidly toward the near ground, preserving the matte reading surface.
  if (uFog > 0.001) {
    float path = ground ? exp(d.y * 28.0) : exp(-d.y * 8.0);
    float fogAlpha = (1.0 - exp(-uFog * 3.8 * path)) * (ground ? 0.52 : 1.0);
    vec3 fogInk = mix(vec3(0.085, 0.10, 0.13), vec3(0.66, 0.70, 0.73), uDayness);
    rgb = rgb * (1.0 - fogAlpha) + fogInk * fogAlpha;
    alpha = alpha + fogAlpha * (1.0 - alpha);
  }
  if (!ground && (uRain > 0.001 || uSnow > 0.001)) {
    vec2 uv = frag / uSize.y;
    float distanceFade = smoothstep(0.0, 0.16, d.y);
    float precipitation = 0.0;
    if (uRain > 0.001) precipitation += (rainLayer(uv, 0.0) + rainLayer(uv, 1.0)) * 0.075;
    if (uSnow > 0.001) precipitation += (snowLayer(uv, 0.0) * 0.14 + snowLayer(uv, 1.0) * 0.26);
    float a = clamp(precipitation * distanceFade, 0.0, 0.7);
    vec3 tint = mix(vec3(0.32, 0.36, 0.43), vec3(0.86, 0.89, 0.92), uDayness);
    rgb = rgb * (1.0 - a) + tint * a;
    alpha = alpha + a * (1.0 - alpha);
  }
  // Premultiplied output, dithered in display space just like the sky.
  vec2 pixel = floor(frag * uPixelScale);
  float dither = (hash21(pixel) + hash21(pixel + vec2(17, 59)) - 1.0) / 255.0;
  fragColor = vec4(clamp(rgb + dither * alpha, 0.0, alpha), alpha);
}
