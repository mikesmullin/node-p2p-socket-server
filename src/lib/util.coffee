module.exports = Util =
  delay: (ms,f) -> setTimeout f, ms
  interval: (ms,f) -> setInterval f, ms
  select: (a) -> a[Math.floor(Math.random() * a.length)]
  rand: (m,x) -> Math.round(Math.random() * (x-m)) + m
