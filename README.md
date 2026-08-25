# Circle Sans

**Circle Sans** is a fork of [Albert Sans](https://github.com/usted/Albert-Sans) with three
deliberate differences. Everything else — outlines, spacing, kerning, the `wght` and `wdth`
axes, the language coverage — is Albert Sans unchanged.

| Change | What it means |
|---|---|
| **New `Q`** | The tail is a diagonal stroke crossing the bowl at the lower right, replacing the centred vertical bar that read as the Quake logo. A fixed `−52°` at every weight and width. |
| **Frozen alternates** | The long-stem `g` and the open "et" ampersand are now the defaults — no `font-feature-settings` required. |
| **Tabular figures by default** | Digits are tabular out of the box, so numbers line up in tables and UI without extra CSS. |

Nothing is lost by freezing: the original shapes stay reachable in the slots they used to
occupy. `ss02` now returns the *original* short-stem `g`, `ss04` the *original* ampersand,
and `pnum` gives back proportional figures.

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

You should not need `font-feature-settings` for the long-stem `g`, the open ampersand or
tabular figures — those are the defaults now. Reach for a feature only to opt *out*:

```css
.proportional-figures { font-feature-settings: "pnum" 1; }  /* proportional digits    */
.original-g           { font-feature-settings: "ss02" 1; }  /* short-stem g           */
.original-ampersand   { font-feature-settings: "ss04" 1; }  /* the closed ampersand   */
```

## Credits

Circle Sans is a fork of **Albert Sans**, a modern geometric sans serif inspired by the
type-characteristics of Scandinavian architects and designers in the early 20th century,
designed by the Danish type designer **Andreas Rasmussen** of a.Foundry. All of the original
design work is his; this fork only redraws the `Q` and changes which alternates are default.

Albert Sans is licensed under the SIL Open Font License 1.1, and so is Circle Sans.

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

**25 Aug 2026 — forked from Albert Sans v1.31**
- Renamed the family to Circle Sans
- Redrew the `Q` tail as a diagonal stroke crossing the bowl, fixed at −52° across the designspace
- Froze the long-stem `g` and the open ampersand in as defaults
- Made tabular figures the default, keeping `pnum` as the way back

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
