# 059: Ari's logo as SVG

Status: todo.

Plod's logo is PNG for now (`docs/assets/`, 2026-10-22), cropped from a raster
illustration of Ari, a banana slug, on a branch. Draw it as low-poly SVG built from
triangles, in the style of Species in Pieces, so it scales, stays small, and animates.
Task 046 has the brand: the name, the slogan "Takes its time, not yours.", and the
mascot.

## Acceptance criteria

- [ ] Ari is drawn from flat-filled triangles, in the hero's yellow on a dark green
      ground, with all four tentacles: two long upper ones with eyes at the tips and
      two short lower ones
- [ ] Variants: a horizontal lockup (Ari, "Plod", and the slogan), a square icon, and a
      favicon simple enough to read at 16 px
- [ ] Each triangle is its own element with a stable id, so FFFrames can animate Ari
      (a tentacle's reach, a slow crawl) without redrawing; one animation is checked
      in FFFrames
- [ ] The SVGs replace the PNGs in `docs/assets/` and the README's header, and the
      512 px PNG exported from the icon replaces the GitHub social avatar
