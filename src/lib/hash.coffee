crc = require 'crc'
log = require './log'
module.exports =
  iShouldConnectToPeer: (me, peer) ->
    return false if me is peer # never connect to self
    # higher peers always connect to lower peers
    return crc.crc16(me) > crc.crc16(peer)
