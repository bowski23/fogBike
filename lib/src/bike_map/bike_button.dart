import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// A button that toggles the recording of sensor data.
class BikeButton extends StatefulWidget {

  const BikeButton({Key? key, this.onPress, this.onLongPress}) : super(key: key);

  @override
  _BikeButtonState createState() => _BikeButtonState();
  final void Function()? onPress;
  final void Function()? onLongPress;
}

class _BikeButtonState extends State<BikeButton> {
  bool isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      elevation: 4,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
      constraints: const BoxConstraints(minHeight: 50, minWidth: 50),
      shape: const CircleBorder(),
      fillColor: Colors.grey,
      onPressed: () {
        setState(() => isPlaying = !isPlaying);
        widget.onPress?.call();
      },
      onLongPress: () {
        widget.onLongPress?.call();
      },
      child: Icon(
        isPlaying ? Icons.play_arrow : Icons.pause,
        size: 40,
      ),
    );
  }
}
