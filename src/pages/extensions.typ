#import "../template.typ": *

This page documents the packet extensions of the 0.75 protocol: how a server
and a client agree on one, the id registry, and the extensions our server
speaks. The reference specification is
#link("https://github.com/zerospades/aosprotocol")[zerospades/aosprotocol], written by the
#link("https://github.com/zerospades/zerospades")[ZeroSpades] authors, and the
#link("https://github.com/Kyrope01/KyroSpades")[KyroSpades] client speaks it too:
#xref("extensions", anchor: "implementations")[who speaks what] is a table below.

= Overview <extensions:overview>

Every extension has a unique id, decided when it is first registered. There
are two kinds:

#table(
  columns: (auto, auto, 1fr),
  table.header([Type], [Purpose], [Extension id range]),
  [`HAS_PACKETS`], [introduces new packets], [0-191],
  [`PACKETLESS`], [changes existing packets or is only announced], [192-255],
)

An extension with packets is reached by one legacy packet id equal to
`64 + extension id`. `PACKETLESS` extensions have no packet of their own.

Each extension packet carries one extra byte after the packet id: a
#strong[sub packet id], used to have several packets per extension. It is
always there, even when the extension needs only one packet.

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Packet ID], [Uint8], [`64 + extension id`],
  [Sub Packet ID], [Uint8], [0-255],
  [Data], [Uint8 array], [the sub packet's data],
)

= Ext Info <extensions:ext-info>

#dir("Client <-> Server")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [60],
  [Total size], [`2 + 2 * n`],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Count], [Uint8], [the number of entries that follow],
  [Entries], [Ext Info Entry x count], [],
)

An entry:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Extension ID], [Uint8], [see the registry],
  [Version], [Uint8], [at least 1\; our server sends 1],
)

`Count` is the #strong[entry count], with no `+1`. An older revision of the
aosprotocol page worded it "length, `length+1` entries will follow"\; the
current one says `length` entries follow, which is what every implementation
(ZeroSpades, KyroSpades, ours) writes and reads. A client reading a server it
does not know should still treat the field as a count\; if the first entry is
not a known extension id and `count - 1` entries parse cleanly to the end of
the packet, the old wording was meant.

== Protocol Flow <extensions:protocol-flow>

The server #strong[must] send an `Ext Info` on connect (our server sends it
right after `State Data`). The client stores the list and #strong[must] reply
with an `Ext Info` naming the extensions it supports.

The reply is the intersection: never name an extension the server did not
offer, and never one you do not implement. An extension's packets go only to
clients that agreed to it. A server sends nothing of a `PACKETLESS`
extension\; the agreement alone changes how it writes existing packets.

= Registry <extensions:registry>

#table(
  columns: (auto, auto, auto, auto, 1fr),
  table.header([ID], [Name], [Kind], [Packet], [What it does]),
  [`0x00`], [Player Properties], [`HAS_PACKETS`], [64], [exact health, blocks, grenades, ammo and score of players],
  [`0x20`], [Damage Markers], [`HAS_PACKETS`], [96], [hit markers and floating damage numbers],
  [`0x30`], [Teamplay], [`HAS_PACKETS`], [112], [config, pings, ESP marks, teammate names],
  [`0x31`], [Pie Menu], [`HAS_PACKETS`], [113], [server-defined quick-chat rings],
  [`0x32`], [Flashlight], [`HAS_PACKETS`], [114], [per-player lights],
  [`0x33`], [Daytime and Weather], [`HAS_PACKETS`], [115], [time of day and weather],
  [`0x35`], [Player Outfit], [`HAS_PACKETS`], [117], [how players look (a draft)],
  [`0x36`], [Edit Mode], [`HAS_PACKETS`], [118], [lifts the client's building limits],
  [`0xC0`], [Player Limit], [`PACKETLESS`], [\-], [how many players the server accepts],
  [`0xC1`], [Message Types], [`PACKETLESS`], [\-], [chat types 3..6],
  [`0xC2`], [Kick Reason], [`PACKETLESS`], [\-], [the kick text as a system line],
)

