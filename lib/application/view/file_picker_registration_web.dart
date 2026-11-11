import 'package:file_picker_web/file_picker_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

bool _isRegistered = false;

void registerFilePickerForWeb() {
  if (_isRegistered) return;
  FilePickerWeb.registerWith(webPluginRegistrar);
  _isRegistered = true;
}
