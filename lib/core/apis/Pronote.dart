import 'package:connectivity/connectivity.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ynotes/core/apis/model.dart';
import 'package:ynotes/core/logic/modelsExporter.dart';
import 'package:ynotes/main.dart';
import 'package:ynotes/globals.dart';
import 'package:ynotes/ui/screens/settings/sub_pages/logsPage.dart';
import 'package:ynotes/core/apis/Pronote/PronoteAPI.dart';
import 'package:ynotes/core/apis/Pronote/PronoteCas.dart';
import 'package:ynotes/core/apis/utils.dart';
import 'package:ynotes/core/offline/offline.dart';
import 'package:ynotes/core/logic/shared/loginController.dart';

import 'package:ynotes/usefulMethods.dart';

PronoteClient localClient;
//Locks are use to prohibit the app to send too much requests while collecting data and ensure there are made one by one
//They are ABSOLUTELY needed or user will be quickly IP suspended
bool gradeLock = false;
bool hwLock = false;
bool loginLock = false;
bool lessonsLock = false;
bool pollsLock = false;
bool gradeRefreshRecursive = false;
bool hwRefreshRecursive = false;
bool lessonsRefreshRecursive = false;
bool pollsRefreshRecursive = false;

class APIPronote extends API {
  APIPronote(Offline offlineController) : super(offlineController);

  @override
  // TODO: implement listApp

  @override
  Future<List<Discipline>> getGrades({bool forceReload}) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    var offlineGrades = await appSys.offline.disciplines.getDisciplines();

