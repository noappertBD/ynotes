import 'dart:convert';

import 'package:convert/convert.dart' as conv;
import 'package:crypto/crypto.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:uuid/uuid.dart';
import 'package:ynotes/core/apis/pronote/pronote_api.dart';
import 'package:ynotes/core/utils/controller.dart';
import 'package:ynotes/core/utils/logging_utils.dart';
import 'package:ynotes/core/utils/null_safe_map_getter.dart';
import 'package:ynotes/globals.dart';

// TODO: document

enum AuthStatus { initial, loading, success, error }

class QrLoginController extends Controller {
  QrLoginController();

  AuthStatus get status => _status;
  AuthStatus _status = AuthStatus.initial;

  Map<dynamic, dynamic>? _loginData;
  String get url => _loginData?["url"];

  bool isQrCodeValid(Barcode barCode) {
    try {
      Map? raw = jsonDecode(barCode.code);
      if (raw != null) {
        if (mapGet(raw, ["jeton"]) != null && mapGet(raw, ["login"]) != null && mapGet(raw, ["url"]) != null) {
          setState(() {
            _status = AuthStatus.loading;
            _loginData = raw;
          });
          return true;
        } else {
          return false;
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  List<String>? decrypt(String code) {
    setState(() {
      _status = AuthStatus.loading;
    });
    final Encryption encrypt = Encryption();
    encrypt.aesKey = md5.convert(utf8.encode(code));
    try {
      final String login = encrypt.aesDecrypt(conv.hex.decode(_loginData?["login"]));
      final String password = encrypt.aesDecrypt(conv.hex.decode(_loginData?["jeton"]));
      appSys.settings.system.uuid = const Uuid().v4();
      appSys.saveSettings();
      setState(() {
        _status = AuthStatus.success;
      });
      return [login, password];
    } catch (e) {
      setState(() {
        _status = AuthStatus.error;
      });
      CustomLogger.log("LOGIN", "(QR Code) An error occured with the PIN");
      CustomLogger.error(e);
    }
  }

  void reset() {
    setState(() {
      _status = AuthStatus.initial;
      _loginData = null;
    });
  }
}
