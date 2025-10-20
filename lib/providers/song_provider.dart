import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final titleProvider = StateProvider<String>((ref) => 'no Music');

final albumProvider = StateProvider<String>((ref) => 'no Album');

final artistProvider = StateProvider<String>((ref) => 'no Artist');

final imageProvider = StateProvider<Uint8List?>((ref) => null);

final mp3FileProvider = StateProvider<File?>((ref) => null);

final mp3FilePathProvider = StateProvider<String>((ref) => '');

final mp3FileListProvider = StateProvider<List<File>?>((ref) => null);

final songIndexProvider = StateProvider<int>((ref) => 0);

final newSongSetProvider = StateProvider<int>((ref) => 0);

final searchedString = StateProvider<String>((ref) => '');

final firstLaunch = StateProvider<bool>((ref) => true);

final selectedTitleProvider = StateProvider<String>((ref) => 'no Music');

final selectedAlbumProvider = StateProvider<String>((ref) => 'no Album');

final selectedArtistProvider = StateProvider<String>((ref) => 'no Artist');

final newSongAddedProvider = StateProvider<int>((ref) => 0);




// dataları teker teker yollamak yerine direkt olarak mp3 listesini yollayıp + indexini alıp yollayabiliriz, performans kötü olur herhalde ama daha güzel sistem olur.P