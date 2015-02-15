Color = require './color'
cluster = require 'cluster'
module.exports = (s) ->
  d = new Date
  console.log ''+
    "#{Color.bright_white}#{d.getHours()}:#{d.getMinutes()}:#{d.getSeconds()}.#{d.getMilliseconds()} "+
    "#{Color.grey}#{if cluster.isMaster then 'wrapper' else "worker##{cluster.worker.id}"}"+
    "#{Color.reset} "+s
