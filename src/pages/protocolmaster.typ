#import "../template.typ": *

This page documents the server lists a client reads and a server announces
itself to: the classic 0.75 master over ENet, and our HTTP master, which also
carries the WebRTC signalling for browsers and the connect tokens.

= Connection <protocolmaster:connection>

== Classic Master (0.75) <protocolmaster:classic-master-075>

The classic master is an ENet server. Connect like a game server, with connect
data `31`:

#table(
  columns: (auto, 1fr),
  table.header([Number], [Meaning]),
  [31], [the classic master protocol],
)

Send the request to `master.buildandshoot.com` on port `32886`, with ENet 1.3
and the range coder.

== Our Master (HTTP) <protocolmaster:our-master-http>

Everything is plain HTTPS and JSON. Every response carries
`Access-Control-Allow-Origin: *`, so a page can call it.

```
https://master.shootanddestroy.obex.pw
```

A server announces itself over IPv4 and IPv6 separately\; a client reads the
list and joins either. The list is also the WebRTC signalling relay, so a
browser can join a server whose UDP port is not reachable.

= Packets <protocolmaster:packets>

== Classic: Major Update <protocolmaster:classic-major-update>

#dir("Server -> Master")

Sent on start-up or after a map change. The master assumes the player count
resets to zero. There is no packet id.

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Max Players], [Uint8], [],
  [Port], [Uint16], [],
  [Name], [CP437 String], [at most 31 bytes],
  [Game Mode], [CP437 String], [at most 7 bytes],
  [Map], [CP437 String], [at most 20 bytes],
)

== Classic: Count Update <protocolmaster:classic-count-update>

#dir("Server -> Master")

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player Count], [Uint8], [sent whenever it changes],
)

== Our Master: `GET /serverlist.json` <protocolmaster:our-master-get-serverlist-json>

#dir("Client <- Master")

An array, the most players first. This is the one way to the list of servers: the
path of the classic masters' file (`services.buildandshoot.com/serverlist.json`),
with more columns. The first ten are the classic file's, in its order (`name`,
`identifier`, `map`, `game_mode`, `country`, `latency`, `players_current`,
`players_max`, `last_updated`, `game_version`) with the same meanings, so one 0.75
parser reads both; what only a server of ours has comes after them. Our master
also takes the classic announce (ENet, UDP 32886, always on), so a 0.75 server lists
there by changing only its master's address.

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [`name`], [String], [1..64 bytes],
  [`identifier`], [String], [the address to join: IPv4 when present, else IPv6],
  [`identifier6`], [String], [the IPv6 address when there is one],
  [`map`, `game_mode`], [String], [at most 32 and 16 bytes],
  [`players_current`, `players_max`], [Number], [0..255\; bots count],
  [`game_version`], [String], [`"1.0"` or `"0.75"`],
  [`id`, `key`], [String], [the server's identity on our master],
  [`webrtc`], [Boolean], [true when the server takes browser players],
  [`dtls_fingerprint`], [String], [the server's DTLS certificate, as SDP shows it],
  [`info`], [Object], [the `HELLOINFO` answer, may be absent],
  [`ice_servers`], [Array], [STUN/TURN for this server (`urls`, `username`, `credential`)],
  [`last_seen`], [Number], [Unix seconds],
)

Example row:

```json
{
  "name": "Alpha",
  "identifier": "aos10://203.0.113.5:32887",
  "identifier6": "aos10://[2001:db8::5]:32887",
  "map": "hallway",
  "game_mode": "ctf",
  "country": "BR",
  "players_current": 3,
  "players_max": 32,
  "game_version": "1.0",
  "id": "9f86d081884c7d65",
  "webrtc": true,
  "dtls_fingerprint": "sha-256 AB:CD:...",
  "ice_servers": [{"urls": "stun:stun.example.net:3478"}],
  "last_seen": 1792500000
}
```

Rows are not permanent: a server that stops announcing disappears within 90 s.
Fetch the list when the player opens the browser and on Refresh\; do not poll
faster than every 10 s. `GET /v1/servers/{id}` is one row (the list itself is only `/serverlist.json`).

A row's `game_version` decides the protocol for a plain ENet join: `1.0` is
`aos10://` with the 1.0 magic, `0.75` is `aos://` with connect data 3.

A client on an IPv6-only machine uses `identifier6`\; on a dual-stack machine
use `identifier`.

=== The Classic List Format <protocolmaster:the-classic-list-format>

`GET /serverlist.json` on a classic master is the same array with at least:

#table(
  columns: (auto, auto, 1fr),
  table.header([Key], [Example], [Notes]),
  [`name`], [`"Deuces Wild"`], [],
  [`identifier`], [`"aos://16777343:32887"`], [],
  [`map`], [`"Hallway"`], [],
  [`game_mode`], [`"ctf"`], [],
  [`country`], [`"US"`], [ISO 3166-1 alpha-2],
  [`latency`], [`120`], [ms, measured by the master],
  [`players_current`, `players_max`], [`16`, `32`], [],
  [`last_updated`], [`1301931731`], [Unix seconds],
  [`game_version`], [`"0.75"`], [],
)

