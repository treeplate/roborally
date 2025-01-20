// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'board_renderer.dart';
import 'packetbuffer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoboRally Server',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

enum PowerDownStatus { notPoweredDown, nextTurnPoweredDown, poweredDown }

enum Rotation { up, right, down, left }

(int, int) rotationToOffset(Rotation r) {
  switch (r) {
    case Rotation.up:
      return (0, -1);
    case Rotation.right:
      return (1, 0);
    case Rotation.down:
      return (0, 1);
    case Rotation.left:
      return (-1, 0);
  }
}

class Player {
  Socket socket;
  late final String address;
  bool connected = true;
  bool submittedProgramCards = true;
  int life = 3;
  int damage = 0;
  double movementT = 0;
  PowerDownStatus powerDownStatus = PowerDownStatus.notPoweredDown;
  List<int> programCardHand = [];
  final List<int> optionCards = [];
  final List<int?> programCards = List.filled(5,
      null); // most significant bit = 0: visible to everyone; most significant bit = 1: hidden to other players
  String? name;
  Color? color;
  Rotation rotation = Rotation.up;
  int? xPosition;
  int? yPosition;
  late int? archiveMarkerPositionX = xPosition!;
  late int? archiveMarkerPositionY = yPosition!;
  int currentFlag = 0;
  bool dead = false;

  Map<Player, (int, int, int)> getMovementResult(
      int registerPhase, Iterable<Player> allActivePlayers) {
    int xDelta;
    int yDelta;
    int rotationDelta;
    switch (programCardsData[programCards[registerPhase - 1]! % 0x80].type) {
      case ProgramCardType.move1:
        xDelta = rotationToOffset(rotation).$1;
        yDelta = rotationToOffset(rotation).$2;
        rotationDelta = 0;
      case ProgramCardType.move2:
        xDelta = rotationToOffset(rotation).$1 * 2;
        yDelta = rotationToOffset(rotation).$2 * 2;
        rotationDelta = 0;
      case ProgramCardType.move3:
        xDelta = rotationToOffset(rotation).$1 * 3;
        yDelta = rotationToOffset(rotation).$2 * 3;
        rotationDelta = 0;
      case ProgramCardType.backup:
        xDelta = -rotationToOffset(rotation).$1;
        yDelta = -rotationToOffset(rotation).$2;
        rotationDelta = 0;
      case ProgramCardType.turncw:
        xDelta = 0;
        yDelta = 0;
        rotationDelta = 1;
      case ProgramCardType.turnccw:
        xDelta = 0;
        yDelta = 0;
        rotationDelta = -1;
      case ProgramCardType.uturn:
        xDelta = 0;
        yDelta = 0;
        rotationDelta = 2;
    }
    Map<Player, (int, int, int)> deltas = {
      this: (xDelta, yDelta, rotationDelta)
    };
    for (Player player in allActivePlayers) {
      if (player == this) continue;
      if (player.yPosition == yPosition! &&
          player.xPosition! < xPosition! &&
          player.xPosition! >= xPosition! + xDelta) {
        deltas[player] = (xPosition! + xDelta - 1 - player.xPosition!, 0, 0);
      }
      if (player.yPosition == yPosition! &&
          player.xPosition! > xPosition! &&
          player.xPosition! <= xPosition! + xDelta) {
        deltas[player] = (xPosition! + xDelta + 1 - player.xPosition!, 0, 0);
      }
      if (player.xPosition == xPosition! &&
          player.yPosition! < yPosition! &&
          player.yPosition! >= yPosition! + yDelta) {
        deltas[player] = (0, yPosition! + yDelta - 1 - player.yPosition!, 0);
      }
      if (player.xPosition == xPosition! &&
          player.yPosition! > yPosition! &&
          player.yPosition! <= yPosition! + yDelta) {
        deltas[player] = (0, yPosition! + yDelta + 1 - player.yPosition!, 0);
      }
    }
    return deltas;
  }

  void die() {
    dead = true;
    life--;
    damage = 2;
  }

  @override
  String toString() => name ?? address;

  Player(this.socket) {
    address = socket.address.address;
  }

  bool active() =>
      powerDownStatus != PowerDownStatus.poweredDown &&
      !dead &&
      life > 0 &&
      connected &&
      color != null;

