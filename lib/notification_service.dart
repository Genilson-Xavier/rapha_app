import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:io'; // Necessário para verificar a plataforma
import 'package:flutter/foundation.dart'; // Para verificar se é Web

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Se estiver no navegador (Web), as notificações locais funcionam diferente.
    // Por enquanto, vamos apenas pular a inicialização para não travar o app.
    if (kIsWeb) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // Adicionamos as configurações de iOS e Linux para evitar o erro que você viu
    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings();

    const LinuxInitializationSettings initializationSettingsLinux =
    LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Lógica para quando clicar na notificação
        print("Notificação clicada: ${details.payload}");
      },
    );

    tz.initializeTimeZones();
  }

  Future<void> agendarNotificacao({
    required int id,
    required String titulo,
    required String corpo,
    required DateTime horario,
    required int minutosAntes,
  }) async {
    // ESSA É A PROTEÇÃO: Se não for Android e não for iOS, ele apenas sai da função
    if (!Platform.isAndroid && !Platform.isIOS) {
      print("Agendamento de notificações só funciona em dispositivos móveis.");
      return;
    }

    final horarioAlerta = horario.subtract(Duration(minutes: minutosAntes));
    final tz.TZDateTime tzScheduleTime = tz.TZDateTime.from(horarioAlerta, tz.local);

    if (tzScheduleTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      titulo,
      corpo,
      tzScheduleTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'treinos_id', 'Lembrete de Treinos',
          channelDescription: 'Notificações de horários de alunos',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(), // Importante para iOS também
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}