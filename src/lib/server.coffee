net = require 'net'
log = require './log'
hexy = require 'hexy'
Color = require './color'

module.exports =
class Server
  server: null
  constructor: (@ENCODING, @BACKLOG) ->
    @server_sockets = {}
  listen: (@LISTEN_IP, @LISTEN_PORT, app) ->
    @server = net.createServer (socket) =>
      socket.id = "server socket #{socket.remoteAddress}:#{socket.remotePort}"
      socket.connected = true
      log "#{Color.yellow}#{socket.id} accepted.#{Color.reset}"
      socket.setNoDelay true # disable Nagle's algorithm
      socket.setEncoding @ENCODING
      socket.setTimeout 0 # ms to wait before receiving notice of idle user
      socket.on 'error', (err) ->
        log "#{Color.red}#{socket.id} error #{err}#{Color.reset}"
        socket.destroy()
        return
      socket.on 'data', (data) =>
        log "#{Color.blue}#{socket.id} recv:\n#{hexy.hexy(data)}#{Color.reset}"
        app.data? {
          socket: socket
          data: data
        }, {
          send: @send
        }
        return
      socket.on 'timeout', ->
        log "#{Color.red}#{socket.id} idle.#{Color.reset}"
        return
      socket.on 'end', =>
        log "#{Color.yellow}#{socket.id} end.#{Color.reset}"
        @close_socket socket
        return
      socket.on 'close', (had_err) =>
        log "#{Color.yellow}#{socket.id} close#{if had_err then " due to error" else ""}.#{Color.reset}"
        @close_socket socket
        app?.close? socket
        return
      @server_sockets[socket.id] = socket
      app.accepted {
        socket: socket
      }, {
        send: @send
      }
      return
    @server.on 'error', (err) =>
      log "#{Color.red}listen #{@LISTEN_IP}:#{@LISTEN_PORT} error #{err}#{Color.reset}"
      return
    @server.on 'close', =>
      log "#{Color.yellow}listen #{@LISTEN_IP}:#{@LISTEN_PORT} close.#{Color.reset}"
      return
    @server.listen @LISTEN_PORT, @LISTEN_IP, @BACKLOG, =>
      log "#{Color.yellow}listening #{@LISTEN_IP}:#{@LISTEN_PORT}...#{Color.reset}"
      app?.listening? @server
      return
    return

  send: (socket, data, cb) =>
    log "#{Color.yellow}#{socket.id} send:\n#{hexy.hexy(data)}#{Color.reset}"
    socket.write data, @ENCODING, cb

  close_socket: (socket) ->
    if socket.connected
      delete @server_sockets[socket.id]
      log "#{Color.yellow}#{socket.id} ending...#{Color.reset}"
      socket.end()
      log "#{Color.yellow}#{socket.id} closing...#{Color.reset}"
      socket.destroy()
      socket.connected = false
    return

  close: ->
    log "#{Color.yellow}closing listener #{@server.address().address}:#{@server.address().port}...#{Color.reset}"
    for id, socket of @server_sockets when socket isnt null
      @close_socket socket
    @server?.close()
    @server = null
    return
