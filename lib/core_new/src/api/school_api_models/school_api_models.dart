library models;

// flutter packages pub run build_runner build --delete-conflicting-outputs

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:ynotes/core/utils/file_utils.dart';
import 'package:ynotes/core_new/api.dart';
import 'package:ynotes_packages/theme.dart';
import 'package:crypto/crypto.dart';

// HIVE GENERATED FILE
part "school_api_models.g.dart";

part 'src/app_account.dart';
part 'src/school_account.dart';
part 'src/school_life_sanction.dart';
part 'src/school_life_ticket.dart';
part 'src/grade.dart';
part 'src/subjects_filter.dart';
part 'src/period.dart';
part 'src/subject.dart';
part 'src/email.dart';
part 'src/recipient.dart';
part 'src/homework.dart';
part 'src/document.dart';

part 'src/internal/adapters.dart';
part 'src/internal/hive.dart';