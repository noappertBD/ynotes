import 'package:flutter/material.dart';
import 'package:ynotes/core/apis/ecole_directe.dart';
import 'package:ynotes/core/apis/model.dart';
import 'package:ynotes/core/logic/models_exporter.dart';
import 'package:ynotes/core/utils/logging_utils.dart';

class MailsController extends ChangeNotifier {
  dynamic _api;

  bool loading = false;
  List<Mail>? mails;

  MailsController(dynamic api) {
    _api = api;
  }

  set api(dynamic api) {
    _api = api;
  }

  Future<void> refresh({bool force = false}) async {
    CustomLogger.log("MAILS", "Refresh");
    loading = true;
    notifyListeners();
    try {
      mails = await _api.getMails(forceReload: force);
      notifyListeners();
    } catch (e) {
      CustomLogger.log("MAILS", "An error occured while refreshing");
      CustomLogger.error(e);
      loading = false;
    }
    loading = false;
    notifyListeners();
  }
}
