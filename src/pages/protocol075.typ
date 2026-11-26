#import "../template.typ": *

This page documents the Ace of Spades #strong[0.75] protocol and its
#strong[0.76] variation, the classic wire public servers speak. It is written
from the point of view of both ends: every packet says which direction it
goes, what the server sends or expects, and what a client has to send.

0.76 differs in exactly three places, marked `[0.76]` throughout: the ENet
connect data, the `Map Start` packet and the `World Update` entry. One
implementation can speak both.

= Connection <protocol075:connection>

Ace of Spades uses #link("http://enet.bespin.org/")[ENet] 1.3 over UDP. When
you connect, the 32-bit #strong[connect data] picks the protocol:

#table(
  columns: (auto, 1fr),
  table.header([Number], [Protocol]),
  [3], [0.75],
  [4], [0.76],
)

```c
ENetHost *host = enet_host_create(NULL, 1, 1, 0, 0);
enet_host_compress_with_range_coder(host);
ENetPeer *peer = enet_host_connect(host, &address, 1, 3);
```

#table(
  columns: (auto, 1fr),
  table.header([Setting], [Value]),
  [Port], [`32887` by convention],
  [Channels], [1 (channel 0)],
  [Compression], [ENet's range coder, mandatory in both directions],
  [Reliability], [everything reliable except `World Update` (2), sent unreliable],
  [Framing], [one game packet per ENet packet: one `Uint8` id, then the payload],
)

A server must check the length of every packet before reading it, and check
the `player_id` field of a client packet against the sender's id.

A server may send the map again in the middle of a match (a new round)\; a
client must handle `Map Start` at any time.

== Disconnect Reasons <protocol075:disconnect-reasons>

The server puts a `Uint32` reason in the ENet disconnect event. ENet also uses
0 for a timeout, so 0 is ambiguous.

#table(
  columns: (auto, auto, 1fr),
  table.header([Number], [Reason], [Notes]),
  [0], [Timeout], [or an unspecified server reason],
  [1], [Banned], [],
  [2], [Kicked], [some servers use it for "too many connections from your address"],
  [3], [Wrong protocol version], [connect data was not 3 or 4],
  [4], [Server full], [],
  [5], [Server shutting down], [],
  [8, 9, 10, 11], [Banned, full, kicked, wrong version], [the same reasons after the map download\; the Voxlap client only knows 0..4 before it],
  [20], [Invalid name], [],
  [61], [Server shutting down], [an alternative value some servers use],
)

