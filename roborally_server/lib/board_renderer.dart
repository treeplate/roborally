import 'dart:math';

import 'package:flutter/material.dart';

typedef AnimatedRobotState = ({
  bool laserEnabled,
  Offset position,
  Color color,
  double rotation
  /*0=up, .25=right, etc*/
});
typedef AnimatedLaserEmitterState = ({
  bool enabled,
  int positionX,
  int positionY,
  int laserCount,
  double rotation // 0=up, .25=right, etc
});

enum BeltDirectionType { straight, cwCurve, ccwCurve }

typedef AnimatedBeltState = ({
  double t,
  int positionX,
  int positionY,
  bool express,
  BeltDirectionType type,
  double rotation
  /*0=up, .25=right, etc*/
});
typedef AnimatedGearState = ({
  int positionX,
  int positionY,
  bool clockwise,
  double rotation
  /*0=up, .25=right, etc*/
});
typedef Wrench = ({int positionX, int positionY, bool hammer});
typedef Flag = ({int positionX, int positionY, int number});
typedef ArchiveMarkerDisplay = ({int positionX, int positionY, Color color});
typedef Wall = ({int positionX, int positionY, bool vertical, bool toporleft});
typedef Laser = ({int startPosX, int startPosY, double width, double height});

class BoardRenderer extends StatelessWidget {
  const BoardRenderer({
    super.key,
    required this.width,
    required this.height,
    required this.robots,
    required this.laserEmitters,
    required this.belts,
    required this.gears,
    required this.wrenches,
    required this.flags,
    required this.walls,
    required this.draggedTo,
    required this.flagsDraggable,
    required this.lasers,
  });

  final int width;
  final int height;
  final List<AnimatedRobotState> robots;
  final List<AnimatedLaserEmitterState> laserEmitters;
  final List<Laser> lasers;
  final List<AnimatedBeltState> belts;
  final List<AnimatedGearState> gears;
  final List<Wrench> wrenches;
  final List<Flag> flags;
  final List<Wall> walls;
  final void Function(int, int, Object?) draggedTo;
  final bool flagsDraggable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double maxCellWidth = constraints.maxWidth / width;
      double maxCellHeight = constraints.maxHeight / height;
      double cellSize = min(maxCellWidth, maxCellHeight);
      return Center(
        child: Container(
          width: cellSize * width,
          height: cellSize * height,
          color: Colors.brown,
          child: Stack(
            children: [
              for (int x = 0; x < width; x++)
                for (int y = 0; y < height; y++)
                  Positioned(
                    top: y * cellSize,
                    left: x * cellSize,
                    child: DragTarget(
                      builder: (BuildContext context,
                          List<Object?> candidateData,
                          List<dynamic> rejectedData) {
                        return SizedBox(
                          width: cellSize,
                          height: cellSize,
                        );
                      },
                      onAcceptWithDetails: (details) {
                        draggedTo(x, y, details.data);
                      },
                    ),
                  ),
              ...flags
                  .map(
                    (e) => [
                      Positioned(
                        top: e.positionY * cellSize,
                        left: e.positionX * cellSize,
                        child: Image.asset(
                          'images/wrench_flag.png',
                          width: cellSize,
                          height: cellSize,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                      Positioned(
                        top: e.positionY * cellSize,
                        left: e.positionX * cellSize,
                        child: flagsDraggable
                            ? Draggable(
                                data: (
                                  e.positionX,
                                  e.positionY,
                                  number: e.number
                                ),
                                feedback: FlagWidget(
                                  cellSize: cellSize,
                                  number: e.number,
                                ),
                                childWhenDragging: Container(),
                                child: FlagWidget(
                                  cellSize: cellSize,
                                  number: e.number,
                                ),
                              )
                            : FlagWidget(
                                cellSize: cellSize,
                                number: e.number,
                              ),
                      ),
                      if (!flagsDraggable)
                        Positioned(
                          top: e.positionY * cellSize,
                          left: e.positionX * cellSize,
                          child: Container(
                            color: Colors.transparent,
                          ),
                        ),
                    ],
                  )
                  .expand((e) => e),
              ...robots.map(
                (e) => Positioned(
                  top: e.position.dy * cellSize,
                  left: e.position.dx * cellSize,
                  child: Transform.rotate(
                    angle: pi * 2 * e.rotation,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(e.color, BlendMode.xor),
                      child: Image.asset(
                        'images/robot.png',
                        width: cellSize,
                        height: cellSize,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                ),
              ),
              ...lasers.map((e) => Positioned(
                    top: e.startPosY * cellSize + cellSize / 2,
                    left: e.startPosX * cellSize + cellSize / 2,
                    child: Container(
                      color: Colors.red,
                      height: e.height * cellSize,
                      width: e.width * cellSize,
                    ),
                  )),
            ],
          ),
        ),
      );
    });
  }
}

class FlagWidget extends StatelessWidget {
  const FlagWidget({
    super.key,
    required this.cellSize,
    required this.number,
  });

  final double cellSize;
  final int number;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cellSize,
      height: cellSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              height: 2 * cellSize / 3,
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
                  number.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    inherit: false,
                    fontSize: 40,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(cellSize / 3, 0, 0, 0),
            child: Container(
              height: cellSize / 3,
              width: 10,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
