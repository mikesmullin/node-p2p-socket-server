Handlebars.registerHelper 'list', (items, options) ->
  out = ""; out += options.fn item for item in items
  return out
tmpl = Handlebars.compile($("#example-template").html())
socket = new eio.Socket w ='ws://'+address+'/' # TODO: grab hostname and port from document.location
socket.on 'open', ->
  socket.on 'message', (data) ->
    data = JSON.parse data
    console.log data
  socket.on 'close', ->