A system `Chat Message` from player `255` sent just before the disconnect is
the kick text (the Kick Reason extension, see
#xref("extensions")[Extensions]). Show any unknown number as "unknown"\; never
index a table with it.

== About Addresses <protocol075:about-addresses>

```
aos://<address>[:<port>][<version suffix>]
```

- `<address>` is the IPv4 address as one decimal number in
  #strong[little-endian] byte order: `aos://16777343` is `127.0.0.1`
  (`0x0100007F`). Byte 0 of the address is the low byte of the number.
- `<port>` defaults to `32887`.
- A suffix after the port (`:0.75`, `/0.76`) names a version. An unknown suffix
  means 0.75.

Accept a dotted address (`aos://1.2.3.4:32887`) and a bare `host:port` too.

== About Coordinates <protocol075:about-coordinates>

The map is `512 x 512 x 64` voxels. `x` goes east, `y` goes south, and
#strong[`z` grows downwards]: 0 is the top of the world, 63 is the bottom
(water) layer.

- A float position `(0,0,0)` is the corner of voxel `(0,0,0)`\; `(0.5,0.5,0.5)`
  is its centre. Floor each axis to get the voxel.
- A player's position is its #strong[eye], not its feet.
- The two bottom layers, `z = 62` and `z = 63`, cannot be dug.
- Terrain outside 0..511 on `x`/`y` is drawn as a copy of the map (toroidal
  wrap). Players, block edits and block physics do #strong[not] wrap\; grenades
  do.
- A look direction is the unit vector `(ox, oy, oz)`\; `oz` is negative when
  looking up (because `z` grows downwards).

If your engine has `y` up, convert at the protocol boundary:
`engine = (x, 63 - z, y)`, and back with `(x, z, 63 - y)`.

== About Text <protocol075:about-text>

- #strong[CP437] is the original encoding. Bytes `0x80`..`0xFF` are code page
  \437.
- #strong[UTF-8] is sent by newer servers: a string beginning with byte `0xFF`
  and valid UTF-8 after it is UTF-8 (drop the `0xFF`). Anything else is CP437.
  To send, use CP437 when every character fits, otherwise `0xFF` + UTF-8 — and
  only to a server known to read it (its extended version answer's feature bit
  0, or a `0xFF` line it wrote).

Chat text may contain colour control bytes: `0x01`\-`0x02` team colours,
`0x03` spectators, `0x04` red, `0x05` green, `0x06` white, `0x07` grey, `0x08`
yellow. `\n` and `\r` break the line.

= Packets <protocol075:packets>

All packets start with an unsigned byte naming their type\; the sizes below
include that byte. Structures are packed, little-endian, no padding.

== Data Types <protocol075:data-types>

#table(
  columns: (auto, 1fr),
  table.header([Shorthand], [Details]),
  [Uint8], [8-bit unsigned],
  [Int8], [8-bit signed],
  [Uint16], [16-bit unsigned],
  [Int32], [32-bit signed],
  [Uint32], [32-bit unsigned],
  [Float], [32-bit IEEE-754],
  [Vec3], [three Floats: x, y, z],
  [Vec3i], [three Int32: x, y, z],
  [Color], [three bytes in the order #strong[B, G, R]],
  [CP437 String], [NUL-terminated string of that encoding],
  [UTF-8 String], [`0xFF` followed by UTF-8 (see About Text)],
)

== Table of Contents <protocol075:table-of-contents>

- #xref("protocol075", anchor: "position-data")[Position Data]
- #xref("protocol075", anchor: "orientation-data")[Orientation Data]
- #xref("protocol075", anchor: "world-update")[World Update]
- #xref("protocol075", anchor: "input-data")[Input Data]
- #xref("protocol075", anchor: "weapon-input")[Weapon Input]
- #xref("protocol075", anchor: "set-hp--hit")[Set HP / Hit]
- #xref("protocol075", anchor: "grenade")[Grenade]
- #xref("protocol075", anchor: "set-tool")[Set Tool]
- #xref("protocol075", anchor: "set-color")[Set Color]
- #xref("protocol075", anchor: "existing-player")[Existing Player]
- #xref("protocol075", anchor: "short-player-data")[Short Player Data]
- #xref("protocol075", anchor: "move-object")[Move Object]
- #xref("protocol075", anchor: "create-player")[Create Player]
- #xref("protocol075", anchor: "block-action")[Block Action]
- #xref("protocol075", anchor: "block-line")[Block Line]
- #xref("protocol075", anchor: "state-data")[State Data]
- #xref("protocol075", anchor: "kill-action")[Kill Action]
- #xref("protocol075", anchor: "chat-message")[Chat Message]
- #xref("protocol075", anchor: "map-start")[Map Start]
- #xref("protocol075", anchor: "map-chunk")[Map Chunk]
- #xref("protocol075", anchor: "player-left")[Player Left]
- #xref("protocol075", anchor: "territory-capture")[Territory Capture]
- #xref("protocol075", anchor: "progress-bar")[Progress Bar]
- #xref("protocol075", anchor: "intel-capture")[Intel Capture]
- #xref("protocol075", anchor: "intel-pickup")[Intel Pickup]
- #xref("protocol075", anchor: "intel-drop")[Intel Drop]
- #xref("protocol075", anchor: "restock")[Restock]
- #xref("protocol075", anchor: "fog-color")[Fog Color]
- #xref("protocol075", anchor: "weapon-reload")[Weapon Reload]
- #xref("protocol075", anchor: "change-team")[Change Team]
- #xref("protocol075", anchor: "change-weapon")[Change Weapon]
- #xref("protocol075", anchor: "handshake-init")[Handshake Init]
- #xref("protocol075", anchor: "handshake-return")[Handshake Return]
- #xref("protocol075", anchor: "version-get")[Version Get]
- #xref("protocol075", anchor: "version-send")[Version Send]
- #xref("protocol075", anchor: "map-cached")[Map Cached]
- #xref("protocol075", anchor: "ext-info")[Ext Info]
- #xref("protocol075", anchor: "player-properties")[Player Properties]
- #xref("protocol075", anchor: "light")[Light]

== Position Data <protocol075:position-data>

#dir("Server -> Client")

Teleports or corrects #strong[the receiver]. It carries no player id: it is
always about you.

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [0],
  [Total size], [13 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [X, Y, Z], [Vec3], [the eye position],
)

The client sets its position, zeroes its velocity and keeps its look. Never
interpolate: it is a correction, not a movement.

`Client -> Server` uses the same packet to report its eye position, about once
a second while alive and right after a teleport. The server compares it with
its simulation and answers with `Position Data` when it disagrees.

== Orientation Data <protocol075:orientation-data>

#dir("Server -> Client")

Turns the receiver to a direction. Rare\; normally the look rides
`World Update`.

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [1],
  [Total size], [13 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [X, Y, Z], [Vec3], [unit look vector],
)

`Client -> Server`: the client's look, sent when it changed by more than about
0.5 degrees, up to \~120 times a second, and #strong[right before each shot]
so the server can validate the hit.

== World Update <protocol075:world-update>

#dir("Server -> Client")

The only unreliable packet. A newer update replaces the old one.

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [2],
  [Total size], [`1 + 24 * n` (0.76: `1 + 25 * n`)],
)

