# 059: Ari's logo as SVG

Status: in-progress.

Plod's logo was PNG only (`docs/assets/`, 2026-10-22), cropped from a raster
illustration of Ari, a banana slug, on a branch. Draw it as low-poly SVG built from
triangles, in the style of Species in Pieces, so it scales, stays small, and animates.
Task 046 has the brand: the name, the slogan "Takes its time, not yours.", and the
mascot.

The raster stays where the illustration is shown as a picture, the README header and
the social preview, because its blurred ground looks softer than the traced one
(2026-10-23). The SVGs serve animation, videos, and the small sizes. The header PNG is
808 KB; as AVIF at quality 70 it's 36 KB and looks the same, if GitHub shows AVIF in a
README.

## Acceptance criteria

- [x] Ari is drawn from flat-filled faces, in the hero's yellow on a dark green
      ground, with all four tentacles: two long upper ones with eyes at the tips and
      two short lower ones. The faces are triangles merged where one fill fits, up to
      five sides, each flat or a two-stop gradient (accepted 2026-10-23)
- [x] Variants: a horizontal lockup (Ari, "Plod", and the slogan), a square icon, and a
      favicon simple enough to read at 16 px. The words are outlines of Archivo
      (weight 900, width 125) and Inter, both under the OFL; the favicon is drawn by
      hand on a 32-unit grid
- [ ] Each face is its own element with a stable id, so FFFrames can animate Ari
      (a tentacle's reach, a slow crawl) without redrawing; one animation is checked
      in FFFrames. The ids are in place: groups `ground`, `parts`, `branch`, `ari`,
      and `leaves`, and faces `<part>-<n>`
- [x] The SVGs are in `docs/assets/`, and the 512 px icon and the 96, 32, and 16 px
      favicons are exported from them: the icon and the 96 px favicon from
      `plod-icon.svg`, the 32 and 16 px from `plod-favicon.svg`
- [ ] The 512 px icon replaces the GitHub social avatar (a settings change on GitHub)

## Sizes

The traced scene was 323 KB. Coordinates on a quarter-pixel integer grid, and faces
under one square pixel dropped, give 286 KB (52 KB gzipped), with a mean CIE76
difference of 0.05 from the accepted render. No two gradients are identical, so none
are shared. 225 KB is reachable with 16 ground levels instead of 32 and near-flat
gradients made flat, at a mean difference of 1.45; the ground then shifts a little, so
it wasn't taken.

| File | Bytes | Gzipped |
|---|---|---|
| `plod-hero.svg` | 297,808 | 56,654 |
| `plod-icon.svg` | 162,462 | 31,958 |
| `plod-lockup.svg` | 158,189 | 32,969 |
| `plod-favicon.svg` | 2,208 | 693 |
