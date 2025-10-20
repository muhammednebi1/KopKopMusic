import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final pageProvider = StateProvider<String>((ref) => 'Home Page');

final ThemeProvider = StateProvider<String>((ref) => 'Dark');