  void move(Map<Player, (int, int, int)> moveresult) {
    for (Player player in moveresult.keys) {
      player.xPosition = player.xPosition! + moveresult[player]!.$1;
      player.yPosition = player.yPosition! + moveresult[player]!.$2;
      player.rotation =
          Rotation.values[(player.rotation.index + moveresult[player]!.$3) % 4];
    }
  }
}

enum ProgramCardType { move1, move2, move3, backup, turncw, turnccw, uturn }

class ProgramCardData {
  final int priority;
  final ProgramCardType type;

  ProgramCardData(this.priority, this.type);
}

late List<ProgramCardData> programCardsData;

class LaserEmitter {
  final int xPosition;
  final int yPosition;
  final Rotation rotation;
  final int laserCount;

  LaserEmitter(this.laserCount,
      {required this.xPosition,
      required this.yPosition,
      required this.rotation});
}

class Belt {
  final int positionX;
  final int positionY;
  final bool express;
  final BeltDirectionType type;
  final Rotation rotation;

  Belt(
      {required this.positionX,
      required this.positionY,
      required this.express,
      required this.type,
      required this.rotation});
}

class Gear {
  final int positionX;
  final int positionY;
  final bool clockwise;

  Gear(
      {required this.positionX,
      required this.positionY,
      required this.clockwise});
}

class Pusher {
  final int positionX;
  final int positionY;
  final bool even;

  Pusher(
      {required this.positionX, required this.positionY, required this.even});
}

class Board {
  final int width;
  final int height;
  final List<LaserEmitter> laserEmitters;
  final List<Belt> belts;
  final List<Gear> gears;
  final List<Pusher> pushers;
  final List<Wrench> wrenches;
  final List<Flag> flags;
  final List<(int, int)> spawnPositions;

  Board(this.spawnPositions,
      {required this.width,
      required this.height,
      required this.laserEmitters,
      required this.belts,
      required this.pushers,
      required this.gears,
      required this.wrenches,
      required this.flags});
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  List<Player> players = [];
  Board? board = Board(
    [(2, 2), (4, 4)],
    width: 5,
    height: 5,
    laserEmitters: [],
    belts: [],
    gears: [],
    wrenches: [],
    pushers: [],
    flags: [(positionX: 2, positionY: 3, number: 1)],
  );
  bool gameStarted = false;
  late final List<int> allProgramCards;
  late List<int> programCards;
  Random random = Random();
  Player? lastMovedPlayer;
  Map<Player, (int, int, int)> currentMoveDeltas = {};
  List<Laser> lasers = [];
  bool tie = false;

