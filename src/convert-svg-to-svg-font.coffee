


############################################################################################################
# _                         = require 'lodash'
DOMParser                 = ( require 'xmldom' ).DOMParser
math                      = require './math'
xpath                     = require 'xpath'
#...........................................................................................................
CHR                       = require 'coffeenode-chr'
TRM                       = require 'coffeenode-trm'
rpr                       = TRM.rpr.bind TRM
badge                     = 'svg2ttf/svg-to-svg-font'
log                       = TRM.get_logger 'plain',   badge
info                      = TRM.get_logger 'info',    badge
alert                     = TRM.get_logger 'alert',   badge
debug                     = TRM.get_logger 'debug',   badge
warn                      = TRM.get_logger 'warn',    badge
urge                      = TRM.get_logger 'urge',    badge
whisper                   = TRM.get_logger 'whisper', badge
help                      = TRM.get_logger 'help',    badge
echo                      = TRM.echo.bind TRM
#...........................................................................................................
SvgPath                   = require 'svgpath'
#...........................................................................................................
### https://github.com/loveencounterflow/coffeenode-teacup ###
T                         = require 'coffeenode-teacup'


#===========================================================================================================
# OPTIONS
#-----------------------------------------------------------------------------------------------------------
options =
  ### Coordinates of first glyph outline: ###
  'offset':       [ 48, 25.89, ]
  ### Size of grid and font design size: ###
  'module':       12
  'scale':        256 / 12
  ### CID of first glyph outline: ###
  'cid0':         0xe000
  'row-length':   16


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@load = ( source ) ->
  glyphs      = []
  parser      = new DOMParser()
  doc         = parser.parseFromString( source, 'application/xml' )
  select      = select = xpath.useNamespaces 'SVG': 'http://www.w3.org/2000/svg'
  selector    = '/SVG:svg/SVG:path'
  paths       = select selector, doc
  path_count  = paths.length
  paths       = ( path for path in paths when not /^x-/.test path.getAttribute 'id' )
  debug "found #{paths.length} outlines"
  debug "skipped #{path_count - paths.length} non-outline elements"
  #.........................................................................................................
  for path in paths
    d = path.getAttribute 'd'
    path = new SvgPath d
      # .scale 0.5
      # .translate 100, 200
      .abs()
      # .round 0
      # .rel()
      # .round(1) # Fix js floating point error/garbage after rel()
      # .toString()
    # debug JSON.stringify path
    # debug path.toString()
    # help @points_from_absolute_path path
    center      = @center_from_absolute_path path
    [ x, y, ]   = center
    x          -= options[ 'offset' ][ 0 ]
    y          -= options[ 'offset' ][ 1 ]
    col         = Math.floor x / options[ 'module' ]
    row         = Math.floor y / options[ 'module' ]
    cid         = options[ 'cid0' ] + row * options[ 'row-length' ] + col
    dx          = - ( col * options[ 'module' ] ) - options[ 'offset' ][ 0 ]
    dy          = - ( row * options[ 'module' ] ) - options[ 'offset' ][ 1 ]
    path        = path
      .translate  dx, dy
      # .scale      options[ 'scale' ]
      .round      5
    # echo ( T.$marker center, 3 ), [ col, row, CHR.as_ncr cid ]
    # debug path
    glyphs.push [ cid, path, ]
  #.........................................................................................................
  glyphs.sort ( a, b ) ->
    return +1 if a[ 0 ] > b[ 0 ]
    return -1 if a[ 0 ] < b[ 0 ]
    return  0
  #.........................................................................................................
  echo @f glyphs

  # for idx  < paths.length
  #   path = paths[idx]
  # fontElem = doc.getElementsByTagName("font")[0]
  # throw new Error("unable to locate SVG font element")  unless fontElem?
  # fontFaceElem = fontElem.getElementsByTagName("font-face")[0]
  # font =
  #   id: fontElem.getAttribute("id") or "fontello"
  #   familyName: fontFaceElem.getAttribute("font-family") or "fontello"
  #   glyphs: []
  #   stretch: fontFaceElem.getAttribute("font-stretch") or "normal"


  # # Doesn't work with complex content like <strong>Copyright:></strong><em>Fontello</em>
  # font.metadata = metadata.textContent  if metadata and metadata.textContent

  # # Get <font> numeric attributes
  # attributes =
  #   width: "horiz-adv-x"

  #   #height:       'vert-adv-y',
  #   horizOriginX: "horiz-origin-x"
  #   horizOriginY: "horiz-origin-y"
  #   vertOriginX: "vert-origin-x"
  #   vertOriginY: "vert-origin-y"

  # _.forEach attributes, (val, key) ->
  #   font[key] = parseInt(fontElem.getAttribute(val), 10)  if fontElem.hasAttribute(val)
  #   return


  # # Get <font-face> numeric attributes
  # attributes =
  #   ascent: "ascent"
  #   descent: "descent"
  #   unitsPerEm: "units-per-em"

  # _.forEach attributes, (val, key) ->
  #   font[key] = parseInt(fontFaceElem.getAttribute(val), 10)  if fontFaceElem.hasAttribute(val)
  #   return

  # font.weightClass = fontFaceElem.getAttribute("font-weight")  if fontFaceElem.hasAttribute("font-weight")
  # missingGlyphElem = fontElem.getElementsByTagName("missing-glyph")[0]
  # if missingGlyphElem
  #   font.missingGlyph = {}
  #   font.missingGlyph.d = missingGlyphElem.getAttribute("d") or ""
  #   font.missingGlyph.width = parseInt(missingGlyphElem.getAttribute("horiz-adv-x"), 10)  if missingGlyphElem.getAttribute("horiz-adv-x")
  # _.forEach fontElem.getElementsByTagName("glyph"), (glyphElem) ->
  #   font.glyphs.push getGlyph(glyphElem)
  #   return

  # font


