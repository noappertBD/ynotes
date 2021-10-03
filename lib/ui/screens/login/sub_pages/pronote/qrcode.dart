import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:ynotes/core/logic/pronote/login/qr_code/qr_login_controller.dart';
import 'package:ynotes/core/utils/controller.dart';
import 'package:ynotes/globals.dart';
import 'package:ynotes/ui/screens/login/w/widgets.dart';
import 'package:ynotes_packages/components.dart';
import 'package:ynotes_packages/theme.dart';
import 'package:ynotes_packages/utilities.dart';

class LoginPronoteQrcodePage extends StatefulWidget {
  const LoginPronoteQrcodePage({Key? key}) : super(key: key);

  @override
  _LoginPronoteQrcodePageState createState() => _LoginPronoteQrcodePageState();
}

class _LoginPronoteQrcodePageState extends State<LoginPronoteQrcodePage> {
  final QrLoginController controller = QrLoginController();
  QRViewController? qrController;

  @override
  Widget build(BuildContext context) {
    return ControllerConsumer<QrLoginController>(
      controller: controller,
      builder: (context, controller, child) => YPage(
        appBar: const YAppBar(title: "QR Code"),
        scrollable: false,
        floatingButtons: controller.status == AuthStatus.initial
            ? [
                YFloatingButton(
                    icon: MdiIcons.cameraFlip,
                    onPressed: () {
                      qrController?.flipCamera();
                    },
                    color: YColor.secondary),
                YFloatingButton(
                    icon: MdiIcons.flashlight,
                    onPressed: () {
                      qrController?.toggleFlash();
                    },
                    color: YColor.secondary),
              ]
            : null,
        body: controller.status == AuthStatus.initial
            ? Column(children: [
                Expanded(
                    child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QRView(
                        key: GlobalKey(debugLabel: 'QR'),
                        onQRViewCreated: (QRViewController qrController) async {
                          this.qrController = qrController;
                          qrController.scannedDataStream.listen((barCode) async {
                            print("-------------------------------");
                            if (controller.status == AuthStatus.initial && controller.isQrCodeValid(barCode)) {
                              print("YES");
                              await getCode();
                            }
                            print("-------------------------------");
                          });
                        }),
                    const QrCrossHair()
                  ],
                ))
              ])
            : Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Column(
                      children: [
                        YVerticalSpacer(YScale.s16),
                        Text(
                          "Connexion en cours...",
                          style: theme.texts.body1,
                          textAlign: TextAlign.center,
                        ),
                        YVerticalSpacer(YScale.s6),
                        const YLinearProgressBar(),
                      ],
                    )),
              ),
      ),
    );
  }

  Future<void> getCode() async {
    final String? res = await YDialogs.getInput(
        context,
        YInputDialog(
            title: "Code",
            input: YFormField(
              type: YFormFieldInputType.number,
              label: "Code",
              properties: YFormFieldProperties(),
              validator: (String? value) {
                if (value == null || value.isEmpty || value.length != 4) {
                  return "Le code doit comporter 4 caractères";
                }
                return null;
              },
              maxLength: 4,
            )));
    if (res != null) {
      await login(res);
    } else {
      controller.reset();
    }
  }

  Future<void> login(String code) async {
    final List<String>? decryptedData = controller.decrypt(code);
    if (decryptedData == null) {
      YSnackbars.error(context, title: "Erreur", message: "Votre code PIN est invalide");
      getCode();
      return;
    }

    //Login
    final List<dynamic>? data = await appSys.api!.login(decryptedData[0], decryptedData[1], additionnalSettings: {
      "url": controller.url + "?login=true",
      "qrCodeLogin": true,
      "mobileCasLogin": false,
    });
    if (data != null && data[0] == 1) {
      YSnackbars.success(context, title: "Connecté !", message: data[1]);
      await Future.delayed(const Duration(seconds: 3));
      Navigator.pushReplacementNamed(context, "/intro");
    } else {
      YSnackbars.error(context, title: "Erreur", message: data![1]);
      controller.reset();
    }
  }
}