Registered in the specification but not yet merged (open pull requests of
#link("https://github.com/zerospades/aosprotocol")[zerospades/aosprotocol]\; the
ids are reserved by the proposal, so a client should not name them until the
extension is merged):

#table(
  columns: (auto, auto, auto, auto, 1fr),
  table.header([ID], [Name], [Kind], [Packet], [What it does]),
  [`0x02`], [#link("https://github.com/zerospades/aosprotocol/pull/24")[Client Key]], [`HAS_PACKETS`], [66], [a key the client proves it holds, so servers recognise it\; an encrypted chat for commands],
  [`0x34`], [#link("https://github.com/zerospades/aosprotocol/pull/3")[Extended Spawn Packet]], [`HAS_PACKETS`], [116], [per-player flags and a colour that replaces the team colour],
  [`0x35`], [#link("https://github.com/zerospades/aosprotocol/pull/14")[Player Outfit]], [`HAS_PACKETS`], [117], [how players look (documented below)],
  [`0x37`], [#link("https://github.com/zerospades/aosprotocol/pull/10")[Teams and Scores]], [`HAS_PACKETS`], [119], [team count, names and colours, scores set by the server, the winning score],
  [`0x38`], [#link("https://github.com/zerospades/aosprotocol/pull/19")[Command Completion]], [`HAS_PACKETS`], [120], [the commands the server accepts and what each one takes],
  [`0x3B`], [#link("https://github.com/zerospades/aosprotocol/pull/22")[Custom Weapon (Loadout)]], [`HAS_PACKETS`], [123], [classes, the items in each slot, and live fire-rate, spread and recoil changes],
  [`0x3C`], [#link("https://github.com/zerospades/aosprotocol/pull/23")[Team Flags]], [`HAS_PACKETS`], [124], [leaves a whole team (a team of bots) out of the scoreboard, messages and kill feed],
)

The specification also lists #link("https://github.com/zerospades/aosprotocol/blob/master/commands.md")[the chat
commands] servers share (piqueserver's and LSD's): a command is a chat line that
starts with `/`, needs no packet and no negotiation, and is the cheapest way to
add something that does not have to be drawn.

= Implementations <extensions:implementations>

What each project speaks, read from their code (ZeroSpades `Sources/Client/NetProtocol.h`,
KyroSpades `docs/networking.md`, ngspades-client and ngspades-server's 0.75
profile) as of 2026-11-26. "Yes" means the extension is both negotiated and used.

#table(
  columns: (auto, auto, auto, auto, auto),
  table.header([Extension], [ZeroSpades], [KyroSpades], [ngspades-client], [ngspades-server (0.75)]),
  [Player Properties `0x00`], [Yes], [Yes], [Yes], [Yes],
  [Damage Markers `0x20`], [Yes], [Yes], [Yes], [Yes],
  [Client Key `0x02`], [No], [Yes (proposal)], [No], [No],
  [Teamplay `0x30`], [Yes], [Yes], [Yes], [Yes],
  [Pie Menu `0x31`], [Yes], [Yes], [Yes], [No],
  [Flashlight `0x32`], [Yes], [Yes (with Flicker)], [Yes], [Yes],
  [Daytime and Weather `0x33`], [Yes (Sky)], [Yes (Sky)], [Yes], [Yes],
  [Player Outfit `0x35`], [No], [Yes (draft)], [Yes (draft, and KyroSpades' older form)], [No (1.0 has its own)],
  [Edit Mode `0x36`], [No], [No], [No], [No],
  [Player Limit `0xC0`], [Yes], [Yes], [Yes], [Yes],
  [Message Types `0xC1`], [Yes], [Yes], [Yes], [Yes],
  [Kick Reason `0xC2`], [Yes], [Yes], [Yes], [Yes],
  [UTF-8 Chat (no id)], [Yes], [Yes], [Yes], [Yes],
)

Things worth knowing about each:

- #strong[ZeroSpades] wrote the specification and implemented the extensions as
  they were merged: Teamplay (pull request 68), Damage Markers (74), Daytime and
  Weather (76), Pie Menu (79), Flashlight with its Light Config and Flicker, and
  UTF-8 chat. It reserves player id 255 for the server under Player Limit and
  checks every extension sub packet's length through one helper: a packet that
  is too short is dropped, never half read.
- #strong[KyroSpades] is a client only. It answers `Ext Info` with only the
  extensions it really implements, and nothing for one the server did not offer.
  Its Daytime and Weather keeps the world off the screen until the first `Sky`
  arrives (bounded at 3 seconds) and draws night as no sun, no shadows and black
  fog, so a flashlight is as bright by night as by day. It speaks Client Key (a
  per-server Ed25519 key, one reply per connection). Its Player Outfit is the
  draft's `Set Outfit` with the colour byte and `Team Outfits`.
- #strong[ngspades-client] speaks the same set plus KyroSpades' older Outfit form
  (outfit 1 undead, a three byte `Set Outfit`), which the Build and Shoot zombie
  servers use.
- #strong[Edit Mode] has a specification and no implementation yet.

= Player Properties <extensions:player-properties>

#dir("Server -> Client")[— extension `0x00`, packet 64, sub 0]

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [0],
  [Player ID], [Uint8], [],
  [Health], [Uint8], [0 for an enemy],
  [Blocks], [Uint8], [0 for an enemy],
  [Grenades], [Uint8], [0 for an enemy],
  [Magazine], [Uint8], [],
  [Reserve], [Uint8], [],
  [Score], [Uint32], [kills plus score],
)

Sent when a value changes, at most every 100 ms per player. A client keeps the
ammo and score of everyone (the ammo decides whether another player's shot is
drawn) but the health, blocks and grenades of its own player only.

= Damage Markers <extensions:damage-markers>

#dir("Server -> Client")[— extension `0x20`, packet 96]

Sent to the player who dealt the damage, one packet per hit. There is no
client to server form, and no state to clear on `Player Left` or `Map Start`.
Unlike the other extensions this packet has #strong[no sub packet id]\; the
length of the packet selects the type of the amount:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Packet ID], [Uint8], [96],
  [Player ID], [Uint8], [the player who took the damage],
  [Hit Amount], [see below], [the damage the server applied],
)

#table(
  columns: (auto, 1fr),
  table.header([Packet length], [Hit Amount type]),
  [3 bytes], [Uint8],
  [4 bytes], [Int16, signed],
  [6 bytes], [Int32, signed],
)

A packet of any other length is dropped. A negative amount is a heal. The client
draws a hit marker and floats the number over the victim (ZeroSpades and ours
for about three seconds). While the extension is negotiated a client stops
estimating the damage from its own weapon table.

= Teamplay <extensions:teamplay>

#dir("Client <-> Server")[— extension `0x30`, packet 112]

#table(
  columns: (auto, auto, auto, 1fr),
  table.header([Sub], [Name], [Direction], [Purpose]),
  [0], [Config], [`Server -> Client`], [what the server allows],
  [1], [Ping], [both], [a mark for the team],
  [2], [ESP Mark], [`Server -> Client`], [a spot shown through walls],
)

Config:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [0],
  [Flags], [Uint8], [bit 0 teammate ESP, bit 1 pings, bit 2 compass],
  [North X], [Float], [the map direction the client calls north],
  [North Y], [Float], [a zero or NaN means the map's top],
)

Features: bit 0 `TEAM_ESP` (teammates through walls, in their team colour),
bit 1 `PING`, bit 2 `COMPASS_HUD`\; the others are reserved and a client ignores
unknown bits. Ping:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [1],
  [Player ID], [Uint8], [on a relay, who pinged\; 255 is the server itself. Ignored client to server],
  [X, Y, Z], [Float x 3], [the world position],
  [Duration], [Float], [seconds, see below\; a client sends 0, the server fills it in],
  [Surfaces], [Uint8], [bit 0 world, bit 1 minimap, bit 2 compass\; a client sends 0],
  [Blue, Green, Red], [Uint8 x 3], [only the server sets it\; a server with no opinion sends the pinger's team colour],
  [Message ID], [Uint8], [reserved, 0],
  [Reason], [UTF-8 text], [a free label, the remaining bytes],
)

ESP Mark:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [2],
  [Player ID], [Uint8], [the player to reveal],
  [Duration], [Float], [seconds],
  [Surfaces], [Uint8], [as in Ping],
  [Flags], [Uint8], [bit 0 clear on respawn, bit 1 show the name],
  [Blue, Green, Red], [Uint8 x 3], [the outline colour],
  [Message ID], [Uint8], [reserved, 0],
  [Reason], [UTF-8 text], [a free label, the remaining bytes],
)