  @override
  void initState() {
    createTicker(tick).start();
    rootBundle.loadString('program_cards.txt').then((v) {
      allProgramCards = List.generate(v.split('\n').length, (i) => i);
      programCards = allProgramCards.toList()..shuffle(random);
      programCardsData = v.split('\n').map((e) {
        List<String> parts = e.split(' ').toList();
        return ProgramCardData(
          int.parse(parts[0]),
          ProgramCardType.values.singleWhere((e) => e.name == parts[1]),
        );
      }).toList();
    });
    runZonedGuarded(() {
      ServerSocket.bind(InternetAddress.anyIPv4, 2024).then(
        (ServerSocket value) {
          value.listen(
            (Socket socket) {
              Player player = Player(socket);
              socket.add([
                board == null || board!.spawnPositions.length > players.length
                    ? 1
                    : 0
              ]); // 1 - still room; 0 - room full
              setState(() {
                players.add(player);
              });
              PacketBuffer packets = PacketBuffer();
              int? nameLength;
              int? currentPacketLength;
              socket.listen(
                (Uint8List event) {
                  print(event);
                  packets.add(event);
                  nameLength ??= packets.readUint8();
                  if (player.color == null &&
                      packets.available >= nameLength! + 4) {
                    player = newPlayer(player, packets, nameLength, socket);
                    return;
                  }
                  while (packets.available >= 1) {
                    currentPacketLength ??= packets.readUint8();
                    if (packets.available >= currentPacketLength! + 1) {
                      currentPacketLength = null;
                      int messageType = packets.readUint8();
                      switch (messageType) {
                        case 0:
                          if (player.submittedProgramCards) {
                            print('0.a');
                            return;
                          }
                          int index = packets.readUint8();
                          int programCard = packets.readUint8();
                          if (index > 4) {
                            print('0.b');
                            return;
                          }
                          if (!player.programCardHand.contains(programCard)) {
                            print('0.c');
                            return;
                          }
                          player.programCardHand.remove(programCard);
                          player.programCards[index] = programCard | 0x80;
                          resendPlayer(player);
                        case 1:
                          if (player.submittedProgramCards) {
                            print('1.a');
                            return;
                          }
                          int index = packets.readUint8();
                          if (index > 4) {
                            print('1.b');
                            return;
                          }
                          int? programCard = player.programCards[index];
                          if (programCard == null) {
                            print('1.c');
                            return;
                          }
                          if (programCard & 0x80 == 0) {
                            print('1.d');
                            return;
                          }
                          player.programCardHand.add(programCard % 0x80);
                          player.programCards[index] = null;
                          resendPlayer(player);
                        case 2:
                          if (player.submittedProgramCards) {
                            print('2.a');
                            return;
                          }
                          if (player.programCards.any((e) => e == null)) {
                            print('2.b');
                            return;
                          }
                          player.programCardHand = [];
                          player.submittedProgramCards = true;
                          if (players.every(
                              (player) => player.submittedProgramCards)) {
                            startRunPhase();
                          }
                        default:
                          packets.readUint8List(currentPacketLength!);
                      }
                    } else {
                      break;
                    }
                  }
                },
                onError: (e) {
                  setState(() {
                    if (player.name == null) {
                      players.remove(player);
                      sendMessage(
                        socket,
                        [
                          players.length,
                          ...players
                              .map<List<int>>(encodePlayer)
                              .expand((element) => element),
                        ],
                        0,
                      );
                    }
                    player.connected = false;
                  });
                },
                onDone: () {
                  setState(() {
                    if (player.name == null) {
                      players.remove(player);
                      sendMessage(
                        socket,
                        [
                          players.length,
                          ...players
                              .map<List<int>>(encodePlayer)
                              .expand((element) => element),
                        ],
                        0,
                      );
                    }
                    player.connected = false;
                  });
                },
              );
            },
          );
        },
      );
    }, (e, st) {
      print(e);
    });
    super.initState();
  }

  Player newPlayer(
      Player player, PacketBuffer packets, int? nameLength, Socket socket) {
    setState(() {
      player.name = utf8.decode(packets.readUint8List(nameLength!));
      player.color = Color(packets.readUint32());
      Player? newPlayer;
      for (Player player2 in players) {
        if (!player2.connected && player.name == player2.name) {
          player2.socket = player.socket;
          newPlayer = player2;
          break;
        }
      }
      if (newPlayer != null) {
        players.remove(player);
        player = newPlayer;
      } else if (gameStarted) {
        player.xPosition = board!.spawnPositions[players.indexOf(player)].$1;
        player.yPosition = board!.spawnPositions[players.indexOf(player)].$2;
      }
    });
    sendMessage(
      socket,
      [
        players.length,
        ...players.map<List<int>>(encodePlayer).expand((element) => element),
      ],
      0,
    );
    resendPlayer(player);
    return player;
  }

  void resendPlayer(Player player) {
    List<int> message = [players.indexOf(player), ...encodePlayer(player)];
    for (Player otherPlayer in players) {
      if (otherPlayer.connected && otherPlayer.color != null) {
        sendMessage(otherPlayer.socket, message, 1);
      }
    }
  }

  Player? winner;

  List<int> encodePlayer(Player e) => [
        e.currentFlag,
        (e.damage << 4) + (e.powerDownStatus.index << 2) + e.life,
        ...e.programCards.map(
          (e) => e == null
              ? 0x80
              : e & 0x80 == 0
                  ? e
                  : 0x81,
        ),
        e.optionCards.length,
        ...e.optionCards,
        e.name?.length ?? 0,
        ...utf8.encode(e.name ?? ''),
        e.color == null ? 0x80 : (e.color!.a*255).round(),
        e.color == null ? 0x00 : (e.color!.r*255).round(),
        e.color == null ? 0xFF : (e.color!.g*255).round(),
        e.color == null ? 0xFF : (e.color!.b*255).round(),
      ];
  void sendMessage(Socket socket, List<int> message, int messageType) {
    socket.add([message.length, messageType, ...message]);
  }