0.75: one entry per player slot, indexed by id, up to 256 slots.

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Position], [Vec3], [eye position, `(0,0,0)` = not visible],
  [Orientation], [Vec3], [look vector],
)

`[0.76]` one entry per present player:

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Position], [Vec3], [],
  [Orientation], [Vec3], [],
)

Skip your own entry. #strong[A zero position means "not visible": keep the
last known position.] Servers fill dead players, players out of the fog and
free slots with zeros. Interpolate between updates (about 60 a second).

== Input Data <protocol075:input-data>

#dir("Server -> Client")

Another player's movement keys.

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [3],
  [Total size], [3 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Keys], [Uint8], [bit packed, see below],
)

#table(
  columns: (auto, 1fr),
  table.header([Bit], [Key]),
  [1], [forward],
  [2], [back],
  [4], [left],
  [8], [right],
  [16], [jump],
  [32], [crouch],
  [64], [sneak],
  [128], [sprint],
)

For yourself only the jump bit matters (the server echoes the physics it
applied). `Client -> Server` sends the same packet whenever the keys change.

== Weapon Input <protocol075:weapon-input>

#dir("Server -> Client")

Another player's fire buttons.

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [4],
  [Total size], [3 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Buttons], [Uint8], [bit 0 primary (left), bit 1 secondary (right)],
)

It is not the raw mouse: a server sends 0 while a player sprints, switches
tool or reloads. Use it to draw tracers, swings and muzzle flashes for that
player\; ignore it for yourself.

`Client -> Server` sends it whenever a button changes, except while sprinting.

== Set HP / Hit <protocol075:set-hp--hit>

#dir("Server -> Client")[— #strong[Set HP]]

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [5],
  [Total size], [15 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [HP], [Uint8], [the receiver's new health, 0..100],
  [Type], [Uint8], [0 fall damage, 1 anything else],
  [Source], [Vec3], [where the damage came from\; zero for a fall],
)

A drop flashes the screen red and plays the hit sound. The value is
informational: at 0 a `Kill Action` follows.

#dir("Client -> Server")[— #strong[Hit]. Packet id 5 again\; the direction decides.]

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [5],
  [Total size], [3 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Victim], [Uint8], [player id],
  [Hit Type], [Uint8], [0 torso, 1 head, 2 arms, 3 legs, 4 melee],
)

The client reports every hit its shot or swing made\; the server decides
whether it counts and how much it hurts. Send only hits you really saw.

== Grenade <protocol075:grenade>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [6],
  [Total size], [30 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [thrower],
  [Fuse], [Float], [seconds until it explodes],
  [Position], [Vec3], [],
  [Velocity], [Vec3], [#strong[blocks per 1/32 s]],
)

Gravity is 32 blocks/s². The server does not echo a grenade to its thrower.

`Client -> Server`: the throw, with the fuse left (up to 3 s), where it leaves
the hand, and velocity in blocks per 1/32 s (`blocks_per_second / 32`).

== Set Tool <protocol075:set-tool>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [7],
  [Total size], [3 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Tool], [Uint8], [0 spade, 1 block, 2 gun, 3 grenade],
)

Ignore a value above 3. `Client -> Server` sends it whenever the tool changes.

== Set Color <protocol075:set-color>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [8],
  [Total size], [5 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Color], [Color], [B, G, R],
)

