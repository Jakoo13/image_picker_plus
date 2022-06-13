import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:custom_gallery_display/src/app_theme.dart';
import 'package:custom_gallery_display/src/customPackages/crop_image/crop_image.dart';
import 'package:custom_gallery_display/src/customPackages/crop_image/crop_options.dart';
import 'package:custom_gallery_display/src/record_count.dart';
import 'package:custom_gallery_display/src/record_fade_animation.dart';
import 'package:custom_gallery_display/src/selected_image_details.dart';
import 'package:custom_gallery_display/src/taps_names.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum Flash { off, auto, on }

// ignore: must_be_immutable
class CustomCameraDisplay extends StatefulWidget {
  final bool selectedVideo;
  final AppTheme appTheme;
  final TapsNames tapsNames;
  late CameraController controller;
  final VoidCallback moveToVideoScreen;
  final List<CameraDescription> cameras;
  final ValueNotifier<bool> redDeleteText;
  final ValueChanged<bool> replacingTabBar;
  final ValueNotifier<bool> clearVideoRecord;
  late Future<void> initializeControllerFuture;
  final AsyncValueSetter<SelectedImageDetails> moveToPage;

  CustomCameraDisplay({
    Key? key,
    required this.appTheme,
    required this.tapsNames,
    required this.cameras,
    required this.moveToPage,
    required this.controller,
    required this.redDeleteText,
    required this.selectedVideo,
    required this.replacingTabBar,
    required this.clearVideoRecord,
    required this.moveToVideoScreen,
    required this.initializeControllerFuture,
  }) : super(key: key);

  @override
  CustomCameraDisplayState createState() => CustomCameraDisplayState();
}

class CustomCameraDisplayState extends State<CustomCameraDisplay> {
  ValueNotifier<bool> startVideoCount = ValueNotifier(false);
  final cropKey = GlobalKey<CropState>();
  Flash currentFlashMode = Flash.auto;
  late Widget videoStatusAnimation;
  int selectedCamera = 0;
  File? videoRecordFile;

  @override
  void initState() {
    videoStatusAnimation = Container();
    super.initState();
  }