    //If force reload enabled the grades will be loaded online
    if ((connectivityResult == ConnectivityResult.none || forceReload == false || forceReload == null) &&
        offlineGrades != null) {
      print("Loading grades from offline storage.");

      var toReturn = await appSys.offline.disciplines.getDisciplines();
      toReturn = await refreshDisciplinesListColors(toReturn);
      return toReturn;
    } else {
      print("Loading grades inline.");
      var toReturn = await getGradesFromInternet();
      if (toReturn == null) {
        toReturn = await appSys.offline.disciplines.getDisciplines();
      }
      toReturn = await refreshDisciplinesListColors(toReturn);
      if (toReturn != null) {
        appSys.updateSetting(appSys.settings["system"], "lastGradeCount", getAllGrades(toReturn, overrideLimit: true).length);
      }

      return toReturn;
    }
  }

  getGradesFromInternet() async {
    int req = 0;
    //Time out of 20 seconds. Wait until the task is unlocked
    while (gradeLock == true && req < 10) {
      req++;
      await Future.delayed(const Duration(seconds: 2), () => "1");
    }
    //Wait until task is unlocked to avoid parallels execution
    if (gradeLock == false) {
      print("GETTING GRADES");
      gradeLock = true;
      try {
        List<PronotePeriod> periods = await localClient.periods();

        List<Grade> grades = List<Grade>();
        List averages = List();
        List<Discipline> listDisciplines = List<Discipline>();
        for (var i = 0; i < periods.length; i++) {
          //Grades and average
          List data = await periods[i].grades(i + 1);

          grades.addAll(data[0]);
          averages.addAll(data[1]);

          var z = 0;
          grades.forEach((element) {
            if (listDisciplines.every((listDisciplineEl) =>
                listDisciplineEl.disciplineName != element.disciplineName ||
                listDisciplineEl.period != element.periodName)) {
              listDisciplines.add(Discipline(
                  disciplineCode: element.disciplineCode,
                  subdisciplineCode: List(),
                  disciplineName: element.disciplineName,
                  period: element.periodName,
                  gradesList: List(),
                  teachers: List(),
                  average: averages[z][0],
                  maxClassAverage: averages[z][1],
                  minClassAverage: averages[z][2],
                  classAverage: element.classAverage,
                  classGeneralAverage: periods[i].moyenneGeneraleClasse,
                  generalAverage: periods[i].moyenneGenerale));
            }
            z++;
          });
        }
        this.gradesList = null;
        listDisciplines.forEach((element) {
          element.gradesList.addAll(grades.where((grade) => grade.disciplineName == element.disciplineName));
        });
        int index = 0;
        listDisciplines = await refreshDisciplinesListColors(listDisciplines);
        gradeLock = false;
        gradeRefreshRecursive = false;
        appSys.offline.disciplines.updateDisciplines(listDisciplines);
        return listDisciplines;
      } catch (e) {
        gradeLock = false;
        print(e.toString());
        List<Discipline> listDisciplines = List<Discipline>();
        if (gradeRefreshRecursive == false) {
          await refreshClient();
          gradeRefreshRecursive = true;

          listDisciplines.addAll(await getGrades());
        }

        return listDisciplines;
      }
    } else {
      print("GRADES WERE LOCKED");
      List<Discipline> listDisciplines = List<Discipline>();
      return listDisciplines;
    }
  }

  @override
  Future<List<Homework>> getHomeworkFor(DateTime dateHomework) async {
    int req = 0;
    //Time out of 20 seconds. Wait until the task is unlocked
    while (hwLock == true && req < 10) {
      req++;
      await Future.delayed(const Duration(seconds: 2), () => "1");
    }
    if (hwLock == false) {
      try {
        print("GETTING HOMEWORK");
        hwLock = true;

        List<Homework> listHW = List<Homework>();
        var hws = await localClient.homework(dateHomework, date_to: dateHomework);

        //This returns all the week
        listHW.addAll(hws);
        //Remove the others
        listHW.removeWhere((element) => element.date.day != dateHomework.day);

        hwLock = false;
        hwRefreshRecursive = false;
        return listHW;
      } catch (e) {
        print("Error while getting homework" + e);
        List<Homework> listHW = List<Homework>();
        hwLock = false;

        if (hwRefreshRecursive == false) {
          await refreshClient();
          hwRefreshRecursive = true;

          listHW.addAll(await getHomeworkFor(dateHomework));
        }
      }
    } else {
      print("HOMEWORK WERE LOCKED");
      List<Homework> listHW = List<Homework>();
      return listHW;
    }
    return null;
  }

  @override
  Future<List<Homework>> getNextHomework({bool forceReload}) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    var offlineHomework = await appSys.offline.homework.getHomework();

    //If force reload enabled the grades will be loaded online
    if ((connectivityResult == ConnectivityResult.none || forceReload == false || forceReload == null) &&
        offlineHomework != null) {
      print("Loading homework from offline storage.");
      offlineHomework.sort((a, b) => a.date.compareTo(b.date));
      return offlineHomework;
    } else {
      print("Loading homework inline.");
      List<Homework> toReturn = await getNextHomeworkFromInternet();
      if (toReturn == null) {
        toReturn = await appSys.offline.homework.getHomework();
      }
      toReturn.sort((a, b) => a.date.compareTo(b.date));
      return toReturn;
    }
  }

  getNextHomeworkFromInternet() async {
    int req = 0;
    //Time out of 20 seconds. Wait until the task is unlocked
    while (hwLock == true && req < 10) {
      req++;
      await Future.delayed(const Duration(seconds: 2), () => "1");
    }
    if (hwLock == false) {
      try {
        print("GETTING HOMEWORK");
        hwLock = true;
        DateTime now = DateTime.now();
        List<Homework> listHW = List<Homework>();
        List<Homework> hws = await localClient.homework(now);
        hws.removeWhere((element) => element.date.isBefore(now));
        listHW.addAll(hws);
        List<DateTime> pinnedDates = await appSys.offline.pinnedHomework.getPinnedHomeworkDates();
        //Add pinned content
        await Future.wait(pinnedDates.map((element) async {
          List<Homework> pinnedHomework = await localClient.homework(element, date_to: element);
          pinnedHomework.removeWhere((pinnedHWElement) => element.day != pinnedHWElement.date.day);
          pinnedHomework.forEach((pinned) {
            if (!listHW.any((hw) => hw.id == pinned.id)) {
              listHW.add(pinned);
            }
          });
        }));

        //delete duplicates
        listHW = listHW.toSet().toList();

        hwLock = false;
        hwRefreshRecursive = false;
        appSys.offline.homework.updateHomework(listHW);

        return listHW;
      } catch (e) {
        hwLock = false;
        print("Error while getting homework" + e.toString());
        List<Homework> listHW = List<Homework>();

        if (hwRefreshRecursive == false) {
          await refreshClient();
          hwRefreshRecursive = true;
          listHW.addAll(await getNextHomework());
        }
      }
    } else {
      print("HOMEWORK WERE LOCKED");
      List<Homework> listHW = List<Homework>();
      return listHW;
    }
  }

  int loginReqNumber = 0;
  @override
  Future<List> login(username, password, {url, cas}) async {
    print(username + " " + password + " " + url);
    int req = 0;
    while (loginLock == true && req < 5) {
      req++;
      await Future.delayed(const Duration(seconds: 2), () => "1");
    }
    if (loginLock == false && loginReqNumber < 5) {
      loginReqNumber = 0;
      loginLock = true;
      try {
        var cookies = await callCas(cas, username, password, url ?? "");
        localClient = PronoteClient(url, username: username, password: password, cookies: cookies);

        await localClient.init();
        if (localClient.loggedIn) {
          this.loggedIn = true;
          loginLock = false;
          return ([1, "Bienvenue $actualUser!"]);
        } else {
          loginLock = false;
          return ([
            0,
            "Oups, une erreur a eu lieu. Vérifiez votre mot de passe et les autres informations de connexion.",
            localClient.stepsLogger
          ]);
        }
      } catch (e) {
        loginLock = false;
        localClient.stepsLogger.add("❌ Pronote login failed : " + e.toString());
        print(e);
        String error = "Une erreur a eu lieu. " + e.toString();
        if (e.toString().contains("invalid url")) {
          error = "L'URL entrée est invalide";
        }
        if (e.toString().contains("split")) {
          error =
              "Le format de l'URL entrée est invalide. Vérifiez qu'il correspond bien à celui fourni par votre établissement";
        }
        if (e.toString().contains("runes")) {
          error = "Le mot de passe et/ou l'identifiant saisi(s) est/sont incorrect(s)";
        }
        if (e.toString().contains("IP")) {
          error =
              "Une erreur inattendue  a eu lieu. Pronote a peut-être temporairement suspendu votre adresse IP. Veuillez recommencer dans quelques minutes.";
        }
        if (e.toString().contains("SocketException")) {
          error = "Impossible de se connecter à l'adresse saisie. Vérifiez cette dernière et votre connexion.";
        }
        if (e.toString().contains("Invalid or corrupted pad block")) {
          error = "Le mot de passe et/ou l'identifiant saisi(s) est/sont incorrect(s)";
        }
        if (e.toString().contains("HTML PAGE")) {
          error = "Problème de page HTML.";
        }
        if (e.toString().contains("nombre d'erreurs d'authentification autorisées")) {
          error =
              "Vous avez dépassé le nombre d'erreurs d'authentification authorisées ! Réessayez dans quelques minutes.";
        }
        if (e.toString().contains("Failed login request")) {
          error = "Impossible de se connecter à l'URL renseignée. Vérifiez votre connexion et l'URL entrée.";
        }
        print("test");
        await logFile(error);
        return ([0, error, localClient.stepsLogger]);
      }
    } else {
      loginReqNumber++;
    }
  }

  @override
  Future<bool> testNewGrades() async {
    return null;
  }

  @override
  Future app(String appname, {String args, String action, CloudItem folder}) async {
    switch (appname) {
      case "polls":
        {
          if (action == "get") {
            int req = 0;
            while (pollsLock == true && req < 10) {
              req++;
              await Future.delayed(const Duration(seconds: 2), () => "1");
            }
            if (pollsLock == false) {
              try {
                pollsLock = true;
                List<PollInfo> toReturn = await getPronotePolls(args == "forced");
                pollsLock = false;
                return toReturn;
              } catch (e) {
                if (!pollsRefreshRecursive) {
                  pollsRefreshRecursive = true;
                  pollsLock = false;
                  await refreshClient();
                  List<PollInfo> toReturn = await getPronotePolls(args == "forced");

                  return toReturn;
                }
                pollsLock = false;
                print("Erreur pendant la collection des sondages/informations " + e.toString());
              }
            }
          }
          if (action == "read") {
            int req = 0;
            while (pollsLock == true && req < 10) {
              req++;
              await Future.delayed(const Duration(seconds: 2), () => "1");
            }
            try {
              pollsLock = true;
              await localClient.setPollRead(args);
              pollsLock = false;
            } catch (e) {
              pollsLock = false;
              if (!pollsRefreshRecursive) {
                await refreshClient();
                await localClient.setPollRead(args);
              }
            }
          }
          if (action == "answer") {
            int req = 0;
            while (pollsLock == true && req < 10) {
              req++;
              await Future.delayed(const Duration(seconds: 2), () => "1");
            }
            try {
              pollsLock = true;
              await localClient.setPollResponse(args);
              pollsLock = false;
            } catch (e) {
              pollsLock = false;
              if (!pollsRefreshRecursive) {
                await refreshClient();
                await localClient.setPollResponse(args);
              }
            }
          }
        }
        break;
    }
  }

  @override
  Future uploadFile(String contexte, String id, String filepath) {
    // TODO: implement sendFile
    throw UnimplementedError();
  }

  @override
  Future<List<DateTime>> getDatesNextHomework() {
    // TODO: implement getDatesNextHomework
    throw UnimplementedError();
  }

  @override
  Future<List<Period>> getPeriods() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    try {
      return await getOfflinePeriods();
    } catch (e) {
      print("Erreur while getting offline period " + e);
      if (connectivityResult != ConnectivityResult.none) {
        if (localClient.loggedIn) {
          print("getting periods online");
          return await getOnlinePeriods();
        } else {
          throw "Pronote isn't logged in";
        }
      } else {
        try {
          return await getOfflinePeriods();
        } catch (e) {
          throw ("Error while collecting offline periods");
        }
      }
    }
  }

  @override
  Future getNextLessons(DateTime dateToUse, {bool forceReload}) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    List<Lesson> toReturn;
    int req = 0;
    while (lessonsLock == true && req < 10) {
      req++;
      await Future.delayed(const Duration(seconds: 2), () => "1");
    }

    if (lessonsLock == false) {
      lessonsLock = true;
      try {
        //get lessons from offline storage
        var offlineLesson = await appSys.offline.lessons.get(await get_week(dateToUse));
        if (offlineLesson != null) {
          toReturn = List();
          toReturn.addAll(offlineLesson);

          //filter lessons
          toReturn ??
              [].removeWhere((lesson) =>
                  DateTime.parse(DateFormat("yyyy-MM-dd").format(lesson.start)) !=
                  DateTime.parse(DateFormat("yyyy-MM-dd").format(dateToUse)));
        }
        //Check if needed to force refresh if not offline
        if ((forceReload == true || toReturn == null) && connectivityResult != ConnectivityResult.none) {
          try {
            List<Lesson> onlineLessons = await localClient.lessons(dateToUse);

            await appSys.offline.lessons.updateLessons(onlineLessons, await get_week(dateToUse));

            toReturn = onlineLessons;
          } catch (e) {
            print("Failed to force refresh " + e.toString());
          }
        }

        lessonsLock = false;
        toReturn ?? [].sort((a, b) => a.start.compareTo(b.start));
        return toReturn
            .where((lesson) =>
                DateTime.parse(DateFormat("yyyy-MM-dd").format(lesson.start)) ==
                DateTime.parse(DateFormat("yyyy-MM-dd").format(dateToUse)))
            .toList();
      } catch (e) {
        print("Error while getting next lessons " + e.toString());
        lessonsLock = false;
        //If not recursive and if not offline
        if (lessonsRefreshRecursive == false && connectivityResult != ConnectivityResult.none) {
          lessonsRefreshRecursive = true;
          await refreshClient();
          toReturn = await localClient.lessons(dateToUse);
          toReturn ??
              [].removeWhere((lesson) =>
                  DateTime.parse(DateFormat("yyyy-MM-dd").format(lesson.start)) !=
                  DateTime.parse(DateFormat("yyyy-MM-dd").format(dateToUse)));
          toReturn ?? [].sort((a, b) => a.start.compareTo(b.start));

          return toReturn;
        }
      }
    } else {
      print("Was locked");
    }
  }

  getOfflinePeriods() async {
    try {
      List<Period> listPeriods = List();
      List<Discipline> disciplines = await appSys.offline.disciplines.getDisciplines();
      List<Grade> grades = getAllGrades(disciplines, overrideLimit: true);
      grades.forEach((grade) {
        if (!listPeriods.any((period) => period.name == grade.periodName && period.id == grade.periodCode)) {
          listPeriods.add(Period(grade.periodName, grade.periodCode));
        }
      });

      listPeriods.sort((a, b) => a.name.compareTo(b.name));

      return listPeriods;
    } catch (e) {
      print("Error while collecting offline periods " + e.toString());
    }
  }

  getOnlinePeriods() async {
    try {
      List<Period> listPeriod = List<Period>();
      if (localClient.localPeriods != null) {
        localClient.localPeriods.forEach((pronotePeriod) {
          listPeriod.add(Period(pronotePeriod.name, pronotePeriod.id));
        });

        return listPeriod;
      } else {
        var listPronotePeriods = await localClient.periods();
        //refresh local pronote periods
        localClient.localPeriods = listPronotePeriods;
        listPronotePeriods.forEach((pronotePeriod) {
          listPeriod.add(Period(pronotePeriod.name, pronotePeriod.id));
        });
        return listPeriod;
      }
    } catch (e) {
      print("Erreur while getting period " + e.toString());
    }
  }

  refreshClient() async {
    await appSys.loginController.login();
    //reset all recursives
    if (appSys.loginController.actualState == loginStatus.loggedIn) {
      gradeRefreshRecursive = false;
      hwRefreshRecursive = false;
      lessonsRefreshRecursive = false;
      pollsRefreshRecursive = false;
    }
  }

  getPronoteGradesFromInternet() async {
    int req = 0;
    //Time out of 20 seconds. Wait until the task is unlocked
    while (gradeLock == true && req < 10) {
      req++;
      await Future.delayed(const Duration(seconds: 2), () => "1");
    }
    //Wait until task is unlocked to avoid parallels execution
    if (gradeLock == false) {
      print("GETTING GRADES");
      gradeLock = true;
      try {
        List periods = await localClient.periods();

        List<Grade> grades = List<Grade>();
        List averages = List();
        List<Discipline> listDisciplines = List<Discipline>();
        for (var i = 0; i < periods.length; i++) {
          //Grades and average
          List data = await periods[i].disciplines(i + 1);

          grades.addAll(data[0]);
          averages.addAll(data[1]);

          var z = 0;
          grades.forEach((element) {
            if (listDisciplines.every((listDisciplineEl) =>
                listDisciplineEl.disciplineName != element.disciplineName ||
                listDisciplineEl.period != element.periodName)) {
              listDisciplines.add(Discipline(
                  disciplineCode: element.disciplineCode,
                  subdisciplineCode: List(),
                  disciplineName: element.disciplineName,
                  period: element.periodName,
                  gradesList: List(),
                  teachers: List(),
                  average: averages[z][0],
                  maxClassAverage: averages[z][1],
                  classAverage: element.classAverage,
                  classGeneralAverage: periods[i].classGeneralAverage,
                  generalAverage: periods[i].generalAverage));
            }
            z++;
          });
        }

        listDisciplines.forEach((element) {
          element.gradesList.addAll(grades.where((grade) => grade.disciplineName == element.disciplineName));
        });
        int index = 0;
        listDisciplines = await refreshDisciplinesListColors(listDisciplines);
        gradeLock = false;
        gradeRefreshRecursive = false;
        appSys.offline.disciplines.updateDisciplines(listDisciplines);
        return listDisciplines;
      } catch (e) {
        gradeLock = false;
      }
    } else {
      print("GRADES WERE LOCKED");
      List<Discipline> listDisciplines = List<Discipline>();
      return listDisciplines;
    }
  }

  @override
  Future<http.Request> downloadRequest(Document document) async {
    String url = await localClient.downloadUrl(document);
    http.Request request = http.Request('GET', Uri.parse(url));
    return request;
  }
}

Future<List<PollInfo>> getPronotePolls(bool forced) async {
  List<PollInfo> listPolls;
  try {
    if (forced) {
      listPolls = await localClient.polls() as List<PollInfo>;
      await appSys.offline.polls.update(listPolls);
      return listPolls;
    } else {
      listPolls = await appSys.offline.polls.get();
      if (listPolls == null) {
        print("Error while returning offline polls");
        listPolls = await localClient.polls() as List<PollInfo>;
        await appSys.offline.polls.update(listPolls);
        return listPolls;
      } else {
        return listPolls;
      }
    }
  } catch (e) {
    listPolls = await appSys.offline.polls.get();
    return listPolls;
  }
}
