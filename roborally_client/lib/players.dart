import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';

enum LifeCount { zero, one, two, three }

enum DamageCount { zero, one, two, three, four, five, six, seven, eight, nine }

enum PowerDownStatus { notPoweredDown, nextTurnPoweredDown, poweredDown }

class Player {
  final int currentFlag;
  final LifeCount life;
  final DamageCount damage;
  final PowerDownStatus powerDownStatus;
  final Uint8List programCards;
  final Uint8List optionCards;
  final String name;
  final Color color;

  Player(this.currentFlag, this.life, this.damage, this.powerDownStatus,
      this.programCards, this.optionCards, this.name, this.color) {
    assert(programCards.length == 5);
  }
}

class PlayerDataWidget extends StatelessWidget {
  const PlayerDataWidget(this.player, {super.key});

  final Player player;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                color: player.color,
                child: Text(
                  player.name,
                  style: TextStyle(
                    color: Color(~player.color.value).withAlpha(255),
                    inherit: false,
                    fontSize: 30,
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.all(10)),
            Container(
              width: 45,
              height: 45,
              decoration: const ShapeDecoration(
                color: Colors.yellow,
                shape: StarBorder.polygon(
                  sides: 3,
                  side: BorderSide(color: Colors.orange, width: 3),
                ),
              ),
              child: Center(
                child: Text(
                  player.damage.index.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    inherit: false,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.all(10)),
            Container(
              width: 35,
              height: 35,
              decoration: ShapeDecoration(
                color: Colors.green,
                shape: CircleBorder(
                  side: BorderSide(
                    color: Colors.green[900]!,
                    width: 3,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  player.life.index.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    inherit: false,
                    fontSize: 25,
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.all(10)),
            if (player.powerDownStatus != PowerDownStatus.notPoweredDown)
              Container(
                width: 45,
                height: 45,
                decoration: ShapeDecoration(
                  color: player.powerDownStatus ==
                          PowerDownStatus.nextTurnPoweredDown
                      ? Colors.red.withOpacity(.3)
                      : Colors.red,
                  shape: StarBorder.polygon(
                    rotation: 360 / 16,
                    sides: 8,
                    side: BorderSide(
                        color: player.powerDownStatus ==
                                PowerDownStatus.nextTurnPoweredDown
                            ? Colors.yellow.withOpacity(.3)
                            : Colors.yellow,
                        width: 3),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.power_settings_new,
                    color: player.powerDownStatus ==
                            PowerDownStatus.nextTurnPoweredDown
                        ? Colors.yellow.withOpacity(.3)
                        : Colors.yellow,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          width: 30,
          height: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  height: 2 * 30 / 3,
                  decoration: const ShapeDecoration(
                    color: Colors.yellow,
                    shape: StarBorder.polygon(
                      sides: 3,
                      rotation: 360 / 4,
                      side: BorderSide(
                        color: Colors.orange,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      player.currentFlag.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        inherit: false,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(30 / 3, 0, 0, 0),
                child: Container(
                  height: 30 / 3,
                  width: 2,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [...player.programCards.map((e) => ProgramCardWidget(e))],
        ),
        Expanded(
          child: GridView(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 100,
            ),
            children: [...player.optionCards.map((e) => OptionCardWidget(e))],
          ),
        ),
      ],
    );
  }
}

enum ProgramCardType { move1, move2, move3, backup, turncw, turnccw, uturn }

class ProgramCardData {
  final int priority;
  final ProgramCardType type;

  ProgramCardData(this.priority, this.type);
}

late List<ProgramCardData> programCards;

class ProgramCardWidget extends StatelessWidget {
  final int card;

  const ProgramCardWidget(this.card, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (card) {
      case 0x80:
        return DottedBorder(
          child: const SizedBox(
            width: 60,
            height: 100,
          ),
        );
      case 0x81:
        return DottedBorder(
          child: Container(
            width: 60,
            height: 100,
            color: Colors.amber,
          ),
        );
      default:
        ProgramCardData card2 = programCards[card];
        IconData icon;
        switch (card2.type) {
          case ProgramCardType.move1:
            icon = Icons.keyboard_arrow_up;
          case ProgramCardType.move2:
            icon = Icons.keyboard_double_arrow_up;
          case ProgramCardType.move3:
            icon = Icons.more_vert;
          case ProgramCardType.backup:
            icon = Icons.keyboard_arrow_down;
          case ProgramCardType.turncw:
            icon = Icons.rotate_90_degrees_cw;
          case ProgramCardType.turnccw:
            icon = Icons.rotate_90_degrees_ccw;
          case ProgramCardType.uturn:
            icon = Icons.u_turn_left;
        }
        return Padding(
          padding: const EdgeInsets.all(2.0),
          child: Container(
            width: 60,
            height: 100,
            color: Colors.grey,
            child: DottedBorder(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card2.priority.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      inherit: false,
                      fontSize: 25,
                    ),
                  ),
                  Icon(icon),
                ],
              ),
            ),
          ),
        );
    }
  }
}

class OptionCardWidget extends StatelessWidget {
  final int card;

  const OptionCardWidget(this.card, {super.key});

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}
