import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: VideoApp(),
    );
  }
}

class VideoApp extends StatefulWidget {
  const VideoApp({super.key});

  @override
  State<VideoApp> createState() => _VideoAppState();
}

class _VideoAppState extends State<VideoApp> {
  List<AssetEntity> videoAssets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    requestPermission();
  }

  Future<void> requestPermission() async {
    final permissionStatus = await Permission.storage.request();
    if (permissionStatus.isGranted) {
      fetchVideos();
    } else {
      log("Storage permission denied!");
    }
  }

  Future<void> fetchVideos() async {
    try {
      final List<AssetPathEntity> assetPaths =
          await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );

      if (assetPaths.isNotEmpty) {
        final List<AssetEntity> videoList =
            await assetPaths[0].getAssetListPaged(page: 0, size: 100);

        setState(() {
          videoAssets = videoList;
          isLoading = false;
        });

        log("Found ${videoAssets.length} videos!");
      } else {
        setState(() {
          isLoading = false;
        });
        log("------------------------------------------No video paths found.-----------------------------------------");
      }
    } catch (e) {
      log("------------------------------------------Failed to get videos: $e---------------------------------------");
      setState(() {
        isLoading = false;
      });
    }
  }

  void playVideo(AssetEntity asset) async {
    final file = await asset.file;

    log("-------------------------path--$file---------------------------------------------------");

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(videoPath: file!.path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("All Videos")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : videoAssets.isEmpty
              ? Center(child: Text("No video found"))
              : ListView.builder(
                  itemCount: videoAssets.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: FutureBuilder<Uint8List?>(
                        future: videoAssets[index].thumbnailDataWithSize(
                          ThumbnailSize(200, 200),
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.data != null) {
                            return Stack(
                              children: [
                                Image.memory(
                                  snapshot.data!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Icon(Icons.play_circle_fill,
                                      color: Colors.white, size: 30),
                                ),
                              ],
                            );
                          } else {
                            return Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey,
                            );
                          }
                        },
                      ),
                      title: Text(videoAssets[index].title ?? "Unknown Video",
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => playVideo(videoAssets[index]),
                    );
                  },
                ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.videoPath});
  final String videoPath;
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlayerInitialized = false;
  double playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController =
          VideoPlayerController.file(File(widget.videoPath));

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.white,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.lightBlue,
        ),
      );

      setState(() {
        _isPlayerInitialized = true;
      });
    } catch (e) {
      log("--------------------------------------Error initializing video player: $e-------------------------------------");
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void togglePlayPause() {
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
    } else {
      _videoPlayerController.play();
    }
  }

  void seekToPosition(Duration position) {
    _videoPlayerController.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Video Player")),
      body: Center(
        child: _isPlayerInitialized

            ? Column(
                children: [
                  Expanded(child: Chewie(controller: _chewieController!)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(_videoPlayerController.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow),
                        onPressed: togglePlayPause,
                      ),
                      Slider(
                        value: _videoPlayerController.value.position.inSeconds
                            .toDouble(),
                        max: _videoPlayerController.value.duration.inSeconds
                            .toDouble(),
                        onChanged: (value) {
                          seekToPosition(Duration(seconds: value.toInt()));
                        },
                      ),
                    ],
                  ),
                  Slider(
                    value: playbackSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 3,
                    label: playbackSpeed.toString(),
                    onChanged: (value) {
                      setState(() {
                        playbackSpeed = value;
                        _videoPlayerController.setPlaybackSpeed(playbackSpeed);
                      });
                    },
                  ),
                ],
              )

//             ? Chewie(controller: _chewieController!)

            : CircularProgressIndicator(),
      ),
    );
  }
}
