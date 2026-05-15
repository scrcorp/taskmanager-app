// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppL10nEs extends AppL10n {
  AppL10nEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'HTM Asistencia';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get actionContinue => 'Continuar';

  @override
  String get actionDone => 'Listo';

  @override
  String get commonHeadsUp => 'Atención';

  @override
  String get commonSavedTitle => 'Guardado';

  @override
  String get commonSaveFailedTitle => 'No se pudo guardar';

  @override
  String get commonComingSoon => 'Próximamente';

  @override
  String get commonUnknown => 'Desconocido';

  @override
  String get commonStore => 'Tienda';

  @override
  String get commonDevice => 'Dispositivo';

  @override
  String get commonDismiss => 'Descartar';

  @override
  String get commonRefresh => 'Actualizar';

  @override
  String get commonSettings => 'Ajustes';

  @override
  String get commonUntitled => 'Sin título';

  @override
  String get attAccessCodeRegisterTitle => 'Registrar este dispositivo';

  @override
  String get attAccessCodeRegisterDescription =>
      'Ingresa el código de acceso de 6 caracteres proporcionado por tu gerente.';

  @override
  String get attAccessCodeRegisterButton => 'Registrar dispositivo';

  @override
  String get attAccessCodeChangeStoreTitle => 'Cambiar tienda';

  @override
  String get attAccessCodeChangeStoreDescription =>
      'Ingresa un nuevo código de acceso de 6 caracteres para cambiar este dispositivo a otra tienda.';

  @override
  String get attAccessCodeInvalid => 'Código de acceso inválido';

  @override
  String get attAccessCodeRegisterFailedTitle =>
      'No se pudo registrar el dispositivo';

  @override
  String get attStoreSelectTitle => 'Seleccionar tienda';

  @override
  String attStoreSelectDeviceNeedsAssignment(String deviceName) {
    return 'Este dispositivo ($deviceName) necesita ser asignado a una tienda.';
  }

  @override
  String get attStoreSelectGenericNeedsAssignment =>
      'Este dispositivo necesita ser asignado a una tienda.';

  @override
  String get attStoreSelectLoadFailed =>
      'No se pudieron cargar las tiendas del servidor. Mostrando opciones predeterminadas/manuales.';

  @override
  String get attStoreSelectEmpty =>
      'No hay tiendas disponibles. Contacta a un administrador.';

  @override
  String get attStoreSelectManualLabel => 'ID de tienda manual';

  @override
  String get attStoreSelectManualHint => 'Pegar UUID de tienda (alternativa)';

  @override
  String get attStoreSelectAssignButton => 'Asignar tienda';

  @override
  String get attStoreSelectAssignFailed => 'No se pudo asignar la tienda';

  @override
  String get attStoreSelectAssignFailedTitle => 'No se pudo asignar la tienda';

  @override
  String get attSettingsTitle => 'Ajustes del dispositivo';

  @override
  String get attSettingsDeviceLabel => 'Dispositivo';

  @override
  String get attSettingsStoreLabel => 'Tienda';

  @override
  String get attSettingsStoreNotAssigned => 'Sin asignar';

  @override
  String get attSettingsDeviceIdLabel => 'ID del dispositivo';

  @override
  String get attSettingsLanguageLabel => 'Idioma';

  @override
  String get attSettingsLanguageEnglish => 'English';

  @override
  String get attSettingsLanguageSpanish => 'Español';

  @override
  String get attSettingsChangeStore => 'Cambiar tienda';

  @override
  String get attSettingsChangeStoreConfirm =>
      'Para cambiar este dispositivo a otra tienda, necesitarás un nuevo código de acceso. Se revocará el registro actual del dispositivo.';

  @override
  String get attSettingsKioskLockTitle => 'Bloqueo de quiosco';

  @override
  String get attSettingsKioskLockOn =>
      'La aplicación está bloqueada. Desactiva para usar el dispositivo libremente.';

  @override
  String get attSettingsKioskLockOff =>
      'La aplicación está desbloqueada. Activa para restringir el dispositivo.';

  @override
  String get attSettingsKioskEnableTitle => 'Activar bloqueo de quiosco';

  @override
  String get attSettingsKioskEnableMessage =>
      'Android mostrará un cuadro de diálogo del sistema pidiendo fijar esta aplicación. DEBES tocar \"Entendido\" / \"OK\" para activar el modo quiosco. Si tocas \"No, gracias\", el dispositivo quedará desbloqueado.';

  @override
  String get attSettingsKioskNotActiveTitle => 'Bloqueo no activo';

  @override
  String get attSettingsKioskNotActiveMessage =>
      'Rechazaste el aviso de fijación. El modo quiosco es obligatorio para este dispositivo. Toca Reintentar y confirma el cuadro de diálogo del sistema.';

  @override
  String get attSettingsKioskDisableTitle => 'Desactivar bloqueo de quiosco';

  @override
  String get attSettingsKioskDisableConfirm => 'Desbloquear';

  @override
  String get attSettingsKioskDisabledTitle => 'Quiosco desactivado';

  @override
  String get attSettingsKioskDisabledMessage =>
      'El bloqueo de quiosco se reactivará automáticamente en 5 minutos. Actívalo de nuevo en cualquier momento para volver a bloquear de inmediato.';

  @override
  String get attSettingsUnregister => 'Cancelar registro de este dispositivo';

  @override
  String get attSettingsUnregisterConfirmTitle =>
      'Cancelar registro del dispositivo';

  @override
  String get attSettingsUnregisterConfirmMessage =>
      'Este dispositivo será eliminado de la organización. Necesitarás un nuevo código de acceso para registrarlo de nuevo.';

  @override
  String get attSettingsUnregisterVerifyTitle =>
      'Confirmar cancelación de registro';

  @override
  String get attSettingsUnregisterVerifyConfirm => 'Cancelar registro';

  @override
  String get attSettingsAccessCodePromptTitle => 'No se puede continuar';

  @override
  String get attSettingsAccessCodePromptMessage =>
      'No hay código de acceso registrado. Vuelve a registrar este dispositivo para habilitar esta acción.';

  @override
  String get attSettingsAccessCodeEnter =>
      'Ingresa el código de acceso del dispositivo.';

  @override
  String get attSettingsAccessCodeIncorrectTitle => 'Código incorrecto';

  @override
  String get attSettingsAccessCodeIncorrectMessage =>
      'El código de acceso no coincide.';

  @override
  String get attSettingsAccessCodeHint => 'ABC123';

  @override
  String get attSettingsKioskUnlockedTitle => 'Quiosco desbloqueado';

  @override
  String get attSettingsKioskUnlockedMessage =>
      'Ahora puedes salir de la aplicación. Vuelve a registrar o reinstala para reactivar el modo quiosco.';

  @override
  String attPinHi(String name) {
    return 'Hola, $name';
  }

  @override
  String get attPinTitle => 'Ingresa tu PIN';

  @override
  String attPinSubtitle(int length) {
    return 'Usa tu número de $length dígitos para continuar';
  }

  @override
  String get attPinCancelReturn => 'Cancelar y volver';

  @override
  String get attPinVerify => 'Verificar identidad';

  @override
  String get attPinPadClear => 'BORRAR';

  @override
  String get attPinSecureAccessTitle => 'Acceso seguro';

  @override
  String get attPinSecureAccessDescription =>
      'La verificación garantiza la seguridad y responsabilidad de todo el personal.';

  @override
  String get attPinShiftRecognitionTitle => 'Reconocimiento de turno';

  @override
  String get attPinShiftRecognitionDescription =>
      'Marcar entrada registra tu presencia para el ciclo actual.';

  @override
  String get attPinVerificationFailedTitle => 'Verificación fallida';

  @override
  String get attPinVerificationFailedMessage =>
      'PIN inválido. Intenta de nuevo.';

  @override
  String get attSuccessClockIn => 'Entrada exitosa';

  @override
  String get attSuccessClockOut => 'Salida exitosa';

  @override
  String get attSuccessShortBreak => 'Descanso de 10 min iniciado';

  @override
  String get attSuccessLongBreak => 'Comida iniciada';

  @override
  String get attSuccessBreakEnded => 'Descanso terminado';

  @override
  String get attSuccessWelcomeBack => 'Bienvenido de nuevo';

  @override
  String attSuccessWelcomeBackName(String name) {
    return ', ¡$name!';
  }

  @override
  String get attSuccessGoToDashboard => 'Ir al panel';

  @override
  String attSuccessRedirecting(int seconds) {
    return 'REDIRIGIENDO EN $seconds SEGUNDOS';
  }

  @override
  String attSuccessWorkedTime(int hours, int minutes) {
    return 'Trabajaste ${hours}h ${minutes}m hoy';
  }

  @override
  String get attSuccessGreatJob => '¡Buen trabajo, descansa!';

  @override
  String get attMainWorkDateLabel => 'FECHA DE TRABAJO';

  @override
  String get attMainKioskUnlockedTitle => 'Quiosco desbloqueado';

  @override
  String get attMainKioskUnlockedMessage =>
      'Bloqueo de quiosco desactivado temporalmente. Se reactivará automáticamente en 5 minutos.';

  @override
  String get attMainAttendanceLabel => 'ASISTENCIA';

  @override
  String get attMainSelectNameFirst => 'Selecciona tu nombre primero';

  @override
  String get attMainShiftCompleted => 'Turno ya completado';

  @override
  String get attMainTapToChooseAction => 'Toca para elegir acción';

  @override
  String get attMainSelected => 'SELECCIONADO';

  @override
  String get attMainClearSelection => 'Borrar selección';

  @override
  String get attMainChooseAction => 'ELEGIR ACCIÓN';

  @override
  String get attMainActionClockIn => 'ENTRADA';

  @override
  String get attMainActionClockInSubtitle => 'Iniciar jornada';

  @override
  String get attMainActionClockOut => 'SALIDA';

  @override
  String get attMainActionClockOutSubtitle => 'Terminar turno';

  @override
  String get attMainActionShortBreak => 'DESCANSO 10 MIN';

  @override
  String get attMainActionShortBreakSubtitle => 'Pagado';

  @override
  String get attMainActionLongBreak => 'COMIDA';

  @override
  String get attMainActionLongBreakSubtitle => 'No pagado';

  @override
  String get attMainActionEndBreak => 'TERMINAR DESCANSO';

  @override
  String get attMainActionEndBreakSubtitle => 'Volver al trabajo';

  @override
  String get attMainClockedIn => 'Trabajando';

  @override
  String attMainActiveBadge(int count) {
    return '$count ACTIVOS';
  }

  @override
  String get attMainNoOneOnShift => 'Nadie está en turno actualmente';

  @override
  String get attMainNotClockedIn => 'Sin marcar entrada';

  @override
  String get attMainNoUpcoming => 'No hay turnos próximos';

  @override
  String attMainBadgeUpcoming(int count) {
    return '$count PRÓXIMOS';
  }

  @override
  String attMainBadgeSoon(int count) {
    return '$count PRONTO';
  }

  @override
  String attMainBadgeLate(int count) {
    return '$count TARDE';
  }

  @override
  String attMainBadgeNoShow(int count) {
    return '$count NO SE PRESENTÓ';
  }

  @override
  String get attMainBadgeSoonShort => 'PRONTO';

  @override
  String get attMainBadgeLateShort => 'TARDE';

  @override
  String get attMainBadgeNoShowShort => 'NO SE PRESENTÓ';

  @override
  String get attMainClockedOut => 'Salidos';

  @override
  String attMainDoneBadge(int count) {
    return '$count TERMINADOS';
  }

  @override
  String get attMainNoCompletedShifts => 'Aún no hay turnos completados';

  @override
  String get attMainCurrentTimeLabel => 'HORA ACTUAL';

  @override
  String get attMainNoticeBoard => 'Tablero de avisos';

  @override
  String get attMainNoNotices => 'Sin avisos';

  @override
  String get attMainNoSchedule => 'Sin horario';

  @override
  String attMainClockedInAt(String time) {
    return 'Entrada a las $time';
  }

  @override
  String get attMainBreakLong => 'Comida no pagada';

  @override
  String get attMainBreakShort => '10 min pagado';

  @override
  String get attMainBreakOnBreak => 'En descanso';

  @override
  String attMainOnBreakWith(String label) {
    return 'En descanso · $label';
  }

  @override
  String get attMainLateBadge => 'Tarde';

  @override
  String get attMainEarlyClockOutTitle => 'Saliendo antes de tiempo';

  @override
  String attMainEarlyClockOutMessage(String remaining) {
    return 'Tu turno aún tiene $remaining restantes. ¿Estás seguro de que quieres marcar salida ahora?';
  }

  @override
  String get attMainEarlyClockOutReasonLabel =>
      'Por favor ingresa una razón — requerida para salida temprana.';

  @override
  String get attMainEarlyClockOutReasonHint =>
      'ej. Emergencia familiar, no me siento bien';

  @override
  String get attMainTimeAgoJustNow => 'Justo ahora';

  @override
  String attMainTimeAgoMinutes(int count) {
    return 'hace $count min';
  }

  @override
  String attMainTimeAgoHours(int count) {
    return 'hace ${count}h';
  }

  @override
  String attMainTimeAgoDays(int count) {
    return 'hace ${count}d';
  }

  @override
  String attMainDurationHM(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String attMainDurationM(int minutes) {
    return '${minutes}m';
  }

  @override
  String get attUpdateRequiredTitle => 'Actualización de la app requerida';

  @override
  String attUpdateRequiredMessage(String current, String required) {
    return 'Este dispositivo ejecuta $current pero se requiere $required o superior para continuar.';
  }

  @override
  String attUpdateDownloadButton(String version) {
    return 'Descargar actualización (v$version)';
  }

  @override
  String get attUpdateUnavailableTitle => 'Actualización no disponible';

  @override
  String get attUpdateUnavailableMessage =>
      'No hay URL de descarga configurada. Contacta a tu administrador.';

  @override
  String get attUpdateCannotOpenTitle => 'No se puede abrir la descarga';

  @override
  String get attUpdateCannotOpenMessage =>
      'No se pudo abrir la URL de descarga.';

  @override
  String attUpdateAvailableBanner(String latest, String current) {
    return 'Actualización disponible: v$latest (actual v$current)';
  }

  @override
  String get attUpdateButton => 'Actualizar';

  @override
  String get attUpdateDownloading => 'Descargando';

  @override
  String get attUpdateLaunchingInstaller => 'Abriendo instalador…';
}
