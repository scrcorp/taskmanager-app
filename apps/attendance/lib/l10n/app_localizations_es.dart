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
  String get attSettingsAppLabel => 'Aplicación';

  @override
  String get attSettingsVersionLabel => 'Versión';

  @override
  String get attSettingsCompanyLabel => 'Empresa';

  @override
  String get attSettingsCompanyName => 'Tigers Plus';

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
  String get scheduleSectionWorking => 'Trabajando';

  @override
  String get scheduleSectionWorkingEmpty => 'Nadie está trabajando.';

  @override
  String get scheduleSectionUpcoming => 'Próximos';

  @override
  String get scheduleSectionUpcomingEmpty => 'Todos han fichado entrada.';

  @override
  String get scheduleSectionDone => 'Finalizado';

  @override
  String get scheduleSectionDoneEmpty => 'Nadie ha fichado salida todavía.';

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

  @override
  String get pfStoreFallback => 'Tienda';

  @override
  String get pfHeaderSchedule => 'Horario';

  @override
  String get pfHeaderSettings => 'Ajustes';

  @override
  String get pfHeaderRefreshTooltip => 'Actualizar';

  @override
  String get pfHeaderRefreshed => 'Actualizado';

  @override
  String pfPinHint(int min, int max) {
    return 'Ingresa $min~$max dígitos y toca Verificar';
  }

  @override
  String get pfPinShow => 'Mostrar PIN';

  @override
  String get pfPinHide => 'Ocultar PIN';

  @override
  String get pfPinClear => 'BORRAR';

  @override
  String get pfPinVerify => 'Verificar identidad';

  @override
  String get pfKioskUnlockedToast =>
      'Bloqueo de quiosco liberado por 5 minutos';

  @override
  String get pfMainWorkingHeader => 'TRABAJANDO';

  @override
  String get pfMainWorkingEmpty => 'Nadie está trabajando ahora.';

  @override
  String pfMainWorkingDuration(String duration) {
    return 'Trabajando $duration';
  }

  @override
  String pfMainBreakDuration(String duration, String type) {
    return 'Descanso $duration · $type';
  }

  @override
  String get pfMainBreakTypeShort => '10m';

  @override
  String get pfMainBreakTypeMeal => 'comida';

  @override
  String get pfKioskUnlockedTitle => 'Quiosco desbloqueado';

  @override
  String get pfKioskUnlockedBody =>
      'Tienes 5 minutos para usar el dispositivo libremente.\nEl quiosco se bloqueará automáticamente.';

  @override
  String get pfIdHeader => '¿ERES TÚ?';

  @override
  String get pfIdYes => 'Sí, soy yo';

  @override
  String get pfIdClose => 'Cerrar';

  @override
  String get pfIdNoShiftTitle => 'SIN TURNO HOY';

  @override
  String get pfIdNoShiftBody =>
      'No tienes turno hoy. Acciones de reloj desactivadas.';

  @override
  String get pfIdWalkInTitle => 'ENTRADA LIBRE';

  @override
  String get pfIdWalkInBody =>
      'Sin turno programado. Registro de entrada libre habilitado.';

  @override
  String get pfIdWalkInAgainBody =>
      'Turno anterior completado. Puede registrar entrada de nuevo.';

  @override
  String pfStaleWarnTitle(int count) {
    return '$count registro(s) sin finalizar';
  }

  @override
  String get pfStaleWarnBody =>
      'No fichaste la salida estos días. Consulta con tu gerente.';

  @override
  String pfStaleMore(int count) {
    return '+$count más';
  }

  @override
  String get pfStatusWorking => 'Trabajando';

  @override
  String get pfStatusOnBreak => 'En descanso';

  @override
  String get pfStatusUpcoming => 'Turno próximo';

  @override
  String get pfStatusSoon => 'Turno por comenzar';

  @override
  String get pfStatusLate => 'Llegada tarde';

  @override
  String get pfStatusNoShow => 'No se presentó';

  @override
  String get pfStatusClockedOut => 'Turno completado';

  @override
  String pfBreakOnBreakTitle(String breakLabel) {
    return 'EN DESCANSO · $breakLabel';
  }

  @override
  String pfBreakElapsed(int minutes) {
    return '$minutes m transcurridos';
  }

  @override
  String get pfBreakLabelPaid10Min => 'Descanso 10 min (pagado)';

  @override
  String get pfBreakLabelMealUnpaid => 'Comida (no pagado)';

  @override
  String get pfBreakLabelOnBreak => 'En descanso';

  @override
  String pfBreakHintPaidTooShort(int minutes) {
    return 'Disponible terminar en $minutes m más (10 m mínimo).';
  }

  @override
  String get pfBreakHintPaidWithin =>
      'Pagado hasta 10 m. Puedes terminar el descanso.';

  @override
  String pfBreakHintPaidOver(int minutes) {
    return 'El exceso de $minutes m no se pagará.';
  }

  @override
  String pfBreakHintMealTooShort(int minutes) {
    return 'Disponible terminar en $minutes m más (30 m mínimo).';
  }

  @override
  String get pfBreakHintMealWithin =>
      'Dentro del rango (30~35 m). Puedes terminar.';

  @override
  String get pfBreakHintMealRequiresReason =>
      'Más de 35 m — se requiere motivo para terminar.';

  @override
  String get pfActionHeader => 'ELEGIR ACCIÓN';

  @override
  String get pfActionHint =>
      'Solo se habilitan acciones válidas para tu estado actual.';

  @override
  String get pfActionClockIn => 'Marcar entrada';

  @override
  String get pfActionClockInSub => 'Comenzar tu turno';

  @override
  String get pfActionClockOut => 'Marcar salida';

  @override
  String get pfActionClockOutSub => 'Terminar tu turno';

  @override
  String get pfActionBreakShort => 'Descanso 10 min';

  @override
  String get pfActionBreakShortSub => 'Descanso corto pagado';

  @override
  String get pfActionBreakLong => 'Comida';

  @override
  String get pfActionBreakLongSub => 'Comida no pagada';

  @override
  String get pfActionBreakEnd => 'Terminar descanso';

  @override
  String get pfActionBreakEndSub => 'Volver al trabajo';

  @override
  String pfActionWaitMore(int minutes) {
    return 'Espera $minutes m más';
  }

  @override
  String get pfEarlyHeader => 'SALIDA TEMPRANA';

  @override
  String pfEarlyRemainingLine(String remaining, String end) {
    return 'Faltan $remaining para el fin programado ($end)';
  }

  @override
  String pfEarlyTitle(String name) {
    return '$name, ¿por qué te vas temprano?';
  }

  @override
  String get pfEarlyBody =>
      'Se requiere motivo para salir temprano. Tu gerente lo verá.';

  @override
  String get pfEarlyReasonUnwell => 'Me siento mal';

  @override
  String get pfEarlyReasonFamily => 'Emergencia familiar';

  @override
  String get pfEarlyReasonManager => 'Aprobado por gerente';

  @override
  String get pfEarlyReasonPersonal => 'Motivo personal';

  @override
  String get pfEarlyReasonOther => 'Otro (especificar)';

  @override
  String get pfEarlyDetailHint => 'Describe...';

  @override
  String get pfEarlyCancel => 'Cancelar';

  @override
  String get pfEarlySubmit => 'Enviar y salir';

  @override
  String get pfTipHeader => 'PROPINAS';

  @override
  String pfTipTitle(String name) {
    return 'Propinas de $name hoy';
  }

  @override
  String get pfTipBody =>
      'Registra tus propinas y distribúyelas a tus compañeros.';

  @override
  String get pfTipCardLabel => 'Propinas en tarjeta';

  @override
  String get pfTipCardSub => 'Total del POS';

  @override
  String get pfTipCashLabel => 'Propinas en efectivo';

  @override
  String get pfTipCashSub => 'Efectivo que te llevas';

  @override
  String get pfTipDistributeHeader => 'DISTRIBUIR PROPINAS DE TARJETA';

  @override
  String get pfTipDistributeSub =>
      'Elige compañeros y divide — el total no puede exceder';

  @override
  String get pfTipSplitEvenly => 'Dividir igual';

  @override
  String get pfTipNoTeammates => 'Ningún compañero trabajó contigo hoy.';

  @override
  String pfTipWorked(String hours) {
    return '$hours h trabajadas';
  }

  @override
  String pfTipDistributedLine(String dist, String card) {
    return 'Distribuido: \$$dist / \$$card';
  }

  @override
  String pfTipOverBy(String amount) {
    return 'Excede por \$$amount';
  }

  @override
  String get pfTipAddTeammateButton => 'Agregar compañero (no en la lista)';

  @override
  String get pfTipAddTeammateHeader => 'AGREGAR COMPAÑERO';

  @override
  String get pfTipAddSearchHint => 'Buscar por nombre…';

  @override
  String get pfTipAddNoMatch => 'Sin resultados.';

  @override
  String get pfTipSkip => 'Saltar — ingresar después';

  @override
  String get pfTipSubmit => 'Enviar propinas';

  @override
  String get pfSuccessClockedIn => 'ENTRADA REGISTRADA';

  @override
  String pfSuccessClockedInMsg(String name) {
    return '¡Que tengas un buen turno, $name!';
  }

  @override
  String get pfSuccessClockedOut => 'SALIDA REGISTRADA';

  @override
  String pfSuccessClockedOutMsg(String name) {
    return '¡Buen trabajo hoy, $name!';
  }

  @override
  String get pfSuccessOn10MinBreak => 'EN DESCANSO DE 10 MIN';

  @override
  String pfSuccessOn10MinBreakMsg(String name) {
    return '¡Nos vemos en 10, $name!';
  }

  @override
  String get pfSuccessMealBreak => 'COMIDA';

  @override
  String pfSuccessMealBreakMsg(String name) {
    return '¡Disfruta tu comida, $name!';
  }

  @override
  String get pfSuccessBackToWork => 'VOLVISTE AL TRABAJO';

  @override
  String pfSuccessBackToWorkMsg(String name) {
    return '¡Bienvenido de vuelta, $name!';
  }

  @override
  String get pfSuccessOk => 'OK';

  @override
  String get pfSuccessAutoClose => 'Se cierra automáticamente en 5 segundos';

  @override
  String get pfErrorFallback => 'Algo salió mal';

  @override
  String get pfErrorOk => 'OK';
}
