# Server-Client Protocol
This uses dart's [Socket](https://api.dart.dev/stable/3.3.0/dart-io/Socket-class.html) API; which means each message is a list of bytes.<br>
## New player:
### Server -> Client
`[roomOpen]`

`roomOpen` : `int8` - 0 if the board has been selected and there are as many players as the max players for that board, 1 otherwise.
### Client -> Server
`[nameLength, name, colorA, colorR, colorG, colorB]`

`nameLength` : `int8` - Length in bytes of the name.<br>
`name` : `int8` x `nameLength` - Name of robot.<br>
`colorA` : `int8` - Alpha value of color of robot.<br>
`colorR` : `int8` - Red value of color of robot.<br>
`colorG` : `int8` - Green value of color of robot.<br>
`colorB` : `int8` - Blue value of color of robot.
## General message structure
`[messageLength, messageType, data]`

`messageLength` : `int8` - Length in bytes of `data`.<br>
`messageType` : `int8` - type of message (see below)<br>
`data` : `int8` x messageLength - see below
## Player data messages (Server -> Client)
### Full player data (message type 0)

`[playerCount, playerCount x player]`

`playerCount` : `int8` - How many players there are.<br>
`player` - Message type `1`, without the `index` field.

### Individual player data (message type 1)

`[index, status, 5x programCard, optionCardCount, optionCards, nameLength, name, colorA, colorR, colorG, colorB]`

`index` : `int8` - The index into the full player data list to update. This can be up to one more than the previous maximum index (i.e. up to the length of the current player data list)
`flag` : `int8` - The current flag that the archive marker is on.
`status` : `int8` - Made up of three parts, in order from most significant bit to least:
- `damage` : `int4`- How much damage this robot has taken. This number cannot be above 9.
- `powerDownStatus` : `int2` - 0=not powered down, 1=will be powered down next turn, 2=currently powered down
- `life` : `int2` - How many lives this robot has left. 0 means the robot is dead.

`programCard` : `int8` - there are 5 `programCard`s, each one represents a program card slot in order from first register phase to last:
- `0b1000_0001`: there is a program card there
- `0b1000_0000`: there is not a program card there
- anything else: there is a face-up program card there. The program cards are listed in order in [this file](program_cards.txt).

`optionCardCount` : `int8` - How many option cards this robot has. This number cannot be above 26, as there are only 26 option cards.<br>
`optionCards` : `int8` x `optionCardCount` - For each option card, the index of the option card. These option cards are listed in order in [this file](roborally_client/option_cards.txt). This number cannot be above 25.<br>
`nameLength` : `int8` - Length in bytes of the name.<br>
`name` : `int8` x `nameLength` - Name of robot.<br>
`colorA` : `int8` - Alpha value of color of robot.<br>
`colorR` : `int8` - Red value of color of robot.<br>
`colorG` : `int8` - Green value of color of robot.<br>
`colorB` : `int8` - Blue value of color of robot.
## Programming Phase
### Server -> Client: Program card options (message type 2)

`[pcCount, pcCount x [programCard]]`

`pcCount` : `int8` - The number of program card you have. This number must be less than 10.<br>
`programCard` : `int8` The program card options are listed in [this file](program_cards.txt).

### Client -> Server: Select program card (message type 0)

`[index, programCard]`

`index` : `int8` - The index of the slot you are placing the card in. This number must be less than 5.
`programCard` : `int8` - The program card you have selected. This has to be in the Program card options list above, and cannot be already in a different slot.

### Client -> Server: Deselect program card (message type 1)

`[index]`

`index` : `int8` - The index of the slot you are taking the card from. This number must be less than 5.

### Client -> Server: Submit program cards (message type 2)

`[]`
## TODO: option card usage, choosing to sacrifice an option card instead of being damaged, powering down, etc