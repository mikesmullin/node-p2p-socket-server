_ = require 'lodash' # map data structures with ease
CoffeeScript = require 'coffee-script'
config = require '../../config' # user preferences

module.exports =
  parse: ->
    OPTION = /^--?(\w+)\s*=?\s*(.*)$/
    argv = []
    options = {}
    args = process.argv.slice 2

    while args.length
      arg = args.shift()
      if null isnt matches = arg.match OPTION
        [nil, key, value] = matches
        if key and value
          options[key] = value
        else if key
          options[key] = true
      else
        argv.push arg

    process.args = argv
    process.options = options
    return @

  mergeAlias: (key, alias) ->
    process.options[key] ||= process.options[alias]
    return @

  validateInt: (key, _default) ->
    process.options[key] = parseInt(process.options[key]) or _default
    return @

  validateCSON: (key) ->
    if process.options[key]
      process.options[key] = eval CoffeeScript.compile process.options[key], bare: true
    return @

  mergeConfig: (key, configKey) ->
    configVal = eval 'config.'+configKey
    type = typeof process.options[key]
    if type is 'undefined'
      type = typeof configVal

    switch type
      when 'object'
        if Array.isArray(process.options[key]) or Array.isArray configVal
          process.options[key] ||= []
          process.options[key] = configVal.concat process.options[key]
        else
          process.options[key] ||= {}
          process.options[key] = _.merge configVal, process.options[key]
      else
        process.options[key] ||= configVal
    return @
