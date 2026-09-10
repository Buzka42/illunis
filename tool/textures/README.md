# Cloud texture assets — 2026-09-09

Generated with the built-in image-generation tool in response to the user's
request for higher-resolution clouds and different cloud types. No API key,
runtime image generation or runtime download is involved.

Runtime assets (original generated PNGs, 1254×1254 each):

- [Cumulus](../../app/assets/sky/clouds/cumulus.png): rounded scattered formations.
- [Stratus](../../app/assets/sky/clouds/stratus.png): continuous soft sheet.
- [Cirrus](../../app/assets/sky/clouds/cirrus.png): fine high-cloud filaments.

The tool returned 1254×1254 despite the requested 2048 size. The images have
not been upscaled or presented as 2048. Combined PNG size is 6,564,725 bytes;
three RGBA decoded textures require approximately 18.0 MiB per Flutter engine,
excluding GPU copies/driver overhead. They are loaded once and shared between
views within an engine. The initial
[stratocumulus study](stratocumulus-reference.png) is retained for review but
is not shipped as a runtime asset.

`weather.frag` samples grayscale density, applies coverage/morphology, and
relights it for Sun/Moon/dayness. `cumulus` blends stratus→cumulus, `cirrus`
blends toward the high-cloud texture. The sampler uses mirrored coordinates
and a half-texel inset so generated opposite edges need not match exactly.
These are generated visual approximations, not observed meteorology or
scientifically measured optical-depth maps. The textures replace the previous
procedural cloud noise; precipitation and fog remain computed by the shader.

## Exact prompt set

Built-in generation, one image per following suffix appended to this common prompt:

> Generate one square high-resolution grayscale seamless tileable cloud density texture, edge-to-edge, intended for a mobile sky shader. This is a technical density map: black means clear air, white means dense cloud, intermediate grays are translucent wisps. Orthographic view with NO horizon, ground, blue sky, sun, stars, text, labels, border or watermark. Neutral diffuse illumination without baked directional shadows. Natural finely resolved cloud detail, not blurred procedural blobs, no central subject, no obvious repeated stamps. Request native 2048x2048 detail if available.

Cumulus:

> Scattered fair-weather CUMULUS seen from below looking straight up: varied rounded cotton cloud formations, realistic turbulent feathered edges and internal fine detail, substantial clear gaps between clouds, roughly 40 percent cloud coverage, no towering storm anvils or dramatic shadows.

Stratus:

> Natural STRATUS: a quiet almost continuous cloud sheet, layered soft translucent veils and subtle mottled fine-scale density variation, no separate cauliflower cloud piles, no dramatic dark contrasts. Full-frame variations from mid-gray thin areas to pale dense areas, organic nonuniform detail with no obvious blurry blobs.

Cirrus:

> Natural CIRRUS: sparse long delicate ice-cloud filaments and wispy feathered streaks with fine hairlike structure, varied diagonal curvature and flowing streamers, large areas of dark clear air, roughly 25 percent cloud coverage. No cumulus puffs, no dense fog, no storm piles. Crisp yet naturally feathery filaments.

Initial study prompt:

> Use case: photorealistic-natural. Asset type: high-resolution grayscale cloud DENSITY texture for a real-time mobile sky shader, square 2048 by 2048 or higher. Generate one production texture only, edge-to-edge, seamless tileable in both axes. An orthographic view of natural broken stratocumulus cloud cover, many varied medium and small formations, delicate wispy transitions and finely resolved turbulent cloud edges, organic multiscale detail like satellite cloud optical depth but without terrain. Neutral grayscale: near black represents clear air, pale gray and white represent increasing cloud density, continuous intermediate gray wisps. Roughly half the image clear or thin haze and half varied cloud density, balanced distribution without an obvious central subject. Even diffuse illumination, no baked directional cast shadows or sun glare, no horizon, no blue sky, no landscape, no stars, no rain, no snow, no labels, no borders, no text, no watermark. Avoid blurred blobs, coarse smooth noise, dramatic storm contrast, cauliflower piles, obvious repeated stamps. This is a technical density map to be sampled and relit, not a finished photograph of a sky.
