import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(VideoListApp());
}

class VideoListApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoListScreen(),
    );
  }
}

class VideoListScreen extends StatefulWidget {
  @override
  _VideoListScreenState createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
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
      print("Storage permission denied!");
    }
  }

  // Fetch videos using the photo_manager package
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

        print("Found ${videoAssets.length} videos!");
      } else {
        setState(() {
          isLoading = false;
        });
        print("No video paths found.");
      }
    } catch (e) {
      print("Failed to get videos: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void playVideo(AssetEntity asset) async {
    final file = await asset.file;

    log("-------------------------path--$file---------------------------------------------------");

    // Get the file for the video
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
                      leading: FutureBuilder<File?>(
                        future: videoAssets[index].file,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.data != null) {
                            return Icon(Icons.video_collection);
                          } else {
                            return Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey,
                            );
                          }
                        },
                      ),
                      title: Text(videoAssets[index].title ?? "Unknown Video"),
                      onTap: () => playVideo(videoAssets[index]),
                    );
                  },
                ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  VideoPlayerScreen({required this.videoPath});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlayerInitialized = false;

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
        _isPlayerInitialized =
            true; // Update the state when the player is ready
      });
    } catch (e) {
      print("Error initializing video player: $e");
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Video Player")),
      body: Center(
        child: _isPlayerInitialized
            ? Chewie(controller: _chewieController!)
            : CircularProgressIndicator(), // Show loading indicator until player is ready
      ),
    );
  }
}
