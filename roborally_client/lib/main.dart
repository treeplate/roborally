import 'dart:convert';
import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'packetbuffer.dart';
import 'players.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoboRally Client',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: Center(
        child: Container(
          width: 700,
          height: 350,
          decoration: BoxDecoration(
            color: Colors.brown[300],
            border: Border.all(color: Colors.brown, width: 10),
          ),
          child: const MyHomePage(),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  String tempMessage = 'loading...';
  Socket? server;
  List<(String, String)>? servers;
  bool accepted = false;
  bool joined = false;
  List<int>? programCardHand;
  List<int?> programCardsPlaced = List.filled(5, null);
  static const Color defaultColor = Colors.lightBlue;
  Color currentSelectedColor = defaultColor;
  String currentName = '';
  List<Player>? players;
  late TabController controller = TabController(length: 0, vsync: this);

  @override
  void initState() {
    rootBundle.loadString('servers.cfg').then((value) {
      setState(() {
        servers = value.split('\n').map((e) {
          List<String> parts = e.split(' ').toList();
          return (parts[0], parts.skip(1).join(' '));
        }).toList();
      });
    });
    rootBundle.loadString('program_cards.txt').then((value) {
      setState(() {
        programCards = value.split('\n').map((e) {
          List<String> parts = e.split(' ').toList();
          print('MOO (${parts[1].length}) "${parts[1]}"\nMEOW ${ProgramCardType.values.map((e) => e.name)}');
          return ProgramCardData(
            int.parse(parts[0]),
            ProgramCardType.values.singleWhere((e) => e.name == parts[1]),
          );
        }).toList();
      });
    });
    super.initState();
  }

  Future<dynamic> connectionError(String message) {
    quitServer();
    return showDialog(
      context: context,
      builder: (context) {
        return BoilerplateDialog(
          title: 'Connection error',
          children: [
            Text(message),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Return to start menu'),
            )
          ],
        );
      },
    );
  }

  int? currentPacketLength;

  void handlePacket(Uint8List event, PacketBuffer packets) {
    return setState(() {
      if (!accepted) {
        if (event.length != 1) {
          connectionError(
            'Bad protocol: starting message too ${event.isEmpty ? 'short' : 'long'}',
          );
          return;
        }
        if (event.single == 1) {
          accepted = true;
          return;
        }
        if (event.single == 0) {
          quitServer();
          showDialog(
            context: context,
            builder: (context) {
              return BoilerplateDialog(
                title: 'Room full',
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Return to start menu',
                    ),
                  )
                ],
              );
            },
          );
          return;
        }
        connectionError(
          'Bad protocol: starting message ${event.single}, expected 0 or 1',
        );
        return;
      }
      packets.add(event);
      while (packets.available >= 1) {
        currentPacketLength ??= packets.readUint8();
        if (packets.available >= currentPacketLength! + 1) {
          currentPacketLength = null;
          int messageType = packets.readUint8();
          switch (messageType) {
            case 0:
              print('case0');
              int playerCount = packets.readUint8();
              int opc = players?.length ?? -1;
              players = [];
              while (players!.length < playerCount) {
                Player player = parsePlayer(packets);
                players!.add(player);
              }

              if (opc != playerCount) {
                controller = TabController(length: playerCount, vsync: this);
              }
              setState(() {});
            case 1:
              print('case1');
              int index = packets.readUint8();
              Player player = parsePlayer(packets);
              setState(() {
                if (index > (players?.length ?? -1)) {
                  connectionError(
                    'Bad protocol: player index more than length of current player list',
                  );
                } else if (index == players!.length) {
                  players!.add(player);
                  controller = TabController(length: index + 1, vsync: this);
                } else {
                  players![index] = player;
                }
              });
            case 2:
              print('case2');
              setState(() {
                int programCardCount = packets.readUint8();
                programCardHand =
                    packets.readUint8List(programCardCount).toList();
                programCardsPlaced = List.filled(5, null);
              });
            default:
              connectionError(
                'Bad protocol: invalid message type $messageType',
              );
          }
        } else {
          break;
        }
      }
    });
  }

  Player parsePlayer(PacketBuffer packets) {
    int currentFlag = packets.readUint8();
    int status = packets.readUint8();
    Uint8List programCards = packets.readUint8List(5);
    int optionCardCount = packets.readUint8();
    Uint8List optionCards = packets.readUint8List(optionCardCount);
    int nameLength = packets.readUint8();
    String name = String.fromCharCodes(packets.readUint8List(nameLength));
    Color color = Color(packets.readUint32());
    Player player = Player(
      currentFlag,
      LifeCount.values[status & 0x3],
      DamageCount.values[(status >> 4)],
      PowerDownStatus.values[(status >> 2) & 0x3],
      programCards,
      optionCards,
      name,
      color,
    );
    return player;
  }

  void sendMessage(List<int> message, int messageType) {
    server!.add([message.length, messageType, ...message]);
  }

  @override
  Widget build(BuildContext context) {
    if (servers == null) return const Text('loading servers.cfg...');
    if (server == null) {
      return ListView(
        children: [
          const Center(
            child: Text('Join Server',
                style: TextStyle(inherit: false, fontSize: 30)),
          ),
          const Divider(),
          ...servers!.expand(
            (e) => [
              const Padding(padding: EdgeInsets.only(top: 20)),
              OutlinedButton(
                onPressed: () {
                  Socket.connect(e.$1, 2024).then(
                    (value) {
                      PacketBuffer packets = PacketBuffer();
                      value.listen(
                        (event) {
                          if (server == null) throw StateError('unreachable');
                          handlePacket(event, packets);
                        },
                        onDone: () {
                          setState(quitServer);
                          showDialog(
                            context: context,
                            builder: (context) {
                              return BoilerplateDialog(
                                title: 'Disconnected from server',
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Return to start menu'),
                                  )
                                ],
                              );
                            },
                          );
                        },
                      );
                      setState(() {
                        accepted = false;
                        server = value;
                      });
                    },
                    onError: (error) {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return BoilerplateDialog(
                            title: 'Failed to connect to ${e.$2}',
                            children: [
                              Text('Error when connecting to ${e.$1}: $error'),
                              TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Return to start menu'))
                            ],
                          );
                        },
                      );
                    },
                  );
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      return Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.5);
                    },
                  ),
                ),
                child: Text(
                  e.$2,
                  style: const TextStyle(inherit: false),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (!accepted) return const CircularProgressIndicator();
    if (!joined) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            color: currentSelectedColor,
            child: Text(
              currentName,
              style: TextStyle(
                color: Color(~currentSelectedColor.value).withAlpha(255),
                inherit: false,
                fontSize: 30,
              ),
            ),
          ),
          SizedBox(
            width: 175,
            height: 175,
            child: ColorWheelPicker(
              color: currentSelectedColor,
              onChanged: (color) {
                setState(() {
                  currentSelectedColor = color;
                });
              },
              onWheel: (value) {},
            ),
          ),
          Material(
            child: TextField(
              onChanged: (value) {
                setState(() {
                  currentName = value;
                });
              },
            ),
          ),
          OutlinedButton(
            onPressed: () {
              List<int> utf8Name = utf8.encode(currentName);
              server!.add(
                [
                  utf8Name.length,
                  ...utf8Name,
                  currentSelectedColor.alpha,
                  currentSelectedColor.red,
                  currentSelectedColor.green,
                  currentSelectedColor.blue
                ],
              );
              setState(() {
                joined = true;
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) {
                  return Theme.of(context).colorScheme.primary.withOpacity(0.5);
                },
              ),
            ),
            child: const Text('Join server'),
          )
        ],
      );
    }
    if (players == null) {
      return const Center(
          child: Text(
        'Waiting for server...',
        style: TextStyle(inherit: false, fontSize: 30),
      ));
    }
    return Row(
      children: [
        Expanded(
          child: TabBarView(
            controller: controller,
            children: [
              ...players!.map(
                (e) => PlayerDataWidget(e),
              ),
            ],
          ),
        ),
        if (programCardHand != null)
          Expanded(
            child: Column(
              children: [
                OutlinedButton(
                  onPressed: programCardsPlaced.every((e) => e != null)
                      ? () {
                          sendMessage([], 2);
                          setState(() {
                            programCardHand = null;
                          });
                        }
                      : null,
                  child: const Text(
                    'Submit program',
                    style: TextStyle(
                      color: Colors.black,
                      inherit: false,
                      fontSize: 25,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      for (int i = 0; i < programCardsPlaced.length; i++)
                        DragTarget(
                          builder: (context, accepted, rejected) {
                            return programCardsPlaced[i] == null
                                ? const ProgramCardWidget(0x80)
                                : Draggable(
                                    feedback: ProgramCardWidget(
                                        programCardsPlaced[i]!),
                                    data: programCardsPlaced[i],
                                    childWhenDragging:
                                        const ProgramCardWidget(0x80),
                                    child: ProgramCardWidget(
                                        programCardsPlaced[i]!),
                                  );
                          },
                          onAcceptWithDetails: (details) {
                            if (programCardsPlaced[i] != null) return;
                            if (!programCardHand!.remove(details.data as int)) {
                              return;
                            }
                            setState(() {
                              programCardsPlaced[i] = details.data as int;
                            });
                            sendMessage([i, details.data as int], 0);
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (int i = 0; i < programCardHand!.length; i++)
                        DragTarget(
                          builder: (context, accepted, rejected) {
                            return Draggable(
                              feedback: ProgramCardWidget(programCardHand![i]),
                              data: programCardHand![i],
                              childWhenDragging: const ProgramCardWidget(0x80),
                              child: ProgramCardWidget(programCardHand![i]),
                            );
                          },
                          onAcceptWithDetails: (details) {
                            int index =
                                programCardsPlaced.indexOf(details.data as int);
                            if (index == -1) return;
                            setState(() {
                              programCardsPlaced[index] = null;
                              programCardHand!.add(details.data as int);
                            });
                            sendMessage([index], 1);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          const Expanded(child: Placeholder()),
      ],
    );
  }

  void quitServer() {
    server?.destroy();
    server = null;
    accepted = false;
    joined = false;
    players = null;
    programCardHand = null;
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
