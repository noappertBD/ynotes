library notification_service;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ynotes/app/app.dart';
import 'package:ynotes/legacy/logging_utils/logging_utils.dart';
import 'package:ynotes/core/api.dart';
import 'package:ynotes/core/extensions.dart';

part 'src/notification/service.dart';
part 'src/notification/payload.dart';
part 'src/notification/notifications.dart';