  BoardRenderer renderBoard(bool flagPlacementMode) {
    return BoardRenderer(
      width: board!.width,
      height: board!.height,
      robots: flagPlacementMode
          ? []
          : players.where((e) => e.color != null).map((e) {
              (int, int, int) moveresult = currentMoveDeltas[e] ?? (0, 0, 0);
              return (
                laserEnabled: laserT > 0 && laserT < 1,
                color: e.color!,
                position: Offset(
                  e.xPosition!.toDouble() +
                      moveresult.$1 * ((lastMovedPlayer?.movementT ?? 0) % 1),
                  e.yPosition!.toDouble() +
                      moveresult.$2 * ((lastMovedPlayer?.movementT ?? 0) % 1),
                ),
                rotation: (e.rotation.index / 4) +
                    moveresult.$3 / 4 * ((lastMovedPlayer?.movementT ?? 0) % 1)
              );
            }).toList(),
      laserEmitters: board!.laserEmitters
          .map((e) => (
                laserCount: e.laserCount,
                enabled: false,
                positionX: e.xPosition,
                positionY: e.yPosition,
                rotation: e.rotation.index / 4
              ))
          .toList(),
      belts: board!.belts
          .map((e) => (
                t: (beltT1 + (e.express ? beltT2 : 0)) % 1,
                positionX: e.positionX,
                positionY: e.positionY,
                express: e.express,
                rotation: e.rotation.index / 4,
                type: e.type
              ))
          .toList(),
      gears: board!.gears
          .map((e) => (
                rotation: gearT / 4 * (e.clockwise ? 1 : -1),
                positionX: e.positionX,
                positionY: e.positionY,
                clockwise: e.clockwise,
              ))
          .toList(),
      wrenches: board!.wrenches,
      flags: board!.flags,
      walls: const [],
      draggedTo: flagPlacementMode
          ? (int x, int y, Object? value) {
              setState(() {
                if (value is! int) {
                  (int, int, {int number}) pos =
                      value as (int, int, {int number});
                  board!.flags.removeWhere(
                      (({int number, int positionX, int positionY}) flag) {
                    return flag.positionX == pos.$1 && flag.positionY == pos.$2;
                  });
                  value = pos.number;
                }
                board!.flags
                    .add((number: value as int, positionX: x, positionY: y));
              });
            }
          : (x, y, v) {
              throw StateError('unreachable');
            },
      flagsDraggable: flagPlacementMode,
      lasers: lasers,
    );
  }

  int drawProgramCard() {
    if (programCards.isEmpty) {
      programCards = allProgramCards.toList()
        ..removeWhere((e) => players.any((f) =>
            f.programCardHand.any((g) => g % 0x80 == e) ||
            f.programCards.any((g) => g != null && g % 0x80 == e)))
        ..shuffle();
    }
    return programCards.removeLast();
  }

  void startProgrammingPhase() {
    if (players.every((e) => !e.active())) {
      tie = true;
    }
    for (Player player in players) {
      if (!player.active()) continue;
      player.submittedProgramCards = false;
      player.programCardHand = [];
      List<int> cards = List.generate(9 - player.damage, (i) {
        int pc = drawProgramCard();
        player.programCardHand.add(pc);
        return pc;
      });
      sendMessage(player.socket, [cards.length, ...cards], 2);
    }
  }

  bool inRunPhase = false;
  int registerPhase = 1;
  double beltT1 = 0;
  double beltT2 = 0;
  double gearT = 0;
  double pusherT = 0;
  double laserT = 0;
  void startRunPhase() {
    inRunPhase = true;
    registerPhase = 1;
    for (Player player in players) {
      player.movementT = 0;
    }
    beltT1 = 0;
    beltT2 = 0;
    gearT = 0;
    pusherT = 0;
    laserT = 0;
    setState(() {
      for (Player player in players) {
        if (player.active()) {
          player.programCards[registerPhase - 1] =
              player.programCards[registerPhase - 1]! % 0x80;
          resendPlayer(player);
        }
      }
    });
  }