Keep it even for a player who is not alive or not joined yet: later block
packets use it. `Client -> Server` sends it when the player picks a colour.

== Existing Player <protocol075:existing-player>

#dir("Client <-> Server")

A player already in the match (server to client), or the client's join (client
to server).

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [9],
  [Total size], [`11 + name`],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Team], [Int8], [0 team 1, 1 team 2, \-1 (255 on the wire) spectator],
  [Weapon], [Uint8], [0 rifle, 1 SMG, 2 shotgun],
  [Tool], [Uint8], [as in Set Tool],
  [Kills], [Uint32], [],
  [Color], [Color], [B, G, R],
  [Name], [CP437 String], [the classic limit is 15 characters],
)

A server sends it for every other player after the map and before
`State Data`. #strong[It carries no position]: keep the player hidden until a
`World Update` or `Create Player` places them.

A client sends it after `State Data` to join, with its own id, the chosen
team, weapon, tool (gun), zero kills, its block colour and its name. The
server answers with `Create Player`.

The extended version answer reuses this id: the first byte after the id is
`'x'` (0x78), which no player id can be (see #xref("extensions")[Extensions]).

== Short Player Data <protocol075:short-player-data>

#dir("Client -> Server")

The older join form.

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [10],
  [Total size], [4 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Team], [Uint8], [],
  [Weapon], [Uint8], [],
)

Servers accept it as well as `Existing Player`.

== Move Object <protocol075:move-object>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [11],
  [Total size], [15 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Object], [Uint8], [CTF: 0/1 intels, 2/3 tents. TC: territory index],
  [Team], [Int8], [the owner, for TC],
  [Position], [Vec3], [the new cell],
)

CTF: moving an intel also drops it from its carrier, silently. TC: `team` is
`0`, `1` or `2` (neutral).

== Create Player <protocol075:create-player>

#dir("Server -> Client")

A player spawned (or joined for the first time).

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [12],
  [Total size], [`15 + name` (16 with an empty name)],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Weapon], [Uint8], [],
  [Team], [Int8], [spectator = not alive],
  [Position], [Vec3], [the #strong[eye]],
  [Name], [CP437 String], [absent in a 16-byte packet],
)

The player is alive unless the team is spectator. It faces east for team 1 and
west for team 2. Reset its block colour to `(111,111,111)` and restock it
(full health, 50 blocks, 3 grenades, full magazine and reserve).

The original Voxlap client draws the player at `position.z - 2`\; modern
clients use the value as given. A 16-byte packet has no name: keep the one you
had.

== Block Action <protocol075:block-action>

#dir("Client <-> Server")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [13],
  [Total size], [15 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Action], [Uint8], [see below],
  [X, Y, Z], [Vec3i], [the block cell],
)

#table(
  columns: (auto, 1fr),
  table.header([Action], [Effect]),
  [0], [build one block with the player's colour (a repaint when already solid)],
  [1], [destroy one block],
  [2], [spade: destroy the block and the ones above and below (1 x 1 x 3)],
  [3], [grenade: destroy 3 x 3 x 3, silently],
  [4], [destroy one block (a gun)],
  [5], [destroy one block (a spade)],
)

Actions 2 and 3 leave `z >= 62` alone\; cells outside the map are ignored.

A server applies its rules (tool in hand, no sprinting, reach about 4 blocks,
a solid neighbour for a build, the block count, editable cells) and relays it
to everyone. A client #strong[batches edits that arrive together]: keys by
position (last wins), apply creates then destroys, then run block physics
once. Applying them one by one makes a repaint collapse a structure.

== Block Line <protocol075:block-line>

#dir("Client <-> Server")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [14],
  [Total size], [26 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Start], [Vec3i], [],
  [End], [Vec3i], [],
)

Builds a line of blocks between the two cells (a 3D DDA), skipping cells that
are already solid. It costs `|dx| + |dy| + |dz| + 1` blocks.

== State Data <protocol075:state-data>

#dir("Server -> Client")

Ends the map download.

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [15],
  [Total size], [83 bytes (CTF), `32 + 13 * n` (TC)],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [you],
  [Fog], [Color], [],
  [Team 1 Color], [Color], [],
  [Team 2 Color], [Color], [],
  [Team 1 Name], [10 bytes], [NUL padded, may lack the NUL],
  [Team 2 Name], [10 bytes], [],
  [Mode], [Uint8], [0 CTF, 1 TC],
)