#-----------------------------------------------------------------------------------------------------------
@center_from_absolute_path = ( path ) ->
  return @center_from_absolute_points @points_from_absolute_path path

#-----------------------------------------------------------------------------------------------------------
@center_from_absolute_points = ( path ) ->
  node_count  = path.length
  sum_x       = 0
  sum_y       = 0
  for [ x, y, ] in path
    throw new Error "found undefined points in path" unless x? and y?
    sum_x += x
    sum_y += y
  return [ sum_x / node_count, sum_y / node_count, ]

#-----------------------------------------------------------------------------------------------------------
@points_from_absolute_path = ( path ) ->
  R = []
  #.........................................................................................................
  for node in path[ 'segments' ]
    [ command, xy..., ] = node
    #.......................................................................................................
    ### Ignore closepath command: ###
    continue if /^[zZ]$/.test command
    #.......................................................................................................
    throw new Error "unknown command #{rpr command} in path #{rpr path}" unless /^[MLHVCSQTA]$/.test command
    #.......................................................................................................
    switch command
      #.....................................................................................................
      when 'H'
        [ x, y, ] = [ xy[ 0 ], last_y, ]
        R.push [ x, y, ]
      #.....................................................................................................
      when 'V'
        [ x, y, ] = [ last_x, xy[ 0 ], ]
        R.push [ x, y, ]
      #.....................................................................................................
      when 'M', 'L'
        for idx in [ 0 ... xy.length ] by +2
          [ x, y, ] = [ xy[ idx ], xy[ idx + 1 ], ]
          R.push [ x, y, ]
      #.....................................................................................................
      when 'C'
        for idx in [ 0 ... xy.length ] by +6
          [ x, y, ] = [ xy[ idx + 4 ], xy[ idx + 5 ], ]
          R.push [ x, y, ]
      #.....................................................................................................
      when 'S'
        for idx in [ 0 ... xy.length ] by +4
          [ x, y, ] = [ xy[ idx + 2 ], xy[ idx + 3 ], ]
          R.push [ x, y, ]
      #.....................................................................................................
      else
        [ x, y, ] = [ null, null, ]
        R.push [ x, y, ]
    #.......................................................................................................
    last_x = x
    last_y = y
  #.........................................................................................................
  return R

#===========================================================================================================
# SVG GENERATION
#-----------------------------------------------------------------------------------------------------------
T.SVG = ( P... ) ->
  Q =
    'xmlns':        'http://www.w3.org/2000/svg'
  return T.TAG 'svg', Q, P...

# <font id="icomoon" horiz-adv-x="512">
# <font-face units-per-em="512" ascent="480" descent="-32" />

#-----------------------------------------------------------------------------------------------------------
T.DEFS = ( P... ) ->
  return T.TAG 'defs', P...