  void tick(duration) {
    if (inRunPhase) {
      setState(() {
        for (Player player in players.toList()
          ..sort(
            (a, b) => a.programCards[registerPhase - 1]!
                .compareTo(b.programCards[registerPhase - 1]!),
          )) {
          if (!player.active()) continue;
          if (player.movementT < 1) {
            if (player.movementT == 0) {
              currentMoveDeltas = player.getMovementResult(
                  registerPhase, players.where((e) => e.active()));
              lastMovedPlayer = player;
            }
            player.movementT += 1 / 128;
            if (player.movementT >= 1) {
              player.move(currentMoveDeltas);
              if (player.xPosition! < 0 ||
                  player.xPosition! >= board!.width ||
                  player.yPosition! < 0 ||
                  player.yPosition! >= board!.height) {
                player.die();
                resendPlayer(player);
              }
            }
            return;
          }
        }
        if (beltT1 < 1 && board!.belts.isNotEmpty) {
          beltT1 += 1 / 128;
          return;
        }
        if (beltT2 < 1 && board!.belts.any((e) => e.express)) {
          beltT2 += 1 / 128;
          return;
        }
        if (gearT < 1 && board!.gears.isNotEmpty) {
          gearT += 1 / 128;
          return;
        }
        if (pusherT < 1 &&
            board!.pushers.any((e) => e.even == registerPhase.isEven)) {
          pusherT += 1 / 128;
          return;
        }
        if (laserT < 1) {
          if (laserT == 0) {
            for (Player player in players) {
              if (!player.active()) continue;
              int startPosX;
              int startPosY;
              double width = 0;
              double height = 0;
              print(
                  'laser at ${player.xPosition},${player.yPosition} facing ${player.rotation}');
              if (player.rotation == Rotation.right ||
                  player.rotation == Rotation.down) {
                startPosX = player.xPosition!;
                startPosY = player.yPosition!;
                if (player.rotation == Rotation.right) {
                  height = .1;
                  int currentX = startPosX;
                  while (true) {
                    if (currentX >= board!.width) break;
                    currentX++;
                    width++;
                    print('pew pew $currentX, $startPosY');
                    if (players.any((e) =>
                        e.xPosition == currentX && e.yPosition == startPosY)) {
                      for (Player p in players.where((e) =>
                          e.xPosition == currentX &&
                          e.yPosition == startPosY)) {
                        print('hit player ${p.damage} ${p.dead}');
                        if (!p.dead) {
                          p.damage++;
                        }
                        print('new damage ${p.damage}');
                        if (p.damage == 10) {
                          p.die();
                        }
                        resendPlayer(p);
                      }
                      break;
                    }
                  }
                } else {
                  width = .1;
                  int currentY = startPosY;
                  while (true) {
                    if (currentY >= board!.width) break;
                    currentY++;
                    height++;
                    print('pew pew $startPosX, $currentY');
                    if (players.any((e) =>
                        e.xPosition == startPosX && e.yPosition == currentY)) {
                      for (Player p in players.where((e) =>
                          e.xPosition == startPosX &&
                          e.yPosition == currentY)) {
                        print('hit player ${p.damage} ${p.dead}');
                        if (!p.dead) {
                          p.damage++;
                        }
                        print('new damage ${p.damage}');
                        if (p.damage == 10) {
                          p.die();
                        }
                        resendPlayer(p);
                      }
                      break;
                    }
                  }
                }
              } else {
                int endPosX = player.xPosition!;
                int endPosY = player.yPosition!;
                if (player.rotation == Rotation.left) {
                  height = .1;
                  int currentX = endPosX;
                  while (true) {
                    if (currentX < 0) break;
                    currentX--;
                    width++;
                    print('pew pew $currentX, $endPosY');
                    if (players.any((e) =>
                        e.xPosition == currentX && e.yPosition == endPosY)) {
                      for (Player p in players.where((e) =>
                          e.xPosition == currentX && e.yPosition == endPosY)) {
                        print('hit player ${p.damage} ${p.dead}');
                        if (!p.dead) {
                          p.damage++;
                        }
                        print('new damage ${p.damage}');
                        if (p.damage == 10) {
                          p.die();
                        }
                        resendPlayer(p);
                      }
                      break;
                    }
                  }
                } else {
                  width = .1;
                  int currentY = endPosY;
                  while (true) {
                    if (currentY < 0) break;
                    currentY--;
                    height++;
                    print('pew pew $endPosX, $currentY');
                    if (players.any((e) =>
                        e.xPosition == endPosX && e.yPosition == currentY)) {
                      for (Player p in players.where((e) =>
                          e.xPosition == endPosX && e.yPosition == currentY)) {
                        print('hit player ${p.damage} ${p.dead}');
                        if (!p.dead) {
                          p.damage++;
                        }
                        print('new damage ${p.damage}');
                        if (p.damage == 10) {
                          p.die();
                        }
                        resendPlayer(p);
                      }
                      break;
                    }
                  }
                }
                startPosY = (endPosY - height).round();
                startPosX = (endPosX - width).round();
              }
              lasers.add((
                startPosX: startPosX,
                startPosY: startPosY,
                width: width,
                height: height
              ));
            }
          }
          laserT += 1 / 128;
          if (laserT >= 1) {
            lasers = [];
          }
          return;
        }
        registerPhase++;
        beltT1 = 0;
        beltT2 = 0;
        gearT = 0;
        pusherT = 0;
        laserT = 0;
        for (Player player in players) {
          player.movementT = 0;
          if (player.active() && registerPhase <= 5) {
            player.programCards[registerPhase - 1] =
                player.programCards[registerPhase - 1]! % 0x80;
          }
          if (player.active()) {
            if (board!.flags.any((e) =>
                player.xPosition == e.positionX &&
                player.yPosition == e.positionY)) {
              if (player.damage >= 1) {
                player.damage -= 1;
              }
              player.archiveMarkerPositionX = player.xPosition;
              player.archiveMarkerPositionY = player.yPosition;
              if (board!.flags
                          .singleWhere((e) =>
                              player.xPosition == e.positionX &&
                              player.yPosition == e.positionY)
                          .number -
                      1 ==
                  player.currentFlag) {
                player.currentFlag += 1;
                if (player.currentFlag == board!.flags.length) {
                  winner = player;
                }
              }
            }
            resendPlayer(player);
          }
        }
        if (registerPhase > 5) {
          registerPhase = 1;
          for (Player player in players) {
            player.programCardHand = [];
            int i = 0;
            while (9 - player.damage > i && i < 5) {
              player.programCards[i] = null;
              i++;
            }
            if (player.dead) {
              player.xPosition = player.archiveMarkerPositionX;
              player.yPosition = player.archiveMarkerPositionY;
            }
            player.dead = false;
            resendPlayer(player);
          }
          inRunPhase = false;
          startProgrammingPhase();
          return;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (board == null) return const Placeholder();
    if (!gameStarted) {
      return Row(
        children: [
          DragTarget(
            builder: (BuildContext context, List<Object?> candidateData,
                List<dynamic> rejectedData) {
              return Draggable(
                data: board!.flags.length + 1,
                feedback: FlagWidget(
                  cellSize: 200,
                  number: board!.flags.length + 1,
                ),
                child: FlagWidget(
                  cellSize: 200,
                  number: board!.flags.length + 1,
                ),
              );
            },
            onAcceptWithDetails: (details) {
              if (details.data is (int, int, {int number})) {
                setState(() {
                  (int, int, {int number}) pos =
                      details.data as (int, int, {int number});
                  board!.flags.removeWhere(
                      (({int number, int positionX, int positionY}) flag) {
                    return flag.positionX == pos.$1 && flag.positionY == pos.$2;
                  });
                });
              }
            },
          ),
          renderBoard(true),
          OutlinedButton(
            style: ButtonStyle(
                foregroundColor:
                    WidgetStateColor.resolveWith((arg) => Colors.white)),
            onPressed: () {
              setState(() {
                int index = 0;
                while (index < players.length) {
                  players[index].xPosition = board!.spawnPositions[index].$1;
                  players[index].yPosition = board!.spawnPositions[index].$2;
                  players[index]
                      .archiveMarkerPositionX; // player.xPosition will change during the game; this sets the archive marker to the starting position
                  players[index]
                      .archiveMarkerPositionY; // player.yPosition will change during the game; this sets the archive marker to the starting position
                  index++;
                }
                gameStarted = true;
                startProgrammingPhase();
              });
            },
            child: const Text(
              'Start game',
              style: TextStyle(fontSize: 50),
            ),
          )
        ],
      );
    }
    if (winner != null) {
      return Center(
        child: Text(
          '${winner!.name} won!',
          style: TextStyle(
              fontSize: 50,
              color: winner!.color,
              decoration: TextDecoration.none),
        ),
      );
    }
    if (tie) {
      return const Center(
        child: Text(
          'TIE',
          style: TextStyle(fontSize: 50, decoration: TextDecoration.none),
        ),
      );
    }
    return renderBoard(false);
  }
}

class BoilerplateDialog extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const BoilerplateDialog(
      {super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(title),
            const SizedBox(height: 15),
            ...children,
          ],
        ),
      ),
    );
  }
}
