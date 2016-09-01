Promise   = require 'bluebird'
fs        = Promise.promisifyAll require 'fs'
request   = Promise.promisifyAll require 'request'
crypto    = require 'crypto'
path      = require 'path'
moment    = require 'moment'

P = (fn) -> new Promise fn

sha = (str) ->
  crypto.createHash 'sha1'
  .update str
  .digest 'hex'

hash = sha

head = (url) -> request.headAsync url
parse_name = (str) -> /.*filename="(.*)".*/.exec(str)?[1]
head_name = (url) -> head(url).then (h) -> parse_name h.headers['content-disposition']

stamp = (m = moment()) -> m.format 'YYMMDD HH:mm.ss  #x'

mson_cache = (url, nm, hurl) -> """
  name: #{nm}
  url: #{url}
  hash_url: #{hurl}

  """
mson_done = (path, time) -> """
  path: #{path}
  done: #{time}

  """
mson_start = (started) -> """
  started: #{started}

  """
mson_parse = (data) ->
  obj = {}
  r=/^(\w+): (.*)$/
  for line in String(data).split '\n'
    if ro = r.exec line
      [all, key, val] = ro
      obj[key] = val
  obj


with_cache = (hurlp) ->
  fs.readFileAsync hurlp
  .then (data) -> mson_parse data

test_finished = (hurlp) ->
  with_cache hurlp
  .then (cache) ->
    if cache.done
      return (fns) -> fns.done cache
    if cache.name
      return (fns) -> fns.name cache, cache.name
    else
      err = new Error 'Invalid cache: ' + cache
      err.cache = cache
      err.data = data
      throw err

download_req = (url, nmp, hurl, cp) -> P (resolve, reject) ->
  ws = fs.createWriteStream nmp
  rq = request.get(url)
  rq.pipe ws
  rq.on 'error', reject
  rq.on 'resposnse', -> console.log 'response:', nmp
  rq.on 'end', (x) -> fs.appendFile cp, mson_done(nmp, do stamp), (err) ->
    if err then console.log 'done.err:', err, nmp #even err is ok at this point
    else console.log 'done:', nmp
    resolve ws:x, nmp:nmp, url:url, hurl:hurl, err:err

download = (url, cache_path, folder) ->
  hurl  = hash url
  hurlp = path.join cache_path, '.'+hurl

  test_finished(hurlp).then (pick) -> pick
    name: (cache, nm) ->
      nmp   = path.join folder, nm
      # inform cache
      console.log 'start:', nm
      fs.appendFileAsync(hurlp, mson_start do stamp)
        .then -> download_req url, nmp, hurl, hurlp
    done: (cache) -> console.log 'already downloaded:', cache.name

init_cache = (url, cache_path) ->
  hurl = hash url
  hurlp = path.join(cache_path.path, '.'+hurl)

  with_cache hurlp
  .catch (err) ->
    unless err.code is 'ENOENT' #no such file (Error NO entity)
      throw err
    head_name(url).then (nm) ->
      unless nm then throw name:nm, url:url
      fs.writeFileAsync(hurlp, mson_cache url, nm, hurl).then ->
        path:hurlp, new:true, name: nm
# WRONG: the following will follow the error too (duh)
# receives pnn OR cache
  .then (cache) -> path:hurlp, new:false, name:cache.name #, cache:cache
  .then (pnn) ->
    pr = path.join cache_path.rev, pnn.name
    pr = '/'+path.relative '/', pr #get absolute path for symlink
    ph = '/'+path.relative '/', hurlp #get absolute path for symlink
    fs.symlinkAsync ph, pr
    .then -> pnn


@head = head
@download = download
@req = request
@parse_name = parse_name
@hash = hash
@init_cache = init_cache
@mson_parse = mson_parse
@mson_cache = mson_cache