#strong[CTF (52 bytes)]

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Team 1 Score], [Uint8], [captures],
  [Team 2 Score], [Uint8], [],
  [Capture Limit], [Uint8], [],
  [Intel State], [Uint8], [bit 0 team 1's intel held, bit 1 team 2's],
  [Team 1 Intel], [12 bytes], [held: `{Uint8 carrier; 11 bytes padding}`\; else `Vec3 position`],
  [Team 2 Intel], [12 bytes], [the same],
  [Team 1 Base], [Vec3], [the tent],
  [Team 2 Base], [Vec3], [],
)

#strong[TC (`1 + 13 * n`)]

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Count], [Uint8], [number of territories],
  [Territories], [Count x Territory], [],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Territory Field], [Field Type], [Notes]),
  [Position], [Vec3], [],
  [Team], [Uint8], [0, 1 or 2 (neutral)],
)

Treat an unknown mode as TC. Read the names as 10 bytes. Load the map only
now, then open the team menu.

== Kill Action <protocol075:kill-action>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [16],
  [Total size], [5 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Victim], [Uint8], [],
  [Killer], [Uint8], [equal to the victim for a suicide],
  [Kind], [Uint8], [see below],
  [Respawn], [Uint8], [seconds until the respawn],
)

#table(
  columns: (auto, 1fr),
  table.header([Kind], [Meaning]),
  [0], [weapon],
  [1], [headshot],
  [2], [melee],
  [3], [grenade],
  [4], [fall],
  [5], [team change],
  [6], [weapon/class change],
)

The killer scores unless it was a suicide. Draw the kill feed and start the
respawn countdown.

== Chat Message <protocol075:chat-message>

#dir("Client <-> Server")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [17],
  [Total size], [`3 + text` (the NUL is included)],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [255 = the server],
  [Type], [Uint8], [0 all, 1 team, 2 system\; 3-6 optional (see Message Types)],
  [Text], [CP437 String], [or UTF-8 with the `0xFF` prefix],
)

Server notices use type 2 from player 255. Types 3-6 (big, info, warning,
error) are the Message Types extension. A client sends types 0 and 1 only.

A system line from player 255 sent just before a disconnect is the kick text.

== Map Start <protocol075:map-start>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [18],
  [Total size], [5 bytes (0.76: 73)],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Map Size], [Uint32], [length of the compressed map stream],
)

`[0.76]`

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Map Size], [Uint32], [],
  [CRC32], [Uint32], [of the compressed stream],
  [Map Name], [64 bytes], [NUL padded],
)

The stream is a #strong[zlib-compressed VXL] map. Append every `Map Chunk`
until you have `Map Size` bytes, then inflate and load. A 0.76 server asks
first: answer `Map Cached` with 1 when you already have that CRC32, and it
sends no chunks.

== Map Chunk <protocol075:map-chunk>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [19],
  [Total size], [`1 + n`],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Data], [Uint8 array], [a piece of the stream, in order],
)

Chunks may be any size. Do not start decoding before the total matches.

== Player Left <protocol075:player-left>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [20],
  [Total size], [2 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
)

Clear the slot.

== Territory Capture <protocol075:territory-capture>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [21],
  [Total size], [4 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Territory], [Uint8], [index],
  [Winning], [Uint8], [1 ends the round],
  [Team], [Uint8], [0, 1 or 2 (neutral)],
)

Some clients read an uninitialized pointer when `team` is not 0/1/2\; a server
should only send those three.

== Progress Bar <protocol075:progress-bar>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [22],
  [Total size], [8 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Territory], [Uint8], [index],
  [Team], [Int8], [the capturing team],
  [Rate], [Int8], [progress per 50 s],
  [Progress], [Float], [0..1],
)

A client advances `0.05 * rate` a second, like the 0.75 reference.

== Intel Capture <protocol075:intel-capture>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [23],
  [Total size], [3 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Winning], [Uint8], [1 ends the round],
)

Ten points to the player and one to the team.

== Intel Pickup <protocol075:intel-pickup>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [24],
  [Total size], [2 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [the carrier],
)

== Intel Drop <protocol075:intel-drop>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [25],
  [Total size], [14 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [who dropped it],
  [Position], [Vec3], [where it lies now],
)

== Restock <protocol075:restock>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [26],
  [Total size], [2 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
)

