// A TCP proxy in front of the fixture server that can lose the network on demand,
// since the iOS Simulator has no airplane mode.
//
//   node cut-proxy.mjs [listenPort=8792] [targetPort=8791] [controlPort=8793]
//   curl localhost:8793/cut      every open connection is destroyed (no close frame)
//                                and new ones are refused, like a dead network
//   curl localhost:8793/restore  connections are accepted again
//   curl localhost:8793/state
import net from "node:net"
import http from "node:http"

const [listenPort = 8792, targetPort = 8791, controlPort = 8793] = process.argv.slice(2).map(Number)
let cut = false
const open = new Set()

net
  .createServer((client) => {
    if (cut) return client.destroy()
    const upstream = net.connect(targetPort, "127.0.0.1")
    open.add(client)
    open.add(upstream)
    const done = () => {
      open.delete(client)
      open.delete(upstream)
      client.destroy()
      upstream.destroy()
    }
    client.on("error", done).on("close", done)
    upstream.on("error", done).on("close", done)
    client.pipe(upstream)
    upstream.pipe(client)
  })
  .listen(listenPort, "0.0.0.0")

http
  .createServer((req, res) => {
    if (req.url === "/cut") {
      cut = true
      for (const socket of open) socket.destroy()
      open.clear()
    } else if (req.url === "/restore") {
      cut = false
    }
    console.log(new Date().toISOString(), req.url, "cut=" + cut)
    res.end(JSON.stringify({ cut, open: open.size }) + "\n")
  })
  .listen(controlPort, "127.0.0.1")

console.log(`cut-proxy :${listenPort} -> :${targetPort}, control :${controlPort}`)
