# Circle Sans

**Circle Sans** is a fork of [Albert Sans](https://github.com/usted/Albert-Sans) with four
deliberate differences — two redraws and two additions. Everything else — outlines, spacing,
figures, the `wght` and `wdth` axes, the language coverage — is Albert Sans unchanged.

| Change | What it means |
|---|---|
| **New `Q`** | The tail is a diagonal stroke crossing the bowl at the lower right, replacing the centred vertical bar that read as the Quake logo. A fixed `−52°` at every weight and width. |
| **Frozen alternates** | The long-stem `g` and the open "et" ampersand are now the defaults — no `font-feature-settings` required. |
| **New `ff` ligature** | Albert Sans draws an `fi` but no `ff`, so *Kaffee*, *Koffein* and *Coffee* collided two crossbars and were kerned apart to hide it. The new one follows the `fi`'s own logic and is on by default. |
| **The drip mark** | The Coffee Circle logo as a glyph. Type `[drip]`, or use `U+E000`. Drawn once and identical in all twelve masters, so it never gains weight, narrows or slants. |

Nothing is lost by freezing: the original shapes stay reachable in the slots they used to
occupy. `ss02` returns the *original* short-stem `g`, and `ss04` the *original* ampersand.

[![][Fontbakery]](https://slcr.github.io/circle-sans/fontbakery/fontbakery-report.html)
[![][Universal]](https://slcr.github.io/circle-sans/fontbakery/fontbakery-report.html)
[![][Font File]](https://slcr.github.io/circle-sans/fontbakery/fontbakery-report.html)
[![][Outline]](https://slcr.github.io/circle-sans/fontbakery/fontbakery-report.html)
[![][Shaping]](https://slcr.github.io/circle-sans/fontbakery/fontbakery-report.html)

[Fontbakery]: https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fslcr%2Fcircle-sans%2Fgh-pages%2Fbadges%2Foverall.json
[Font File]: https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fslcr%2Fcircle-sans%2Fgh-pages%2Fbadges%2FFontFileChecks.json
[Outline]: https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fslcr%2Fcircle-sans%2Fgh-pages%2Fbadges%2FOutlineChecks.json
[Shaping]: https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fslcr%2Fcircle-sans%2Fgh-pages%2Fbadges%2FShapingChecks.json
[Universal]: https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fslcr%2Fcircle-sans%2Fgh-pages%2Fbadges%2FUniversalProfileChecks.json

![Sample Image](documentation/image1.png)

## Installing it

**Install Circle Sans.app** fetches the newest release and installs it, so nobody has to
work out which zip is current — the point being that a stale Circle Sans looks exactly like
a fresh one until a glyph is missing. Build it with `scripts/build-installer-app.sh`, or run
`scripts/install-circle-sans.sh` from a terminal to do the same thing without the app.

Either way it sets aside every Circle Sans already installed before copying the new files
in, since two families of the same name leave macOS to pick between them. What it replaces
is kept in `~/Library/Application Support/Circle Sans/`. Fonts in `~/Library/Fonts` are
active as soon as they land, but apps hold their own copy in memory — Figma and browsers
need a full quit and reopen, not just a reload.

The app is unsigned, because signing needs a paid Apple Developer account. A Mac that
downloaded it through a browser or Slack will refuse the first double-click; right-click it,
choose **Open**, and macOS remembers from then on. Passing it around on a mounted drive
avoids the warning altogether.

## Using it

Nine weights (Thin to Black) in two widths (Normal and Narrow), roman and italic, as a
variable font.

```css
@font-face {
  font-family: "Circle Sans";
  src: url("CircleSans[wdth,wght].woff2") format("woff2-variations");
  font-weight: 100 900;
  font-stretch: 87.5% 100%;
  font-style: normal;
}
```

You should not need `font-feature-settings` for the long-stem `g` or the open ampersand —
those are the defaults now. Reach for a feature only to opt *out*:

```css
.original-g         { font-feature-settings: "ss02" 1; }  /* short-stem g         */
.original-ampersand { font-feature-settings: "ss04" 1; }  /* the closed ampersand */
```

### Ligatures

`fi` and `ff` are standard ligatures, so every browser and app applies them with no CSS at
all. There is one trap worth knowing about, and it is a rendering-engine rule rather than
anything in the font: **WebKit drops ligatures on letter-spaced text**, and no declaration
brings them back. A tracked headline shows two loose `f` in Safari while looking correct in
Chrome. Keep styles that can carry an `ff` or `fi` untracked:

```css
h1, .hero { letter-spacing: 0; }  /* tracking here costs the ff in Safari */
```

Blink keeps ligatures under tracking only when they are asked for explicitly, so it is worth
declaring them once for the whole page:

```css
body { font-variant-ligatures: common-ligatures; }
```

### The drip mark

Typing `[drip]` resolves to the logo. Only the exact sequence does — `[dripping]` and an
unclosed `[drip` are left alone:

```html
<p>Coffee Circle [drip]</p>
```

Since that substitution is itself a ligature, it falls back to a literal `[drip]` under
letter-spacing in Safari. Wherever a style carries tracking, use the codepoint instead,
which is never subject to the tracking rule:

```html
<p>Coffee Circle &#xE000;</p>
```

The mark sits on the baseline like a descending letter: the drip tip rests on the descender,
the ring meets cap height, 744 units wide. It takes `currentColor` and scales with
`font-size`, so it needs no SVG to place or recolour.

### Figures

Figures are **proportional by default**, which is right for running text — tabular digits
are padded to a uniform width and go visibly gappy in prose.

Switch to tabular only where digits need to line up in a column, or where a number updates
in place and would otherwise jitter as digits change:

```css
.price,
.cart-total,
.order-table td,
.qty-stepper { font-variant-numeric: tabular-nums; }
```

## Credits

Circle Sans is a fork of **Albert Sans**, a modern geometric sans serif inspired by the
type-characteristics of Scandinavian architects and designers in the early 20th century,
designed by the Danish type designer **Andreas Rasmussen** of a.Foundry. All of the original
design work is his; this fork redraws the `Q`, changes which alternates are default, and adds
an `ff` ligature and the Coffee Circle mark.

Albert Sans is licensed under the SIL Open Font License 1.1, and so is Circle Sans. The drip
outlines ship inside an OFL font and travel under that licence like every other glyph;
trademark is what protects the mark itself.

## Building

Fonts are built automatically by GitHub Actions - take a look in the "Actions" tab for the latest build.

If you want to build fonts manually on your own computer:

* `make build` will produce font files.
* `make test` will run [FontBakery](https://github.com/googlefonts/fontbakery)'s quality assurance tests.
* `make proof` will generate HTML proof files.

The proof files and QA tests are also available automatically via GitHub Actions - look at [https://slcr.github.io/circle-sans](https://slcr.github.io/circle-sans).

## Changelog

[Font Versioning](https://github.com/googlefonts/gf-docs/tree/main/Spec#font-versioning) follows semver.

### Circle Sans

**2 Sep 2026 — v1.6**
- Digits no longer kern against the comma and the period. Albert Sans 1.3 rebuilt its
  kerning and tucked both separators under the overhang of a `7` or `9` — `9,` is −102 and
  `7.` −111 at Bold, −125 at Black — and pulled the following `1` in under the comma. In a
  price at 18 px the comma sat 2.6 px from the 9's tail instead of 5.4, and *9,90 €* read as
  one shape.
  The 57 group pairs per master between the ten digit classes and `comma`, `comma.ss01` and
  `period` are gone, in all twelve masters, roman and italic, both comma styles. 342 entries
  per source, nothing else touched.
- Only pairs where a digit meets a separator change. `e,` `r,` `y,` and every other
  letter-to-comma pair keep their values, as do digit-to-digit pairs, so a sentence is spaced
  as before and only its numbers open up.
- The comma itself is untouched. Its bounding box shows a negative left sidebearing, but that
  is the tail tip below the baseline, where no digit has ink; shifting it would only open
  every letter-to-comma pair by the same amount.
- First spacing change since the fork; all earlier changes were to outlines or features.

**27 Aug 2026 — v1.5**
- The Coffee Circle mark is now a glyph. Type `[drip]` — a `liga` rule sitting after the
  ff rule — or reach it directly at `U+E000`. The logo now travels wherever the font
  does, at text size, on the baseline, in `currentColor`, with no SVG to place or recolour.
- Sized so the drip tip rests on the descender and the ring meets the cap height, so it
  sits in a line the way a descending letter does rather than a pasted-in image. 744 units
  wide, 56 a side. The ring is a little smaller than a cap `O` as a result.
- Drawn once and identical in all twelve masters on purpose — the mark must not gain
  weight along `wght`, narrow along `wdth`, or slant in the italic. It compiles with no
  variation deltas at all.
- `[dripping]` and an unclosed `[drip` are left alone; only the exact sequence resolves.
- Safari's tracking rule from v1.4 applies here too: a letter-spaced headline shows a
  literal `[drip]`. That reads as a tag rather than as damage, but it isn't the mark —
  use `U+E000` wherever the style carries tracking.
- The outlines ship inside an OFL font and travel under that licence. Trademark still
  protects the mark itself, which is what actually matters for a logo.

**27 Aug 2026 — v1.4**
- New `f_f` ligature, on by default through `liga`. Drawn after the fi's own logic:
  first arm trimmed the way fi trims it, one fused crossbar, the second stem planted
  where fi plants its dotted stem. Until now the two f were kerned +34 units apart to
  soften the crossbar clash. Drawn in all twelve masters — roman, italic and Narrow —
  with kerning mirrored from `f` on both flanks. First outline addition since the fork.
- `ffi` still resolves as f + fi: the ff rule sits after the fi rule on purpose.
- The specimen shows the complete character set (grouped, one section open at a time)
  and embeds its own webfont, so it renders correctly opened straight from disk, without
  falling back to whatever Circle Sans is installed.
- Ligatures and `letter-spacing` don't mix in Safari: WebKit drops them on any tracked
  text and no CSS re-enables them. Keep styles that can carry ff or fi untracked — the
  specimen's own display styles lost their tracking for exactly this reason.

**26 Aug 2026 — v1.3**
- Manufacturer, vendor URL and OS/2 vendor ID now read Coffee Circle,
  `https://www.coffeecircle.com` and `CCIR`. They previously read a.Foundry,
  `a-foundry.com` and `AFOU` - a.Foundry's registered vendor ID - which credited them
  for a binary they never produced and sent support questions to their site.
- The designer fields are unchanged and still name Andreas Rasmussen. The design is
  his; only the publisher changed.
- `CCIR` is pending registration with Microsoft, so FontBakery's `vendor_id` check
  reports it as unrecognised until the registry catches up. See `fontbakery.yaml`.
- Builds off `main` now carry their own version (`1.20N`, counting commits since the
  last tag), so a development build can no longer be mistaken for a release.
- No outline changes since v1.2.

**25 Aug 2026 — v1.2**
- The font version now tracks the release tag, so two builds can no longer claim the
  same version. v1.0 and v1.1 both reported 1.310, inherited from Albert Sans 1.31.
- The specimen is now the GitHub Pages landing page.
- No outline changes since v1.1.

**25 Aug 2026 — v1.1**
- Reverted tabular figures to proportional. Tabular is right for price columns and
  live-updating numbers, but it goes gappy in running text, and Circle Sans is used for
  both. Apply `font-variant-numeric: tabular-nums` per component instead.

**25 Aug 2026 — v1.0, forked from Albert Sans v1.31**
- Renamed the family to Circle Sans
- Redrew the `Q` tail as a diagonal stroke crossing the bowl, fixed at −52° across the designspace
- Froze the long-stem `g` and the open ampersand in as defaults

### Albert Sans (upstream history)

**12 Aug 2021. Version 1.00**
- Initial release

**28 Aug 2021. Version 1.01**
- Outline corrections
- Stem corrections
- Angle adjustments

**30 Aug 2021. Version 1.02**
- Updated outlines
- Two new glyphs added
- Spacing adjustments

**02 Sep 2021. Version 1.03**
- Minor glyph width adjustments
- Minor spacing adjustments

**23 Sep 2021. Version 1.10**
- Glyph width adjustments
- New ampersand and alternates added

**06 Nov 2021. Version 1.11**
- Fixed a, s, S
- Improved OT features

**20 Nov 2021. Version 1.20**
- Minor weight adjustments
- A variety of new glyphs to support more languages 

**30 Dec 2021. Version 1.21**
- Updated kerning
 
**25 Feb 2022. Version 1.22**
- Minor adjustments

**13 Mar 2022. Version 1.23**
- Minor adjustments

**11 Apr 2022. Version 1.24**
- Minor adjustments

**23 May 2022. Version 1.25**
- Minor adjustments


**01 Mar 2024. Version 1.3**
- Added Width-axis with Narrow
- Spacing adjustments
- Extensive kerning update
- Added glyphs, including tabular numbers
- Glyphs adjustments






## License

This Font Software is licensed under the SIL Open Font License, Version 1.1.
This license is copied below, and is also available with a FAQ at
https://scripts.sil.org/OFL

## Repository Layout

This font repository structure is inspired by [Unified Font Repository v0.3](https://github.com/unified-font-repository/Unified-Font-Repository), modified for the Google Fonts workflow.