Merge both lists by address, ours winning: a server listed twice appears once,
as ours.

== Our Master: `POST /v1/announce` <protocolmaster:our-master-post-v1announce>

#dir("Server -> Master")

Every call is a #strong[signed envelope]:

```json
{"key": "<base64 Ed25519 public key>",
 "body": "<JSON text>",
 "sig": "<base64 Ed25519 signature over body's bytes>"}
```

`body` is a JSON object as a string, so the signature covers its exact bytes.
Every body has `type` and `time` (Unix #strong[milliseconds]). The master
refuses a body more than 5 minutes off its clock, a body it has seen before
(replay), and a type that is not the endpoint's.

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [`type`, `time`], [String, Number], [`"announce"`],
  [`name`], [String], [1..64 bytes],
  [`port`], [Number], [the game's UDP port],
  [`map`, `mode`], [String], [at most 32 and 16 bytes],
  [`players_current`, `players_max`], [Number], [],
  [`country`], [String], [at most 3 bytes],
  [`webrtc_port`], [Number], [the ICE UDP mux port\; 0 or absent = no browsers],
  [`dtls_fingerprint`], [String], [as in SDP],
  [`info`], [Object], [the `HELLOINFO` answer],
  [`protocol`], [String], [`"1.0"` (default) or `"0.75"`],
  [`ice_servers`], [Array], [at most 8],
  [`join_code`], [String], [optional, six unambiguous characters],
  [`unlisted`], [Boolean], [keep the row off the public list],
)

Answer: `{"id", "identifier", "stale_after", "token_key"}`.

The listed address is the #strong[request's own source address], never one in
the body. The master probes the UDP port with `HELLOINFO` and refuses an
unreachable server with `502`. Announce at start, every 30 s and on a change\;
`{"type": "leave"}` unlists at shutdown.

Errors: `400` malformed or out of range, `401` signature/time/replay, `403`
key not allowed, `404` not listed, `410` a stale answer, `429` too many
servers from one address.

== Our Master: `POST /v1/poll` and `POST /v1/answer` <protocolmaster:our-master-post-v1poll-and-post-v1answer>

#dir("Server <-> Master")

A server with `webrtc_port` long-polls `{"type": "poll"}`\; the master holds
it up to 25 s and answers:

```json
{"offers": [{"id": "<offer id>", "sdp": "<SDP offer>", "ip": "<browser's address>"}]}
```

Within 10 s answer with
`{"type": "answer", "time": ..., "offer": "<id>", "sdp": "<SDP answer>"}` or
`{"type": "reject", "offer": "<id>", "reason": "server full"}`. Poll again at
once, one poll at a time.

== Our Master: `POST /v1/servers/{id}/offer` <protocolmaster:our-master-post-v1serversidoffer>

`Browser -> Master -> Server`

The browser's way in.

```json
{"sdp": "<SDP offer>"}
```

#table(
  columns: (auto, auto, 1fr),
  table.header([Status], [Body], [When]),
  [200], [`{"sdp": "<answer>"}`], [the server answered],
  [400], [`{"error": ...}`], [no `sdp`],
  [404], [], [no such server],
  [409], [], [the server takes no WebRTC],
  [429], [`Retry-After: 60`], [more than 10 offers a minute from one address],
  [503], [`{"error": "<reason>"}`], [the server rejected it, or 32 offers are waiting],
  [504], [], [no answer within the offer timeout],
)

