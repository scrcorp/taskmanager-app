// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppL10nEs extends AppL10n {
  AppL10nEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'App de Personal';

  @override
  String get actionLogin => 'Iniciar sesión';

  @override
  String get actionRegister => 'Registrarse';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionNext => 'Siguiente';

  @override
  String get actionBack => 'Atrás';

  @override
  String get actionSubmit => 'Enviar';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get actionSearch => 'Buscar';

  @override
  String get actionContinue => 'Continuar';

  @override
  String get loginEmailOrUsernameHint => 'Correo o usuario';

  @override
  String get loginPasswordHint => 'Contraseña';

  @override
  String get loginFindUsername => 'Buscar usuario';

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginNoAccountPrompt => '¿No tienes cuenta? ';

  @override
  String get loginRegisterAction => 'Regístrate';

  @override
  String get loginFailedTitle => 'Error al iniciar sesión';

  @override
  String get loginFailedDefault => 'No se pudo iniciar sesión';

  @override
  String get loginAlreadyHaveAccountPrompt => '¿Ya tienes cuenta? ';

  @override
  String get companyCodeTitle => 'Ingresa el código de empresa';

  @override
  String get companyCodeSubtitle =>
      'Pídele el código de empresa a tu supervisor';

  @override
  String get companyCodeHint => 'Código de empresa';

  @override
  String get commonHeadsUp => 'Atención';

  @override
  String get errorServerLater =>
      'Error del servidor. Inténtalo de nuevo más tarde.';

  @override
  String get errorServerNotResponding =>
      'El servidor no responde. Inténtalo de nuevo.';

  @override
  String get errorNoInternet => 'Sin conexión a internet.';

  @override
  String get actionLogout => 'Cerrar sesión';

  @override
  String get actionResend => 'Reenviar';

  @override
  String get actionSendCode => 'Enviar código';

  @override
  String get actionVerify => 'Verificar';

  @override
  String get fieldEmail => 'Correo';

  @override
  String get fieldVerificationCode => 'Código de verificación';

  @override
  String get hintEmailExample => 'ejemplo@correo.com';

  @override
  String get hint6DigitCode => 'Código de 6 dígitos';

  @override
  String get emailVerifyHeader => 'Verificación de correo';

  @override
  String get emailVerifyHeading => 'Verifica tu correo';

  @override
  String get emailVerifySubheading =>
      'Para seguir usando HTM,\npor favor verifica tu correo electrónico.';

  @override
  String get emailVerifyMissingEmail => 'Por favor ingresa tu correo.';

  @override
  String get emailVerifyCodeSentTitle => 'Código enviado';

  @override
  String get emailVerifyCodeSentMessage =>
      'Se envió el código de verificación.';

  @override
  String get emailVerifyCodeSendErrorTitle => 'No se pudo enviar el código';

  @override
  String get emailVerifyCodeSendErrorDefault => 'No se pudo enviar el código.';

  @override
  String get emailVerifyMissing6Digit =>
      'Por favor ingresa el código de 6 dígitos.';

  @override
  String get emailVerifyFailedTitle => 'Verificación fallida';

  @override
  String get emailVerifyFailedDefault => 'La verificación falló.';

  @override
  String get emailVerifySuccessTitle => '¡Correo verificado!';

  @override
  String get emailVerifySuccessMessage =>
      'Tu correo se verificó correctamente.\nYa puedes usar todas las funciones.';

  @override
  String get emailVerifyGoHome => 'Ir al inicio';

  @override
  String get emailVerifyChangeEmail => 'Cambiar correo';

  @override
  String get emailVerifyChangeEmailHint =>
      'Puedes cambiar tu correo si lo necesitas.';

  @override
  String emailVerifyTimerRemaining(String time) {
    return '⏱ $time restante';
  }

  @override
  String get actionResendCode => 'Reenviar código';

  @override
  String get actionGoToLogin => 'Ir a iniciar sesión';

  @override
  String get actionResetPassword => 'Restablecer contraseña';

  @override
  String get codeNotReceivedPrompt => '¿No recibiste el código?';

  @override
  String get findUsernameHeader => 'Buscar usuario';

  @override
  String get findUsernameHeading => 'Encuentra tu usuario';

  @override
  String get findUsernameSubheading =>
      'Ingresa el correo asociado a tu cuenta.';

  @override
  String get findUsernameHelp =>
      'Buscaremos tu cuenta y te mostraremos una versión enmascarada de tu usuario para verificar.';

  @override
  String get findUsernameNotFoundTitle => 'Cuenta no encontrada';

  @override
  String get findUsernameNotFoundDefault =>
      'No se encontró ninguna cuenta con este correo.';

  @override
  String get findUsernameStep2Title => '¿Es esta tu cuenta?';

  @override
  String get findUsernameStep2Subtitle =>
      'Encontramos una cuenta con el correo que proporcionaste.';

  @override
  String get findUsernameStep2Hint =>
      'Para ver tu usuario completo, verifica tu correo.';

  @override
  String get findUsernameLabel => 'Usuario';

  @override
  String get findUsernameTryDifferent => 'Probar otro correo';

  @override
  String get findUsernameSuccessTitle => 'Usuario encontrado';

  @override
  String get findUsernameSuccessMessage => 'Tu usuario se ha verificado.';

  @override
  String get findUsernameYourUsername => 'Tu usuario';

  @override
  String get findUsernameUsernameHint =>
      'Usa este usuario para iniciar sesión en tu cuenta.';

  @override
  String get actionSendVerificationCode => 'Enviar código de verificación';

  @override
  String get fieldUsername => 'Usuario';

  @override
  String get fieldNewPassword => 'Nueva contraseña';

  @override
  String get fieldConfirmPassword => 'Confirmar contraseña';

  @override
  String get hintEnterUsername => 'Ingresa tu usuario';

  @override
  String get hintEnterNewPassword => 'Ingresa la nueva contraseña';

  @override
  String get hintReenterNewPassword => 'Vuelve a ingresar la nueva contraseña';

  @override
  String get resetHeader => 'Restablecer contraseña';

  @override
  String get resetHeading => 'Restablece tu contraseña';

  @override
  String get resetSubheading =>
      'Ingresa tu usuario y correo para verificar tu identidad.';

  @override
  String get resetMissingUsernameEmail =>
      'Por favor ingresa tu usuario y correo.';

  @override
  String get resetNoAccountDefault => 'No se encontró ninguna cuenta.';

  @override
  String get resetCodeSentInfo =>
      'Se enviará un código de verificación a tu correo.';

  @override
  String get resetCodeResentTitle => 'Código reenviado';

  @override
  String get resetCodeResentMessage => 'Código de verificación reenviado.';

  @override
  String get resetCodeResendErrorTitle => 'No se pudo reenviar el código';

  @override
  String get resetCodeResendErrorDefault => 'No se pudo reenviar el código.';

  @override
  String get resetEnterCodeHeading => 'Ingresa el código de verificación';

  @override
  String resetCodeSentTo(String email) {
    return 'Enviamos un código de 6 dígitos a $email';
  }

  @override
  String get resetWrongEmail => '¿Correo incorrecto? Volver';

  @override
  String get resetSetNewHeading => 'Crea una nueva contraseña';

  @override
  String get resetSetNewSubheading =>
      'Crea una nueva contraseña para tu cuenta.';

  @override
  String get resetMissingFields => 'Por favor completa todos los campos.';

  @override
  String get resetPasswordsMismatchTitle => 'Las contraseñas no coinciden';

  @override
  String get resetPasswordsMismatchMessage => 'Las contraseñas no coinciden.';

  @override
  String get resetFailedTitle => 'No se pudo restablecer la contraseña';

  @override
  String get resetFailedDefault => 'No se pudo restablecer la contraseña.';

  @override
  String get resetSuccessTitle => 'Contraseña cambiada';

  @override
  String get resetSuccessMessage =>
      'Tu contraseña se restableció correctamente.\nYa puedes iniciar sesión con tu nueva contraseña.';

  @override
  String get resetSuccessDevicesNote =>
      'Por seguridad se cerró la sesión en todos los demás dispositivos.';

  @override
  String get actionGetStarted => 'Empezar';

  @override
  String get fieldFullName => 'Nombre completo';

  @override
  String get fieldPassword => 'Contraseña';

  @override
  String get fieldPreferredLanguage => 'Idioma preferido';

  @override
  String get hintFullName => 'Ingresa tu nombre completo';

  @override
  String get hintChooseUsername => 'Elige un nombre de usuario';

  @override
  String get hintEnterPassword => 'Ingresa la contraseña';

  @override
  String get hintReenterPassword => 'Vuelve a ingresar tu contraseña';

  @override
  String get passwordsMismatchInline => 'Las contraseñas no coinciden';

  @override
  String get registerTermsHeading => 'Revisa los términos';

  @override
  String get registerTermsSubheading =>
      'Acepta los términos para usar el servicio.';

  @override
  String get registerTermsBody =>
      'Términos del servicio\n\nEstos términos rigen el uso del servicio HTM. Por favor léelos con atención antes de usar el servicio.\n\nArtículo 1 (Propósito)\nEstos términos definen los derechos, obligaciones y responsabilidades entre la empresa y sus miembros respecto al uso del servicio.\n\nArtículo 2 (Definiciones)\nLas definiciones de los términos usados son las siguientes.';

  @override
  String get registerAgreeAll => 'Aceptar todos los términos';

  @override
  String get registerAgreeTos =>
      'Acepto los Términos del servicio. (Obligatorio)';

  @override
  String get registerAgreePrivacy =>
      'Acepto la Política de privacidad. (Obligatorio)';

  @override
  String get registerAgreeMarketing =>
      'Acepto recibir información de marketing. (Opcional)';

  @override
  String get registerTermsRequired =>
      'Por favor acepta todos los términos obligatorios.';

  @override
  String get registerStoresHeading => 'Selecciona tus tiendas';

  @override
  String get registerStoresSubheading =>
      'Elige las tiendas en las que trabajas.\nPuedes seleccionar varias tiendas.';

  @override
  String registerStoresSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tiendas seleccionadas',
      one: '1 tienda seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get registerStoresSearchHint => 'Buscar tiendas...';

  @override
  String registerStoresNoSearchResult(String query) {
    return 'No se encontraron tiendas para \"$query\".';
  }

  @override
  String get registerStoresEmpty =>
      'No hay tiendas disponibles.\nPor favor contacta a tu supervisor.';

  @override
  String get registerStoresLoadFailed => 'No se pudieron cargar las tiendas.';

  @override
  String get registerSelectStoreRequired =>
      'Por favor selecciona al menos una tienda.';

  @override
  String get registerInfoHeading => 'Cuéntanos sobre ti';

  @override
  String get registerInfoSubheading =>
      'Ingresa tu información básica para comenzar.';

  @override
  String get registerEnterName => 'Por favor ingresa tu nombre.';

  @override
  String get registerEnterUsername => 'Por favor ingresa un nombre de usuario.';

  @override
  String get registerEnterPassword => 'Por favor ingresa una contraseña.';

  @override
  String get registerEmailSubheading =>
      'Te enviaremos un código de verificación a tu correo.';

  @override
  String get registerEnterValidEmail => 'Por favor ingresa un correo válido.';

  @override
  String get registerCodeSendFailed =>
      'No se pudo enviar el código. Por favor intenta de nuevo.';

  @override
  String get registerEmailVerifiedTitle => 'Correo verificado';

  @override
  String get registerEmailVerifiedMessage =>
      'Tu correo se ha verificado correctamente.';

  @override
  String get registerEmailVerifiedBadge => '✓ Correo verificado';

  @override
  String get registerCodeExpiresHint =>
      'El código expira en 5 minutos después de enviarse.';

  @override
  String get registerVerifyEmailFirst =>
      'Por favor verifica tu correo primero.';

  @override
  String get registerFailedTitle => 'Registro fallido';

  @override
  String get registerFailedDefault => 'El registro falló';

  @override
  String registerWelcomeName(String name) {
    return '¡Bienvenido, $name!';
  }

  @override
  String get registerCompleteTitle => 'Registro completo';

  @override
  String get registerCompleteMessage =>
      'Empieza a usar el servicio ahora mismo.';

  @override
  String get registerStepTerms => 'Términos';

  @override
  String get registerStepStore => 'Tienda';

  @override
  String get registerStepInfo => 'Datos';

  @override
  String get registerStepEmail => 'Correo';

  @override
  String get registerStepDone => 'Listo';

  @override
  String get scheduleViewWeekly => 'Semanal';

  @override
  String get scheduleViewMonthly => 'Mensual';

  @override
  String get scheduleToday => 'Hoy';

  @override
  String get scheduleThisWeek => 'Esta semana';

  @override
  String scheduleDaysHours(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return '$_temp0 · ${hours}h';
  }

  @override
  String scheduleShiftsHours(int shifts, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      shifts,
      locale: localeName,
      other: '$shifts turnos',
      one: '1 turno',
    );
    return '$_temp0 · ${hours}h';
  }

  @override
  String get scheduleNoShifts => 'Sin turnos';

  @override
  String scheduleBadgePending(int count) {
    return 'Pendiente $count';
  }

  @override
  String scheduleBadgeConfirmed(int count) {
    return 'Confirmado $count';
  }

  @override
  String scheduleBadgeRejected(int count) {
    return 'Rechazado $count';
  }

  @override
  String get scheduleStatusConfirmed => 'Confirmado';

  @override
  String get scheduleStatusRejected => 'Rechazado';

  @override
  String get scheduleStatusModified => 'Modificado';

  @override
  String get scheduleStatusSubmitted => 'Enviado';

  @override
  String get scheduleStatusPending => 'Pendiente';

  @override
  String get scheduleConfirmedSection => 'Horario confirmado';

  @override
  String scheduleRequestSection(String label) {
    return 'Horario $label';
  }

  @override
  String get scheduleStoreLabel => 'Tienda';

  @override
  String get scheduleWorkRoleLabel => 'Puesto';

  @override
  String get scheduleTimeLabel => 'Hora';

  @override
  String scheduleNetWork(String duration) {
    return 'Trabajo neto: $duration';
  }

  @override
  String get scheduleUpcomingChecklist => 'Próxima lista';

  @override
  String get scheduleViewChecklist => 'Ver lista';

  @override
  String get scheduleChangedByManager => 'Modificado por el supervisor';

  @override
  String get scheduleEmpty => 'Sin horario';

  @override
  String get commonComingSoon => 'Próximamente';

  @override
  String get commonUnknown => 'Desconocido';

  @override
  String get clockTitle => 'Entrada / Salida';

  @override
  String get clockSubtitle =>
      'Marca tu entrada y salida para registrar tus horas.';

  @override
  String get ojtTitle => 'Capacitación OJT';

  @override
  String get ojtSubtitle =>
      'Aquí estarán disponibles los módulos de capacitación.';

  @override
  String get noticesHeader => 'Avisos';

  @override
  String get noticesEmpty => 'Sin avisos';

  @override
  String get tasksHeader => 'Tareas';

  @override
  String get tasksFilterLabel => 'Filtro: ';

  @override
  String get tasksFilterAll => 'Todas';

  @override
  String get tasksFilterPending => 'Pendientes';

  @override
  String get tasksFilterInProgress => 'En curso';

  @override
  String get tasksFilterCompleted => 'Completadas';

  @override
  String get tasksEmpty => 'Sin tareas';

  @override
  String tasksDuePrefix(String date) {
    return 'Vence: $date';
  }

  @override
  String get commonSavedTitle => 'Guardado';

  @override
  String get commonSaveFailedTitle => 'No se pudo guardar';

  @override
  String get settingsHeader => 'Ajustes';

  @override
  String get settingsAlertSettings => 'Ajustes de alertas';

  @override
  String get settingsEditUsername => 'Editar usuario';

  @override
  String get settingsEnterNewUsername => 'Ingresa el nuevo usuario';

  @override
  String get settingsChangePassword => 'Cambiar contraseña';

  @override
  String get settingsLanguageSaved => 'Idioma guardado.';

  @override
  String get settingsLanguageFailed => 'No se pudo actualizar el idioma';

  @override
  String get settingsUsernameSaved => 'Usuario actualizado.';

  @override
  String get settingsUsernameFailed => 'No se pudo actualizar el usuario';

  @override
  String get fieldCurrentPassword => 'Contraseña actual';

  @override
  String get fieldConfirmNewPassword => 'Confirmar nueva contraseña';

  @override
  String get hintEnterCurrentPassword => 'Ingresa la contraseña actual';

  @override
  String get changePasswordHeader => 'Cambiar contraseña';

  @override
  String get changePasswordHeading => 'Cambiar contraseña';

  @override
  String get changePasswordSubheading =>
      'Ingresa tu contraseña actual y crea una nueva.';

  @override
  String get changePasswordDevicesNote =>
      'Después de cambiar tu contraseña, se cerrará la sesión en todos los demás dispositivos.';

  @override
  String get changePasswordSuccessTitle => 'Contraseña cambiada';

  @override
  String get changePasswordSuccessMessage =>
      'Contraseña cambiada correctamente.';

  @override
  String get changePasswordFailedTitle => 'No se pudo cambiar la contraseña';

  @override
  String get changePasswordFailedDefault => 'No se pudo cambiar la contraseña.';

  @override
  String get alertsHeader => 'Alertas';

  @override
  String alertsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sin leer',
      one: '1 sin leer',
    );
    return '$_temp0';
  }

  @override
  String get alertsMarkAllRead => 'Marcar todas como leídas';

  @override
  String get alertsLoadFailed => 'No se pudieron cargar las alertas';

  @override
  String get alertsEmpty => 'Sin alertas';

  @override
  String get timeJustNow => 'ahora mismo';

  @override
  String timeMinAgo(int n) {
    return 'hace ${n}m';
  }

  @override
  String timeHourAgo(int n) {
    return 'hace ${n}h';
  }

  @override
  String get timeYesterday => 'ayer';

  @override
  String timeDayAgo(int n) {
    return 'hace ${n}d';
  }

  @override
  String timeWeekAgo(int n) {
    return 'hace ${n}sem';
  }

  @override
  String get dailyReportsHeader => 'Reportes diarios';

  @override
  String get dailyReportsEmpty => 'Sin reportes';

  @override
  String get dailyReportsFilterDraft => 'Borrador';

  @override
  String get dailyReportsFilterSubmitted => 'Enviado';

  @override
  String get inventoryHeader => 'Inventario';

  @override
  String get inventoryStoresLoadFailed => 'No se pudieron cargar las tiendas';

  @override
  String get inventoryNoStoresTitle => 'Sin tiendas asignadas';

  @override
  String get inventoryNoStoresMessage =>
      'Aún no estás asignado a ninguna tienda.';

  @override
  String inventoryStockItems(int count) {
    return '$count artículos';
  }

  @override
  String inventoryStockLow(int count) {
    return '$count bajo';
  }

  @override
  String inventoryStockOut(int count) {
    return '$count agotado';
  }

  @override
  String get actionReset => 'Restablecer';

  @override
  String get commonConnectionError =>
      'Verifica tu conexión e intenta de nuevo.';

  @override
  String get alertSettingsHeader => 'Ajustes de alertas';

  @override
  String get alertSettingsLoadFailed => 'No se pudieron cargar los ajustes.';

  @override
  String get alertSettingsSaved => 'Preferencias de alertas actualizadas.';

  @override
  String get alertSettingsResetTitle => '¿Restablecer a predeterminado?';

  @override
  String get alertSettingsResetMessage =>
      'Todas las categorías volverán a activarse. Puedes ajustarlas de nuevo más tarde.';

  @override
  String get alertSettingsResetButton => 'Restablecer a predeterminado';

  @override
  String get alertSettingsIntro =>
      'Elige qué categorías recibes en la app y por correo. Un guion (—) indica que el correo no está disponible.';

  @override
  String get alertSettingsHeaderInApp => 'APP';

  @override
  String get alertSettingsHeaderEmail => 'CORREO';

  @override
  String get actionChange => 'Cambiar';

  @override
  String get commonStaff => 'Personal';

  @override
  String get homeGreetingMorning => 'Buenos días';

  @override
  String get homeGreetingAfternoon => 'Buenas tardes';

  @override
  String get homeGreetingEvening => 'Buenas noches';

  @override
  String get homeFirstNameSuffix => '.';

  @override
  String get homePasswordBannerMessage =>
      'Tu contraseña se restableció recientemente. Te recomendamos cambiarla por una nueva.';

  @override
  String get homeTodayOverview => 'Resumen de hoy';

  @override
  String get homeStatChecklist => 'Lista';

  @override
  String get homeStatTasks => 'Tareas';

  @override
  String get homeStatDueToday => 'Vence hoy';

  @override
  String get homeQuickNotices => 'Avisos';

  @override
  String get homeQuickOjt => 'OJT';

  @override
  String get homeQuickDailyReports => 'Reportes';

  @override
  String get homeQuickInventory => 'Inventario';

  @override
  String get homeVoiceHint => '¡Comparte tu opinión!';

  @override
  String get homeVoiceSubmittedTitle => 'Enviado';

  @override
  String get homeVoiceSubmittedMessage => '¡Gracias por compartir!';

  @override
  String get homeVoiceFailedTitle => 'No se pudo enviar';

  @override
  String get homeVoiceFailedMessage =>
      'No se pudo enviar. Por favor intenta de nuevo.';

  @override
  String get homeVoiceCategoryIdea => '💡 Idea';

  @override
  String get homeVoiceCategoryFacility => '🔧 Instalación';

  @override
  String get homeVoiceCategorySafety => '⚠️ Seguridad';

  @override
  String get homeVoiceCategoryHr => '👤 RR. HH.';

  @override
  String get homeVoiceCategoryOther => '📋 Otro';

  @override
  String get homeImportantNotice => 'AVISO IMPORTANTE';

  @override
  String get homeViewDetails => 'Ver detalles';

  @override
  String get homeScheduleHeader => 'Horario de esta semana';

  @override
  String get homeViewAll => 'Ver todo →';

  @override
  String get homeNextShift => 'PRÓXIMO TURNO';

  @override
  String get homeTomorrow => 'Mañana';

  @override
  String get homeStatChanged => 'Cambiado';

  @override
  String homeRejectedRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solicitudes rechazadas',
      one: '1 solicitud rechazada',
    );
    return '$_temp0';
  }

  @override
  String get homeResubmit => 'Reenviar →';

  @override
  String get actionRemove => 'Quitar';

  @override
  String get actionUpload => 'Subir';

  @override
  String get actionLogoutConfirm => 'Cerrar sesión';

  @override
  String get commonComingSoonTitle => 'Próximamente';

  @override
  String get myPageHeader => 'Mi cuenta';

  @override
  String get myPinPrefix => 'PIN: ';

  @override
  String get myTakePhoto => 'Tomar foto';

  @override
  String get myChooseGallery => 'Elegir de la galería';

  @override
  String get myRemovePhoto => 'Quitar foto';

  @override
  String get myChangePhoto => 'Cambiar foto de perfil';

  @override
  String get myUploadDocument => 'Subir documento';

  @override
  String get myReplaceDocument => 'Reemplazar documento';

  @override
  String myUploadedAt(String date) {
    return 'Subido $date';
  }

  @override
  String get myDocumentsHeader => 'Documentos';

  @override
  String get myDocumentsSubtitle =>
      'Sube los documentos requeridos para la verificación laboral';

  @override
  String get myDocumentsUnderDev => 'Esta función está en desarrollo';

  @override
  String get myLogoutConfirmTitle => 'Cerrar sesión';

  @override
  String get myLogoutConfirmMessage => '¿Seguro que quieres cerrar sesión?';

  @override
  String get myDocFoodHandlerTitle => 'Tarjeta de manipulador de alimentos';

  @override
  String get myDocFoodHandlerSubtitle =>
      'Certificación de seguridad alimentaria requerida';

  @override
  String get myDocSsnTitle => 'SSN / Autorización de trabajo';

  @override
  String get myDocSsnSubtitle => 'Número de Seguro Social o permiso de trabajo';

  @override
  String get myDocIdTitle => 'Identificación oficial';

  @override
  String get myDocIdSubtitle => 'Licencia de conducir / ID estatal / Pasaporte';

  @override
  String get myDocI9Title => 'Formulario I-9';

  @override
  String get myDocI9Subtitle => 'Verificación de elegibilidad de empleo';

  @override
  String get myDocW4Title => 'Formulario W-4';

  @override
  String get myDocW4Subtitle => 'Certificado de retenciones del empleado';

  @override
  String get noticeDetailHeader => 'Aviso';

  @override
  String get noticeNotFound => 'Aviso no encontrado';

  @override
  String get noticeAcknowledgedTitle => 'Confirmado';

  @override
  String get noticeAcknowledgedMessage => 'Confirmado';

  @override
  String noticeCommentsCount(int count) {
    return 'Comentarios ($count)';
  }

  @override
  String get noticeNoComments => 'Sin comentarios';

  @override
  String get noticeFirstComment => 'Sé el primero en comentar';

  @override
  String get noticeCommentHint => 'Escribe un comentario...';

  @override
  String get noticeMarkAsRead => 'Marcar como leído';

  @override
  String get noticeAcknowledgedButton => 'Confirmado';

  @override
  String get fieldDescription => 'Descripción';

  @override
  String get taskDetailHeader => 'Detalle de tarea';

  @override
  String get taskNotFound => 'Tarea no encontrada';

  @override
  String get taskMarkComplete => 'Marcar como completada';

  @override
  String get taskCompletedTitle => 'Completada';

  @override
  String get taskCompletedMessage => 'Tarea marcada como completada';

  @override
  String taskCompletedByLine(String name, String time) {
    return 'Completada por $name · $time';
  }

  @override
  String get taskStartTimeLabel => 'Inicio';

  @override
  String get taskDueDateLabel => 'Vencimiento';

  @override
  String get taskAssignedToLabel => 'Asignada a';

  @override
  String get taskCreatedByLabel => 'Creada por';

  @override
  String get taskCreatedAtLabel => 'Creada el';

  @override
  String taskAssigneesCount(int count) {
    return 'Asignados ($count)';
  }

  @override
  String taskDoneAt(String time) {
    return 'Hecho $time';
  }

  @override
  String get drHeaderNew => 'Nuevo reporte';

  @override
  String get drHeaderDetail => 'Detalle del reporte';

  @override
  String get drNotFound => 'Reporte no encontrado';

  @override
  String get drSelectStorePrompt => 'Por favor selecciona una tienda';

  @override
  String get drTemplateLoadFailedTitle => 'No se pudo cargar la plantilla';

  @override
  String get drTemplateLoadFailedMessage => 'No se pudo cargar la plantilla';

  @override
  String get drCreateFailedTitle => 'No se pudo crear el reporte';

  @override
  String get drCreateFailedMessage => 'No se pudo crear el reporte';

  @override
  String get drDraftSaved => 'Borrador guardado';

  @override
  String get drSaveFailed => 'No se pudo guardar';

  @override
  String get drSubmittedTitle => 'Enviado';

  @override
  String get drSubmittedMessage => 'Reporte enviado';

  @override
  String get drSubmitFailedTitle => 'No se pudo enviar';

  @override
  String get drSubmitFailedMessage => 'No se pudo enviar';

  @override
  String get drDeleteTitle => 'Eliminar borrador';

  @override
  String get drDeleteMessage => '¿Seguro que quieres eliminar este borrador?';

  @override
  String get drDeletedTitle => 'Eliminado';

  @override
  String get drDeletedMessage => 'Borrador eliminado';

  @override
  String get drDeleteFailedTitle => 'No se pudo eliminar';

  @override
  String get drDeleteFailedMessage => 'No se pudo eliminar';

  @override
  String get drExistsTitle => 'El reporte ya existe';

  @override
  String get drExistsMessage =>
      'Ya existe un reporte para esta tienda/fecha/período.\n¿Quieres ver el reporte existente?';

  @override
  String get drExistsGo => 'Ir al reporte';

  @override
  String get drSaveDraftButton => 'Guardar borrador';

  @override
  String get drStoreLabel => 'Tienda';

  @override
  String get drSelectStoreHint => 'Selecciona tienda';

  @override
  String get drDateLabel => 'Fecha';

  @override
  String get drPeriodLabel => 'Período';

  @override
  String get drPeriodLunch => 'Almuerzo';

  @override
  String get drPeriodDinner => 'Cena';

  @override
  String get drStartWriting => 'Empezar';

  @override
  String drSubmittedAt(String time) {
    return 'Enviado $time';
  }

  @override
  String get drContentHeader => 'Contenido del reporte';

  @override
  String get drEnterContent => 'Ingresa el contenido...';

  @override
  String get drOptional => '  (Opcional)';

  @override
  String get drNoContent => '(Sin contenido)';

  @override
  String get drFieldRequired => 'Este campo es obligatorio';

  @override
  String get actionView => 'Ver';

  @override
  String get invChangeStore => 'Cambiar tienda';

  @override
  String get invInStock => 'En stock';

  @override
  String get invLowStock => 'Bajo';

  @override
  String get invOutOfStock => 'Agotado';

  @override
  String get invActionView => 'Ver inventario';

  @override
  String get invActionAudit => 'Auditoría';

  @override
  String get invActionStockIn => 'Entrada';

  @override
  String get invActionStockOut => 'Salida';

  @override
  String invItemsNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artículos requieren atención',
      one: '1 artículo requiere atención',
    );
    return '$_temp0';
  }

  @override
  String get actionAdjust => 'Ajustar';

  @override
  String get invSearchHint => 'Buscar productos...';

  @override
  String get invFilterAll => 'Todos';

  @override
  String get invFilterLowStock => 'Bajo stock';

  @override
  String get invFilterFrequent => 'Solo frecuentes';

  @override
  String get invEmpty => 'Sin productos en el inventario';

  @override
  String get invNoMatch => 'Sin coincidencias';

  @override
  String get invStockInRecorded => 'Entrada registrada';

  @override
  String get invStockOutRecorded => 'Salida registrada';

  @override
  String get invSaveFailed =>
      'No se pudo registrar. Por favor intenta de nuevo.';

  @override
  String get invAdjustedTitle => 'Ajustado';

  @override
  String get invAdjustedMessage => 'Cantidad ajustada';

  @override
  String get invAdjustFailed =>
      'No se pudo ajustar. Por favor intenta de nuevo.';

  @override
  String get invStatusLow => 'Bajo';

  @override
  String get invStatusOut => 'Agotado';

  @override
  String get invStatusOk => 'OK';

  @override
  String get invNeverAudited => 'Sin auditar';

  @override
  String get invFrequent => 'Frecuente';

  @override
  String invLastAudited(String label) {
    return 'Última: $label';
  }

  @override
  String get invCurrentStock => 'Stock actual';

  @override
  String get invStatusOutOfStock => 'Agotado';

  @override
  String get invStatusInStock => 'En stock';

  @override
  String get invSvOnlyMessage =>
      'Solo SV y superiores pueden hacer operaciones de stock.';

  @override
  String get invNegativeStockWarning => 'Resultará en stock negativo';

  @override
  String get invReasonOptional => 'Razón (opcional)';

  @override
  String get invAdjustTitle => 'Ajustar cantidad';

  @override
  String invAdjustHint(int qty) {
    return 'Nueva cantidad (actual: $qty u)';
  }

  @override
  String get invNewQuantityLabel => 'Nueva cantidad (u)';

  @override
  String get invStockInTitle => 'Entrada';

  @override
  String get invStockOutTitle => 'Salida';

  @override
  String get actionDone => 'Listo';

  @override
  String get actionExit => 'Salir';

  @override
  String get auditHeader => 'Auditoría';

  @override
  String get auditLoading => 'Cargando inventario...';

  @override
  String get auditEmpty => 'Sin artículos en el inventario';

  @override
  String get auditModifiedOnly => 'Solo modificados';

  @override
  String get auditSectionFrequent => 'Frecuente';

  @override
  String get auditSectionAll => 'Todos los artículos';

  @override
  String get auditNoModified => 'Sin artículos modificados';

  @override
  String get auditNoItems => 'Sin artículos en la auditoría';

  @override
  String get auditCompleteButton => 'Completar auditoría';

  @override
  String get auditCompleteTitle => 'Completar auditoría';

  @override
  String get auditCompleteMessage =>
      'Esto aplicará todos los ajustes de cantidad. ¿Estás seguro?';

  @override
  String get auditCompleteConfirm => 'Completar';

  @override
  String get auditCompletedTitle => 'Completada';

  @override
  String get auditCompletedMessage => 'Auditoría completada';

  @override
  String get auditFailedMessage => 'No se pudo enviar la auditoría';

  @override
  String get auditExitTitle => 'Salir de la auditoría';

  @override
  String get auditExitMessage => '¿Estás seguro? El progreso no se guardará.';

  @override
  String get auditAdjustmentsApplied => 'Ajustes aplicados';

  @override
  String get auditCompleteHeading => 'Auditoría completa';

  @override
  String get auditNeverAudited => 'Nunca';

  @override
  String auditSystemLastLine(String system, String last) {
    return 'Sistema: $system · Última: $last';
  }

  @override
  String get auditActualLabel => 'Real:';

  @override
  String get chatPhotoUploadFailed => 'Falló la subida de la foto';

  @override
  String get chatPhotoRequiredTitle => 'Foto requerida';

  @override
  String get chatPhotoRequiredMessage => 'Por favor adjunta una foto.';

  @override
  String get chatSubmitFailed =>
      'No se pudo enviar. Por favor intenta de nuevo.';

  @override
  String get chatSendFailed => 'Falló el envío';

  @override
  String get chatPhotoSendFailed => 'Falló el envío de la foto';

  @override
  String get chatAddPhoto => 'Agregar foto';

  @override
  String get chatTakePhoto => 'Tomar foto';

  @override
  String get chatChooseGallery => 'Elegir de la galería';

  @override
  String get chatSubmitting => 'Enviando...';

  @override
  String get chatUploadingPhoto => 'Subiendo foto...';

  @override
  String get chatStatusRejected => 'Rechazado — Reenvío requerido';

  @override
  String get chatStatusReReview => 'Pendiente de re-revisión';

  @override
  String get chatStatusApproved => 'Aprobado';

  @override
  String get chatStatusCompleted => 'Completado — Pendiente de revisión';

  @override
  String get chatStatusNotCompleted => 'No completado — Envía abajo';

  @override
  String chatPhotosLabel(int min) {
    return 'Fotos (requeridas, mín. $min)';
  }

  @override
  String get chatTextLabel => 'Texto (requerido)';

  @override
  String get chatTakePhotoBtn => 'Tomar foto';

  @override
  String get chatGalleryBtn => 'Galería';

  @override
  String chatPhotosCount(int current, int min) {
    return 'Fotos: $current/$min requeridas';
  }

  @override
  String get chatReasonForResubmission => 'Razón del reenvío...';

  @override
  String get chatTextOptional => 'Texto (opcional) — p. ej. tarea completada';

  @override
  String get chatResubmit => 'Reenviar';

  @override
  String get chatSubmit => 'Enviar';

  @override
  String get chatBadgeSubmitted => 'Enviado';

  @override
  String get chatBadgeResubmitted => 'Reenviado';

  @override
  String get chatBadgeRejected => 'Rechazado';

  @override
  String get chatBadgeApproved => 'Aprobado';

  @override
  String get chatBadgeReReview => 'Pendiente de re-revisión';

  @override
  String get chatBadgePending => 'Pendiente';

  @override
  String get chatTypeMessage => 'Escribe un mensaje...';

  @override
  String get chatLabelRejected => 'Rechazado';

  @override
  String get chatLabelApproved => 'Aprobado';

  @override
  String get chatLabelReReview => 'Re-revisión';

  @override
  String get chatLabelDone => 'Listo';

  @override
  String get chatLabelPending => 'Pendiente';

  @override
  String get stockItemsLabel => 'Artículos';

  @override
  String get stockTapToAddItems => 'Toca + para agregar artículos';

  @override
  String get stockReasonOptional => 'Razón (opcional)';

  @override
  String get stockSavedTitle => 'Guardado';

  @override
  String get stockInSavedMessage => 'Entrada registrada correctamente';

  @override
  String get stockOutSavedMessage => 'Salida registrada correctamente';

  @override
  String get stockSaveFailed =>
      'No se pudo guardar. Por favor intenta de nuevo.';

  @override
  String get stockSearchHint => 'Buscar inventario...';

  @override
  String get stockNoProductsFound => 'No se encontraron productos';

  @override
  String get stockAddedBadge => 'Agregado';

  @override
  String get stockWillBeNegative => 'Quedará en negativo';

  @override
  String get stockWillBeBelowMin => 'Quedará bajo el mínimo';

  @override
  String get checklistAllDoneTitle => 'Todo listo';

  @override
  String get checklistAllDoneMessage =>
      '¡Todos los ítems completados! Excelente trabajo.';

  @override
  String get checklistResubmittedTitle => 'Reenviado';

  @override
  String get checklistResubmittedMessage => 'Reenviado.';

  @override
  String get checklistResubmitFailed => 'No se pudo reenviar';

  @override
  String get checklistResubmitFailedMessage =>
      'No se pudo reenviar. Por favor intenta de nuevo.';

  @override
  String get checklistCompleteFailed => 'No se pudo completar';

  @override
  String get checklistCompleteFailedMessage =>
      'No se pudo completar el ítem. Por favor intenta de nuevo.';

  @override
  String get checklistUndoFailed => 'No se pudo deshacer';

  @override
  String get checklistUndoFailedMessage =>
      'No se pudo deshacer. Por favor intenta de nuevo.';

  @override
  String get checklistUndoCompleteTitle => 'Deshacer completado';

  @override
  String get checklistUndoCompleteMessage =>
      '¿Seguro que quieres deshacer este ítem?';

  @override
  String get checklistUndoAction => 'Deshacer';

  @override
  String get checklistCannotUncheckTitle => 'No se puede desmarcar';

  @override
  String get checklistCannotUncheckMessage =>
      'Los ítems revisados no se pueden desmarcar.';

  @override
  String get checklistSubmitReportTitle => 'Enviar reporte';

  @override
  String get checklistSubmitReportMessage =>
      '¿Enviar el reporte de la lista? Después del envío los cambios pueden estar restringidos.';

  @override
  String get checklistSubmitAction => 'Enviar';

  @override
  String get checklistSubmittedTitle => 'Enviado';

  @override
  String get checklistSubmittedMessage => 'Reporte enviado.';

  @override
  String get checklistSubmitFailed => 'No se pudo enviar el reporte';

  @override
  String get checklistSubmitFailedMessage =>
      'No se pudo enviar el reporte. Por favor intenta de nuevo.';

  @override
  String get checklistPhotoUploadFailedTitle => 'No se pudo subir';

  @override
  String get checklistPhotoUploadFailed => 'Falló la subida de la foto';

  @override
  String get checklistAddPhoto => 'Agregar foto';

  @override
  String get checklistTakePhoto => 'Tomar foto';

  @override
  String get checklistChooseGallery => 'Elegir de la galería';

  @override
  String get checklistTitle => 'Lista';

  @override
  String get checklistFailedToLoad => 'No se pudo cargar el horario';

  @override
  String get checklistNotFound => 'Horario no encontrado.';

  @override
  String get checklistUploading => 'Subiendo foto...';

  @override
  String get checklistEmptyPending => 'Sin ítems pendientes.';

  @override
  String get checklistEmptyCompleted => 'Sin ítems completados.';

  @override
  String get checklistEmptyRejected => 'Sin ítems rechazados.';

  @override
  String get checklistEmptyAll => 'Sin ítems en la lista.';

  @override
  String get checklistComplete => 'Completo';

  @override
  String get checklistInProgress => 'En progreso';

  @override
  String checklistItemsCount(int completed, int total) {
    return '$completed/$total ítems';
  }

  @override
  String get checklistTabAll => 'Todos';

  @override
  String get checklistTabTodo => 'Pendientes';

  @override
  String get checklistTabDone => 'Listos';

  @override
  String get checklistTabRejected => 'Rechazados';

  @override
  String get checklistResubmitRequired => 'Reenvío requerido';

  @override
  String get checklistApproved => 'Aprobado';

  @override
  String get checklistRejected => 'Rechazado';

  @override
  String get checklistReReviewPending => 'Re-revisión pendiente';

  @override
  String get checklistTapToView => 'Toca para ver la descripción';

  @override
  String get checklistAllReviewed => 'Todo revisado';

  @override
  String get checklistReportSubmitted => 'Reporte enviado';

  @override
  String get checklistSubmitReport => 'Enviar reporte';

  @override
  String get checklistBadgeDaily => 'Diario';

  @override
  String get checklistBadgePhoto => 'Foto';

  @override
  String get checklistBadgeText => 'Texto';

  @override
  String get checklistMaxPhotosTitle => 'Límite alcanzado';

  @override
  String checklistMaxPhotosMessage(int max) {
    return 'Máximo $max fotos permitidas';
  }

  @override
  String checklistMorePhotosAllowed(int count, int max) {
    return 'Solo se permiten $count foto(s) más (máx. $max)';
  }

  @override
  String get checklistResubmitItem => 'Reenviar ítem';

  @override
  String get checklistCompleteItem => 'Completar ítem';

  @override
  String get checklistPhoto => 'Foto';

  @override
  String checklistPhotoCount(int current, int min, int max) {
    return '$current/$min mín, $max máx';
  }

  @override
  String get checklistAddShort => 'Agregar';

  @override
  String get checklistTapToAddPhoto => 'Toca para agregar foto';

  @override
  String get checklistNote => 'Nota';

  @override
  String get checklistRequired => 'requerido';

  @override
  String get checklistOptional => 'opcional';

  @override
  String get checklistEnterNote => 'Ingresa una nota...';

  @override
  String get checklistOptionalNote => 'Nota opcional...';

  @override
  String get checklistSubmitting => 'Enviando...';

  @override
  String get checklistResubmit => 'Reenviar';

  @override
  String get checklistCompleteAction => 'Completar';

  @override
  String get checklistNoAttachments => 'Sin archivos adjuntos';

  @override
  String get workChecklistTab => 'Lista';

  @override
  String get workTaskTab => 'Tarea';

  @override
  String get workTabToday => 'Hoy';

  @override
  String get workTabPast => 'Anteriores';

  @override
  String get workEmptyChecklistsToday => 'Sin listas asignadas hoy';

  @override
  String get workEmptyPastChecklists => 'Sin listas anteriores';

  @override
  String get workEmptyTasks => 'Sin tareas asignadas';

  @override
  String get workEmptyChecklistItems => 'Sin ítems en la lista';

  @override
  String get workNoMatchingRecords => 'Sin registros coincidentes';

  @override
  String get workNoTasksForDate => 'Sin tareas para la fecha seleccionada';

  @override
  String workNoResultsFor(String query) {
    return 'Sin resultados para \"$query\"';
  }

  @override
  String workUnresolvedCount(int count) {
    return 'Sin resolver $count';
  }

  @override
  String workPreviousUnresolvedCount(int count) {
    return 'Sin resolver anteriormente: $count';
  }

  @override
  String get workUpcoming => 'Próximos';

  @override
  String get workSearchTasksHint => 'Buscar tareas o tiendas';

  @override
  String get workDueLabel => 'Vence';

  @override
  String get workSortBy => 'Ordenar por';

  @override
  String get workSortDueDate => 'Fecha de vencimiento';

  @override
  String get workSortPriority => 'Prioridad';

  @override
  String get workSortRecent => 'Recientes';

  @override
  String get workSortName => 'Nombre';

  @override
  String workTasksDoneCount(int count) {
    return '$count listas';
  }

  @override
  String get workTasksDoneLabel => 'listas';

  @override
  String get workTasksLeftLabel => 'restantes';

  @override
  String get workFilterAll => 'Todas';

  @override
  String get workFilterDate => 'Fecha';

  @override
  String get workCardStatusNotStarted => 'Sin iniciar';

  @override
  String get workCardStatusInProgress => 'En progreso';

  @override
  String get workCardStatusPendingReview => 'Pendiente de revisión';

  @override
  String get workCardStatusDone => 'Listo';

  @override
  String get workStatusApproved => 'Aprobado';

  @override
  String get workStatusRejected => 'Rechazado';

  @override
  String get workStatusSubmitted => 'Enviado';

  @override
  String get workStatusResubmitted => 'Reenviado';

  @override
  String get workStatusPendingReview => 'Pendiente de re-revisión';

  @override
  String get workStatusRevisionRequested => 'Revisión solicitada';

  @override
  String get workStatusPending => 'Pendiente';

  @override
  String get workStatusNotSubmitted => 'No enviado';

  @override
  String get workStatusActionRequired => 'Acción requerida';

  @override
  String workCompletedAt(String time) {
    return 'Completado $time';
  }

  @override
  String get workSelectWorkDate => 'Selecciona la fecha de trabajo';

  @override
  String get workLegendWorkDay => 'Día laboral';

  @override
  String get workLegendNoWork => 'Sin trabajo';

  @override
  String get workAddPhoto => 'Agregar foto';

  @override
  String get workTakePhoto => 'Tomar foto';

  @override
  String get workChooseFromGallery => 'Elegir de la galería';

  @override
  String get workAddAPhoto => 'Agregar una foto';

  @override
  String get workCameraButton => 'Cámara';

  @override
  String get workGalleryButton => 'Galería';

  @override
  String get workPhotoSectionTitle => 'Foto';

  @override
  String get workPhotoSectionSubtitle =>
      'Por favor sube una foto de verificación.';

  @override
  String get workNoteSectionTitle => 'Nota';

  @override
  String get workNoteSectionSubtitle =>
      'Por favor describe el trabajo realizado.';

  @override
  String get workEnterNoteHint => 'Ingresa tu nota...';

  @override
  String get workVerificationHeader => 'Verificación';

  @override
  String get workAddNoteTitle => 'Agregar nota';

  @override
  String get workVerificationNoteHint => 'Ingresa la nota de verificación...';

  @override
  String get workResponseDialogTitle => 'Respuesta';

  @override
  String get workResponseDialogHint => 'Ingresa tu respuesta al rechazo...';

  @override
  String get workPhotoUploadFailedTitle => 'No se pudo subir';

  @override
  String get workPhotoUploadFailedMessage => 'Falló la subida de la foto';

  @override
  String get workAllCompleteCelebration =>
      '¡Todos los ítems completados! ¡Gran trabajo!';

  @override
  String get workDoneButton => 'LISTO';

  @override
  String get workAwaitingResubmission => 'Esperando reenvío';

  @override
  String get workTimelineMessage => 'Mensaje';

  @override
  String get workTimelinePhoto => 'Foto';

  @override
  String get workFailedToLoadImage => 'No se pudo cargar la imagen';

  @override
  String get workPriorityUrgent => 'Urgente';

  @override
  String get workPriorityHigh => 'Alta';

  @override
  String get workPriorityNormal => 'Normal';

  @override
  String get workPriorityLow => 'Baja';

  @override
  String get invAddTitle => 'Agregar producto';

  @override
  String get invAddImageSection => 'Imagen del producto';

  @override
  String get invAddTakePhoto => 'Tomar foto';

  @override
  String get invAddChooseGallery => 'Elegir de la galería';

  @override
  String get invAddRemovePhoto => 'Quitar foto';

  @override
  String get invAddUploadFailedTitle => 'No se pudo subir';

  @override
  String get invAddUploadFailedMessage => 'Falló la subida de la imagen';

  @override
  String get invAddSearchHint => 'Buscar productos por nombre o código...';

  @override
  String get invAddCreateNewProduct => 'Crear nuevo producto';

  @override
  String get invAddAlreadyAdded => 'Ya agregado';

  @override
  String get invAddMinQtyLabel => 'Cantidad mínima';

  @override
  String get invAddInitialQtyLabel => 'Cantidad inicial';

  @override
  String get invAddFrequentAudit => 'Auditoría frecuente';

  @override
  String get invAddAddToStore => 'Agregar a la tienda';

  @override
  String get invAddTapToAddPhoto => 'Toca para agregar foto';

  @override
  String get invAddCameraOrGallery => 'Cámara o galería';

  @override
  String get invAddNameLabel => 'Nombre del producto *';

  @override
  String get invAddNameHint => 'p. ej. Leche entera (1L)';

  @override
  String get invAddNameRequired => 'El nombre del producto es obligatorio';

  @override
  String get invAddCodeLabel => 'Código del producto';

  @override
  String get invAddCodeHint => 'Se genera automáticamente si está vacío';

  @override
  String get invAddCategoryLabel => 'Categoría *';

  @override
  String get invAddCategoryRequired => 'La categoría es obligatoria';

  @override
  String get invAddSubcategoryLabel => 'Subcategoría';

  @override
  String get invAddSubUnitLabel => 'Subunidad';

  @override
  String get invAddSubUnitHelp => 'Déjalo vacío si se cuenta solo en u';

  @override
  String get invAddSubUnitRatioLabel => 'Proporción de subunidad *';

  @override
  String invAddSubUnitRatioHint(String unit) {
    return '1 $unit = ? u (p. ej. 24)';
  }

  @override
  String get invAddRatioInvalid => 'La proporción debe ser mayor a 0';

  @override
  String get invAddDescriptionLabel => 'Descripción';

  @override
  String get invAddDescriptionHint => 'Descripción breve del producto';

  @override
  String get invAddStoreSettingsSection => 'Ajustes de tienda';

  @override
  String get invAddCreateAndAdd => 'Crear y agregar a la tienda';

  @override
  String get invAddCategoryHint => 'Selecciona una categoría';

  @override
  String get invAddAddNew => '+ Agregar nueva';

  @override
  String get invAddNewCategoryHint => 'p. ej. Frescos, Snacks...';

  @override
  String get invAddAlreadyExistsTitle => 'Ya existe';

  @override
  String invAddAlreadyExistsMessage(String name) {
    return '\"$name\" ya existe';
  }

  @override
  String get invAddCreateCategoryFailedTitle => 'No se pudo crear la categoría';

  @override
  String get invAddCreateCategoryFailedMessage =>
      'No se pudo crear la categoría';

  @override
  String get invAddSelectCategoryFirst => 'Selecciona primero una categoría';

  @override
  String get invAddNone => 'Ninguna';

  @override
  String get invAddNewSubcategoryHint => 'Nombre de la nueva subcategoría...';

  @override
  String get invAddCreateSubcategoryFailedTitle =>
      'No se pudo crear la subcategoría';

  @override
  String get invAddCreateSubcategoryFailedMessage =>
      'No se pudo crear la subcategoría';

  @override
  String get invAddSubUnitNone => 'Ninguna (solo u)';

  @override
  String get invAddNewSubUnitHint => 'p. ej. caja, bandeja...';

  @override
  String get invAddCreateSubUnitFailedTitle => 'No se pudo crear la subunidad';

  @override
  String get invAddCreateSubUnitFailedMessage =>
      'No se pudo crear la subunidad';

  @override
  String get invAddAddedTitle => 'Agregado';

  @override
  String invAddAddedMessage(String name) {
    return '$name agregado a la tienda';
  }

  @override
  String get invAddAddFailedTitle => 'No se pudo agregar el producto';

  @override
  String get invAddAddFailedMessage => 'No se pudo agregar el producto';

  @override
  String get invAddCreatedTitle => 'Creado';

  @override
  String invAddCreatedMessage(String name) {
    return '$name creado y agregado a la tienda';
  }

  @override
  String get invAddCreateProductFailedTitle => 'No se pudo crear el producto';

  @override
  String get invAddCreateProductFailedMessage => 'No se pudo crear el producto';
}
