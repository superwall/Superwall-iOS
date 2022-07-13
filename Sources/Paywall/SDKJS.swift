// swiftlint:disable all

let script = #"""
/*! For license information please see main.js.LICENSE.txt */
var SuperwallSDKJS
;(() => {
  "use strict"
  var __webpack_modules__ = {
      276: (e, t, r) => {
        r.d(t, { Jx: () => m })
        const s = "function" == typeof atob,
          n = "function" == typeof Buffer,
          i = "function" == typeof TextDecoder ? new TextDecoder() : void 0,
          o = ((e) => {
            let t = {}
            return e.forEach((e, r) => (t[e] = r)), t
          })(
            ("function" == typeof TextEncoder && new TextEncoder(),
            [..."ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="])
          ),
          a = /^(?:[A-Za-z\d+\/]{4})*?(?:[A-Za-z\d+\/]{2}(?:==)?|[A-Za-z\d+\/]{3}=?)?$/,
          l = String.fromCharCode.bind(String),
          h =
            "function" == typeof Uint8Array.from
              ? Uint8Array.from.bind(Uint8Array)
              : (e, t = (e) => e) => new Uint8Array(Array.prototype.slice.call(e, 0).map(t)),
          c = (e) => e.replace(/[^A-Za-z0-9\+\/]/g, ""),
          u = /[\xC0-\xDF][\x80-\xBF]|[\xE0-\xEF][\x80-\xBF]{2}|[\xF0-\xF7][\x80-\xBF]{3}/g,
          p = (e) => {
            switch (e.length) {
              case 4:
                var t =
                  (((7 & e.charCodeAt(0)) << 18) |
                    ((63 & e.charCodeAt(1)) << 12) |
                    ((63 & e.charCodeAt(2)) << 6) |
                    (63 & e.charCodeAt(3))) -
                  65536
                return l(55296 + (t >>> 10)) + l(56320 + (1023 & t))
              case 3:
                return l(
                  ((15 & e.charCodeAt(0)) << 12) |
                    ((63 & e.charCodeAt(1)) << 6) |
                    (63 & e.charCodeAt(2))
                )
              default:
                return l(((31 & e.charCodeAt(0)) << 6) | (63 & e.charCodeAt(1)))
            }
          },
          d = s
            ? (e) => atob(c(e))
            : n
            ? (e) => Buffer.from(e, "base64").toString("binary")
            : (e) => {
                if (((e = e.replace(/\s+/g, "")), !a.test(e)))
                  throw new TypeError("malformed base64.")
                e += "==".slice(2 - (3 & e.length))
                let t,
                  r,
                  s,
                  n = ""
                for (let i = 0; i < e.length; )
                  (t =
                    (o[e.charAt(i++)] << 18) |
                    (o[e.charAt(i++)] << 12) |
                    ((r = o[e.charAt(i++)]) << 6) |
                    (s = o[e.charAt(i++)])),
                    (n +=
                      64 === r
                        ? l((t >> 16) & 255)
                        : 64 === s
                        ? l((t >> 16) & 255, (t >> 8) & 255)
                        : l((t >> 16) & 255, (t >> 8) & 255, 255 & t))
                return n
              },
          f = n ? (e) => h(Buffer.from(e, "base64")) : (e) => h(d(e), (e) => e.charCodeAt(0)),
          g = n
            ? (e) => Buffer.from(e, "base64").toString("utf8")
            : i
            ? (e) => i.decode(f(e))
            : (e) => d(e).replace(u, p),
          m = (e) => g(c(e.replace(/[-_]/g, (e) => ("-" == e ? "+" : "/"))))
      },
      620: (e, t, r) => {
        r.d(t, { Kj: () => Ct })
        class s {
          valueOf() {}
          liquidMethodMissing(e) {}
        }
        var n = function () {
          return (n =
            Object.assign ||
            function (e) {
              for (var t, r = 1, s = arguments.length; r < s; r++)
                for (var n in (t = arguments[r]))
                  Object.prototype.hasOwnProperty.call(t, n) && (e[n] = t[n])
              return e
            }).apply(this, arguments)
        }
        const i = Object.prototype.toString,
          o = String.prototype.toLowerCase
        function a(e) {
          return "[object String]" === i.call(e)
        }
        function l(e) {
          return "function" == typeof e
        }
        function h(e) {
          return d((e = c(e))) ? "" : String(e)
        }
        function c(e) {
          return e instanceof s ? e.valueOf() : e
        }
        function u(e) {
          return "number" == typeof e
        }
        function p(e) {
          return e && l(e.toLiquid) ? p(e.toLiquid()) : e
        }
        function d(e) {
          return null == e
        }
        function f(e) {
          return "[object Array]" === i.call(e)
        }
        function g(e, t) {
          e = e || {}
          for (const r in e) if (e.hasOwnProperty(r) && !1 === t(e[r], r, e)) break
          return e
        }
        function m(e) {
          return e[e.length - 1]
        }
        function w(e) {
          const t = typeof e
          return null !== e && ("object" === t || "function" === t)
        }
        function T(e, t, r = 1) {
          const s = []
          for (let n = e; n < t; n += r) s.push(n)
          return s
        }
        function y(e, t, r = " ") {
          return b(e, t, r, (e, t) => t + e)
        }
        function b(e, t, r, s) {
          let n = t - (e = String(e)).length
          for (; n-- > 0; ) e = s(e, r)
          return e
        }
        function k(e) {
          return e
        }
        function v(e) {
          return e.replace(/(\w?)([A-Z])/g, (e, t, r) => (t ? t + "_" : "") + r.toLowerCase())
        }
        function _(e, t) {
          return null == e && null == t
            ? 0
            : null == e
            ? 1
            : null == t || (e = o.call(e)) < (t = o.call(t))
            ? -1
            : e > t
            ? 1
            : 0
        }
        class x {
          constructor(e, t, r, s) {
            ;(this.key = e), (this.value = t), (this.next = r), (this.prev = s)
          }
        }
        class O {
          constructor(e, t = 0) {
            ;(this.limit = e),
              (this.size = t),
              (this.cache = {}),
              (this.head = new x("HEAD", null, null, null)),
              (this.tail = new x("TAIL", null, null, null)),
              (this.head.next = this.tail),
              (this.tail.prev = this.head)
          }
          write(e, t) {
            if (this.cache[e]) this.cache[e].value = t
            else {
              const r = new x(e, t, this.head.next, this.head)
              ;(this.head.next.prev = r),
                (this.head.next = r),
                (this.cache[e] = r),
                this.size++,
                this.ensureLimit()
            }
          }
          read(e) {
            if (!this.cache[e]) return
            const { value: t } = this.cache[e]
            return this.remove(e), this.write(e, t), t
          }
          remove(e) {
            const t = this.cache[e]
            ;(t.prev.next = t.next), (t.next.prev = t.prev), delete this.cache[e], this.size--
          }
          clear() {
            ;(this.head.next = this.tail),
              (this.tail.prev = this.head),
              (this.size = 0),
              (this.cache = {})
          }
          ensureLimit() {
            this.size > this.limit && this.remove(this.tail.prev.key)
          }
        }
        var S = Object.freeze({
          resolve: function (e, t, r) {
            return (
              e.length && "/" !== m(e) && (e += "/"),
              (function (e, t) {
                const r = document.createElement("base")
                r.href = e
                const s = document.getElementsByTagName("head")[0]
                s.insertBefore(r, s.firstChild)
                const n = document.createElement("a")
                n.href = t
                const i = n.href
                return s.removeChild(r), i
              })(e, t).replace(/^(\w+:\/\/[^/]+)(\/[^?]+)/, (e, t, s) => {
                const n = s.split("/").pop()
                return /\.\w+$/.test(n) ? e : t + s + r
              })
            )
          },
          readFile: async function (e) {
            return new Promise((t, r) => {
              const s = new XMLHttpRequest()
              ;(s.onload = () => {
                s.status >= 200 && s.status < 300 ? t(s.responseText) : r(new Error(s.statusText))
              }),
                (s.onerror = () => {
                  r(new Error("An error occurred whilst receiving the response."))
                }),
                s.open("GET", e),
                s.send()
            })
          },
          readFileSync: function (e) {
            const t = new XMLHttpRequest()
            if ((t.open("GET", e, !1), t.send(), t.status < 200 || t.status >= 300))
              throw new Error(t.statusText)
            return t.responseText
          },
          exists: async function (e) {
            return !0
          },
          existsSync: function (e) {
            return !0
          },
        })
        function q(e) {
          return e && l(e.equals)
        }
        function E(e, t) {
          return !R(e, t)
        }
        function R(e, t) {
          return t.opts.jsTruthy ? !e : !1 === e || null == e
        }
        const A = {
            "==": (e, t) => (q(e) ? e.equals(t) : q(t) ? t.equals(e) : e === t),
            "!=": (e, t) => (q(e) ? !e.equals(t) : q(t) ? !t.equals(e) : e !== t),
            ">": (e, t) => (q(e) ? e.gt(t) : q(t) ? t.lt(e) : e > t),
            "<": (e, t) => (q(e) ? e.lt(t) : q(t) ? t.gt(e) : e < t),
            ">=": (e, t) => (q(e) ? e.geq(t) : q(t) ? t.leq(e) : e >= t),
            "<=": (e, t) => (q(e) ? e.leq(t) : q(t) ? t.geq(e) : e <= t),
            contains: (e, t) => !(!e || !l(e.indexOf)) && e.indexOf(t) > -1,
            and: (e, t, r) => E(e, r) && E(t, r),
            or: (e, t, r) => E(e, r) || E(t, r),
          },
          D = [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 20, 4, 4, 4, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 20, 2, 8, 0, 0, 0, 0, 8, 0, 0, 0, 64, 0, 65, 0, 0, 33, 33, 33, 33, 33, 33, 33,
            33, 33, 33, 0, 0, 2, 2, 2, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
          ]
        function F(e) {
          const t = {}
          for (const [r, s] of Object.entries(e)) {
            let e = t
            for (let t = 0; t < r.length; t++) {
              const s = r[t]
              ;(e[s] = e[s] || {}),
                t === r.length - 1 && 1 & D[r.charCodeAt(t)] && (e[s].needBoundary = !0),
                (e = e[s])
            }
            ;(e.handler = s), (e.end = !0)
          }
          return t
        }
        D[160] =
          D[5760] =
          D[6158] =
          D[8192] =
          D[8193] =
          D[8194] =
          D[8195] =
          D[8196] =
          D[8197] =
          D[8198] =
          D[8199] =
          D[8200] =
          D[8201] =
          D[8202] =
          D[8232] =
          D[8233] =
          D[8239] =
          D[8287] =
          D[12288] =
            4
        const M = {
          root: ["."],
          cache: void 0,
          extname: "",
          fs: S,
          dynamicPartials: !0,
          jsTruthy: !1,
          trimTagRight: !1,
          trimTagLeft: !1,
          trimOutputRight: !1,
          trimOutputLeft: !1,
          greedy: !0,
          tagDelimiterLeft: "{%",
          tagDelimiterRight: "%}",
          outputDelimiterLeft: "{{",
          outputDelimiterRight: "}}",
          preserveTimezones: !1,
          strictFilters: !1,
          strictVariables: !1,
          lenientIf: !1,
          globals: {},
          keepOutputType: !1,
          operators: A,
          operatorsTrie: F(A),
        }
        function L(e) {
          if (
            ((e = e || {}).hasOwnProperty("root") && (e.root = P(e.root)),
            e.hasOwnProperty("cache"))
          ) {
            let t
            ;(t =
              "number" == typeof e.cache
                ? e.cache > 0
                  ? new O(e.cache)
                  : void 0
                : "object" == typeof e.cache
                ? e.cache
                : e.cache
                ? new O(1024)
                : void 0),
              (e.cache = t)
          }
          return e.hasOwnProperty("operators") && (e.operatorsTrie = F(e.operators)), e
        }
        function P(e) {
          return f(e) ? e : a(e) ? [e] : []
        }
        class N extends Error {
          constructor(e, t) {
            super(e.message), (this.originalError = e), (this.token = t), (this.context = "")
          }
          update() {
            const e = this.originalError
            ;(this.context = (function (e) {
              const [t] = e.getPosition(),
                r = e.input.split("\n"),
                s = Math.max(t - 2, 1),
                n = Math.min(t + 3, r.length)
              return T(s, n + 1)
                .map(
                  (e) => `${e === t ? ">> " : "   "}${y(String(e), String(n).length)}| ${r[e - 1]}`
                )
                .join("\n")
            })(this.token)),
              (this.message = (function (e, t) {
                t.file && (e += `, file:${t.file}`)
                const [r, s] = t.getPosition()
                return e + `, line:${r}, col:${s}`
              })(e.message, this.token)),
              (this.stack =
                this.message + "\n" + this.context + "\n" + this.stack + "\nFrom " + e.stack)
          }
        }
        class $ extends N {
          constructor(e, t) {
            super(new Error(e), t), (this.name = "TokenizationError"), super.update()
          }
        }
        class C extends N {
          constructor(e, t) {
            super(e, t), (this.name = "ParseError"), (this.message = e.message), super.update()
          }
        }
        class I extends N {
          constructor(e, t) {
            super(e, t.token),
              (this.name = "RenderError"),
              (this.message = e.message),
              super.update()
          }
          static is(e) {
            return "RenderError" === e.name
          }
        }
        class B extends N {
          constructor(e, t) {
            super(e, t),
              (this.name = "UndefinedVariableError"),
              (this.message = e.message),
              super.update()
          }
        }
        class j extends Error {
          constructor(e) {
            super(`undefined variable: ${e}`),
              (this.name = "InternalUndefinedVariableError"),
              (this.variableName = e)
          }
        }
        class V extends Error {
          constructor(e) {
            super(e), (this.name = "AssertionError"), (this.message = e + "")
          }
        }
        class z {
          constructor(e = {}, t = M, r = !1) {
            ;(this.scopes = [{}]),
              (this.registers = {}),
              (this.sync = r),
              (this.opts = t),
              (this.globals = t.globals),
              (this.environments = e)
          }
          getRegister(e, t = {}) {
            return (this.registers[e] = this.registers[e] || t)
          }
          setRegister(e, t) {
            return (this.registers[e] = t)
          }
          saveRegister(...e) {
            return e.map((e) => [e, this.getRegister(e)])
          }
          restoreRegister(e) {
            return e.forEach(([e, t]) => this.setRegister(e, t))
          }
          getAll() {
            return [this.globals, this.environments, ...this.scopes].reduce((e, t) => n(e, t), {})
          }
          get(e) {
            const t = this.findScope(e[0])
            return this.getFromScope(t, e)
          }
          getFromScope(e, t) {
            return (
              "string" == typeof t && (t = t.split(".")),
              t.reduce((e, t) => {
                if (
                  ((n = t),
                  (e = d((r = e))
                    ? r
                    : l((r = p(r))[n])
                    ? r[n]()
                    : r instanceof s
                    ? r.hasOwnProperty(n)
                      ? r[n]
                      : r.liquidMethodMissing(n)
                    : "size" === n
                    ? (function (e) {
                        return f(e) || a(e) ? e.length : e.size
                      })(r)
                    : "first" === n
                    ? (function (e) {
                        return f(e) ? e[0] : e.first
                      })(r)
                    : "last" === n
                    ? (function (e) {
                        return f(e) ? e[e.length - 1] : e.last
                      })(r)
                    : r[n]),
                  d(e) && this.opts.strictVariables)
                )
                  throw new j(t)
                var r, n
                return e
              }, e)
            )
          }
          push(e) {
            return this.scopes.push(e)
          }
          pop() {
            return this.scopes.pop()
          }
          bottom() {
            return this.scopes[0]
          }
          findScope(e) {
            for (let t = this.scopes.length - 1; t >= 0; t--) {
              const r = this.scopes[t]
              if (e in r) return r
            }
            return e in this.environments ? this.environments : this.globals
          }
        }
        var U
        function H(e) {
          return Q(e) === U.Operator
        }
        function J(e) {
          return Q(e) === U.HTML
        }
        function W(e) {
          return Q(e) === U.Tag
        }
        function K(e) {
          return Q(e) === U.Quoted
        }
        function Q(e) {
          return e ? e.kind : -1
        }
        function Z(e, t) {
          if (!e || !J(e)) return
          const r = t ? 4 : 16
          for (; D[e.input.charCodeAt(e.end - 1 - e.trimRight)] & r; ) e.trimRight++
        }
        function Y(e, t) {
          if (!e || !J(e)) return
          const r = t ? 4 : 16
          for (; D[e.input.charCodeAt(e.begin + e.trimLeft)] & r; ) e.trimLeft++
          "\n" === e.input.charAt(e.begin + e.trimLeft) && e.trimLeft++
        }
        !(function (e) {
          ;(e[(e.Number = 1)] = "Number"),
            (e[(e.Literal = 2)] = "Literal"),
            (e[(e.Tag = 4)] = "Tag"),
            (e[(e.Output = 8)] = "Output"),
            (e[(e.HTML = 16)] = "HTML"),
            (e[(e.Filter = 32)] = "Filter"),
            (e[(e.Hash = 64)] = "Hash"),
            (e[(e.PropertyAccess = 128)] = "PropertyAccess"),
            (e[(e.Word = 256)] = "Word"),
            (e[(e.Range = 512)] = "Range"),
            (e[(e.Quoted = 1024)] = "Quoted"),
            (e[(e.Operator = 2048)] = "Operator"),
            (e[(e.Delimited = 12)] = "Delimited")
        })(U || (U = {}))
        class X {
          constructor(e, t, r, s, n) {
            ;(this.kind = e), (this.input = t), (this.begin = r), (this.end = s), (this.file = n)
          }
          getText() {
            return this.input.slice(this.begin, this.end)
          }
          getPosition() {
            let [e, t] = [1, 1]
            for (let r = 0; r < this.begin; r++) "\n" === this.input[r] ? (e++, (t = 1)) : t++
            return [e, t]
          }
          size() {
            return this.end - this.begin
          }
        }
        class G extends X {
          constructor(e, t) {
            super(U.Number, e.input, e.begin, t ? t.end : e.end, e.file),
              (this.whole = e),
              (this.decimal = t)
          }
        }
        class ee extends X {
          constructor(e, t, r, s) {
            super(U.Word, e, t, r, s),
              (this.input = e),
              (this.begin = t),
              (this.end = r),
              (this.file = s),
              (this.content = this.getText())
          }
          isNumber(e = !1) {
            for (
              let t = e && 64 & D[this.input.charCodeAt(this.begin)] ? this.begin + 1 : this.begin;
              t < this.end;
              t++
            )
              if (!(32 & D[this.input.charCodeAt(t)])) return !1
            return !0
          }
        }
        class te extends s {
          equals(e) {
            return !(
              e instanceof te ||
              (a((e = c(e))) || f(e) ? 0 !== e.length : !w(e) || 0 !== Object.keys(e).length)
            )
          }
          gt() {
            return !1
          }
          geq() {
            return !1
          }
          lt() {
            return !1
          }
          leq() {
            return !1
          }
          valueOf() {
            return ""
          }
        }
        const re = new (class extends s {
            equals(e) {
              return d(c(e))
            }
            gt() {
              return !1
            }
            geq() {
              return !1
            }
            lt() {
              return !1
            }
            leq() {
              return !1
            }
            valueOf() {
              return null
            }
          })(),
          se = {
            true: !0,
            false: !1,
            nil: re,
            null: re,
            empty: new te(),
            blank: new (class extends te {
              equals(e) {
                return !1 === e || !!d(c(e)) || (a(e) ? /^\s*$/.test(e) : super.equals(e))
              }
            })(),
          }
        class ne extends X {
          constructor(e, t, r, s) {
            super(U.Literal, e, t, r, s),
              (this.input = e),
              (this.begin = t),
              (this.end = r),
              (this.file = s),
              (this.literal = this.getText())
          }
        }
        const ie = {
          "==": 1,
          "!=": 1,
          ">": 1,
          "<": 1,
          ">=": 1,
          "<=": 1,
          contains: 1,
          and: 0,
          or: 0,
        }
        class oe extends X {
          constructor(e, t, r, s) {
            super(U.Operator, e, t, r, s),
              (this.input = e),
              (this.begin = t),
              (this.end = r),
              (this.file = s),
              (this.operator = this.getText())
          }
          getPrecedence() {
            const e = this.getText()
            return e in ie ? ie[e] : 1
          }
        }
        const ae = /[\da-fA-F]/,
          le = /[0-7]/,
          he = { b: "\b", f: "\f", n: "\n", r: "\r", t: "\t", v: "\v" }
        function ce(e) {
          const t = e.charCodeAt(0)
          return t >= 97 ? t - 87 : t >= 65 ? t - 55 : t - 48
        }
        function ue(e) {
          let t = ""
          for (let r = 1; r < e.length - 1; r++)
            if ("\\" === e[r])
              if (void 0 !== he[e[r + 1]]) t += he[e[++r]]
              else if ("u" === e[r + 1]) {
                let s = 0,
                  n = r + 2
                for (; n <= r + 5 && ae.test(e[n]); ) s = 16 * s + ce(e[n++])
                ;(r = n - 1), (t += String.fromCharCode(s))
              } else if (le.test(e[r + 1])) {
                let s = r + 1,
                  n = 0
                for (; s <= r + 3 && le.test(e[s]); ) n = 8 * n + ce(e[s++])
                ;(r = s - 1), (t += String.fromCharCode(n))
              } else t += e[++r]
            else t += e[r]
          return t
        }
        class pe extends X {
          constructor(e, t, r) {
            super(U.PropertyAccess, e.input, e.begin, r, e.file),
              (this.variable = e),
              (this.props = t)
          }
          getVariableAsText() {
            return this.variable instanceof ee
              ? this.variable.getText()
              : ue(this.variable.getText())
          }
        }
        function de(e, t) {
          if (!e) {
            const r = t ? t() : `expect ${e} to be true`
            throw new V(r)
          }
        }
        class fe extends X {
          constructor(e, t, r, s, n, i) {
            super(U.Filter, r, s, n, i), (this.name = e), (this.args = t)
          }
        }
        class ge extends X {
          constructor(e, t, r, s, n, i) {
            super(U.Hash, e, t, r, i),
              (this.input = e),
              (this.begin = t),
              (this.end = r),
              (this.name = s),
              (this.value = n),
              (this.file = i)
          }
        }
        class me extends X {
          constructor(e, t, r, s) {
            super(U.Quoted, e, t, r, s),
              (this.input = e),
              (this.begin = t),
              (this.end = r),
              (this.file = s)
          }
        }
        class we extends X {
          constructor(e, t, r, s) {
            super(U.HTML, e, t, r, s),
              (this.input = e),
              (this.begin = t),
              (this.end = r),
              (this.file = s),
              (this.trimLeft = 0),
              (this.trimRight = 0)
          }
          getContent() {
            return this.input.slice(this.begin + this.trimLeft, this.end - this.trimRight)
          }
        }
        class Te extends X {
          constructor(e, t, r, s, n, i, o, a) {
            super(e, r, s, n, a),
              (this.trimLeft = !1),
              (this.trimRight = !1),
              (this.content = this.getText())
            const l = "-" === t[0],
              h = "-" === m(t)
            ;(this.content = t.slice(l ? 1 : 0, h ? -1 : t.length).trim()),
              (this.trimLeft = l || i),
              (this.trimRight = h || o)
          }
        }
        class ye extends Te {
          constructor(e, t, r, s, n) {
            const {
                trimTagLeft: i,
                trimTagRight: o,
                tagDelimiterLeft: a,
                tagDelimiterRight: l,
              } = s,
              h = e.slice(t + a.length, r - l.length)
            super(U.Tag, h, e, t, r, i, o, n)
            const c = new qe(this.content, s.operatorsTrie)
            if (((this.name = c.readIdentifier().getText()), !this.name))
              throw new $("illegal tag syntax", this)
            c.skipBlank(), (this.args = c.remaining())
          }
        }
        class be extends X {
          constructor(e, t, r, s, n, i) {
            super(U.Range, e, t, r, i),
              (this.input = e),
              (this.begin = t),
              (this.end = r),
              (this.lhs = s),
              (this.rhs = n),
              (this.file = i)
          }
        }
        class ke extends Te {
          constructor(e, t, r, s, n) {
            const {
                trimOutputLeft: i,
                trimOutputRight: o,
                outputDelimiterLeft: a,
                outputDelimiterRight: l,
              } = s,
              h = e.slice(t + a.length, r - l.length)
            super(U.Output, h, e, t, r, i, o, n)
          }
        }
        class ve {
          constructor(e) {
            this.postfix = [...Se(e)]
          }
          *evaluate(e, t) {
            de(e, () => "unable to evaluate: context not defined")
            const r = []
            for (const s of this.postfix)
              if (H(s)) {
                const t = yield r.pop(),
                  n = yield r.pop(),
                  i = Oe(e.opts.operators, s, n, t, e)
                r.push(i)
              } else r.push(yield _e(s, e, t && 1 === this.postfix.length))
            return r[0]
          }
        }
        function _e(e, t, r = !1) {
          return Q(e) === U.PropertyAccess
            ? (function (e, t, r) {
                const s = e.getVariableAsText(),
                  n = e.props.map((e) => _e(e, t, !1))
                try {
                  return t.get([s, ...n])
                } catch (t) {
                  if (r && "InternalUndefinedVariableError" === t.name) return null
                  throw new B(t, e)
                }
              })(e, t, r)
            : (function (e) {
                return Q(e) === U.Range
              })(e)
            ? (function (e, t) {
                return T(+_e(e.lhs, t), +_e(e.rhs, t) + 1)
              })(e, t)
            : (function (e) {
                return Q(e) === U.Literal
              })(e)
            ? (function (e) {
                return se[e.literal]
              })(e)
            : (function (e) {
                return Q(e) === U.Number
              })(e)
            ? (function (e) {
                const t = e.whole.content + "." + (e.decimal ? e.decimal.content : "")
                return Number(t)
              })(e)
            : (function (e) {
                return Q(e) === U.Word
              })(e)
            ? e.getText()
            : K(e)
            ? xe(e)
            : void 0
        }
        function xe(e) {
          return ue(e.getText())
        }
        function Oe(e, t, r, s, n) {
          return (0, e[t.operator])(r, s, n)
        }
        function* Se(e) {
          const t = []
          for (const r of e)
            if (H(r)) {
              for (; t.length && t[t.length - 1].getPrecedence() > r.getPrecedence(); )
                yield t.pop()
              t.push(r)
            } else yield r
          for (; t.length; ) yield t.pop()
        }
        class qe {
          constructor(e, t, r = "") {
            ;(this.input = e),
              (this.trie = t),
              (this.file = r),
              (this.p = 0),
              (this.rawBeginAt = -1),
              (this.N = e.length)
          }
          readExpression() {
            return new ve(this.readExpressionTokens())
          }
          *readExpressionTokens() {
            const e = this.readValue()
            if (e)
              for (yield e; this.p < this.N; ) {
                const e = this.readOperator()
                if (!e) return
                const t = this.readValue()
                if (!t) return
                yield e, yield t
              }
          }
          readOperator() {
            this.skipBlank()
            const e = (function (e, t, r, s = e.length) {
              let n,
                i = r,
                o = t
              for (; i[e[o]] && o < s; ) (i = i[e[o++]]), i.end && (n = i)
              return n ? (n.needBoundary && 1 & D[e.charCodeAt(o)] ? -1 : o) : -1
            })(this.input, this.p, this.trie, this.p + 8)
            if (-1 !== e) return new oe(this.input, this.p, (this.p = e), this.file)
          }
          readFilters() {
            const e = []
            for (;;) {
              const t = this.readFilter()
              if (!t) return e
              e.push(t)
            }
          }
          readFilter() {
            if ((this.skipBlank(), this.end())) return null
            de("|" === this.peek(), () => `unexpected token at ${this.snapshot()}`), this.p++
            const e = this.p,
              t = this.readIdentifier()
            if (!t.size()) return null
            const r = []
            if ((this.skipBlank(), ":" === this.peek()))
              do {
                ++this.p
                const e = this.readFilterArg()
                for (
                  e && r.push(e);
                  this.p < this.N && "," !== this.peek() && "|" !== this.peek();

                )
                  ++this.p
              } while ("," === this.peek())
            return new fe(t.getText(), r, this.input, e, this.p, this.file)
          }
          readFilterArg() {
            const e = this.readValue()
            if (!e) return
            if ((this.skipBlank(), ":" !== this.peek())) return e
            ++this.p
            const t = this.readValue()
            return [e.getText(), t]
          }
          readTopLevelTokens(e = M) {
            const t = []
            for (; this.p < this.N; ) {
              const r = this.readTopLevelToken(e)
              t.push(r)
            }
            return (
              (function (e, t) {
                let r = !1
                for (let s = 0; s < e.length; s++) {
                  const n = e[s]
                  Q(n) & U.Delimited &&
                    (!r && n.trimLeft && Z(e[s - 1], t.greedy),
                    W(n) && ("raw" === n.name ? (r = !0) : "endraw" === n.name && (r = !1)),
                    !r && n.trimRight && Y(e[s + 1], t.greedy))
                }
              })(t, e),
              t
            )
          }
          readTopLevelToken(e) {
            const { tagDelimiterLeft: t, outputDelimiterLeft: r } = e
            return this.rawBeginAt > -1
              ? this.readEndrawOrRawContent(e)
              : this.match(t)
              ? this.readTagToken(e)
              : this.match(r)
              ? this.readOutputToken(e)
              : this.readHTMLToken(e)
          }
          readHTMLToken(e) {
            const t = this.p
            for (; this.p < this.N; ) {
              const { tagDelimiterLeft: t, outputDelimiterLeft: r } = e
              if (this.match(t)) break
              if (this.match(r)) break
              ++this.p
            }
            return new we(this.input, t, this.p, this.file)
          }
          readTagToken(e = M) {
            const { file: t, input: r } = this,
              s = this.p
            if (-1 === this.readToDelimiter(e.tagDelimiterRight))
              throw this.mkError(`tag ${this.snapshot(s)} not closed`, s)
            const n = new ye(r, s, this.p, e, t)
            return "raw" === n.name && (this.rawBeginAt = s), n
          }
          readToDelimiter(e) {
            for (; this.p < this.N; )
              if (8 & this.peekType()) this.readQuoted()
              else if ((++this.p, this.rmatch(e))) return this.p
            return -1
          }
          readOutputToken(e = M) {
            const { file: t, input: r } = this,
              { outputDelimiterRight: s } = e,
              n = this.p
            if (-1 === this.readToDelimiter(s))
              throw this.mkError(`output ${this.snapshot(n)} not closed`, n)
            return new ke(r, n, this.p, e, t)
          }
          readEndrawOrRawContent(e) {
            const { tagDelimiterLeft: t, tagDelimiterRight: r } = e,
              s = this.p
            let n = this.readTo(t) - t.length
            for (; this.p < this.N; )
              if ("endraw" === this.readIdentifier().getText())
                for (; this.p <= this.N; ) {
                  if (this.rmatch(r)) {
                    const t = this.p
                    return s === n
                      ? ((this.rawBeginAt = -1), new ye(this.input, s, t, e, this.file))
                      : ((this.p = n), new we(this.input, s, n, this.file))
                  }
                  if (this.rmatch(t)) break
                  this.p++
                }
              else n = this.readTo(t) - t.length
            throw this.mkError(`raw ${this.snapshot(this.rawBeginAt)} not closed`, s)
          }
          mkError(e, t) {
            return new $(e, new ee(this.input, t, this.N, this.file))
          }
          snapshot(e = this.p) {
            return JSON.stringify(
              (16, (t = this.input.slice(e)).length > 16 ? t.substr(0, 13) + "..." : t)
            )
            var t
          }
          readWord() {
            return (
              console.warn("Tokenizer#readWord() will be removed, use #readIdentifier instead"),
              this.readIdentifier()
            )
          }
          readIdentifier() {
            this.skipBlank()
            const e = this.p
            for (; 1 & this.peekType(); ) ++this.p
            return new ee(this.input, e, this.p, this.file)
          }
          readHashes() {
            const e = []
            for (;;) {
              const t = this.readHash()
              if (!t) return e
              e.push(t)
            }
          }
          readHash() {
            this.skipBlank(), "," === this.peek() && ++this.p
            const e = this.p,
              t = this.readIdentifier()
            if (!t.size()) return
            let r
            return (
              this.skipBlank(),
              ":" === this.peek() && (++this.p, (r = this.readValue())),
              new ge(this.input, e, this.p, t, r, this.file)
            )
          }
          remaining() {
            return this.input.slice(this.p)
          }
          advance(e = 1) {
            this.p += e
          }
          end() {
            return this.p >= this.N
          }
          readTo(e) {
            for (; this.p < this.N; ) if ((++this.p, this.rmatch(e))) return this.p
            return -1
          }
          readValue() {
            const e = this.readQuoted() || this.readRange()
            if (e) return e
            if ("[" === this.peek()) {
              this.p++
              const e = this.readQuoted()
              if (!e) return
              if ("]" !== this.peek()) return
              return this.p++, new pe(e, [], this.p)
            }
            const t = this.readIdentifier()
            if (!t.size()) return
            let r = t.isNumber(!0)
            const s = []
            for (;;)
              if ("[" === this.peek()) {
                ;(r = !1), this.p++
                const e = this.readValue() || new ee(this.input, this.p, this.p, this.file)
                this.readTo("]"), s.push(e)
              } else {
                if ("." !== this.peek() || "." === this.peek(1)) break
                {
                  this.p++
                  const e = this.readIdentifier()
                  if (!e.size()) break
                  e.isNumber() || (r = !1), s.push(e)
                }
              }
            return !s.length && se.hasOwnProperty(t.content)
              ? new ne(this.input, t.begin, t.end, this.file)
              : r
              ? new G(t, s[0])
              : new pe(t, s, this.p)
          }
          readRange() {
            this.skipBlank()
            const e = this.p
            if ("(" !== this.peek()) return
            ++this.p
            const t = this.readValueOrThrow()
            this.p += 2
            const r = this.readValueOrThrow()
            return ++this.p, new be(this.input, e, this.p, t, r, this.file)
          }
          readValueOrThrow() {
            const e = this.readValue()
            return de(e, () => `unexpected token ${this.snapshot()}, value expected`), e
          }
          readQuoted() {
            this.skipBlank()
            const e = this.p
            if (!(8 & this.peekType())) return
            ++this.p
            let t = !1
            for (; this.p < this.N && (++this.p, this.input[this.p - 1] !== this.input[e] || t); )
              t ? (t = !1) : "\\" === this.input[this.p - 1] && (t = !0)
            return new me(this.input, e, this.p, this.file)
          }
          readFileName() {
            const e = this.p
            for (; !(4 & this.peekType()) && "," !== this.peek() && this.p < this.N; ) this.p++
            return new ee(this.input, e, this.p, this.file)
          }
          match(e) {
            for (let t = 0; t < e.length; t++) if (e[t] !== this.input[this.p + t]) return !1
            return !0
          }
          rmatch(e) {
            for (let t = 0; t < e.length; t++)
              if (e[e.length - 1 - t] !== this.input[this.p - 1 - t]) return !1
            return !0
          }
          peekType(e = 0) {
            return D[this.input.charCodeAt(this.p + e)]
          }
          peek(e = 0) {
            return this.input[this.p + e]
          }
          skipBlank() {
            for (; 4 & this.peekType(); ) ++this.p
          }
        }
        class Ee {
          constructor(e) {
            ;(this.html = ""),
              (this.break = !1),
              (this.continue = !1),
              (this.keepOutputType = !1),
              (this.keepOutputType = e)
          }
          write(e) {
            ;(e = !0 === this.keepOutputType ? c(e) : h(c(e))),
              !0 === this.keepOutputType && "string" != typeof e && "" === this.html
                ? (this.html = e)
                : (this.html = h(this.html) + h(e))
          }
        }
        class Re {
          *renderTemplates(e, t, r) {
            r || (r = new Ee(t.opts.keepOutputType))
            for (const s of e)
              try {
                const e = yield s.render(t, r)
                if ((e && r.write(e), r.break || r.continue)) break
              } catch (e) {
                throw I.is(e) ? e : new I(e, s)
              }
            return r.html
          }
        }
        class Ae {
          constructor(e, t) {
            ;(this.handlers = {}),
              (this.stopRequested = !1),
              (this.tokens = e),
              (this.parseToken = t)
          }
          on(e, t) {
            return (this.handlers[e] = t), this
          }
          trigger(e, t) {
            const r = this.handlers[e]
            return !!r && (r(t), !0)
          }
          start() {
            let e
            for (this.trigger("start"); !this.stopRequested && (e = this.tokens.shift()); ) {
              if (this.trigger("token", e)) continue
              if (W(e) && this.trigger(`tag:${e.name}`, e)) continue
              const t = this.parseToken(e, this.tokens)
              this.trigger("template", t)
            }
            return this.stopRequested || this.trigger("end"), this
          }
          stop() {
            return (this.stopRequested = !0), this
          }
        }
        class De {
          constructor(e) {
            this.token = e
          }
        }
        class Fe {
          constructor(e) {
            this.hash = {}
            const t = new qe(e, {})
            for (const e of t.readHashes()) this.hash[e.name.content] = e.value
          }
          *render(e) {
            const t = {}
            for (const r of Object.keys(this.hash)) t[r] = yield _e(this.hash[r], e)
            return t
          }
        }
        class Me {
          constructor(e, t, r, s) {
            ;(this.name = e), (this.impl = t || k), (this.args = r), (this.liquid = s)
          }
          render(e, t) {
            const r = []
            for (const e of this.args) f(e) ? r.push([e[0], _e(e[1], t)]) : r.push(_e(e, t))
            return this.impl.apply({ context: t, liquid: this.liquid }, [e, ...r])
          }
        }
        class Le {
          constructor(e, t) {
            this.filters = []
            const r = new qe(e, t.options.operatorsTrie)
            ;(this.initial = r.readExpression()),
              (this.filters = r
                .readFilters()
                .map(({ name: e, args: r }) => new Me(e, t.filters.get(e), r, t)))
          }
          *value(e, t) {
            t =
              t ||
              (e.opts.lenientIf && this.filters.length > 0 && "default" === this.filters[0].name)
            let r = yield this.initial.evaluate(e, t)
            for (const t of this.filters) r = yield t.render(r, e)
            return r
          }
        }
        function Pe(e) {
          const t = { then: (t) => t(e), catch: () => t }
          return t
        }
        function Ne(e) {
          const t = { then: (r, s) => (s ? s(e) : t), catch: (t) => t(e) }
          return t
        }
        function $e(e) {
          return (function (e) {
            return e && l(e.then)
          })(e)
            ? e
            : (function (e) {
                return e && l(e.next) && l(e.throw) && l(e.return)
              })(e)
            ? (function t(r) {
                let s
                try {
                  s = e.next(r)
                } catch (e) {
                  return Ne(e)
                }
                return s.done
                  ? Pe(s.value)
                  : $e(s.value).then(t, (r) => {
                      let s
                      try {
                        s = e.throw(r)
                      } catch (e) {
                        return Ne(e)
                      }
                      return s.done ? Pe(s.value) : t(s.value)
                    })
              })()
            : Pe(e)
        }
        function Ce(e) {
          return Promise.resolve($e(e))
        }
        function Ie(e) {
          let t
          return (
            $e(e)
              .then((e) => ((t = e), Pe(t)))
              .catch((e) => {
                throw e
              }),
            t
          )
        }
        class Be extends De {
          constructor(e, t, r) {
            super(e), (this.name = e.name)
            const s = r.tags.get(e.name)
            ;(this.impl = Object.create(s)),
              (this.impl.liquid = r),
              this.impl.parse && this.impl.parse(e, t)
          }
          *render(e, t) {
            const r = yield new Fe(this.token.args).render(e),
              s = this.impl
            if (l(s.render)) return yield s.render(e, t, r)
          }
        }
        class je extends De {
          constructor(e, t) {
            super(e), (this.value = new Le(e.content, t))
          }
          *render(e, t) {
            const r = yield this.value.value(e, !1)
            t.write(r)
          }
        }
        class Ve extends De {
          constructor(e) {
            super(e), (this.str = e.getContent())
          }
          *render(e, t) {
            t.write(this.str)
          }
        }
        class ze {
          constructor(e) {
            this.liquid = e
          }
          parse(e) {
            let t
            const r = []
            for (; (t = e.shift()); ) r.push(this.parseToken(t, e))
            return r
          }
          parseToken(e, t) {
            try {
              return W(e)
                ? new Be(e, t, this.liquid)
                : Q(e) === U.Output
                ? new je(e, this.liquid)
                : new Ve(e)
            } catch (t) {
              throw new C(t, e)
            }
          }
          parseStream(e) {
            return new Ae(e, (e, t) => this.parseToken(e, t))
          }
        }
        var Ue = {
          parse: function (e) {
            const t = new qe(e.args, this.liquid.options.operatorsTrie)
            ;(this.key = t.readIdentifier().content),
              t.skipBlank(),
              de("=" === t.peek(), () => `illegal token ${e.getText()}`),
              t.advance(),
              (this.value = t.remaining())
          },
          render: function* (e) {
            e.bottom()[this.key] = yield this.liquid._evalValue(this.value, e)
          },
        }
        function He(e) {
          return f(e)
            ? e
            : a(e) && e.length > 0
            ? [e]
            : w(e)
            ? Object.keys(e).map((t) => [t, e[t]])
            : []
        }
        function Je(e) {
          return f(e) ? e : [e]
        }
        class We extends s {
          constructor(e) {
            super(), (this.i = 0), (this.length = e)
          }
          next() {
            this.i++
          }
          index0() {
            return this.i
          }
          index() {
            return this.i + 1
          }
          first() {
            return 0 === this.i
          }
          last() {
            return this.i === this.length - 1
          }
          rindex() {
            return this.length - this.i
          }
          rindex0() {
            return this.length - this.i - 1
          }
          valueOf() {
            return JSON.stringify(this)
          }
        }
        var Ke,
          Qe = {
            type: "block",
            parse: function (e, t) {
              const r = new qe(e.args, this.liquid.options.operatorsTrie),
                s = r.readIdentifier(),
                n = r.readIdentifier(),
                i = r.readValue()
              let o
              de(s.size() && "in" === n.content && i, () => `illegal tag: ${e.getText()}`),
                (this.variable = s.content),
                (this.collection = i),
                (this.hash = new Fe(r.remaining())),
                (this.templates = []),
                (this.elseTemplates = [])
              const a = this.liquid.parser
                .parseStream(t)
                .on("start", () => (o = this.templates))
                .on("tag:else", () => (o = this.elseTemplates))
                .on("tag:endfor", () => a.stop())
                .on("template", (e) => o.push(e))
                .on("end", () => {
                  throw new Error(`tag ${e.getText()} not closed`)
                })
              a.start()
            },
            render: function* (e, t) {
              const r = this.liquid.renderer
              let s = He(yield _e(this.collection, e))
              if (!s.length) return void (yield r.renderTemplates(this.elseTemplates, e, t))
              const n = yield this.hash.render(e),
                i = n.offset || 0,
                o = void 0 === n.limit ? s.length : n.limit
              ;(s = s.slice(i, i + o)), "reversed" in n && s.reverse()
              const a = { forloop: new We(s.length) }
              e.push(a)
              for (const n of s) {
                if (
                  ((a[this.variable] = n), yield r.renderTemplates(this.templates, e, t), t.break)
                ) {
                  t.break = !1
                  break
                }
                ;(t.continue = !1), a.forloop.next()
              }
              e.pop()
            },
          },
          Ze = {
            parse: function (e, t) {
              const r = new qe(e.args, this.liquid.options.operatorsTrie)
              ;(this.variable = (function (e) {
                const t = e.readIdentifier().content
                if (t) return t
                const r = e.readQuoted()
                return r ? xe(r) : void 0
              })(r)),
                de(this.variable, () => `${e.args} not valid identifier`),
                (this.templates = [])
              const s = this.liquid.parser.parseStream(t)
              s
                .on("tag:endcapture", () => s.stop())
                .on("template", (e) => this.templates.push(e))
                .on("end", () => {
                  throw new Error(`tag ${e.getText()} not closed`)
                }),
                s.start()
            },
            render: function* (e) {
              const t = this.liquid.renderer,
                r = yield t.renderTemplates(this.templates, e)
              e.bottom()[this.variable] = r
            },
          },
          Ye = {
            parse: function (e, t) {
              ;(this.cond = new Le(e.args, this.liquid)),
                (this.cases = []),
                (this.elseTemplates = [])
              let r = []
              const s = this.liquid.parser
                .parseStream(t)
                .on("tag:when", (e) => {
                  r = []
                  const t = new qe(e.args, this.liquid.options.operatorsTrie)
                  for (; !t.end(); ) {
                    const e = t.readValue()
                    e && this.cases.push({ val: e, templates: r }), t.readTo(",")
                  }
                })
                .on("tag:else", () => (r = this.elseTemplates))
                .on("tag:endcase", () => s.stop())
                .on("template", (e) => r.push(e))
                .on("end", () => {
                  throw new Error(`tag ${e.getText()} not closed`)
                })
              s.start()
            },
            render: function* (e, t) {
              const r = this.liquid.renderer,
                s = c(yield this.cond.value(e, e.opts.lenientIf))
              for (const n of this.cases)
                if (_e(n.val, e, e.opts.lenientIf) === s)
                  return void (yield r.renderTemplates(n.templates, e, t))
              yield r.renderTemplates(this.elseTemplates, e, t)
            },
          },
          Xe = {
            parse: function (e, t) {
              const r = this.liquid.parser.parseStream(t)
              r
                .on("token", (e) => {
                  "endcomment" === e.name && r.stop()
                })
                .on("end", () => {
                  throw new Error(`tag ${e.getText()} not closed`)
                }),
                r.start()
            },
          }
        !(function (e) {
          ;(e[(e.OUTPUT = 0)] = "OUTPUT"), (e[(e.STORE = 1)] = "STORE")
        })(Ke || (Ke = {}))
        var Ge = Ke,
          et = {
            parse: function (e) {
              const t = e.args,
                r = new qe(t, this.liquid.options.operatorsTrie)
              ;(this.file = this.liquid.options.dynamicPartials ? r.readValue() : r.readFileName()),
                de(this.file, () => `illegal argument "${e.args}"`)
              const s = r.p
              "with" === r.readIdentifier().content
                ? (r.skipBlank(), ":" !== r.peek() ? (this.withVar = r.readValue()) : (r.p = s))
                : (r.p = s),
                (this.hash = new Fe(r.remaining()))
            },
            render: function* (e, t) {
              const { liquid: r, hash: s, withVar: n, file: i } = this,
                { renderer: o } = r,
                a = e.opts.dynamicPartials
                  ? K(i)
                    ? yield o.renderTemplates(r.parse(xe(i)), e)
                    : yield _e(i, e)
                  : i.getText()
              de(a, () => `illegal filename "${i.getText()}":"${a}"`)
              const l = e.saveRegister("blocks", "blockMode")
              e.setRegister("blocks", {}), e.setRegister("blockMode", Ge.OUTPUT)
              const h = yield s.render(e)
              n && (h[a] = _e(n, e))
              const c = yield r._parseFile(a, e.opts, e.sync)
              e.push(h), yield o.renderTemplates(c, e, t), e.pop(), e.restoreRegister(l)
            },
          },
          tt = {
            parse: function (e) {
              const t = e.args,
                r = new qe(t, this.liquid.options.operatorsTrie)
              for (
                this.file = this.liquid.options.dynamicPartials ? r.readValue() : r.readFileName(),
                  de(this.file, () => `illegal argument "${e.args}"`);
                !r.end();

              ) {
                r.skipBlank()
                const e = r.p,
                  t = r.readIdentifier()
                if (
                  ("with" === t.content || "for" === t.content) &&
                  (r.skipBlank(), ":" !== r.peek())
                ) {
                  const e = r.readValue()
                  if (e) {
                    const s = r.p
                    let n
                    "as" === r.readIdentifier().content ? (n = r.readIdentifier()) : (r.p = s),
                      (this[t.content] = { value: e, alias: n && n.content }),
                      r.skipBlank(),
                      "," === r.peek() && r.advance()
                    continue
                  }
                }
                r.p = e
                break
              }
              this.hash = new Fe(r.remaining())
            },
            render: function* (e, t) {
              const { liquid: r, file: s, hash: n } = this,
                { renderer: i } = r,
                o = e.opts.dynamicPartials
                  ? K(s)
                    ? yield i.renderTemplates(r.parse(xe(s)), e)
                    : _e(s, e)
                  : s.getText()
              de(o, () => `illegal filename "${s.getText()}":"${o}"`)
              const a = new z({}, e.opts, e.sync),
                l = yield n.render(e)
              if (this.with) {
                const { value: t, alias: r } = this.with
                l[r || o] = _e(t, e)
              }
              if ((a.push(l), this.for)) {
                const { value: s, alias: n } = this.for
                let h = _e(s, e)
                ;(h = He(h)), (l.forloop = new We(h.length))
                for (const e of h) {
                  l[n] = e
                  const s = yield r._parseFile(o, a.opts, a.sync)
                  yield i.renderTemplates(s, a, t), l.forloop.next()
                }
              } else {
                const e = yield r._parseFile(o, a.opts, a.sync)
                yield i.renderTemplates(e, a, t)
              }
            },
          },
          rt = {
            parse: function (e) {
              const t = new qe(e.args, this.liquid.options.operatorsTrie)
              this.variable = t.readIdentifier().content
            },
            render: function (e, t) {
              const r = e.environments
              u(r[this.variable]) || (r[this.variable] = 0), t.write(h(--r[this.variable]))
            },
          },
          st = {
            parse: function (e) {
              const t = new qe(e.args, this.liquid.options.operatorsTrie),
                r = t.readValue()
              for (
                t.skipBlank(),
                  this.candidates = [],
                  r &&
                    (":" === t.peek() ? ((this.group = r), t.advance()) : this.candidates.push(r));
                !t.end();

              ) {
                const e = t.readValue()
                e && this.candidates.push(e), t.readTo(",")
              }
              de(this.candidates.length, () => `empty candidates: ${e.getText()}`)
            },
            render: function (e, t) {
              const r = `cycle:${_e(this.group, e)}:` + this.candidates.join(","),
                s = e.getRegister("cycle")
              let n = s[r]
              void 0 === n && (n = s[r] = 0)
              const i = this.candidates[n]
              ;(n = (n + 1) % this.candidates.length), (s[r] = n)
              const o = _e(i, e)
              t.write(o)
            },
          },
          nt = {
            parse: function (e, t) {
              let r
              ;(this.branches = []), (this.elseTemplates = [])
              const s = this.liquid.parser
                .parseStream(t)
                .on("start", () =>
                  this.branches.push({ cond: new Le(e.args, this.liquid), templates: (r = []) })
                )
                .on("tag:elsif", (e) => {
                  this.branches.push({ cond: new Le(e.args, this.liquid), templates: (r = []) })
                })
                .on("tag:else", () => (r = this.elseTemplates))
                .on("tag:endif", () => s.stop())
                .on("template", (e) => r.push(e))
                .on("end", () => {
                  throw new Error(`tag ${e.getText()} not closed`)
                })
              s.start()
            },
            render: function* (e, t) {
              const r = this.liquid.renderer
              for (const s of this.branches)
                if (E(yield s.cond.value(e, e.opts.lenientIf), e))
                  return void (yield r.renderTemplates(s.templates, e, t))
              yield r.renderTemplates(this.elseTemplates, e, t)
            },
          },
          it = {
            parse: function (e) {
              const t = new qe(e.args, this.liquid.options.operatorsTrie)
              this.variable = t.readIdentifier().content
            },
            render: function (e, t) {
              const r = e.environments
              u(r[this.variable]) || (r[this.variable] = 0)
              const s = r[this.variable]
              r[this.variable]++, t.write(h(s))
            },
          },
          ot = {
            parse: function (e, t) {
              const r = new qe(e.args, this.liquid.options.operatorsTrie),
                s = this.liquid.options.dynamicPartials ? r.readValue() : r.readFileName()
              de(s, () => `illegal argument "${e.args}"`),
                (this.file = s),
                (this.hash = new Fe(r.remaining())),
                (this.tpls = this.liquid.parser.parse(t))
            },
            render: function* (e, t) {
              const { liquid: r, hash: s, file: n } = this,
                { renderer: i } = r
              if ("none" === n.getText()) {
                e.setRegister("blockMode", Ge.OUTPUT)
                const r = yield i.renderTemplates(this.tpls, e)
                return void t.write(r)
              }
              const o = e.opts.dynamicPartials
                ? K(n)
                  ? yield i.renderTemplates(r.parse(xe(n)), e)
                  : _e(this.file, e)
                : n.getText()
              de(o, () => `file "${n.getText()}"("${o}") not available`)
              const a = yield r._parseFile(o, e.opts, e.sync)
              e.setRegister("blockMode", Ge.STORE)
              const l = yield i.renderTemplates(this.tpls, e),
                h = e.getRegister("blocks")
              void 0 === h[""] && (h[""] = () => l),
                e.setRegister("blockMode", Ge.OUTPUT),
                e.push(yield s.render(e))
              const c = yield i.renderTemplates(a, e)
              e.pop(), t.write(c)
            },
          }
        class at extends s {
          constructor(e = () => "") {
            super(), (this.superBlockRender = e)
          }
          super() {
            return this.superBlockRender()
          }
        }
        var lt = {
            parse(e, t) {
              const r = /\w+/.exec(e.args)
              ;(this.block = r ? r[0] : ""), (this.tpls = [])
              const s = this.liquid.parser
                .parseStream(t)
                .on("tag:endblock", () => s.stop())
                .on("template", (e) => this.tpls.push(e))
                .on("end", () => {
                  throw new Error(`tag ${e.getText()} not closed`)
                })
              s.start()
            },
            *render(e, t) {
              const r = this.getBlockRender(e)
              yield this.emitHTML(e, t, r)
            },
            getBlockRender(e) {
              const { liquid: t, tpls: r } = this,
                s = e.getRegister("blocks")[this.block],
                n = function* (s) {
                  e.push({ block: s })
                  const n = yield t.renderer.renderTemplates(r, e)
                  return e.pop(), n
                }
              return s ? (e) => s(new at(() => n(e))) : n
            },
            *emitHTML(e, t, r) {
              e.getRegister("blockMode", Ge.OUTPUT) === Ge.STORE
                ? (e.getRegister("blocks")[this.block] = r)
                : t.write(yield r(new at()))
            },
          },
          ht = {
            parse: function (e, t) {
              this.tokens = []
              const r = this.liquid.parser.parseStream(t)
              r
                .on("token", (e) => {
                  "endraw" === e.name ? r.stop() : this.tokens.push(e)
                })
                .on("end", () => {
                  throw new Error(`tag ${e.getText()} not closed`)
                }),
                r.start()
            },
            render: function () {
              return this.tokens.map((e) => e.getText()).join("")
            },
          }
        class ct extends We {
          constructor(e, t) {
            super(e), (this.length = e), (this.cols = t)
          }
          row() {
            return Math.floor(this.i / this.cols) + 1
          }
          col0() {
            return this.i % this.cols
          }
          col() {
            return this.col0() + 1
          }
          col_first() {
            return 0 === this.col0()
          }
          col_last() {
            return this.col() === this.cols
          }
        }
        const ut = {
            assign: Ue,
            for: Qe,
            capture: Ze,
            case: Ye,
            comment: Xe,
            include: et,
            render: tt,
            decrement: rt,
            increment: it,
            cycle: st,
            if: nt,
            layout: ot,
            block: lt,
            raw: ht,
            tablerow: {
              parse: function (e, t) {
                const r = new qe(e.args, this.liquid.options.operatorsTrie)
                ;(this.variable = r.readIdentifier()), r.skipBlank()
                const s = r.readIdentifier()
                let n
                de(s && "in" === s.content, () => `illegal tag: ${e.getText()}`),
                  (this.collection = r.readValue()),
                  (this.hash = new Fe(r.remaining())),
                  (this.templates = [])
                const i = this.liquid.parser
                  .parseStream(t)
                  .on("start", () => (n = this.templates))
                  .on("tag:endtablerow", () => i.stop())
                  .on("template", (e) => n.push(e))
                  .on("end", () => {
                    throw new Error(`tag ${e.getText()} not closed`)
                  })
                i.start()
              },
              render: function* (e, t) {
                let r = He(yield _e(this.collection, e))
                const s = yield this.hash.render(e),
                  n = s.offset || 0,
                  i = void 0 === s.limit ? r.length : s.limit
                r = r.slice(n, n + i)
                const o = s.cols || r.length,
                  a = this.liquid.renderer,
                  l = new ct(r.length, o),
                  h = { tablerowloop: l }
                e.push(h)
                for (let s = 0; s < r.length; s++, l.next())
                  (h[this.variable.content] = r[s]),
                    0 === l.col0() &&
                      (1 !== l.row() && t.write("</tr>"), t.write(`<tr class="row${l.row()}">`)),
                    t.write(`<td class="col${l.col()}">`),
                    yield a.renderTemplates(this.templates, e, t),
                    t.write("</td>")
                r.length && t.write("</tr>"), e.pop()
              },
            },
            unless: {
              parse: function (e, t) {
                let r
                ;(this.templates = []), (this.branches = []), (this.elseTemplates = [])
                const s = this.liquid.parser
                  .parseStream(t)
                  .on("start", () => {
                    ;(r = this.templates), (this.cond = new Le(e.args, this.liquid))
                  })
                  .on("tag:elsif", (e) => {
                    this.branches.push({ cond: new Le(e.args, this.liquid), templates: (r = []) })
                  })
                  .on("tag:else", () => (r = this.elseTemplates))
                  .on("tag:endunless", () => s.stop())
                  .on("template", (e) => r.push(e))
                  .on("end", () => {
                    throw new Error(`tag ${e.getText()} not closed`)
                  })
                s.start()
              },
              render: function* (e, t) {
                const r = this.liquid.renderer
                if (R(yield this.cond.value(e, e.opts.lenientIf), e))
                  yield r.renderTemplates(this.templates, e, t)
                else {
                  for (const s of this.branches)
                    if (E(yield s.cond.value(e, e.opts.lenientIf), e))
                      return void (yield r.renderTemplates(s.templates, e, t))
                  yield r.renderTemplates(this.elseTemplates, e, t)
                }
              },
            },
            break: {
              render: function (e, t) {
                t.break = !0
              },
            },
            continue: {
              render: function (e, t) {
                t.continue = !0
              },
            },
          },
          pt = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&#34;", "'": "&#39;" },
          dt = { "&amp;": "&", "&lt;": "<", "&gt;": ">", "&#34;": '"', "&#39;": "'" }
        function ft(e) {
          return h(e).replace(/&|<|>|"|'/g, (e) => pt[e])
        }
        const gt = Math.abs,
          mt = Math.max,
          wt = Math.min,
          Tt = Math.ceil,
          yt = Math.floor,
          bt = /%([-_0^#:]+)?(\d+)?([EO])?(.)/,
          kt = [
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December",
          ],
          vt = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
          _t = kt.map(St),
          xt = vt.map(St),
          Ot = { 1: "st", 2: "nd", 3: "rd", default: "th" }
        function St(e) {
          return e.slice(0, 3)
        }
        function qt(e) {
          return [
            31,
            (function (e) {
              const t = e.getFullYear()
              return !(0 != (3 & t) || !(t % 100 || (t % 400 == 0 && t)))
            })(e)
              ? 29
              : 28,
            31,
            30,
            31,
            30,
            31,
            31,
            30,
            31,
            30,
            31,
          ]
        }
        function Et(e) {
          let t = 0
          for (let r = 0; r < e.getMonth(); ++r) t += qt(e)[r]
          return t + e.getDate()
        }
        function Rt(e, t) {
          const r = Et(e) + (t - e.getDay()),
            s = 7 - new Date(e.getFullYear(), 0, 1).getDay() + t
          return String(Math.floor((r - s) / 7) + 1)
        }
        const At = { d: 2, e: 2, H: 2, I: 2, j: 3, k: 2, l: 2, L: 3, m: 2, M: 2, S: 2, U: 2, W: 2 },
          Dt = { a: " ", A: " ", b: " ", B: " ", c: " ", e: " ", k: " ", l: " ", p: " ", P: " " },
          Ft = {
            a: (e) => xt[e.getDay()],
            A: (e) => vt[e.getDay()],
            b: (e) => _t[e.getMonth()],
            B: (e) => kt[e.getMonth()],
            c: (e) => e.toLocaleString(),
            C: (e) =>
              (function (e) {
                return parseInt(e.getFullYear().toString().substring(0, 2), 10)
              })(e),
            d: (e) => e.getDate(),
            e: (e) => e.getDate(),
            H: (e) => e.getHours(),
            I: (e) => String(e.getHours() % 12 || 12),
            j: (e) => Et(e),
            k: (e) => e.getHours(),
            l: (e) => String(e.getHours() % 12 || 12),
            L: (e) => e.getMilliseconds(),
            m: (e) => e.getMonth() + 1,
            M: (e) => e.getMinutes(),
            N: (e, t) => {
              const r = Number(t.width) || 9
              return (function (e, t, r = " ") {
                return b(e, t, r, (e, t) => e + t)
              })(String(e.getMilliseconds()).substr(0, r), r, "0")
            },
            p: (e) => (e.getHours() < 12 ? "AM" : "PM"),
            P: (e) => (e.getHours() < 12 ? "am" : "pm"),
            q: (e) =>
              (function (e) {
                const t = e.getDate().toString(),
                  r = parseInt(t.slice(-1))
                return Ot[r] || Ot.default
              })(e),
            s: (e) => Math.round(e.valueOf() / 1e3),
            S: (e) => e.getSeconds(),
            u: (e) => e.getDay() || 7,
            U: (e) => Rt(e, 0),
            w: (e) => e.getDay(),
            W: (e) => Rt(e, 1),
            x: (e) => e.toLocaleDateString(),
            X: (e) => e.toLocaleTimeString(),
            y: (e) => e.getFullYear().toString().substring(2, 4),
            Y: (e) => e.getFullYear(),
            z: (e, t) => {
              const r = e.getTimezoneOffset(),
                s = Math.abs(r),
                n = s % 60
              return (
                (r > 0 ? "-" : "+") +
                y(Math.floor(s / 60), 2, "0") +
                (t.flags[":"] ? ":" : "") +
                y(n, 2, "0")
              )
            },
            t: () => "\t",
            n: () => "\n",
            "%": () => "%",
          }
        function Mt(e, t) {
          const [r, s = "", n, i, o] = t,
            a = Ft[o]
          if (!a) return r
          const l = {}
          for (const e of s) l[e] = !0
          let h = String(a(e, { flags: l, width: n, modifier: i })),
            c = Dt[o] || "0",
            u = n || At[o] || 0
          var p
          return (
            l["^"]
              ? (h = h.toUpperCase())
              : l["#"] &&
                ((p = h),
                (h = [...p].some((e) => e >= "a" && e <= "z") ? p.toUpperCase() : p.toLowerCase())),
            l._ ? (c = " ") : l[0] && (c = "0"),
            l["-"] && (u = 0),
            y(h, u, c)
          )
        }
        Ft.h = Ft.b
        class Lt extends Date {
          constructor(e) {
            super(e),
              (this.dateString = e),
              (this.ISO8601_TIMEZONE_PATTERN = /([zZ]|([+-])(\d{2}):(\d{2}))$/),
              (this.inputTimezoneOffset = 0)
            const t = e.match(this.ISO8601_TIMEZONE_PATTERN)
            if (t && "Z" === t[1]) this.inputTimezoneOffset = this.getTimezoneOffset()
            else if (t && t[2] && t[3] && t[4]) {
              const [, , e, r, s] = t,
                n = ("+" === e ? 1 : -1) * (60 * parseInt(r, 10) + parseInt(s, 10))
              this.inputTimezoneOffset = this.getTimezoneOffset() + n
            }
          }
          getDisplayDate() {
            return new Date(+this + 60 * this.inputTimezoneOffset * 1e3)
          }
        }
        var Pt = Object.freeze({
          escape: ft,
          escapeOnce: function (e) {
            return ft(
              (function (e) {
                return String(e).replace(/&(amp|lt|gt|#34|#39);/g, (e) => dt[e])
              })(e)
            )
          },
          newlineToBr: function (e) {
            return e.replace(/\n/g, "<br />\n")
          },
          stripHtml: function (e) {
            return e.replace(/<script.*?<\/script>|<!--.*?-->|<style.*?<\/style>|<.*?>/g, "")
          },
          abs: gt,
          atLeast: mt,
          atMost: wt,
          ceil: Tt,
          dividedBy: (e, t) => e / t,
          floor: yt,
          minus: (e, t) => e - t,
          modulo: (e, t) => e % t,
          times: (e, t) => e * t,
          round: function (e, t = 0) {
            const r = Math.pow(10, t)
            return Math.round(e * r) / r
          },
          plus: function (e, t) {
            return Number(e) + Number(t)
          },
          sortNatural: function (e, t) {
            return e && e.sort
              ? void 0 !== t
                ? [...e].sort((e, r) => _(e[t], r[t]))
                : [...e].sort(_)
              : []
          },
          urlDecode: (e) => e.split("+").map(decodeURIComponent).join(" "),
          urlEncode: (e) => e.split(" ").map(encodeURIComponent).join("+"),
          join: (e, t) => e.join(void 0 === t ? " " : t),
          last: (e) => (f(e) ? m(e) : ""),
          first: (e) => (f(e) ? e[0] : ""),
          reverse: (e) => [...e].reverse(),
          sort: function (e, t) {
            const r = (e) => (t ? this.context.getFromScope(e, t.split(".")) : e)
            return Je(e).sort((e, t) => ((e = r(e)) < (t = r(t)) ? -1 : e > t ? 1 : 0))
          },
          size: (e) => (e && e.length) || 0,
          map: function (e, t) {
            return Je(e).map((e) => this.context.getFromScope(e, t.split(".")))
          },
          compact: function (e) {
            return Je(e).filter((e) => !d(e))
          },
          concat: function (e, t) {
            return Je(e).concat(t)
          },
          slice: function (e, t, r = 1) {
            return (t = t < 0 ? e.length + t : t), e.slice(t, t + r)
          },
          where: function (e, t, r) {
            return Je(e).filter((e) => {
              const s = this.context.getFromScope(e, String(t).split("."))
              return void 0 === r ? E(s, this.context) : s === r
            })
          },
          uniq: function (e) {
            const t = {}
            return (e || []).filter(
              (e) => !t.hasOwnProperty(String(e)) && ((t[String(e)] = !0), !0)
            )
          },
          date: function (e, t) {
            let r = e
            return (
              "now" === e || "today" === e
                ? (r = new Date())
                : u(e)
                ? (r = new Date(1e3 * e))
                : a(e) &&
                  (r = /^\d+$/.test(e)
                    ? new Date(1e3 * +e)
                    : this.context.opts.preserveTimezones
                    ? new Lt(e)
                    : new Date(e)),
              (function (e) {
                return e instanceof Date && !isNaN(e.getTime())
              })(r)
                ? (function (e, t) {
                    let r = e
                    r instanceof Lt && (r = r.getDisplayDate())
                    let s,
                      n = "",
                      i = t
                    for (; (s = bt.exec(i)); )
                      (n += i.slice(0, s.index)),
                        (i = i.slice(s.index + s[0].length)),
                        (n += Mt(r, s))
                    return n + i
                  })(r, t)
                : e
            )
          },
          Default: function (e, t) {
            return f(e) || a(e) ? (e.length ? e : t) : R(c(e), this.context) ? t : e
          },
          json: function (e) {
            return JSON.stringify(e)
          },
          append: function (e, t) {
            return de(2 === arguments.length, () => "append expect 2 arguments"), h(e) + h(t)
          },
          prepend: function (e, t) {
            return de(2 === arguments.length, () => "prepend expect 2 arguments"), h(t) + h(e)
          },
          lstrip: function (e) {
            return h(e).replace(/^\s+/, "")
          },
          downcase: function (e) {
            return h(e).toLowerCase()
          },
          upcase: function (e) {
            return h(e).toUpperCase()
          },
          remove: function (e, t) {
            return h(e).split(String(t)).join("")
          },
          removeFirst: function (e, t) {
            return h(e).replace(String(t), "")
          },
          rstrip: function (e) {
            return h(e).replace(/\s+$/, "")
          },
          split: function (e, t) {
            return h(e).split(String(t))
          },
          strip: function (e) {
            return h(e).trim()
          },
          stripNewlines: function (e) {
            return h(e).replace(/\n/g, "")
          },
          capitalize: function (e) {
            return (e = h(e)).charAt(0).toUpperCase() + e.slice(1).toLowerCase()
          },
          replace: function (e, t, r) {
            return h(e).split(String(t)).join(r)
          },
          replaceFirst: function (e, t, r) {
            return h(e).replace(String(t), r)
          },
          truncate: function (e, t = 50, r = "...") {
            return (e = h(e)).length <= t ? e : e.substr(0, t - r.length) + r
          },
          truncatewords: function (e, t = 15, r = "...") {
            const s = e.split(/\s+/)
            let n = s.slice(0, t).join(" ")
            return s.length >= t && (n += r), n
          },
        })
        class Nt {
          constructor() {
            this.impls = {}
          }
          get(e) {
            const t = this.impls[e]
            return de(t, () => `tag "${e}" not found`), t
          }
          set(e, t) {
            this.impls[e] = t
          }
        }
        class $t {
          constructor(e, t) {
            ;(this.strictFilters = e), (this.liquid = t), (this.impls = {})
          }
          get(e) {
            const t = this.impls[e]
            return de(t || !this.strictFilters, () => `undefined filter: ${e}`), t
          }
          set(e, t) {
            this.impls[e] = t
          }
          create(e, t) {
            return new Me(e, this.get(e), t, this.liquid)
          }
        }
        class Ct {
          constructor(e = {}) {
            var t
            ;(this.options = ((t = L(e)), Object.assign({}, M, t))),
              (this.parser = new ze(this)),
              (this.renderer = new Re()),
              (this.filters = new $t(this.options.strictFilters, this)),
              (this.tags = new Nt()),
              g(ut, (e, t) => this.registerTag(v(t), e)),
              g(Pt, (e, t) => this.registerFilter(v(t), e))
          }
          parse(e, t) {
            const r = new qe(e, this.options.operatorsTrie, t).readTopLevelTokens(this.options)
            return this.parser.parse(r)
          }
          _render(e, t, r, s) {
            const n = Object.assign({}, this.options, L(r)),
              i = new z(t, n, s),
              o = new Ee(n.keepOutputType)
            return this.renderer.renderTemplates(e, i, o)
          }
          async render(e, t, r) {
            return Ce(this._render(e, t, r, !1))
          }
          renderSync(e, t, r) {
            return Ie(this._render(e, t, r, !0))
          }
          _parseAndRender(e, t, r, s) {
            const n = this.parse(e)
            return this._render(n, t, r, s)
          }
          async parseAndRender(e, t, r) {
            return Ce(this._parseAndRender(e, t, r, !1))
          }
          parseAndRenderSync(e, t, r) {
            return Ie(this._parseAndRender(e, t, r, !0))
          }
          *_parseFile(e, t, r) {
            const s = Object.assign({}, this.options, L(t)),
              n = s.root.map((t) => s.fs.resolve(t, e, s.extname))
            if (void 0 !== s.fs.fallback) {
              const t = s.fs.fallback(e)
              void 0 !== t && n.push(t)
            }
            for (const e of n) {
              const { cache: t } = s
              if (t) {
                const r = yield t.read(e)
                if (r) return r
              }
              if (!(r ? s.fs.existsSync(e) : yield s.fs.exists(e))) continue
              const n = this.parse(r ? s.fs.readFileSync(e) : yield s.fs.readFile(e), e)
              return t && t.write(e, n), n
            }
            throw this.lookupError(e, s.root)
          }
          async parseFile(e, t) {
            return Ce(this._parseFile(e, t, !1))
          }
          parseFileSync(e, t) {
            return Ie(this._parseFile(e, t, !0))
          }
          async renderFile(e, t, r) {
            const s = await this.parseFile(e, r)
            return this.render(s, t, r)
          }
          renderFileSync(e, t, r) {
            const s = this.parseFileSync(e, r)
            return this.renderSync(s, t, r)
          }
          _evalValue(e, t) {
            return new Le(e, this).value(t, !1)
          }
          async evalValue(e, t) {
            return Ce(this._evalValue(e, t))
          }
          evalValueSync(e, t) {
            return Ie(this._evalValue(e, t))
          }
          registerFilter(e, t) {
            this.filters.set(e, t)
          }
          registerTag(e, t) {
            this.tags.set(e, t)
          }
          plugin(e) {
            return e.call(this, Ct)
          }
          express() {
            const e = this
            return function (t, r, s) {
              const n = { root: [...P(this.root), ...e.options.root] }
              e.renderFile(t, r, n).then((e) => s(null, e), s)
            }
          }
          lookupError(e, t) {
            const r = new Error("ENOENT")
            return (r.message = `ENOENT: Failed to lookup "${e}" in "${t}"`), (r.code = "ENOENT"), r
          }
          async getTemplate(e, t) {
            return this.parseFile(e, t)
          }
          getTemplateSync(e, t) {
            return this.parseFileSync(e, t)
          }
        }
      },
    },
    __webpack_module_cache__ = {}
  function __webpack_require__(e) {
    var t = __webpack_module_cache__[e]
    if (void 0 !== t) return t.exports
    var r = (__webpack_module_cache__[e] = { exports: {} })
    return __webpack_modules__[e](r, r.exports, __webpack_require__), r.exports
  }
  ;(__webpack_require__.d = (e, t) => {
    for (var r in t)
      __webpack_require__.o(t, r) &&
        !__webpack_require__.o(e, r) &&
        Object.defineProperty(e, r, { enumerable: !0, get: t[r] })
  }),
    (__webpack_require__.o = (e, t) => Object.prototype.hasOwnProperty.call(e, t)),
    (__webpack_require__.r = (e) => {
      "undefined" != typeof Symbol &&
        Symbol.toStringTag &&
        Object.defineProperty(e, Symbol.toStringTag, { value: "Module" }),
        Object.defineProperty(e, "__esModule", { value: !0 })
    })
  var __webpack_exports__ = {}
  ;(() => {
    __webpack_require__.r(__webpack_exports__),
      __webpack_require__.d(__webpack_exports__, {
        evaluate64: () => evaluate64,
        evaluate: () => evaluate,
        evaluateJS: () => evaluateJS,
        evaluateJS64: () => evaluateJS64,
      })
    var liquidjs__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(620),
      js_base64__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(276),
      engine = new liquidjs__WEBPACK_IMPORTED_MODULE_0__.Kj(),
      evaluate64 = function (e) {
        var t = js_base64__WEBPACK_IMPORTED_MODULE_1__.Jx(e),
          r = JSON.parse(t)
        return evaluate(r)
      },
      evaluate = function (e) {
        var t = e.expression,
          r = e.values,
          s = engine.parse("{% if " + t + " %}true{% else %}false{% endif %}")
        return "true" === engine.renderSync(s, r)
      },
      evaluateJS = function (_a) {
        var expressionJS = _a.expressionJS,
          values = _a.values
        try {
          var func = eval(expressionJS)
          return !!func(values)
        } catch (e) {
          return console.error("e", e), !1
        }
      },
      evaluateJS64 = function (e) {
        var t = js_base64__WEBPACK_IMPORTED_MODULE_1__.Jx(e),
          r = JSON.parse(t)
        return evaluateJS(r)
      }
  })(),
    (SuperwallSDKJS = __webpack_exports__)
})()
"""#