That player gets full health, 50 blocks, 3 grenades and a full reserve. For
yourself update the HUD\; for someone else only play the sound. Ignore it
while you are dead.

== Fog Color <protocol075:fog-color>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [27],
  [Total size], [5 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Alpha], [Uint8], [unused],
  [Color], [Color], [B, G, R],
)

0.75 has no fog distance: it is always 128 blocks.

== Weapon Reload <protocol075:weapon-reload>

#dir("Client <-> Server")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [28],
  [Total size], [4 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Magazine], [Uint8], [rounds now in the gun],
  [Reserve], [Uint8], [rounds left],
)

A client sends it when it starts a reload. The server answers when the reload
finishes\; for yourself that answer settles the ammo, for another player it
only plays the sound (and refills your view of their clip, or you stop drawing
their shots).

== Change Team <protocol075:change-team>

#dir("Client -> Server")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [29],
  [Total size], [3 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Team], [Uint8], [0, 1 or 255],
)

A team change during a match is a death (kill kind 5) followed by a respawn.

== Change Weapon <protocol075:change-weapon>

#dir("Client -> Server")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [30],
  [Total size], [3 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Player ID], [Uint8], [],
  [Weapon], [Uint8], [0 rifle, 1 SMG, 2 shotgun],
)

A death with kill kind 6, then a respawn.

== Handshake Init <protocol075:handshake-init>

#dir("Server -> Client")

Optional client fingerprinting.

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [31],
  [Total size], [5 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Challenge], [Uint32], [echo it back],
)

The Voxlap client does not answer\; a server must never require it.

== Handshake Return <protocol075:handshake-return>

#dir("Client -> Server")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [32],
  [Total size], [5 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Challenge], [Uint32], [the same four bytes],
)

== Version Get <protocol075:version-get>

#dir("Server -> Client")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [33],
  [Total size], [1 byte, or `1 + n` for the extended form],
)

`Version Get` with property ids after the id asks for the extended answer (see
#xref("extensions")[Extensions]).

== Version Send <protocol075:version-send>

#dir("Client -> Server")

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [34],
  [Total size], [69 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Client], [Uint8], [`'B'` BetterSpades and ours, `'o'` OpenSpades],
  [Major, Minor, Revision], [Uint8 x 3], [],
  [OS], [64 bytes], [NUL padded],
)

== Map Cached <protocol075:map-cached>

#dir("Client -> Server")[`[0.76]`]

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [31],
  [Total size], [2 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Cached], [Uint8], [1 = I have the map, send no chunks],
)

== Ext Info <protocol075:ext-info>

#dir("Client <-> Server")

The extension negotiation. Its layout and the registry are in
#xref("extensions")[Extensions].

== Player Properties <protocol075:player-properties>

#dir("Server -> Client")

Optional extension `0x00`.

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [64],
  [Total size], [12 bytes],
)

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

Sent when a value changes, at most every 100 ms per player.

== Light <protocol075:light>

#dir("Client <-> Server")

Optional extension `0x32` (Flashlight).

#table(
  columns: (auto, 1fr),
  table.header([Info], [Value]),
  [Packet ID], [114],
  [Total size], [4 bytes],
)

#table(
  columns: (auto, auto, 1fr),
  table.header([Field Name], [Field Type], [Notes]),
  [Sub], [Uint8], [0 request / relay, 1 relay, 2 config, 3 state],
  [Player ID], [Uint8], [],
  [On], [Uint8], [0 or 1],
)

Send a request only after you accepted the extension, and draw the beam only
when the server relays it. A light goes off silently on `Create Player`,
`Kill Action`, `Player Left` and a new map.

= Game Rules <protocol075:game-rules>

The wire carries state\; the game still needs these rules.

== Players <protocol075:players>

Ids 0..255. Keep state for all 256: joined, alive, team, weapon, tool, score,
name, block colour, position, orientation, input. Only for yourself: health,
blocks, grenades, magazine, reserve. Out-of-range values fall back to
something safe (spectator, rifle, spade)\; never index a table with a value
from the wire.

== Fog <protocol075:fog>

Sight is a cylinder of radius 128 around the camera. Nothing beyond is drawn,
shots stop there, the sky is the fog colour. `State Data` and `Fog Color` set
the colour. A server may send positions beyond the fog anyway\; do not draw
them (that is a wallhack).

== Block Physics <protocol075:block-physics>