Duration: 0 removes the ping or mark, a positive finite number is its life in
seconds (the client removes it itself), `+inf` (`0x7F800000`) stays until the
server removes it or the target leaves, and a negative number or NaN is invalid
and the packet is dropped. Our server sends the server's own pings as player
255.

A server with this extension also registers the chat command
`/pingmark <x> <y> <z> [reason...]`, handled as a client to server Ping with
that position and label under the same rules (the `PING` bit, the rate limit,
the checks on the position). A key bind or a Pie Menu slice can send it as a
plain chat line, for example `/pingmark %h Enemy`.

= Pie Menu <extensions:pie-menu>

#dir("Server -> Client")[— extension `0x31`, packet 113]

The server defines the client's quick-chat rings. One ring is a #strong[pie], one
wedge a #strong[slice]\; choosing a slice sends its text as a chat line, often a
command. Server to client only: a server that receives one drops it.

Menu (packet 113, sub 0):

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [0],
  [Pie Count], [Uint8], [how many pies follow],
  [Pies], [Pie x count], [the remaining bytes],
)

Strings are NUL-terminated and encoded as a chat message is (Code Page 437, or
UTF-8 behind `0xFF`) and drawn the way chat is, colour codes included. A Pie:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Contexts], [Uint8], [where it is offered, below],
  [Theme Message ID], [Uint8], [reserved, 0],
  [Theme], [String], [the caption in the middle, empty for none],
  [Slices], [Slice x 6], [exactly six: a server that wants fewer leaves slices blank],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Context bit], [Name], [Offered when the menu opens on]),
  [0], [`BLOCK`], [a block],
  [1], [`TEAMMATE`], [a player of the opening player's team],
  [2], [`ENEMY`], [a player of the other team],
  [3], [`SPECTATOR`], [anything, while the opening player spectates],
  [4], [`DEAD`], [anything, while the opening player is dead],
  [5], [`SKY`], [nothing: no block and no player under the aim],
)

