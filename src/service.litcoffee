#### Dependencies

    _        = require 'lodash' # map data structures with ease
    path     = require 'path'
    log      = require './lib/log'
    cluster  = require 'cluster'
    async    = require './lib/async'
    hash     = require './lib/hash'
    Protocol = require './lib/protocol'
    Cli      = require('./lib/cli').parse() # parse argv

#### Process Fork

    Cli.mergeAlias('writers', 'w').validateInt('writers', 0)
    Cli.mergeAlias('readers', 'r').validateInt('readers', 0)
    Cli.mergeAlias('monitors', 'm').validateInt('monitors', 0)
    worker_count = process.options.writers + process.options.readers + process.options.monitors
    if cluster.isMaster
      log "wrapper pid is #{process.pid}."
      workers = {}
      flow1 = []; flow2 = []
      for type in ['writer', 'reader', 'monitor']
        workers[type] = []
        for nil in [0...process.options[type+'s']]
          do (type) -> flow1.push (next1) -> flow2.push (next2) ->
            worker_type = type
            workers[type].push worker = cluster.fork()
            log "forking #{type}##{worker.id} pid #{worker.process.pid}..."
            worker.on 'exit', (worker, code, signal) ->
              log "wrapper detected fork ##{worker.id} was killed by signal: #{signal}" if signal
              log "wrapper detected fork ##{worker.id} exited with error code: #{code}" if code isnt 0
              log "wrapper detected fork ##{worker.id} exited normally"
            worker.on 'message', (data) ->
              switch data?.cmd
                when 'listening' then next1()
                when 'ready' then next2()
      async.parallel flow1, (err) ->
        throw err if err
        log "all workers forked and listening. ready for connections."
        for worker_id, worker of cluster.workers
          worker.send cmd: 'peer_up'
      async.parallel flow2, (err) ->
        throw err if err
        for worker_id, worker of cluster.workers
          worker.send cmd: 'accept_work'
        log "all workers connected. ready for work."

#### App Globals

    if cluster.isWorker
      Server  = require './lib/server'
      Client  = require './lib/client'
      app = new Server 'utf8'
      app.package = require '../package.json' # npm package data
      app.err     = (s) ->
        process.stderr.write "#{s}\n"
        console.trace()
      accept_work = false
      processServerCommand = -> # no-op
      processClientCommand = -> # no-op

      # TODO: generate and store unique uuid per node unless one is already there in the config
      #         can be one uuid for the entire wrapper process with suffixes for each worker type and id
      #         doesn't really matter yet if id is persisted between restarts since its in-memory only
      #         and all data is disposable between restarts

#### Listen

      # must start server before networking
      Cli.mergeAlias('bind', 'b').mergeConfig('bind', 'bind.ipv4')
      Cli.mergeAlias('port', 'p').mergeConfig('port', 'bind.port').validateInt('port')
      peers_established = {}; me = ''
      # each worker listens on its own port within a range--from the given port, to
      # that number plus the total number of workers.
      server_protocol = new Protocol
      app.listen process.options.bind, process.options.port + cluster.worker.id - 1,
        listening: (server) ->
          log "worker##{cluster.worker.id} listening on #{JSON.stringify server.address()}."
          {address, port} = server.address()
          me = "#{address}:#{port}"
          process.send cmd: 'listening'

        accepted: ({ socket }, res) ->
          if peers_established[peer]
            peer = "#{socket.remoteAddress}:#{socket.remotePort}"
            peers_established[peer] = socket
            log "incoming peer #{peer} accepted."

        data: ({ socket, data }, res) ->
          server_protocol.parse data, (cmd, args) ->
            processServerCommand { socket: socket, cmd: cmd, args: args }, res

        close: (socket) ->

#### Peer Network

      process.on 'message', (data) ->
        if data?.cmd is 'peer_up'
          flow = []
          peers = []
          Cli.validateCSON('peers').mergeConfig('peers', 'peers')

          # establish connection between local forks
          process.options.peers ||= []
          for port in [process.options.port...process.options.port+worker_count]
            if port isnt process.options.port + cluster.worker.id - 1 # skip self
              process.options.peers.unshift "#{process.options.bind}:#{port}"

          # and establish connection to any externals listed in config or on command line
          for peer in process.options.peers when hash.iShouldConnectToPeer me, peer
            do (peer) -> flow.push (next) ->
              [host, port] = peer.split ':'
              client_protocol = new Protocol
              peers.push client = new Client(host, port, 'utf8').connect
                connected: ({ socket }, res) ->
                  peers_established[peer] = socket
                  log "outgoing peer #{peer} established."
                  # TODO: request id and use that instead of host:ip to identify peers
                  # TODO: auto discover peers' peers on each connect? nah probably stick to static list
                  # TODO: retry connections every 30 seconds until success
                  #       to give other server time to startup or recover
                  next()

                data: ({ socket, data }, res) ->
                  client_protocol.parse data, (cmd, args) ->
                    processClientCommand { socket: socket, cmd: cmd, args: args }, res

                close: (socket) ->

          async.parallel flow, (err) ->
            throw err if err
            process.send cmd: 'ready'

#### Command Processing

        if data?.cmd is 'accept_work'
          accept_work = true

      # e.g., acknowledgements returned from server
      processClientCommand = ({ socket, cmd, args }, res) ->
        return unless accept_work

        log "processing client command #{cmd}"
        switch (cmd)
          when "OK"
            # simple success acknowledgement
            return

          else
            res.send "UNSUPPORTED\u0000"

      # e.g., directives from a client
      processServerCommand = ({ socket, cmd, args }, res) ->
        return unless accept_work

        log "processing server command #{cmd}"
        switch (cmd)
          when "ID"
            # TODO: parse id request and return unique uuid
            return

          when "SLAVEOF"
            # TODO: can issue command like SLAVEOF to make wrapper processes aware of each other
            return

          else
            res.send socket, "UNSUPPORTED\u0000"

