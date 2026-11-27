#import "../template.typ": *

This page documents the networking protocols of #strong[Ace of Spades
0.75/0.76] and #strong[ngspades 1.0], for anyone writing a
client or a server that should play with them.

= Overview <index:overview>

#link("http://buildandshoot.com/")[Ace of Spades] uses the
#link("http://enet.bespin.org/Features.html")[ENet networking library] for all
server-client communication. The 0.75 information comes from the original
#link("https://github.com/piqueserver/piqueserver")[pyspades] source and the
clients that speak it, plus the extensions
#link("https://github.com/zerospades")[ZeroSpades] registered for it,
collected in the
#link("https://github.com/zerospades/aosprotocol")[aosprotocol] specification
and spoken by ngspades-client. 1.0 starts from the abandoned
ngspades branch of OpenSpades (yvt's "strengtheningAo" work)\; the ngspades
organization is reviving it, and ngspades-server speaks
#strong[protocol 1.0], its finished and documented form.

== Versions <index:versions>

- #xref("protocol075")[0.75 and 0.76] — the classic protocol public servers
  speak.
- #xref("protocol10")[1.0] — the protocol of ngspades-server.
- #xref("extensions")[Extensions] — the 0.75 extension registry.
- #xref("protocolmaster")[Master Server] and #xref("protocolping")[Ping] — the
  lists, WebRTC signalling, tokens and the raw UDP queries.
- #link("https://github.com/ngspades/protocol/blob/main/examples/c/README.md")[Examples]
  — C and Godot code for the codecs and the connections.

== Implementers <index:implementers>

#table(
  columns: (auto, auto, 1fr),
  table.header([Project], [0.75], [1.0]),
  [#link("https://ngspades.obex.pw/")[ngspades-client and ngspades-server]], [Yes (and the new ZeroSpades extensions)], [Yes],
  [#link("https://github.com/zerospades/zerospades")[ZeroSpades]], [Yes (and the extensions it wrote)], [No],
  [#link("https://github.com/Kyrope01/KyroSpades")[KyroSpades]], [Yes (and the extensions)], [No],
  [#link("https://github.com/xtreme8000/BetterSpades")[BetterSpades]], [Yes], [No],
  [#link("https://github.com/yvt/openspades")[OpenSpades]], [Yes], [No (its abandoned ngspades branch started 1.0)],
  [#link("https://github.com/piqueserver/piqueserver")[piqueserver]], [Yes], [No],
  [#link("https://github.com/SpadesX/SpadesX")[SpadesX]], [Yes], [No],
)

= Other Resources <index:other-resources>

- #link("http://silverspaceship.com/aosmap/aos_file_format.html")[VXL file
  format] — the map format both protocols send.
- #link("https://web.archive.org/web/20100102023608/http://mystaddict.tlayeh.com/Computer%20Camp/Slab6/slab6.txt")[KVX
  file format] — the model format, based on Slab6's.
- #link("https://github.com/piqueserver/piqueserver")[piqueserver] and
  #link("https://github.com/xtreme8000/BetterSpades")[BetterSpades] — reference
  implementations of 0.75.
- #link("https://notaburner.mooo.com/assets/clidoc3.html")[AoS 0.75.015 Canon Client Doc]
  by not a burner (CC0, version 0.0.3) and his server
  #link("https://66.135.15.57/lsd/")[LSd] — a client's view of the 0.75 protocol and a
  server written as its reference. Page 0.75 is checked against both.
- #link("https://github.com/zerospades/aosprotocol")[aosprotocol] — the
  specification of the 0.75 extensions, by the
  #link("https://github.com/zerospades/zerospades")[ZeroSpades] authors\;
  #link("https://github.com/Kyrope01/KyroSpades")[KyroSpades] speaks it too (see
  #xref("extensions", anchor: "implementations")[who speaks what]).
