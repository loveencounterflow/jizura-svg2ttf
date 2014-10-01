"use strict"

_ = require("lodash")
DOMParser = require("xmldom").DOMParser
math = require("./math")
xpath = require("xpath")
TRM = require("coffeenode-trm")
debug = TRM.get_logger("debug", "svg2ttf/svg")
rpr = TRM.rpr.bind(TRM)

# supports multibyte characters
getUnicode = (character) ->
  if character.length is 1

    # 2 bytes
    character.charCodeAt 0
  else if character.length is 2

    # 4 bytes
    surrogate1 = character.charCodeAt(0)
    surrogate2 = character.charCodeAt(1)

    #jshint bitwise: false
    ((surrogate1 & 0x3ff) << 10) + (surrogate2 & 0x3ff) + 0x10000
getGlyph = (glyphElem) ->
  glyph = {}
  glyph.d = glyphElem.getAttribute("d")
  if glyphElem.getAttribute("unicode")
    glyph.character = glyphElem.getAttribute("unicode")
    glyph.unicode = getUnicode(glyph.character)
  glyph.name = glyphElem.getAttribute("glyph-name")
  glyph.width = parseInt(glyphElem.getAttribute("horiz-adv-x"), 10)  if glyphElem.getAttribute("horiz-adv-x")
  glyph
load = (str) ->
  attrs = undefined
  doc = (new DOMParser()).parseFromString(str, "application/xml")
  metadata = doc.getElementsByTagName("metadata")[0]

  # debug( doc );
  # debug( xpath.select( 'svg/*', doc ) );
  paths = doc.getElementsByTagName("path")
  idx = 0

  while idx < paths.length
    path = paths[idx]
    debug rpr(path.getAttribute("id"))
    idx++
  fontElem = doc.getElementsByTagName("font")[0]
  throw new Error("unable to locate SVG font element")  unless fontElem?
  fontFaceElem = fontElem.getElementsByTagName("font-face")[0]
  font =
    id: fontElem.getAttribute("id") or "fontello"
    familyName: fontFaceElem.getAttribute("font-family") or "fontello"
    glyphs: []
    stretch: fontFaceElem.getAttribute("font-stretch") or "normal"


  # Doesn't work with complex content like <strong>Copyright:></strong><em>Fontello</em>
  font.metadata = metadata.textContent  if metadata and metadata.textContent

  # Get <font> numeric attributes
  attrs =
    width: "horiz-adv-x"

    #height:       'vert-adv-y',
    horizOriginX: "horiz-origin-x"
    horizOriginY: "horiz-origin-y"
    vertOriginX: "vert-origin-x"
    vertOriginY: "vert-origin-y"

  _.forEach attrs, (val, key) ->
    font[key] = parseInt(fontElem.getAttribute(val), 10)  if fontElem.hasAttribute(val)
    return


  # Get <font-face> numeric attributes
  attrs =
    ascent: "ascent"
    descent: "descent"
    unitsPerEm: "units-per-em"

  _.forEach attrs, (val, key) ->
    font[key] = parseInt(fontFaceElem.getAttribute(val), 10)  if fontFaceElem.hasAttribute(val)
    return

  font.weightClass = fontFaceElem.getAttribute("font-weight")  if fontFaceElem.hasAttribute("font-weight")
  missingGlyphElem = fontElem.getElementsByTagName("missing-glyph")[0]
  if missingGlyphElem
    font.missingGlyph = {}
    font.missingGlyph.d = missingGlyphElem.getAttribute("d") or ""
    font.missingGlyph.width = parseInt(missingGlyphElem.getAttribute("horiz-adv-x"), 10)  if missingGlyphElem.getAttribute("horiz-adv-x")
  _.forEach fontElem.getElementsByTagName("glyph"), (glyphElem) ->
    font.glyphs.push getGlyph(glyphElem)
    return

  font
cubicToQuad = (segment, index, x, y) ->
  if segment[0] is "C"
    quadCurves = math.bezierCubicToQuad(new math.Point(x, y), new math.Point(segment[1], segment[2]), new math.Point(segment[3], segment[4]), new math.Point(segment[5], segment[6]), 0.3)
    res = []
    _.forEach quadCurves, (curve) ->
      res.push [
        "Q"
        curve[1].x
        curve[1].y
        curve[2].x
        curve[2].y
      ]
      return

    res

# Converts svg points to contours.  All points must be converted
# to relative ones, smooth curves must be converted to generic ones
# before this conversion.
#
toSfntCoutours = (svgPath) ->
  resContours = []
  resContour = []
  svgPath.iterate (segment, index, x, y) ->

    #start new contour
    if index is 0 or segment[0] is "M"
      resContour = []
      resContours.push resContour
    name = segment[0]
    if name is "Q"

      #add control point of quad spline, it is not on curve
      resContour.push
        x: segment[1]
        y: segment[2]
        onCurve: false


    # add on-curve point
    if name is "H"

      # vertical line has Y coordinate only, X remains the same
      resContour.push
        x: segment[1]
        y: y
        onCurve: true

    else if name is "V"

      # horizontal line has X coordinate only, Y remains the same
      resContour.push
        x: x
        y: segment[1]
        onCurve: true

    else if name isnt "Z"

      # for all commands (except H and V) X and Y are placed in the end of the segment
      resContour.push
        x: segment[segment.length - 2]
        y: segment[segment.length - 1]
        onCurve: true

    return

  resContours


module.exports.load = load
module.exports.cubicToQuad = cubicToQuad
module.exports.toSfntCoutours = toSfntCoutours
