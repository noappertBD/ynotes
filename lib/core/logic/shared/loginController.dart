import 'package:flutter/material.dart';
import 'package:ynotes/core/apis/utils.dart';
import 'package:ynotes/core/logic/modelsExporter.dart';
import 'package:ynotes/core/apis/EcoleDirecte.dart';
import 'package:ynotes/core/apis/Pronote.dart';
import 'package:ynotes/main.dart';
import 'package:ynotes/usefulMethods.dart';

enum loginStatus { loggedIn, loggedOff, offline, error }

///Login change notifier
class LoginController extends ChangeNotifier {
  //Login state
  var _actualState = loginStatus.loggedOff;
  //Login status details
  String _details = "Déconnecté";
  //Error logs
  String _logs = "";
  var internetConnexion;
  //getters
  get actualState => _actualState;
  set actualState(loginStatus) {
    _actualState = loginStatus;
    notifyListeners();
  }

  get details => _details;
  set details(details) {
    _details = details;
    notifyListeners();
  }

  init() async {
    ConnectionStatusSingleton connectionStatus = ConnectionStatusSingleton.getInstance();
    if (await connectionStatus.checkConnection() == false) {
      _actualState = loginStatus.offline;
      _details = "Vous êtes hors ligne";
      notifyListeners();
    }
    internetConnexion = connectionStatus.connectionChange.listen(connectionChanged);
    if (_actualState != loginStatus.offline && localApi.loggedIn == false) {
      await login();
    } else if (localApi.loggedIn) {
      _details = "Connecté";
      _actualState = loginStatus.loggedIn;
      notifyListeners();
    }
  }

//on connection change
  void connectionChanged(dynamic hasConnection) async {
    if (hasConnection != true) {
      _actualState = loginStatus.offline;
      _details = "Vous êtes hors ligne";
      notifyListeners();
    } else {
      _actualState = loginStatus.loggedOff;
      _details = "Reconnecté";
      notifyListeners();
      await login();
    }
  }

  login() async {
    try {
      _actualState = loginStatus.loggedOff;
      _details = "Connexion à l'API...";
      notifyListeners();
      await reloadChosenApi();
      String u = await ReadStorage("username");
      String p = await ReadStorage("password");
      String url = await ReadStorage("pronoteurl");
      String cas = await ReadStorage("pronotecas");
      bool iscas = (await ReadStorage("ispronotecas") == "true");

      var z = await storage.read(key: "agreedTermsAndConfiguredApp");
      if (u != null && p != null && z != null) {
        await localApi.login(u, p, url: url, mobileCasLogin: iscas ?? false, cas: cas).then((List loginValues) {
          if (loginValues == null) {
            _actualState = loginStatus.loggedOff;
            _details = "Connexion à l'API...";
            notifyListeners();
          }
          if (loginValues[0] == 1) {
            gradeRefreshRecursive = false;
            hwRefreshRecursive = false;
            lessonsRefreshRecursive = false;
            _details = "Connecté";
            _actualState = loginStatus.loggedIn;
            notifyListeners();
          } else {
            print("La valeur est :" + loginValues[1].toString());
            if (loginValues[1].contains("IP")) {
              _details = "Ban temporaire IP !";
            } else {
              _details = "Erreur de connexion.";
            }

            _logs = loginValues[1].toString();
            _actualState = loginStatus.error;
            notifyListeners();
          }
        });
      } else {
        _details = "Déconnecté";
        _actualState = loginStatus.loggedOff;
        notifyListeners();
      }
    } catch (e) {}
  }
}