A spectator is offered `SPECTATOR` pies alone, a dead player `DEAD` pies alone. A
Slice:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Message ID], [Uint8], [reserved, 0],
  [Flags], [Uint8], [bit 0 `GLOBAL`: to everyone instead of the team (there is no enemy channel)],
  [Text], [String], [what it sends],
  [Label], [String], [what it draws, empty means the Text unexpanded],
  [Tooltip], [String], [shown while highlighted, never sent],
)

A slice whose Text and Label are both empty is blank and cannot be chosen.
These tokens in a Text are replaced just before it is sent, from the aim taken
when the menu opened:

#table(
  columns: (auto, 1fr, auto),
  table.header([Token], [Expands to], [Example]),
  [`%p`], [`\#` and the id of the player aimed at], [`\#7`],
  [`%b`], [the block aimed at, three integers], [`257 298 40`],
  [`%h`], [the point aimed at, three decimals (at least two places)], [`256.37 298.02 40.00`],
  [`%r`], [the camera ray: position then a unit direction], [`255.50 300.12 40.25 0.7071 -0.7071 0.0000`],
  [`%%`], [a percent sign], [`%`],
)

A token with nothing to name expands to nothing, so `/votekick %p` with nobody
aimed at sends `/votekick ` and not `/votekick \#`. Anything else after a `%` is
reserved and left as it is. Slice 0 is at the top and the rest run clockwise, 60
degrees each\; the centre selects nothing.

