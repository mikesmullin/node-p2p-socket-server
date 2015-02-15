module.exports =
class Protocol
  constructor: -> @flush()
  flush: -> @buffer = ''
  parse: (buf, cb) =>
    # remote can transmit messages split across several packets,
    # as well as more than one message per packet
    @buffer += buf.toString()
    while (pos = @buffer.indexOf("\u0000")) isnt -1 # we have a complete message
      recv = @buffer.substr 0, pos
      @buffer = @buffer.substr pos+1

      if null isnt matches = recv.match /^(\w+) ?(.*)$/
        [cmd, args] = matches
        cb cmd, args

    return
