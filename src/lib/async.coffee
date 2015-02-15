module.exports =
class async
  @serial: (a, cb) ->
    return cb() unless a.length
    a.push cb
    (next = (err, result) ->
      if err or 1 is a.length
        a[a.length-1] err, result
        a = []
        return
      a.shift() next
      return
    )()
    return

  @parallel: (a, cb) ->
    return cb() unless a.length
    a.push cb
    next = (err) ->
      a.shift()
      if err or 1 is a.length
        a[a.length-1] err
        a = []
      return
    for i of a when i < a.length-1
      a[i] next
    return
