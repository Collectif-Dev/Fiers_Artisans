import 'package:web/web.dart' as web;

String? readWebLocalStorage(String key) => web.window.localStorage.getItem(key);

Future<void> writeWebLocalStorage(String key, String value) async {
  web.window.localStorage.setItem(key, value);
}

Future<void> deleteWebLocalStorage(String key) async {
  web.window.localStorage.removeItem(key);
}

Future<void> clearWebLocalStorage() async {
  web.window.localStorage.clear();
}