When a voxel stops being solid, check its six neighbours. Each solid one
starts a flood fill through solid voxels. If the fill reaches `z >= 62`,
nothing happens\; otherwise everything it reached is detached, falls and is
removed. Voxels that were #strong[already empty] inside a spade or grenade
area must not start a check.

== Damage, Death and Respawn <protocol075:damage-death-and-respawn>

The client reports hits\; the server sends `Set HP`, then `Kill Action` at 0.
On death the intel is dropped (`Intel Drop`), the corpse is drawn (or a
grave), the kill feed updates and the respawn counter runs from the kill
packet. The server spawns the player with `Create Player`.

== Blocks <protocol075:blocks>

A player carries at most 50 blocks. A build costs one, a spade destroy gives
one back. `Restock` refills at the tent. The client counts locally for the
HUD\; the server counts for the rules.

== CTF <protocol075:ctf>

Two scores, a capture limit, two intels (held by a player or lying at a cell),
two tents. Touching the enemy intel picks it up, carrying it into your tent
captures it, dying drops it. A capture puts the intel back at its base
(`Move Object`). A round ends at the capture limit.

== TC <protocol075:tc>

A list of territories (position and owner). Standing in one moves its capture
towards your team\; the server sends `Progress Bar` and then
`Territory Capture`. Owning them all wins.

= Server List <protocol075:server-list>

The classic public list is a JSON array at `/serverlist.json`, for example
`https://services.buildandshoot.com/serverlist.json`. Each entry has at least:

#table(
  columns: (auto, auto, 1fr),
  table.header([Key], [Example], [Notes]),
  [`name`], [`"Deuces Wild"`], [],
  [`identifier`], [`"aos://16777343:32887"`], [the address to join],
  [`map`], [`"Hallway"`], [],
  [`game_mode`], [`"ctf"`], [],
  [`country`], [`"US"`], [ISO 3166-1 alpha-2],
  [`latency`], [`120`], [ms, measured by the list],
  [`players_current`, `players_max`], [`16`, `32`], [],
  [`last_updated`], [`1301931731`], [Unix seconds],
  [`game_version`], [`"0.75"`], [],
)

Ignore keys you do not know and expect duplicates. Our master serves the same
shape plus `id`, `identifier6` and `info`\; see #xref("protocolmaster")[Master
Server].

= Writing a Server <protocol075:writing-a-server>

#strong[Must]

+ An ENet host with the range coder, accepting connect data 3 (and 4).
+ Version, ban and capacity checks with the right disconnect reasons.
+ The map: VXL, zlib, `Map Start`, `Map Chunk`.
+ `Existing Player` for every player, then `State Data`, after the map.
+ The join (`Existing Player` or `Short Player Data`), then `Create Player` to
  everyone.
+ `World Update` at a steady rate, unreliable, zeros for unseen slots.
+ Relay and validate `Input Data`, `Weapon Input`, `Set Tool`, `Set Color`,
  `Orientation Data`, `Position Data`.
+ `Hit` \-\> `Set HP` \-\> `Kill Action` \-\> respawn.
+ `Block Action` and `Block Line` with validation, block physics, `Restock`.
+ Chat and `Player Left`.
+ At least CTF.

#strong[Should]

- Server-side movement physics with corrections.
- `Create Player` for players that do not move (bots) when someone joins, or
  they stand at the map corner until the next `World Update`.
- Grenades simulated on the server.
- `Version Get` / `Handshake Init`, as optional checks.
- `0xFF` + UTF-8 for text CP437 cannot express.
- `Ext Info` and the extensions.

Spawn a player with 100 health, 50 blocks, 3 grenades, a full magazine and
reserve, the gun in hand and no input held. Send every packet reliable except
`World Update`, and one game packet per ENet packet.

= Other Resources <protocol075:other-resources>

- #xref("protocol10")[Protocol 1.0] — the protocol of our server.
- #xref("extensions")[Extensions] — the aosprotocol extension registry.
- #xref("protocolmaster")[Master Server] and #xref("protocolping")[Ping].
- #link("http://silverspaceship.com/aosmap/aos_file_format.html")[VXL file
  format].
- #link("https://github.com/xtreme8000/BetterSpades")[BetterSpades],
  #link("https://github.com/yvt/openspades")[OpenSpades],
  #link("https://github.com/piqueserver/piqueserver")[pyspades] — reference
  implementations.