  initializeCamera(int cameraIndex) async {
    widget.controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );
    widget.initializeControllerFuture = widget.controller.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(context),
      body: buildBody(),
    );
  }

  SafeArea buildBody() {
    Color whiteColor = widget.appTheme.primaryColor;
    return SafeArea(
      child: FutureBuilder<void>(
        future: widget.initializeControllerFuture,
        builder: (BuildContext context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Container(
                    width: double.infinity,
                    color: Colors.blue,
                    child: CameraPreview(widget.controller)),
                if (selectedImage != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                        color: whiteColor,
                        height: 360,
                        width: double.infinity,
                        child: Crop.file(
                          selectedImage!,
                          key: cropKey,
                          alwaysShowGrid: true,
                        )),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () {
                      if (widget.cameras.length > 1) {
                        setState(() {
                          selectedCamera = selectedCamera == 0 ? 1 : 0;
                          initializeCamera(selectedCamera);
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(widget.tapsNames.notFoundingCameraName),
                          duration: const Duration(seconds: 2),
                        ));
                      }
                    },
                    icon: const Icon(Icons.flip_camera_android_rounded,
                        color: Colors.white),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        currentFlashMode = currentFlashMode == Flash.off
                            ? Flash.auto
                            : (currentFlashMode == Flash.auto
                                ? Flash.on
                                : Flash.off);
                      });
                      currentFlashMode == Flash.on
                          ? widget.controller.setFlashMode(FlashMode.torch)
                          : (currentFlashMode == Flash.auto
                              ? widget.controller.setFlashMode(FlashMode.auto)
                              : widget.controller.setFlashMode(FlashMode.off));
                    },
                    icon: Icon(
                        currentFlashMode == Flash.on
                            ? Icons.flash_on_rounded
                            : (currentFlashMode == Flash.auto
                                ? Icons.flash_auto_rounded
                                : Icons.flash_off_rounded),
                        color: Colors.white),
                  ),
                ),
                Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 270,
                      color: whiteColor,
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1.0),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: RecordCount(
                                startVideoCount: startVideoCount,
                                makeProgressRed: widget.redDeleteText,
                                clearVideoRecord: widget.clearVideoRecord,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(60),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: cameraButton(context),
                                ),
                              ),
                              Positioned(
                                  bottom: 120, child: videoStatusAnimation),
                            ],
                          ),
                          const Spacer(),
                        ],
                      ),
                    )),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  AppBar appBar(BuildContext context) {
    Color whiteColor = widget.appTheme.primaryColor;
    Color blackColor = widget.appTheme.focusColor;

    return AppBar(
      backgroundColor: whiteColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.clear_rounded, color: blackColor, size: 30),
        onPressed: () {
          Navigator.of(context).maybePop();
        },
      ),
      actions: <Widget>[
        // if (widget.selectedVideo)
        AnimatedSwitcher(
          duration: const Duration(seconds: 1),
          switchInCurve: Curves.easeIn,
          child: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded,
                color: Colors.blue, size: 30),
            onPressed: () async {
              if (videoRecordFile != null) {
                SelectedImageDetails details = SelectedImageDetails(
                  selectedFile: videoRecordFile!,
                  multiSelectionMode: false,
                  isThatImage: false,
                  aspectRatio: 1.0,
                );
                widget.moveToPage(details);
              } else {
                if (selectedImage != null) {
                  File? croppedFile = await cropImage(selectedImage!);
                  if (croppedFile != null) {
                    SelectedImageDetails details = SelectedImageDetails(
                      selectedFile: File(croppedFile.path),
                      multiSelectionMode: false,
                      aspectRatio: 1.0,
                    );
                    widget.moveToPage(details);
                  }
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Future<File?> cropImage(File imageFile) async {
    await ImageCrop.requestPermissions();
    final scale = cropKey.currentState!.scale;
    final area = cropKey.currentState!.area;
    if (area == null) {
      return null;
    }
    final sample = await ImageCrop.sampleImage(
      file: imageFile,
      preferredSize: (2000 / scale).round(),
    );
    final File file = await ImageCrop.cropImage(
      file: sample,
      area: area,
    );
    sample.delete();
    return file;
  }

  File? selectedImage;
  GestureDetector cameraButton(BuildContext context) {
    Color whiteColor = widget.appTheme.primaryColor;
    return GestureDetector(
      onTap: () async {
        if (!widget.selectedVideo) {
          try {
            await widget.initializeControllerFuture;
            final image = await widget.controller.takePicture();
            File selectedImage = File(image.path);
            setState(() {
              this.selectedImage = selectedImage;
            });
          } catch (e) {
            if (kDebugMode) {
              print(e);
            }
          }
        } else {
          setState(() {
            videoStatusAnimation = buildFadeAnimation();
          });
        }
      },
      onLongPress: () {
        widget.controller.startVideoRecording();
        widget.moveToVideoScreen();
        setState(() {
          startVideoCount.value = true;
        });
      },
      onLongPressUp: () async {
        setState(() {
          startVideoCount.value = false;
          widget.replacingTabBar(true);
        });
        XFile w = await widget.controller.stopVideoRecording();
        videoRecordFile = File(w.path);
      },
      child: CircleAvatar(
          backgroundColor: Colors.grey[400],
          radius: 40,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: whiteColor,
          )),
    );
  }

  RecordFadeAnimation buildFadeAnimation() {
    Color whiteColor = widget.appTheme.primaryColor;
    return RecordFadeAnimation(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10.0)),
              boxShadow: [
                BoxShadow(
                    blurRadius: 3, color: Colors.black, offset: Offset(1, 2))
              ],
              color: Color.fromARGB(255, 49, 49, 49),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Text(
                    widget.tapsNames.holdButtonName,
                    style: TextStyle(color: whiteColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Center(
              child: Icon(
                Icons.arrow_drop_down_rounded,
                color: Color.fromARGB(255, 49, 49, 49),
                size: 65,
              ),
            ),
          ),
        ],
      ),
    );
  }
}