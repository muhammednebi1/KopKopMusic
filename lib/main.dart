import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:id3/id3.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musicplayer/providers/song_provider.dart';
import 'package:musicplayer/providers/general_provider.dart';

import 'package:just_audio/just_audio.dart';
import 'dart:async';

void main() {
  initializeDirectiories();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  Widget build(BuildContext context) {
    ref.watch(ThemeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Music Player',
      home: HomePage(),
      theme: ref.watch(ThemeProvider.notifier).state == 'Dark'
          ? ThemeData.dark()
          : ThemeData.light(),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    ref.watch(pageProvider);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  child: Container(
                    child: Column(
                      children: [
                        Container(
                            height: 200,
                            width: 320,
                            child: Column(
                              children: [
                                SideBarWidget(),
                              ],
                            )),
                        MediaQuery.of(context).size.height > 670
                            ? DetailsWidget()
                            : SizedBox(),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: ref.watch(pageProvider.notifier).state ==
                                'Home Page'
                            ? (PlaylistWidget())
                            : SettingsPage(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
          ),
          PlayerWidget()
        ],
      ),
    );
  }
}

class PlayerWidget extends ConsumerStatefulWidget {
  const PlayerWidget({super.key});

  @override
  ConsumerState<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends ConsumerState<PlayerWidget> {
  double songLength = 1;

  // Player Details
  bool playStatus = false;
  double audioLevel = 0.5;
  bool audioMute = false;
  double trackTimer = 0;
  Timer? timer;
  double playerTimer = 0;
  int songIndex = 0;
  Uint8List? imageBytes;

  // Player Settings
  final player = AudioPlayer();
  bool songSet = false;
  bool shuffle = false;
  bool loop = false;

  List<File>? mp3Files;
  bool isFilesSet = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  void sync() async {
    songs = await mp3FileToSong();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    player.dispose();
    super.dispose();
  }

  Future<void> loadFiles() async {
    final dir = Directory(await getDatabaseFolderPath());
    final fileList = await dir.list().toList();
    setState(() {
      mp3Files = fileList.whereType<File>().toList();
    });
  }

  List<Map<String, dynamic>> songs = [];

  Future<List<Map<String, dynamic>>> mp3FileToSong() async {
    await loadFiles();
    List<Map<String, dynamic>> list = [];

    for (int i = 0; i < mp3Files!.length; i++) {
      File selectedFile = mp3Files![i];
      List<int> mp3Bytes = File(selectedFile.path).readAsBytesSync();
      MP3Instance mp3instance = MP3Instance(mp3Bytes);

      if (mp3instance.parseTagsSync()) {
        list.add({
          'title': mp3instance.getMetaTags()?['Title'],
          'album': mp3instance.getMetaTags()?['Album'],
          'artist': mp3instance.getMetaTags()?['Artist'],
          'duration': "TBD"
        });
      }
    }
    return list;
  }

  String secondsToTimer(double sec) {
    double hours = sec / 3600;
    double min = sec / 60;
    sec %= 60;

    return "${min.toInt()}:${sec.toInt() > 10 ? sec.toInt() : "0${sec.toInt()}"}";
  }

  void songImage() {
    File selectedFile = mp3Files![ref.read(songIndexProvider.notifier).state];
    List<int> mp3Bytes = File(selectedFile.path).readAsBytesSync();
    MP3Instance mp3instance = MP3Instance(mp3Bytes);

    if (mp3instance.parseTagsSync()) {
      var apic = mp3instance.getMetaTags()?['APIC'];
      if (apic != null) {
        setState(() {
          imageBytes = base64Decode(apic['base64']);
          ref.read(imageProvider.notifier).state = imageBytes;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Song Details
    String title = songs[songIndex]['title'];
    String artist = songs[songIndex]['artist'];

    ref.listen(newSongAddedProvider, (prev, next) {
      setState(() {
        sync();
      });
    });

    Future<void> loadSongs() async {
      if (mp3Files == null) {
        trackTimer = 0;
        songSet = false;
        playStatus = false;
        print("song is not set");
      }
      if (mp3Files != null) {
        player.stop();
        trackTimer = 0;
        await player.setFilePath(mp3Files![songIndex].path);
        print("song index taken: $songIndex");
        songSet = true;
        playStatus = true;
        player.play();
      }
    }

    Future<void> initLoads() async {
      if (isFilesSet == false && mp3Files != null) {
        isFilesSet = true;
        setState(() {
          trackTimer = 0;
        });
        print(playStatus);

        await loadSongs();
        setState(() {
          playStatus = false;
          player.pause();
        });
      }
    }

    initLoads();

    player.durationStream.listen((duration) {
      if (duration != null) {
        setState(() {
          songLength = duration.inSeconds.toDouble();
        });
      }
    });

    ref.listen(newSongSetProvider, (prev, next) {
      setState(() {
        songIndex = ref.watch(songIndexProvider);
        loadSongs();
        songImage();
      });
    });

    if (timer == null || !timer!.isActive) {
      timer = Timer.periodic(const Duration(seconds: 1), (time) {
        setState(() {
          if (playStatus) {
            trackTimer++;
            playerTimer = trackTimer / songLength;
            if (playerTimer > 1) {
              playerTimer = 1;
            }
          }
        });
      });
    }

    // Play next song
    Future(() {
      if (playerTimer >= 1) {
        setState(() {
          player.stop();

          if (loop) {
            trackTimer = 0;
            playerTimer = 0;
            ref.read(newSongSetProvider.notifier).state++;
          } else if (shuffle) {
            trackTimer = 0;
            playerTimer = 0;
            ref.read(songIndexProvider.notifier).state =
                Random().nextInt(mp3Files!.length);

            ref.read(newSongSetProvider.notifier).state++;
          } else if (ref.read(songIndexProvider.notifier).state <
              mp3Files!.length - 1) {
            trackTimer = 0;
            playerTimer = 0;
            ref.read(songIndexProvider.notifier).state++;
            ref.read(newSongSetProvider.notifier).state++;
          }
        });
      }
    });

    return Container(
      color: ThemeData.dark().hoverColor,
      height: 150,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 35,
                              ),

                              /*
                              Container(
                                  width: 100,
                                  height: 100,
                                  child: imageBytes != null
                                      ? Image.memory(
                                          imageBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : SizedBox()),
                                      */
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 8,
                                        right: 8,
                                        top: 16,
                                      ),
                                      child: Text(
                                        title,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Text(
                                        artist,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 16,
                      ),
                      Container(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                loop = !loop;
                                shuffle = false;
                              },
                              icon: loop
                                  ? Icon(
                                      Icons.loop_rounded,
                                      color: Color.fromARGB(255, 255, 29, 180),
                                    )
                                  : Icon(Icons.loop_rounded),
                              iconSize: 46,
                            ),
                            IconButton(
                              onPressed: () {
                                if (ref.read(songIndexProvider.notifier).state >
                                    0) {
                                  ref.read(songIndexProvider.notifier).state--;
                                  ref.read(newSongSetProvider.notifier).state++;
                                }
                              },
                              icon: Icon(Icons.skip_previous_rounded),
                              iconSize: 46,
                            ),
                            IconButton(
                              onPressed: () {
                                if (songSet) {
                                  if (playStatus) {
                                    player.pause();
                                  }
                                  if (!playStatus) {
                                    player.play();
                                  }
                                  playStatus = !playStatus;
                                }
                              },
                              icon: playStatus
                                  ? Icon(Icons.pause_circle_filled_rounded)
                                  : Icon(Icons.play_circle_fill_rounded),
                              iconSize: 46,
                            ),
                            IconButton(
                              onPressed: () {
                                if (ref.read(songIndexProvider.notifier).state <
                                    mp3Files!.length - 1) {
                                  ref.read(songIndexProvider.notifier).state++;
                                  ref.read(newSongSetProvider.notifier).state++;
                                }
                              },
                              icon: Icon(Icons.skip_next_rounded),
                              iconSize: 46,
                            ),
                            IconButton(
                              onPressed: () {
                                shuffle = !shuffle;
                                loop = false;
                              },
                              icon: shuffle
                                  ? Icon(
                                      Icons.shuffle_rounded,
                                      color: Color.fromARGB(255, 255, 29, 180),
                                    )
                                  : Icon(Icons.shuffle_rounded),
                              iconSize: 46,
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              secondsToTimer(trackTimer),
                              style: TextStyle(fontSize: 16),
                            ),
                            SliderTheme(
                              data: const SliderThemeData(
                                  trackHeight: 4,
                                  thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: 8),
                                  overlayShape: RoundSliderOverlayShape(
                                      overlayRadius: 8)),
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.4,
                                child: Slider(
                                  value: playerTimer > 1 ? 0 : playerTimer,
                                  onChanged: (value) => {
                                    setState(() {
                                      playerTimer = value;
                                      if (value > 0.999) {
                                        playerTimer = 0.999;
                                      }
                                      trackTimer = playerTimer * songLength;
                                    })
                                  },
                                  onChangeEnd: (value) => {
                                    setState(() {
                                      player.seek(Duration(
                                          seconds: (value *
                                                  player.duration!.inSeconds)
                                              .toInt()));
                                    })
                                  },
                                ),
                              ),
                            ),
                            Text(
                              secondsToTimer(songLength),
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              MediaQuery.of(context).size.width > 1200
                                  ? IconButton(
                                      onPressed: () {},
                                      icon: Icon(Icons.lyrics_rounded))
                                  : SizedBox(),
                              MediaQuery.of(context).size.width > 1200
                                  ? IconButton(
                                      onPressed: () {},
                                      icon: Icon(Icons.info_outline_rounded))
                                  : SizedBox(),
                              SliderTheme(
                                data: const SliderThemeData(
                                    trackHeight: 4,
                                    thumbShape: RoundSliderThumbShape(
                                        enabledThumbRadius: 8),
                                    overlayShape: RoundSliderOverlayShape(
                                        overlayRadius: 8)),
                                child: Row(
                                  children: [
                                    IconButton(
                                        onPressed: () {
                                          if (audioMute) {
                                            player.setVolume(audioLevel);
                                          } else {
                                            player.setVolume(0);
                                          }
                                          audioMute = !audioMute;
                                        },
                                        icon: audioLevel == 0
                                            ? Icon(Icons.volume_off_rounded)
                                            : audioMute
                                                ? Icon(Icons.volume_off_rounded)
                                                : audioLevel > 0.5
                                                    ? Icon(
                                                        Icons.volume_up_rounded)
                                                    : Icon(Icons
                                                        .volume_down_rounded)),
                                    Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.1,
                                      child: Slider(
                                        value: audioMute ? 0 : audioLevel,
                                        onChanged: (value) => {
                                          setState(() {
                                            audioLevel = value;
                                            if (audioLevel > 0) {
                                              audioMute = false;
                                            }
                                            player.setVolume(audioLevel);
                                          })
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<List<FileSystemEntity>> getFilesInDiretory(String path) async {
  final dir = Directory(path);
  final List<FileSystemEntity> files = await dir.list().toList();
  return files.whereType<File>().toList();
}

class PlaylistWidget extends ConsumerStatefulWidget {
  const PlaylistWidget({super.key});

  @override
  ConsumerState<PlaylistWidget> createState() => _PlaylistWidgetState();
}

class _PlaylistWidgetState extends ConsumerState<PlaylistWidget> {
  List<File> mp3Files = [];

  Future<void> loadFiles() async {
    final dir = Directory(await getDatabaseFolderPath());
    final fileList = await dir.list().toList();
    setState(() {
      mp3Files = fileList.whereType<File>().toList();
    });
  }

  List<Map<String, dynamic>> songs = [];

  Future<List<Map<String, dynamic>>> mp3FileToSong() async {
    await loadFiles();
    List<Map<String, dynamic>> list = [];

    for (int i = 0; i < mp3Files.length; i++) {
      File selectedFile = mp3Files[i];
      List<int> mp3Bytes = File(selectedFile.path).readAsBytesSync();
      MP3Instance mp3instance = MP3Instance(mp3Bytes);

      if (mp3instance.parseTagsSync()) {
        list.add({
          'title': mp3instance.getMetaTags()?['Title'],
          'album': mp3instance.getMetaTags()?['Album'],
          'artist': mp3instance.getMetaTags()?['Artist'],
          'year': mp3instance.getMetaTags()?['Year'],
        });
      }
    }
    return list;
  }

  Future<void> sync() async {
    songs = await mp3FileToSong();
    if (ref.watch(firstLaunch.notifier).state == true) {
      setSong(ref, 0);
      ref.read(firstLaunch.notifier).state = false;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    sync();
  }

  void setSong(WidgetRef ref, id) {
    ref.read(titleProvider.notifier).state = songs[id]['title'];
    ref.read(albumProvider.notifier).state = songs[id]['album'];
    ref.read(artistProvider.notifier).state = songs[id]['artist'];
    ref.read(mp3FileProvider.notifier).state = mp3Files[id];
    ref.read(mp3FilePathProvider.notifier).state = mp3Files[id].path;
    ref.read(mp3FileListProvider.notifier).state = mp3Files;
    ref.read(songIndexProvider.notifier).state = id;
    ref.read(newSongSetProvider.notifier).state++;
    print(
        "Provided - Song is set to: ${ref.read(titleProvider.notifier).state}, with the id of: ${id}");
  }

  void setSelectedSong(WidgetRef ref, id) {
    ref.read(selectedTitleProvider.notifier).state = songs[id]['title'];
    ref.read(selectedAlbumProvider.notifier).state = songs[id]['album'];
    ref.read(selectedArtistProvider.notifier).state = songs[id]['artist'];
    print(ref.read(selectedArtistProvider.notifier).state);
  }

  @override
  Widget build(BuildContext context) {
    final int currentSongId = ref.read(songIndexProvider.notifier).state;

    ref.watch(searchedString);

    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          SearchBarWidget(),
          Row(
            children: [
              const SizedBox(
                width: 24,
                height: 30,
              ),
              Container(
                width: MediaQuery.of(context).size.width * 0.1,
                child: Text(
                  "Title",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(
                width: 20,
              ),
              const Expanded(child: SizedBox()),
              Container(
                width: MediaQuery.of(context).size.width * 0.1,
                child: Text(
                  "Album",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(
                width: 20,
              ),
              const Expanded(child: SizedBox()),
              Container(
                width: MediaQuery.of(context).size.width * 0.1,
                child: Text(
                  "Artist",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(
                width: 20,
              ),
              const Expanded(child: SizedBox()),
              Container(
                width: MediaQuery.of(context).size.width * 0.1,
                child: Text(
                  "Year",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          Divider(
            thickness: 3,
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                  children: songs
                      .asMap()
                      .entries
                      .map((song) => song.value['title']
                              .toString()
                              .toLowerCase()
                              .contains(ref
                                  .watch(searchedString.notifier)
                                  .state
                                  .toLowerCase())
                          ? SongCardWidget(
                              title: song.value['title'],
                              album: song.value['album'],
                              artist: song.value['artist'],
                              year: song.value['year'],
                              songId: song.key,
                              onOneTap: () => setSelectedSong(ref, song.key),
                              onDoubleTap: () => setSong(ref, song.key),
                            )
                          : SizedBox())
                      .toList()),
            ),
          )
        ],
      ),
    );
  }
}

class SearchBarWidget extends ConsumerStatefulWidget {
  const SearchBarWidget({super.key});

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final songCount = 0;
    if (ref.watch(mp3FileProvider.notifier).state != null) {
      final songCount = ref.watch(mp3FileProvider.notifier).state!.length();
    }

    return Container(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(128),
                  border: Border.all(width: 0.4),
                ),
                child: Container(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Find your music',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(128)),
                      prefixIcon: IconButton(
                          onPressed: () {}, icon: Icon(Icons.search_rounded)),
                      suffixIcon: IconButton(
                          onPressed: () {
                            ref.read(searchedString.notifier).state = '';
                            controller.clear();
                          },
                          icon: Icon(Icons.close_rounded)),
                    ),
                    controller: controller,
                    onChanged: (value) {
                      ref.read(searchedString.notifier).state = value;
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SideBarWidget extends ConsumerStatefulWidget {
  SideBarWidget({super.key});

  @override
  ConsumerState<SideBarWidget> createState() => _SideBarWidgetState();
}

class _SideBarWidgetState extends ConsumerState<SideBarWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          const Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Kopkop",
              style: TextStyle(fontSize: 48),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TextButton(
                  child: Row(
                    children: [
                      Icon(
                        Icons.music_note_rounded,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Songs",
                          style: TextStyle(fontSize: 26),
                        ),
                      ),
                    ],
                  ),
                  style: TextButton.styleFrom(
                      foregroundColor:
                          ref.read(pageProvider.notifier).state == 'Home Page'
                              ? Color.fromARGB(255, 255, 29, 180)
                              : Theme.of(context).textTheme.bodyMedium?.color),
                  onPressed: () {
                    ref.read(pageProvider.notifier).state = 'Home Page';
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TextButton(
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_rounded,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Settings",
                          style: TextStyle(fontSize: 26),
                        ),
                      ),
                    ],
                  ),
                  style: TextButton.styleFrom(
                      foregroundColor: ref.read(pageProvider.notifier).state ==
                              'Settings Page'
                          ? Color.fromARGB(255, 255, 29, 180)
                          : Theme.of(context).textTheme.bodyMedium?.color),
                  onPressed: () {
                    ref.read(pageProvider.notifier).state = 'Settings Page';
                  },
                ),
              ],
            ),
          ),
          Divider(),
        ],
      ),
    );
  }
}

Future<void> initializeDirectiories() async {
  final directory = await getApplicationDocumentsDirectory();
  final myListenerDir = Directory('${directory.path}/MyListener');

  if (!await myListenerDir.exists()) {
    await myListenerDir.create(recursive: true);
  }
}

Future<Directory> getDatabaseFolder() async {
  final directory = await getApplicationDocumentsDirectory();
  final myListenerDir = Directory('${directory.path}/MyListener');

  return myListenerDir;
}

Future<String> getDatabaseFolderPath() async {
  final directory = await getApplicationDocumentsDirectory();
  final myListenerDir = '${directory.path}/MyListener';

  return myListenerDir;
}

class SongCardWidget extends ConsumerStatefulWidget {
  final String? title;
  final String? album;
  final String? artist;
  final String? year;
  final int songId;
  final VoidCallback onDoubleTap;
  final VoidCallback onOneTap;

  const SongCardWidget(
      {super.key,
      this.title = "Song Name",
      this.album = "Album Name",
      this.artist = "Artist Name",
      this.year = "Year",
      required this.songId,
      required this.onDoubleTap,
      required this.onOneTap});

  @override
  ConsumerState<SongCardWidget> createState() => _SongCardWidgetState();
}

class _SongCardWidgetState extends ConsumerState<SongCardWidget> {
  get title => null;
  Color selectionColor = Color.fromARGB(255, 255, 29, 180);

  @override
  Widget build(BuildContext context) {
    ref.watch(songIndexProvider);
    return GestureDetector(
      onTap: widget.onOneTap,
      onDoubleTap: widget.onDoubleTap,
      child: Container(
        /*
        color: Theme.of(context).canvasColor,
        */
        color: widget.songId == ref.watch(songIndexProvider.notifier).state
            ? Theme.of(context).hoverColor
            : Theme.of(context).canvasColor,
        child: Row(
          children: [
            SizedBox(
              height: 48,
              width: 24,
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.1,
              child: Text(
                "${widget.title}",
                style: TextStyle(
                  color: widget.songId ==
                          ref.watch(songIndexProvider.notifier).state
                      ? selectionColor
                      : Theme.of(context).textTheme.bodyMedium!.color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(
              width: 20,
            ),
            const Expanded(child: SizedBox()),
            Container(
              width: MediaQuery.of(context).size.width * 0.1,
              child: Text(
                "${widget.album}",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: widget.songId ==
                          ref.watch(songIndexProvider.notifier).state
                      ? selectionColor
                      : Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
            ),
            const SizedBox(
              width: 20,
            ),
            const Expanded(child: SizedBox()),
            Container(
              width: MediaQuery.of(context).size.width * 0.1,
              child: Text(
                "${widget.artist}",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: widget.songId ==
                          ref.watch(songIndexProvider.notifier).state
                      ? selectionColor
                      : Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
            ),
            const SizedBox(
              width: 20,
            ),
            const Expanded(child: SizedBox()),
            Container(
              width: MediaQuery.of(context).size.width * 0.1,
              child: Text(
                "${widget.year}",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: widget.songId ==
                          ref.watch(songIndexProvider.notifier).state
                      ? selectionColor
                      : Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  bool darkTheme = true;

  Widget build(BuildContext context) {
    final String? themeString = ref.watch(ThemeProvider.notifier).state;
    if (themeString != null) {
      if (themeString == 'Dark') {
        darkTheme = true;
      } else {
        darkTheme = false;
      }
    }
    String? selectedPath;
    Future<void> pickFile() async {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedPath = result.files.single.path!;
        });
      }

      String targetDirectory = (await getDatabaseFolder()).path;
      String fileName = path.basename(selectedPath!);
      String destinationPath = path.join(targetDirectory, '$fileName');

      File selectedFile = File(selectedPath!);
      await selectedFile.copy(destinationPath);

      List<int> mp3Bytes = File(selectedFile.path).readAsBytesSync();
      MP3Instance mp3instance = MP3Instance(mp3Bytes);

      if (mp3instance.parseTagsSync()) {
        print(mp3instance.getMetaTags());
      }

      ref.read(newSongAddedProvider.notifier).state++;
    }

    return Container(
      height: 120,
      child: Padding(
        padding: const EdgeInsets.all(64.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(
                    "Dark Theme",
                    style: TextStyle(fontSize: 26),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Switch(
                      value: darkTheme,
                      onChanged: (value) {
                        setState(
                          () {
                            if (value == false) {
                              ref.read(ThemeProvider.notifier).state = 'Light';
                              print(ref.read(ThemeProvider.notifier).state);
                            }
                            if (value == true) {
                              ref.read(ThemeProvider.notifier).state = 'Dark';
                              print(ref.read(ThemeProvider.notifier).state);
                            }
                            print(value);
                            darkTheme = value;
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(
                    "Import Song",
                    style: TextStyle(fontSize: 26),
                  ),
                  IconButton(
                      iconSize: 32,
                      onPressed: pickFile,
                      icon: Icon(Icons.file_download_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailsWidget extends ConsumerStatefulWidget {
  const DetailsWidget({super.key});

  @override
  ConsumerState<DetailsWidget> createState() => _DetailsWidgetState();
}

class _DetailsWidgetState extends ConsumerState<DetailsWidget> {
  @override
  Widget build(BuildContext context) {
    /*
    String title = ref.watch(selectedTitleProvider.notifier).state;
    String album = ref.watch(selectedAlbumProvider.notifier).state;
    String artist = ref.watch(selectedArtistProvider.notifier).state;
    ref.watch(selectedTitleProvider);

    */
    Uint8List? imageBytes = ref.watch(imageProvider.notifier).state;
    ref.watch(imageProvider);

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 320,
            child: Stack(
              alignment: Alignment.center,
              children: [
                imageBytes != null
                    ? ClipRect(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Image.memory(
                            imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Container(),
                Container(
                  width: 240,
                  child: imageBytes != null
                      ? ClipRect(
                          child: Image.memory(
                            imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