#-----------------------------------------------------------------------------------------------------------
T.FONT = ( P... ) ->
  Q =
    'id':             'jizura2svg'
    'horiz-adv-x':    options[ 'module' ]
    # 'horiz-origin-x':   0
    # 'horiz-origin-y':   0
    # 'vert-origin-x':    0
    # 'vert-origin-y':    0
    # 'vert-adv-y':       0
  return T.TAG 'font', Q, P...

#-----------------------------------------------------------------------------------------------------------
T.FONT_FACE = ->
  Q =
    'id':             'jizura2svg'
    'units-per-em':   options[ 'module' ]
    ### TAINT probably wrong values ###
    'ascent':         options[ 'module' ] - 2
    'descent':        -2
  ### TAINT kludge ###
  # return T.selfClosingTag 'font-face', Q
  return T.RAW ( T.render => T.TAG 'font-face', Q ).replace /><\/font-face>$/, ' />'

#-----------------------------------------------------------------------------------------------------------
T.GLYPH = ( cid, path ) ->
  Q           =
    # unicode:  T.TEXT CHR.as_ncr cid
    unicode:  CHR.as_chr cid
    d:        T._rpr_path path
  return T.TAG 'glyph', Q

#-----------------------------------------------------------------------------------------------------------
T.MARKER = ( xy, r = 10 ) ->
  return T.TAG 'circle', cx: xy[ 0 ], cy: xy[ 1 ], r: r, fill: '#f00'

#-----------------------------------------------------------------------------------------------------------
T._rpr_path = ( path ) ->
  return ( s[ 0 ] + s[ 1 .. ].join ',' for s in path[ 'segments' ] ).join ' '

#-----------------------------------------------------------------------------------------------------------
T.path = ( path ) ->
  path_txt = T._rpr_path path
  return T.TAG 'path', d: path_txt, fill: '#000'

# #-----------------------------------------------------------------------------------------------------------
# do =>
#   for name in 'glyph marker font font-face'.split /\s+/
#     continue unless ( method = T[ name ] )?
#     # TRM.dir T
#     do ( method ) =>
#       T[ '$' + name ] = T.render ( P... ) ->
#         return method P...

#-----------------------------------------------------------------------------------------------------------
@f = ( glyphs ) ->
  return T.render =>
    #.........................................................................................................
    T.RAW """<?xml version="1.0" encoding="utf-8"?>\n"""
    ### must preserve space at end of DOCTYPE declaration ###
    T.RAW """<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd" >\n"""
    T.SVG =>
      T.TEXT '\n'
      T.DEFS =>
        T.TEXT '\n'
        T.FONT =>
          T.TEXT '\n'
          T.FONT_FACE()
          T.TEXT '\n'
          for [ cid, path, ] in glyphs
            T.GLYPH cid, path
            T.TEXT '\n'
        T.TEXT '\n'
      T.TEXT '\n'

  #.........................................................................................................
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@demo = ->
  d = "M168,525.89c38,36,48,48,46,81s5,47-46,52 s-88,35-91-27s-21-73,11-92S168,525.89,168,525.89z"
  path = new SvgPath d
    .scale 0.5
    .translate 100, 200
    .abs()
    .round 0
    # .rel()
    # .round(1) # Fix js floating point error/garbage after rel()
    # .toString()
  debug JSON.stringify path
  # debug path.toString()
  help @points_from_absolute_path path
  help @center_from_absolute_path path

  debug @f path

############################################################################################################
unless module.parent?
  source = ( require 'fs' ).readFileSync './test/first.svg', encoding: 'utf-8'
  # source = ( require 'fs' ).readFileSync '/private/tmp/jizura2-designsheet-5 copy 2.svg', encoding: 'utf-8'
  @load source

  # parser    = new DOMParser()
  # doc       = parser.parseFromString source
  # select    = select = xpath.useNamespaces 'SVG': 'http://www.w3.org/2000/svg'
  # # selector  = '//SVG:svg'
  # # selector  = '//SVG:tspan/text()'
  # # selector  = '//SVG:text[@id="info"]/tspan/text()'
  # selector  = '//SVG:text[@id="info"]/SVG:tspan/text()'
  # nodes     = select selector, doc
  # warn rpr ( node.toString() for node in nodes )

  # info T.render => T.DIV 'helo'
  # info T.render => T.SVG 'helo'
  # info T.render => T.SVG => T.RAW '&#xhelo;'
  # TRM.dir T


