The flow:

#sequence(("browser", "master", "game server"), (
  (note: "open \"reliable\" (defaults) and \"unreliable\" ({ordered: false, maxRetransmits: 0})", at: (0, 1)),
  (note: "createOffer(); wait until iceGatheringState == \"complete\"", at: (0, 1)),
  (from: 0, to: 1, text: "POST /v1/servers/{id}/offer {\"sdp\": offer}"),
  (from: 1, to: 2, text: "the offer, to the waiting long poll"),
  (from: 2, to: 1, text: "POST /v1/answer {\"sdp\": answer}"),
  (from: 1, to: 0, text: "200 {\"sdp\": answer}"),
  (note: "setRemoteDescription(answer)", at: 0),
  (note: "on both channels open: reliable.send(\"connect 135272729\"), text", at: (0, 2)),
  (note: "then binary messages: one 1.0 packet each", at: (0, 2)),
), caption: [WebRTC signalling through the master.])

Do not trickle ICE: wait for `iceGatheringState == "complete"` before posting.
Send `connect <n>` #strong[before] `Initiate Connection`, or the handshake
times out. The server ends with the text `disconnect <reason>`.

== Our Master: Join Codes <protocolmaster:our-master-join-codes>

#dir("Client -> Master")

A listen server announces a six-character code (`ABC-DEF`, with no `I`, `L`,
`O`, `Q`, `0` or `1`). A friend types it in the address box\; the client joins
over WebRTC and the host forwards no port.

#table(
  columns: (auto, 1fr),
  table.header([Call], [Meaning]),
  [`GET /v1/join/{code}`], [the row of the server holding the code\; `404` `{"error": "nobody is playing under this code now"}` when none does],
  [`POST /v1/join/{code}/offer`], [the offer above, by code],
)

The code is given as pasted: `abc-def`, `ABC DEF` and `ABCDEF` are the same.

== Our Master: `POST /v1/token` <protocolmaster:our-master-post-v1token>

#dir("Client -> Master")

Our server admits a UDP player from a #strong[non-local] address only with a
token from the master, so a join flood is rate-limited there. After the
Greeting:

```json
{"address": "203.0.113.5:32887", "nonce": "<base64 of the Greeting's 128 bytes>"}
```

Answer: `{"certificate": "<base64>", "signature": "<base64>"}`, sent as the
`Client Certificate` with `isValid = 1`:

#table(
  columns: (auto, 1fr),
  table.header([Part], [Bytes]),
  [Certificate], [`"SADT"`, version `Uint8` 1, the server's Ed25519 public key (32), expiry `Uint64` little-endian (Unix seconds, 60 s on), nonce length `Uint8`, the nonce],
  [Signature], [Ed25519 by the master over the certificate (64)],
)

`404` when no server is listed at that address, `429` over the limit. Never
cache a token: one token is one connection. Not needed for a local address,
for WebRTC (the offer went through the master), or while the server has no
token key.

= Client Checklist <protocolmaster:client-checklist>

+ Read the list over HTTPS with a timeout (5 s) and a retry (once)\; treat
  "not JSON" as unreachable.
+ Merge our list with the classic list by address, ours winning.
+ Keep the selected row when the list refreshes.
+ Join a row: `aos10://` is 1.0 over ENet, `aos://` is 0.75, a code is WebRTC.
+ Ask #xref("protocolping")[`HELLOINFO`] for the details panel.
+ In a browser only our 1.0 rows are joinable, and only when `webrtc: true`.
+ Fetch a connect token when the server asks, and retry the join once.
+ Never show protocol jargon to a player.

= Other Resources <protocolmaster:other-resources>

- #xref("protocol075")[Protocol 0.75] and #xref("protocol10")[Protocol 1.0].
- #xref("protocolping")[Ping] — `HELLO`, `HELLOLAN`, `HELLOINFO`, map previews.