The menu belongs to the connection: `Map Start` and `Player Left` clear nothing.
With no Menu received the client keeps its own\; a Menu with pies replaces it
whole (menus are never merged)\; a Menu with `Pie Count` 0 means there is no pie
menu and the client's own does not come back. A Menu is parsed whole before any
of it is applied and refused (the previous one stands, the client logs it) when
a record or string runs past the end of the packet, bytes remain after the last
pie, or a UTF-8 string is malformed.

= Flashlight <extensions:flashlight>

#dir("Client <-> Server")[— extension `0x32`, packet 114]

#table(
  columns: (auto, auto, auto, 1fr),
  table.header([Sub], [Name], [Direction], [Purpose]),
  [0], [Light], [both], [a player's light on or off],
  [1], [Light State], [`Server -> Client`], [one bit per player id],
  [2], [Light Config], [`Server -> Client`], [the beam],
)

Light:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [0],
  [Player ID], [Uint8], [],
  [On], [Uint8], [0 or 1],
)

A client sends Light to ask\; the server relays the accepted request to every
client that agreed, the owner included (a client draws only a light the server
switched on). A light goes off #strong[silently] on `Create Player`,
`Kill Action`, `Player Left` and a new map: no packet, every client clears it
itself.

Light State is `[114, 1, bitmask...]`, one bit per player id, low bit first.

Light Config:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [2],
  [Player ID], [Uint8], [255 = every player without one],
  [Reach], [Uint8], [the distance in blocks at which the light reaches zero],
  [Cone], [Uint8], [the full angle in units of pi/256 radians: 128 is 90 degrees, 255 about 179.3],
  [Red, Green, Blue], [Uint8 x 3], [the beam's colour],
  [Flicker], [Uint8], [0 is steady, otherwise the light drops out in short bursts, dark about `Flicker / 512` of the time],
)

A Reach or Cone of 0 gives no light. Our server's `flashlight_cone` is in the
same unit (default 128). A Light Config for an equipped light is resent when the
player equips another one or the light starts or stops flickering.

= Daytime and Weather <extensions:daytime-and-weather>

#dir("Server -> Client")[— extension `0x33`, packet 115]

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [0],
  [Time], [Uint16], [0 is night, anything else is day (720, noon, is what the reference client writes)],
  [Reserved], [Uint16], [must be 0\; a later version will carry the speed of the day here, so a version 1 client ignores it instead of refusing the packet],
  [Weather], [Uint8 x 2], [not implemented in version 1, must be 0],
)

The server sends it after the agreement and after every map. A client that
agreed and got no Sky yet draws the night: with `Time` 0 the fog and the sky
are black, and the flashlights are the only light. A new server starts by day.
The time belongs to the connection: a new connection clears it, `Map Start`
does not. A client answers `0x33` in its `Ext Info` only when the server offered
version 1 or later, and ignores any packet 115 when it did not negotiate it.

= Player Outfit <extensions:player-outfit>

#dir("Server -> Client")[— extension `0x35`, packet 117]

A draft of the aosprotocol specification:

#table(
  columns: (auto, auto, 1fr),
  table.header([Sub], [Name], [Fields]),
  [0], [Set Outfit], [player, outfit, colour (0 team 1, 1 team 2, 255 its own)],
  [1], [Team Outfits], [team, outfit pairs],
)

Outfits: 0 soldier, 7 miner, 64 zombie, 255 the team's outfit. Cosmetic only.
A player's outfit is reset when it leaves and at every map.

= Edit Mode <extensions:edit-mode>

#dir("Client <-> Server")[— extension `0x36`, packet 118]

Lifts the client's building limits, for map editing and creative servers.
Specification only for now: no client or server speaks it yet.

#table(
  columns: (auto, auto, auto, 1fr),
  table.header([Sub], [Name], [Direction], [Purpose]),
  [0], [Edit Mode], [`Server -> Client`], [edit mode on or off for one player],
  [1], [Block Batch], [both], [build or destroy many blocks at once],
)

