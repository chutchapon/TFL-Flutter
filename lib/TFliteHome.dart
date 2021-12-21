import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';

class TFliteHome extends StatefulWidget {
  const TFliteHome({Key? key}) : super(key: key);
  @override
  _TFliteHomeState createState() => _TFliteHomeState();
}

class _TFliteHomeState extends State<TFliteHome> {
  File? _image;

  late double _imageWidth;
  late double _imageHeight;
  late bool _busy = false;

  List? _regcognitions;

  @override
  void initState() {
    super.initState();
    _busy = true;

    loadModel().then((value) {
      setState(() {
        _busy = false;
      });
    });
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      res = (await Tflite.loadModel(
        model: "assets/tflite/yolov2_tiny.tflite",
        labels: "assets/tflite/yolov2_tiny.txt",
      ))!;
      print(res);
    } on PlatformException {
      print('Failed to load model.');
    }
  }

  selectFromImagePicker() async {
    var image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(
      () {
        _busy == true;
      },
    );
    // Convert XFile to File
    final file = File(image.path);
    predictImage(file);
  }

  predictImage(File image) async {
    if (image == null) return;
    await yolov2Tiny(image);

    FileImage(image).resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo info, bool _) {
          setState(
            () {
              _imageWidth = info.image.width.toDouble();
              _imageHeight = info.image.height.toDouble();
            },
          );
        },
      ),
    );
    setState(
      () {
        _image = image;
        _busy == false;
      },
    );
  }

  yolov2Tiny(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
        path: image.path,
        model: "YOLO",
        threshold: 0.3,
        imageMean: 0.0,
        imageStd: 255.0,
        numResultsPerClass: 1);
    setState(
      () {
        _regcognitions = recognitions!;
      },
    );
  }

  ssdMobileNet(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 1,
      threshold: 0.2,
      imageMean: 127.5,
      imageStd: 127.5,
    );
    setState(
      () {
        _regcognitions = recognitions!;
      },
    );
  }

  List<Widget> renderBoxes(Size screen) {
    if (_regcognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = screen.width;
    double factorY = _imageHeight / _imageHeight * screen.width;

    Color blue = Colors.blue;
    return _regcognitions!.map(
      (re) {
        return Positioned(
          left: re["rect"]["x"] * factorX,
          top: re["rect"]["y"] * factorY,
          width: re["rect"]["w"] * factorX,
          height: re["rect"]["h"] * factorY,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: blue,
                width: 3,
              ),
            ),
            child: Text(
              "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                background: Paint()..color = blue,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        );
      },
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];
    stackChildren.add(
      Positioned(
        top: 0.0,
        left: 0.0,
        width: size.width,
        child: _image == null
            ? const Text(
                'No image selected.',
                textAlign: TextAlign.center,
              )
            : Image.file(
                _image!,
              ),
      ),
    );
    stackChildren.addAll(renderBoxes(size));

    if (_busy) {
      stackChildren.add(
        const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('TFlite Demo'),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.image),
        tooltip: "Pick Image",
        onPressed: selectFromImagePicker,
      ),
      body: Stack(
        children: stackChildren,
      ),
    );
  }
}
