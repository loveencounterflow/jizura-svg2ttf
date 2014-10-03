


############################################################################################################
njs_fs                    = require 'fs'
njs_path                  = require 'path'
#...........................................................................................................
DOMParser                 = ( require 'xmldom-silent' ).DOMParser
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
#...........................................................................................................
### https://github.com/isaacs/node-glob ###
glob                      = require 'glob'


#===========================================================================================================
# OPTIONS
#-----------------------------------------------------------------------------------------------------------
module    = 36
em_size   = 4096
options =
  ### Coordinates of first glyph outline: ###
  'offset':           [ module * 4, module * 4, ]
  ### Size of grid and font design size: ###
  'module':           module
  # 'scale':            256 / module
  # 'scale':            1024 / module
  ### Number of glyph rows between two rulers plus one: ###
  'block-height':     9
  ### CID of first glyph outline: ###
  'row-length':       16
  'em-size':          em_size
  'ascent':           +0.8 * em_size
  'descent':          -0.2 * em_size

#...........................................................................................................
options[ 'scale' ] = em_size / module

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@load = ( input_routes... ) ->
  glyphs      = {}
  parser      = new DOMParser()
  select      = xpath.useNamespaces 'SVG': 'http://www.w3.org/2000/svg'
  selector    = '//SVG:svg/SVG:path'
  #.........................................................................................................
  for route in input_routes
    filename    = njs_path.basename route
    cid0        = @_cid0_from_route route
    continue
    source      = njs_fs.readFileSync route, encoding: 'utf-8'
    fallback    = null
    max_cid     = -Infinity
    doc         = parser.parseFromString( source, 'application/xml' )
    paths       = select selector, doc
    path_count  = paths.length
    help "found #{paths.length} outlines in #{filename}"
    #.........................................................................................................
    for path in paths
      d             = path.getAttribute 'd'
      path          = ( new SvgPath d ).abs()
      center        = @center_from_absolute_path path
      [ x, y, ]     = center
      x            -= options[ 'offset' ][ 0 ]
      y            -= options[ 'offset' ][ 1 ]
      col           = Math.floor x / options[ 'module' ]
      row           = Math.floor y / options[ 'module' ]
      block_count   = row // options[ 'block-height' ]
      actual_row    = row - block_count
      cid           = options[ 'cid0' ] + row * options[ 'row-length' ] + col
      max_cid       = Math.max max_cid, cid
      dx            = - ( col * options[ 'module' ] ) - options[ 'offset' ][ 0 ]
      dy            = - ( row * options[ 'module' ] ) - options[ 'offset' ][ 1 ]
      path          = path
        .translate  dx, dy
        .scale      1, -1
        .translate  0, options[ 'module' ]
        .scale      options[ 'scale' ]
        .round      0
      #.....................................................................................................
      if cid < options[ 'cid0' ]
        prefix    = if fallback? then 're-' else ''
        fallback  = path
        help "#{prefix}assigned fallback from #{filename}"
      #.....................................................................................................
      else
        if glyphs[ cid ]?
          warn "duplicate CID: 0x#{cid.toString 16} in #{filename}"
        glyphs[ cid ] = [ cid, path, ]
  #.........................................................................................................
  # debug glyphs
  #.........................................................................................................
  for cid in [ options[ 'cid0' ] .. max_cid ]
    glyphs[ cid ]?= [ cid, fallback, ]
  #.........................................................................................................
  glyphs = ( entry for _, entry of glyphs )
  glyphs.sort ( a, b ) ->
    return +1 if a[ 0 ] > b[ 0 ]
    return -1 if a[ 0 ] < b[ 0 ]
    return  0
  #.........................................................................................................
  echo @f glyphs

#-----------------------------------------------------------------------------------------------------------
@_cid0_from_route = ( route ) ->
  match = route.match /-([0-9a-f]+)\.svg$/
  unless match?
    throw new Error "unable to parse route #{rpr route}"
  R = parseInt match[ 1 ], 16
  unless 0x0000 <= R <= 0x10ffff
    throw new Error "illegal CID in route #{rpr route}"
  debug R, match
  # process.exit()
  # return R

#===========================================================================================================
#
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
    'horiz-adv-x':    options[ 'module' ] * options[ 'scale' ]
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
    'units-per-em':   options[ 'module' ] * options[ 'scale' ]
    ### TAINT probably wrong values ###
    'ascent':         options[ 'ascent' ]
    'descent':        options[ 'descent' ]
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
            T.RAW "<!-- #{cid.toString 16} -->"
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
  # source = ( require 'fs' ).readFileSync '/Volumes/Storage/jizura-materials-2/jizura-font-v3/jizura3-0000.svg', encoding: 'utf-8'
  # source = ( require 'fs' ).readFileSync '/tmp/test-e000.svg', encoding: 'utf-8'
  # source = ( require 'fs' ).readFileSync '/Volumes/Storage/jizura-materials-2/jizura-font-v3/jizura3-e000.svg', encoding: 'utf-8'

  route_glob = '/Volumes/Storage/jizura-materials-2/jizura-font-v3/jizura3-*([0-9a-f]).svg'
  routes = glob.sync route_glob
  @load routes...

