Edit Mode:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [0],
  [Player ID], [Uint8], [the player it applies to],
  [State], [Uint8], [0 off, anything else on],
)

The server sends it to every client that negotiated the extension, and a joining
client gets one for each player in edit mode. A player's edit mode is off when
they join. In edit mode a player never runs out of blocks, a `Block Line` may be
any length, they may build and destroy at any distance, build in the air, build
and destroy at z 62 (z 63 never changes), with no delay between builds or spade
hits, and as a spectator (blocks take the colour of `Existing Player`, then of
each `Set Colour`). A client may also let the player fly the camera and build
from it (client side only: it keeps sending the body's position and orientation).
The server judges each block by the edit mode it has already sent and drops any
it does not allow. The map is saved with the existing `/savemap` command.

Block Batch (the sender is told nothing, the server relays it to every client
that negotiated, the sender included):

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [1],
  [Player ID], [Uint8], [the sender\; ignored by the server],
  [Action type], [Uint8], [0 build, 1 destroy, others reserved],
  [Blocks], [Block x n], [to the end of the packet: Int32 X, Y, Z each, 12 bytes],
)

A build takes the player's colour as `Block Action` 0 does, a destroy removes each
block alone as `Block Action` 1. The server drops a whole batch with a reserved
action, no blocks, or more blocks than it accepts.

A client that negotiated Edit Mode applies every `Block Action`, `Block Line` and
`Block Batch`, whoever sent it: a line is drawn in full whatever its length, a
destroy by a player in edit mode also removes z 62, nothing falls while any
player is in edit mode, and otherwise after each destroy a block stays while
solid blocks touching by faces connect it to z 63 and the rest fall. A client
that did not negotiate it cannot follow this, so while anyone is in edit mode
the server disconnects it or makes it a spectator and sends it no block packets,
until it joins again or the next `Map Start`.

= Player Limit <extensions:player-limit>

`PACKETLESS` — extension `0xC0`

Announced through `Ext Info` only: the number of players the server accepts
(the World Update's slot count). Nothing else is sent.

= Message Types <extensions:message-types>

`PACKETLESS` — extension `0xC1`

A client that agreed may receive `Chat Message` types 3 (big), 4 (info), 5
(warning) and 6 (error)\; the others get type 2. Show 3..6 as popups.

= Kick Reason <extensions:kick-reason>

`PACKETLESS` — extension `0xC2`

A system `Chat Message` from player 255 sent just before a disconnect is the
kick text. Let it leave the ENet queue before disconnecting
(`enet_peer_disconnect_later`, not `enet_peer_disconnect`).

= UTF-8 Chat <extensions:utf-8-chat>

Not an extension: a chat line or name beginning with byte `0xFF` and valid
UTF-8 after it is UTF-8. A client announces that it reads it through the
extended version answer's feature bit 0 (below), and only then sends `0xFF`
lines itself.

= Extra Packets <extensions:extra-packets>

After a plain `Version Send` (34) a server may ask for more, once a
connection:

== Handshake Init <extensions:handshake-init>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [31],
  [Total size], [5 bytes],
)

Answer with the same four bytes (packet 32).

== Extended Version Get <extensions:extended-version-get>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [33],
  [Total size], [`1 + n`],
)

The bytes after the id are the property ids the server asks for. Answer with
`Existing Player` (9) whose #strong[first byte is `'x'`] (0x78), then per
property `id, length, payload`, one packet per property, each repeating the
ones before.

#table(
  columns: (auto, auto, 1fr),
  table.header([Id], [Meaning], [Payload]),
  [0], [application], [e.g. `BetterSpades 0.1.5`],
  [1], [language], [e.g. `en_us`, `pt_br`],
  [2], [feature flags], [bit 0: reads UTF-8 chat],
)

An unknown id gets an empty payload.

= Other Resources <extensions:other-resources>

- #link("https://github.com/zerospades/aosprotocol")[aosprotocol specification].
- #xref("protocol075")[Protocol 0.75].
