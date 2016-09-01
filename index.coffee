Promise   = require 'bluebird'
readline  = require 'readline'
slurps    = require './slurps'
argv      = require 'argv-parse'

args = argv
  cache: type:'string', alias:'c'      #init cache into given folder
  reverse: type:'string', alias:'r'    #reverse cache (symlinks)
  download: type:'string', alias:'d'  #download files to given folder
# -d needs -c too; to know which cache to use!


# line event handler
# :: line -> P _
core_download = (fldr, cachep) -> (line) ->
  slurps.download line, cachep, fldr
  .then (m) -> console.log 'done:', m.nm; m


core_cache_init = (cp) -> (line) -> slurps.init_cache line, cp


line_loop = (lcore, cont) ->
  plines = []
  readline.createInterface
    input: process.stdin
    output: process.stdout

  .on 'line', (line) -> plines.push lcore line
  .on 'error', (err) -> cont err
  .on 'close', -> cont null, plines

fin = (plines) ->
  Promise.all(plines)
  .then (fins) -> console.log 'finised:', fins
  .catch (err) -> console.log err; throw err

run = (lcore) -> Promise.promisify(line_loop)(lcore).then fin


main = ->
  unless args.cache
    return console.error 'needs cache field'
  unless args.reverse
    return console.error 'needs cache reverse field'

  if args.download
    run core_download args.download, path:args.cache
  else
    run core_cache_init {path:args.cache, rev:args.reverse}

main()
