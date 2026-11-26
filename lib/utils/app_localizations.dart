import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class AppLocalizations {
  final BuildContext context;

  AppLocalizations(this.context);

  LanguageProvider get _languageProvider =>
      // Use listen: false to avoid assertion errors when accessed in certain lifecycle methods
      Provider.of<LanguageProvider>(context, listen: false);

  String get languageCode => _languageProvider.languageCode;

  // Common translations
  String get forgotPassword {
    switch (languageCode) {
      case 'ar':
        return 'نسيت كلمة المرور؟';
      case 'fr':
        return 'Mot de passe oublié?';
      case 'es':
        return '¿Olvidaste tu contraseña?';
      case 'de':
        return 'Passwort vergessen?';
      case 'it':
        return 'Password dimenticata?';
      case 'pt':
        return 'Esqueceu a senha?';
      case 'ru':
        return 'Забыли пароль?';
      case 'zh':
        return '忘记密码？';
      case 'ja':
        return 'パスワードを忘れた？';
      case 'hi':
        return 'पासवर्ड भूल गए?';
      case 'tr':
        return 'Şifrenizi mi unuttunuz?';
      default:
        return 'Forgot Password?';
    }
  }

  String get signIn {
    switch (languageCode) {
      case 'ar':
        return 'تسجيل الدخول';
      case 'fr':
        return 'Se connecter';
      case 'es':
        return 'Iniciar sesión';
      case 'de':
        return 'Anmelden';
      case 'it':
        return 'Accedi';
      case 'pt':
        return 'Entrar';
      case 'ru':
        return 'Войти';
      case 'zh':
        return '登录';
      case 'ja':
        return 'ログイン';
      case 'hi':
        return 'साइन इन करें';
      case 'tr':
        return 'Giriş Yap';
      default:
        return 'Sign In';
    }
  }

  String get email {
    switch (languageCode) {
      case 'ar':
        return 'البريد الإلكتروني';
      case 'fr':
        return 'E-mail';
      case 'es':
        return 'Correo electrónico';
      case 'de':
        return 'E-Mail';
      case 'it':
        return 'E-mail';
      case 'pt':
        return 'E-mail';
      case 'ru':
        return 'Электронная почта';
      case 'zh':
        return '电子邮件';
      case 'ja':
        return 'メール';
      case 'hi':
        return 'ईमेल';
      case 'tr':
        return 'E-posta';
      default:
        return 'Email';
    }
  }

  String get password {
    switch (languageCode) {
      case 'ar':
        return 'كلمة المرور';
      case 'fr':
        return 'Mot de passe';
      case 'es':
        return 'Contraseña';
      case 'de':
        return 'Passwort';
      case 'it':
        return 'Password';
      case 'pt':
        return 'Senha';
      case 'ru':
        return 'Пароль';
      case 'zh':
        return '密码';
      case 'ja':
        return 'パスワード';
      case 'hi':
        return 'पासवर्ड';
      case 'tr':
        return 'Şifre';
      default:
        return 'Password';
    }
  }

  String get enterEmail {
    switch (languageCode) {
      case 'ar':
        return 'الرجاء إدخال بريدك الإلكتروني';
      case 'fr':
        return 'Veuillez entrer votre e-mail';
      case 'es':
        return 'Por favor ingrese su correo electrónico';
      case 'de':
        return 'Bitte geben Sie Ihre E-Mail-Adresse ein';
      case 'it':
        return 'Inserisci la tua email';
      case 'pt':
        return 'Por favor, insira seu e-mail';
      case 'ru':
        return 'Пожалуйста, введите ваш email';
      case 'zh':
        return '请输入您的电子邮件';
      case 'ja':
        return 'メールアドレスを入力してください';
      case 'hi':
        return 'कृपया अपना ईमेल दर्ज करें';
      case 'tr':
        return 'Lütfen e-postanızı girin';
      default:
        return 'Please enter your email';
    }
  }

  String get enterPassword {
    switch (languageCode) {
      case 'ar':
        return 'الرجاء إدخال كلمة المرور';
      case 'fr':
        return 'Veuillez entrer votre mot de passe';
      case 'es':
        return 'Por favor ingrese su contraseña';
      case 'de':
        return 'Bitte geben Sie Ihr Passwort ein';
      case 'it':
        return 'Inserisci la tua password';
      case 'pt':
        return 'Por favor, insira sua senha';
      case 'ru':
        return 'Пожалуйста, введите ваш пароль';
      case 'zh':
        return '请输入您的密码';
      case 'ja':
        return 'パスワードを入力してください';
      case 'hi':
        return 'कृपया अपना पासवर्ड दर्ज करें';
      case 'tr':
        return 'Lütfen şifrenizi girin';
      default:
        return 'Please enter your password';
    }
  }

  String get passwordMinLength {
    switch (languageCode) {
      case 'ar':
        return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';
      case 'fr':
        return 'Le mot de passe doit contenir au moins 6 caractères';
      case 'es':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'de':
        return 'Das Passwort muss mindestens 6 Zeichen lang sein';
      case 'it':
        return 'La password deve contenere almeno 6 caratteri';
      case 'pt':
        return 'A senha deve ter pelo menos 6 caracteres';
      case 'ru':
        return 'Пароль должен содержать не менее 6 символов';
      case 'zh':
        return '密码必须至少6个字符';
      case 'ja':
        return 'パスワードは6文字以上である必要があります';
      case 'hi':
        return 'पासवर्ड कम से कम 6 वर्णों का होना चाहिए';
      case 'tr':
        return 'Şifre en az 6 karakter olmalıdır';
      default:
        return 'Password must be at least 6 characters';
    }
  }

  // Navigation & Common UI
  String get getStarted {
    switch (languageCode) {
      case 'ar':
        return 'ابدأ الآن';
      case 'fr':
        return 'Commencer';
      case 'es':
        return 'Comenzar';
      case 'de':
        return 'Loslegen';
      case 'it':
        return 'Inizia';
      case 'pt':
        return 'Começar';
      case 'ru':
        return 'Начать';
      case 'zh':
        return '开始';
      case 'ja':
        return '始める';
      case 'hi':
        return 'शुरू करें';
      case 'tr':
        return 'Başla';
      default:
        return 'Get Started';
    }
  }

  String get welcomeBack {
    switch (languageCode) {
      case 'ar':
        return 'مرحباً بعودتك! 👋';
      case 'fr':
        return 'Bon retour! 👋';
      case 'es':
        return '¡Bienvenido de nuevo! 👋';
      case 'de':
        return 'Willkommen zurück! 👋';
      case 'it':
        return 'Bentornato! 👋';
      case 'pt':
        return 'Bem-vindo de volta! 👋';
      case 'ru':
        return 'С возвращением! 👋';
      case 'zh':
        return '欢迎回来！👋';
      case 'ja':
        return 'おかえりなさい！👋';
      case 'hi':
        return 'वापसी पर स्वागत है! 👋';
      case 'tr':
        return 'Tekrar hoş geldiniz! 👋';
      default:
        return 'Welcome Back! 👋';
    }
  }

  String get signUp {
    switch (languageCode) {
      case 'ar':
        return 'إنشاء حساب';
      case 'fr':
        return 'S\'inscrire';
      case 'es':
        return 'Registrarse';
      case 'de':
        return 'Registrieren';
      case 'it':
        return 'Registrati';
      case 'pt':
        return 'Cadastrar';
      case 'ru':
        return 'Регистрация';
      case 'zh':
        return '注册';
      case 'ja':
        return '登録';
      case 'hi':
        return 'साइन अप करें';
      case 'tr':
        return 'Kayıt Ol';
      default:
        return 'Sign Up';
    }
  }

  String get home {
    switch (languageCode) {
      case 'ar':
        return 'الرئيسية';
      case 'fr':
        return 'Accueil';
      case 'es':
        return 'Inicio';
      case 'de':
        return 'Startseite';
      case 'it':
        return 'Home';
      case 'pt':
        return 'Início';
      case 'ru':
        return 'Главная';
      case 'zh':
        return '首页';
      case 'ja':
        return 'ホーム';
      case 'hi':
        return 'होम';
      case 'tr':
        return 'Ana Sayfa';
      default:
        return 'Home';
    }
  }

  String get browse {
    switch (languageCode) {
      case 'ar':
        return 'تصفح';
      case 'fr':
        return 'Parcourir';
      case 'es':
        return 'Explorar';
      case 'de':
        return 'Durchsuchen';
      case 'it':
        return 'Sfoglia';
      case 'pt':
        return 'Navegar';
      case 'ru':
        return 'Обзор';
      case 'zh':
        return '浏览';
      case 'ja':
        return '閲覧';
      case 'hi':
        return 'ब्राउज़ करें';
      case 'tr':
        return 'Gözat';
      default:
        return 'Browse';
    }
  }

  String get messages {
    switch (languageCode) {
      case 'ar':
        return 'الرسائل';
      case 'fr':
        return 'Messages';
      case 'es':
        return 'Mensajes';
      case 'de':
        return 'Nachrichten';
      case 'it':
        return 'Messaggi';
      case 'pt':
        return 'Mensagens';
      case 'ru':
        return 'Сообщения';
      case 'zh':
        return '消息';
      case 'ja':
        return 'メッセージ';
      case 'hi':
        return 'संदेश';
      case 'tr':
        return 'Mesajlar';
      default:
        return 'Messages';
    }
  }

  String get profile {
    switch (languageCode) {
      case 'ar':
        return 'الملف الشخصي';
      case 'fr':
        return 'Profil';
      case 'es':
        return 'Perfil';
      case 'de':
        return 'Profil';
      case 'it':
        return 'Profilo';
      case 'pt':
        return 'Perfil';
      case 'ru':
        return 'Профиль';
      case 'zh':
        return '个人资料';
      case 'ja':
        return 'プロフィール';
      case 'hi':
        return 'प्रोफ़ाइल';
      case 'tr':
        return 'Profil';
      default:
        return 'Profile';
    }
  }

  String get notifications {
    switch (languageCode) {
      case 'ar':
        return 'الإشعارات';
      case 'fr':
        return 'Notifications';
      case 'es':
        return 'Notificaciones';
      case 'de':
        return 'Benachrichtigungen';
      case 'it':
        return 'Notifiche';
      case 'pt':
        return 'Notificações';
      case 'ru':
        return 'Уведомления';
      case 'zh':
        return '通知';
      case 'ja':
        return '通知';
      case 'hi':
        return 'सूचनाएं';
      case 'tr':
        return 'Bildirimler';
      default:
        return 'Notifications';
    }
  }

  String get search {
    switch (languageCode) {
      case 'ar':
        return 'بحث';
      case 'fr':
        return 'Rechercher';
      case 'es':
        return 'Buscar';
      case 'de':
        return 'Suchen';
      case 'it':
        return 'Cerca';
      case 'pt':
        return 'Pesquisar';
      case 'ru':
        return 'Поиск';
      case 'zh':
        return '搜索';
      case 'ja':
        return '検索';
      case 'hi':
        return 'खोजें';
      case 'tr':
        return 'Ara';
      default:
        return 'Search';
    }
  }

  String get typeMessage {
    switch (languageCode) {
      case 'ar':
        return 'اكتب رسالة...';
      case 'fr':
        return 'Tapez un message...';
      case 'es':
        return 'Escribe un mensaje...';
      case 'de':
        return 'Nachricht eingeben...';
      case 'it':
        return 'Scrivi un messaggio...';
      case 'pt':
        return 'Digite uma mensagem...';
      case 'ru':
        return 'Введите сообщение...';
      case 'zh':
        return '输入消息...';
      case 'ja':
        return 'メッセージを入力...';
      case 'hi':
        return 'संदेश टाइप करें...';
      case 'tr':
        return 'Mesaj yazın...';
      default:
        return 'Type a message...';
    }
  }

  String get searchConversations {
    switch (languageCode) {
      case 'ar':
        return 'بحث في المحادثات...';
      case 'fr':
        return 'Rechercher dans les conversations...';
      case 'es':
        return 'Buscar en conversaciones...';
      case 'de':
        return 'In Unterhaltungen suchen...';
      case 'it':
        return 'Cerca nelle conversazioni...';
      case 'pt':
        return 'Pesquisar conversas...';
      case 'ru':
        return 'Поиск в беседах...';
      case 'zh':
        return '搜索对话...';
      case 'ja':
        return '会話を検索...';
      case 'hi':
        return 'बातचीत खोजें...';
      case 'tr':
        return 'Konuşmalarda ara...';
      default:
        return 'Search conversations...';
    }
  }

  String get noMessages {
    switch (languageCode) {
      case 'ar':
        return 'لا توجد رسائل بعد';
      case 'fr':
        return 'Aucun message pour le moment';
      case 'es':
        return 'Aún no hay mensajes';
      case 'de':
        return 'Noch keine Nachrichten';
      case 'it':
        return 'Nessun messaggio ancora';
      case 'pt':
        return 'Ainda não há mensagens';
      case 'ru':
        return 'Пока нет сообщений';
      case 'zh':
        return '还没有消息';
      case 'ja':
        return 'メッセージはまだありません';
      case 'hi':
        return 'अभी तक कोई संदेश नहीं';
      case 'tr':
        return 'Henüz mesaj yok';
      default:
        return 'No messages yet';
    }
  }

  String get startConversation {
    switch (languageCode) {
      case 'ar':
        return 'ابدأ المحادثة!';
      case 'fr':
        return 'Commencer la conversation!';
      case 'es':
        return '¡Inicia la conversación!';
      case 'de':
        return 'Unterhaltung beginnen!';
      case 'it':
        return 'Inizia la conversazione!';
      case 'pt':
        return 'Inicie a conversa!';
      case 'ru':
        return 'Начать разговор!';
      case 'zh':
        return '开始对话！';
      case 'ja':
        return '会話を始めましょう！';
      case 'hi':
        return 'बातचीत शुरू करें!';
      case 'tr':
        return 'Konuşmayı başlatın!';
      default:
        return 'Start the conversation!';
    }
  }

  String get explore {
    switch (languageCode) {
      case 'ar':
        return 'استكشف';
      case 'fr':
        return 'Explorer';
      case 'es':
        return 'Explorar';
      case 'de':
        return 'Erkunden';
      case 'it':
        return 'Esplora';
      case 'pt':
        return 'Explorar';
      case 'ru':
        return 'Исследовать';
      case 'zh':
        return '探索';
      case 'ja':
        return '探索';
      case 'hi':
        return 'अन्वेषण करें';
      case 'tr':
        return 'Keşfet';
      default:
        return 'Explore';
    }
  }

  String get name {
    switch (languageCode) {
      case 'ar':
        return 'الاسم الكامل';
      case 'fr':
        return 'Nom complet';
      case 'es':
        return 'Nombre completo';
      case 'de':
        return 'Vollständiger Name';
      case 'it':
        return 'Nome completo';
      case 'pt':
        return 'Nome completo';
      case 'ru':
        return 'Полное имя';
      case 'zh':
        return '全名';
      case 'ja':
        return 'フルネーム';
      case 'hi':
        return 'पूरा नाम';
      case 'tr':
        return 'Ad Soyad';
      default:
        return 'Full Name';
    }
  }

  String get createAccount {
    switch (languageCode) {
      case 'ar':
        return 'إنشاء حسابك';
      case 'fr':
        return 'Créer votre compte';
      case 'es':
        return 'Crea tu cuenta';
      case 'de':
        return 'Konto erstellen';
      case 'it':
        return 'Crea il tuo account';
      case 'pt':
        return 'Criar sua conta';
      case 'ru':
        return 'Создать аккаунт';
      case 'zh':
        return '创建您的账户';
      case 'ja':
        return 'アカウントを作成';
      case 'hi':
        return 'अपना खाता बनाएं';
      case 'tr':
        return 'Hesabınızı oluşturun';
      default:
        return 'Create Your Account';
    }
  }

  String get confirmPassword {
    switch (languageCode) {
      case 'ar':
        return 'تأكيد كلمة المرور';
      case 'fr':
        return 'Confirmer le mot de passe';
      case 'es':
        return 'Confirmar contraseña';
      case 'de':
        return 'Passwort bestätigen';
      case 'it':
        return 'Conferma password';
      case 'pt':
        return 'Confirmar senha';
      case 'ru':
        return 'Подтвердите пароль';
      case 'zh':
        return '确认密码';
      case 'ja':
        return 'パスワードを確認';
      case 'hi':
        return 'पासवर्ड की पुष्टि करें';
      case 'tr':
        return 'Şifreyi onayla';
      default:
        return 'Confirm Password';
    }
  }

  String get passwordsDoNotMatch {
    switch (languageCode) {
      case 'ar':
        return 'كلمات المرور غير متطابقة';
      case 'fr':
        return 'Les mots de passe ne correspondent pas';
      case 'es':
        return 'Las contraseñas no coinciden';
      case 'de':
        return 'Passwörter stimmen nicht überein';
      case 'it':
        return 'Le password non corrispondono';
      case 'pt':
        return 'As senhas não coincidem';
      case 'ru':
        return 'Пароли не совпадают';
      case 'zh':
        return '密码不匹配';
      case 'ja':
        return 'パスワードが一致しません';
      case 'hi':
        return 'पासवर्ड मेल नहीं खाते';
      case 'tr':
        return 'Şifreler eşleşmiyor';
      default:
        return 'Passwords do not match';
    }
  }

  // Browse Screen
  String get browseUsers {
    switch (languageCode) {
      case 'ar':
        return 'تصفح المستخدمين';
      case 'fr':
        return 'Parcourir les utilisateurs';
      case 'es':
        return 'Explorar usuarios';
      case 'de':
        return 'Benutzer durchsuchen';
      case 'it':
        return 'Sfoglia utenti';
      case 'pt':
        return 'Navegar usuários';
      case 'ru':
        return 'Просмотр пользователей';
      case 'zh':
        return '浏览用户';
      case 'ja':
        return 'ユーザーを閲覧';
      case 'hi':
        return 'उपयोगकर्ताओं को ब्राउज़ करें';
      case 'tr':
        return 'Kullanıcıları gözat';
      default:
        return 'Browse Users';
    }
  }

  String get findPerfectMatch {
    switch (languageCode) {
      case 'ar':
        return 'ابحث عن تطابق المهارات المثالي';
      case 'fr':
        return 'Trouvez votre correspondance parfaite';
      case 'es':
        return 'Encuentra tu coincidencia perfecta';
      case 'de':
        return 'Finden Sie Ihre perfekte Übereinstimmung';
      case 'it':
        return 'Trova la tua corrispondenza perfetta';
      case 'pt':
        return 'Encontre sua correspondência perfeita';
      case 'ru':
        return 'Найдите идеальное совпадение';
      case 'zh':
        return '找到完美匹配';
      case 'ja':
        return '完璧なマッチを見つける';
      case 'hi':
        return 'अपना सही मैच खोजें';
      case 'tr':
        return 'Mükemmel eşleşmeyi bulun';
      default:
        return 'Find your perfect skill match';
    }
  }

  String get searchByNameSkillFaculty {
    switch (languageCode) {
      case 'ar':
        return 'ابحث بالاسم أو المهارة أو الكلية...';
      case 'fr':
        return 'Rechercher par nom, compétence ou faculté...';
      case 'es':
        return 'Buscar por nombre, habilidad o facultad...';
      case 'de':
        return 'Suche nach Name, Fähigkeit oder Fakultät...';
      case 'it':
        return 'Cerca per nome, abilità o facoltà...';
      case 'pt':
        return 'Pesquisar por nome, habilidade ou faculdade...';
      case 'ru':
        return 'Поиск по имени, навыку или факультету...';
      case 'zh':
        return '按姓名、技能或学院搜索...';
      case 'ja':
        return '名前、スキル、または学部で検索...';
      case 'hi':
        return 'नाम, कौशल या संकाय से खोजें...';
      case 'tr':
        return 'İsim, beceri veya fakülteye göre ara...';
      default:
        return 'Search by name, skill, or faculty...';
    }
  }

  String get quickFilters {
    switch (languageCode) {
      case 'ar':
        return 'مرشحات سريعة';
      case 'fr':
        return 'Filtres rapides';
      case 'es':
        return 'Filtros rápidos';
      case 'de':
        return 'Schnellfilter';
      case 'it':
        return 'Filtri rapidi';
      case 'pt':
        return 'Filtros rápidos';
      case 'ru':
        return 'Быстрые фильтры';
      case 'zh':
        return '快速筛选';
      case 'ja':
        return 'クイックフィルター';
      case 'hi':
        return 'त्वरित फ़िल्टर';
      case 'tr':
        return 'Hızlı filtreler';
      default:
        return 'Quick Filters';
    }
  }

  String get advancedFilters {
    switch (languageCode) {
      case 'ar':
        return 'مرشحات متقدمة';
      case 'fr':
        return 'Filtres avancés';
      case 'es':
        return 'Filtros avanzados';
      case 'de':
        return 'Erweiterte Filter';
      case 'it':
        return 'Filtri avanzati';
      case 'pt':
        return 'Filtros avançados';
      case 'ru':
        return 'Расширенные фильтры';
      case 'zh':
        return '高级筛选';
      case 'ja':
        return '高度なフィルター';
      case 'hi':
        return 'उन्नत फ़िल्टर';
      case 'tr':
        return 'Gelişmiş filtreler';
      default:
        return 'Advanced Filters';
    }
  }

  String get clearFilters {
    switch (languageCode) {
      case 'ar':
        return 'مسح المرشحات';
      case 'fr':
        return 'Effacer les filtres';
      case 'es':
        return 'Limpiar filtros';
      case 'de':
        return 'Filter löschen';
      case 'it':
        return 'Cancella filtri';
      case 'pt':
        return 'Limpar filtros';
      case 'ru':
        return 'Очистить фильтры';
      case 'zh':
        return '清除筛选';
      case 'ja':
        return 'フィルターをクリア';
      case 'hi':
        return 'फ़िल्टर साफ़ करें';
      case 'tr':
        return 'Filtreleri temizle';
      default:
        return 'Clear Filters';
    }
  }

  // Favorites Screen
  String get favorites {
    switch (languageCode) {
      case 'ar':
        return 'المفضلة';
      case 'fr':
        return 'Favoris';
      case 'es':
        return 'Favoritos';
      case 'de':
        return 'Favoriten';
      case 'it':
        return 'Preferiti';
      case 'pt':
        return 'Favoritos';
      case 'ru':
        return 'Избранное';
      case 'zh':
        return '收藏';
      case 'ja':
        return 'お気に入り';
      case 'hi':
        return 'पसंदीदा';
      case 'tr':
        return 'Favoriler';
      default:
        return 'Favorites';
    }
  }

  String get noFavoritesYet {
    switch (languageCode) {
      case 'ar':
        return 'لا توجد مفضلات بعد';
      case 'fr':
        return 'Aucun favori pour le moment';
      case 'es':
        return 'Aún no hay favoritos';
      case 'de':
        return 'Noch keine Favoriten';
      case 'it':
        return 'Nessun preferito ancora';
      case 'pt':
        return 'Ainda não há favoritos';
      case 'ru':
        return 'Пока нет избранного';
      case 'zh':
        return '还没有收藏';
      case 'ja':
        return 'お気に入りはまだありません';
      case 'hi':
        return 'अभी तक कोई पसंदीदा नहीं';
      case 'tr':
        return 'Henüz favori yok';
      default:
        return 'No Favorites Yet';
    }
  }

  String get startAddingFavorites {
    switch (languageCode) {
      case 'ar':
        return 'ابدأ بإضافة المستخدمين إلى المفضلة\nللوصول السريع لاحقاً!';
      case 'fr':
        return 'Commencez à ajouter des utilisateurs à vos favoris\npour un accès rapide plus tard!';
      case 'es':
        return '¡Comienza a agregar usuarios a tus favoritos\npara acceso rápido más tarde!';
      case 'de':
        return 'Beginnen Sie, Benutzer zu Ihren Favoriten hinzuzufügen\nfür schnellen Zugriff später!';
      case 'it':
        return 'Inizia ad aggiungere utenti ai tuoi preferiti\nper un accesso rapido in seguito!';
      case 'pt':
        return 'Comece a adicionar usuários aos seus favoritos\npara acesso rápido mais tarde!';
      case 'ru':
        return 'Начните добавлять пользователей в избранное\nдля быстрого доступа позже!';
      case 'zh':
        return '开始将用户添加到收藏夹\n以便稍后快速访问！';
      case 'ja':
        return 'お気に入りにユーザーを追加して\n後で簡単にアクセスできるようにしましょう！';
      case 'hi':
        return 'अपने पसंदीदा में उपयोगकर्ता जोड़ना शुरू करें\nबाद में त्वरित पहुंच के लिए!';
      case 'tr':
        return 'Favorilerinize kullanıcı eklemeye başlayın\ndaha sonra hızlı erişim için!';
      default:
        return 'Start adding users to your favorites\nfor quick access later!';
    }
  }

  String get all {
    switch (languageCode) {
      case 'ar':
        return 'الكل';
      case 'fr':
        return 'Tout';
      case 'es':
        return 'Todo';
      case 'de':
        return 'Alle';
      case 'it':
        return 'Tutti';
      case 'pt':
        return 'Tudo';
      case 'ru':
        return 'Все';
      case 'zh':
        return '全部';
      case 'ja':
        return 'すべて';
      case 'hi':
        return 'सभी';
      case 'tr':
        return 'Tümü';
      default:
        return 'All';
    }
  }

  String get unread {
    switch (languageCode) {
      case 'ar':
        return 'غير مقروء';
      case 'fr':
        return 'Non lu';
      case 'es':
        return 'No leído';
      case 'de':
        return 'Ungelesen';
      case 'it':
        return 'Non letto';
      case 'pt':
        return 'Não lido';
      case 'ru':
        return 'Непрочитано';
      case 'zh':
        return '未读';
      case 'ja':
        return '未読';
      case 'hi':
        return 'अपठित';
      case 'tr':
        return 'Okunmamış';
      default:
        return 'Unread';
    }
  }

  String get noNotifications {
    switch (languageCode) {
      case 'ar':
        return 'لا توجد إشعارات';
      case 'fr':
        return 'Aucune notification';
      case 'es':
        return 'No hay notificaciones';
      case 'de':
        return 'Keine Benachrichtigungen';
      case 'it':
        return 'Nessuna notifica';
      case 'pt':
        return 'Sem notificações';
      case 'ru':
        return 'Нет уведомлений';
      case 'zh':
        return '没有通知';
      case 'ja':
        return '通知なし';
      case 'hi':
        return 'कोई सूचना नहीं';
      case 'tr':
        return 'Bildirim yok';
      default:
        return 'No Notifications';
    }
  }

  String get cancel {
    switch (languageCode) {
      case 'ar':
        return 'إلغاء';
      case 'fr':
        return 'Annuler';
      case 'es':
        return 'Cancelar';
      case 'de':
        return 'Abbrechen';
      case 'it':
        return 'Annulla';
      case 'pt':
        return 'Cancelar';
      case 'ru':
        return 'Отмена';
      case 'zh':
        return '取消';
      case 'ja':
        return 'キャンセル';
      case 'hi':
        return 'रद्द करें';
      case 'tr':
        return 'İptal';
      default:
        return 'Cancel';
    }
  }

  String get save {
    switch (languageCode) {
      case 'ar':
        return 'حفظ';
      case 'fr':
        return 'Enregistrer';
      case 'es':
        return 'Guardar';
      case 'de':
        return 'Speichern';
      case 'it':
        return 'Salva';
      case 'pt':
        return 'Salvar';
      case 'ru':
        return 'Сохранить';
      case 'zh':
        return '保存';
      case 'ja':
        return '保存';
      case 'hi':
        return 'सहेजें';
      case 'tr':
        return 'Kaydet';
      default:
        return 'Save';
    }
  }

  String get delete {
    switch (languageCode) {
      case 'ar':
        return 'حذف';
      case 'fr':
        return 'Supprimer';
      case 'es':
        return 'Eliminar';
      case 'de':
        return 'Löschen';
      case 'it':
        return 'Elimina';
      case 'pt':
        return 'Excluir';
      case 'ru':
        return 'Удалить';
      case 'zh':
        return '删除';
      case 'ja':
        return '削除';
      case 'hi':
        return 'हटाएं';
      case 'tr':
        return 'Sil';
      default:
        return 'Delete';
    }
  }

  String get edit {
    switch (languageCode) {
      case 'ar':
        return 'تعديل';
      case 'fr':
        return 'Modifier';
      case 'es':
        return 'Editar';
      case 'de':
        return 'Bearbeiten';
      case 'it':
        return 'Modifica';
      case 'pt':
        return 'Editar';
      case 'ru':
        return 'Редактировать';
      case 'zh':
        return '编辑';
      case 'ja':
        return '編集';
      case 'hi':
        return 'संपादित करें';
      case 'tr':
        return 'Düzenle';
      default:
        return 'Edit';
    }
  }

  String get loading {
    switch (languageCode) {
      case 'ar':
        return 'جاري التحميل...';
      case 'fr':
        return 'Chargement...';
      case 'es':
        return 'Cargando...';
      case 'de':
        return 'Wird geladen...';
      case 'it':
        return 'Caricamento...';
      case 'pt':
        return 'Carregando...';
      case 'ru':
        return 'Загрузка...';
      case 'zh':
        return '加载中...';
      case 'ja':
        return '読み込み中...';
      case 'hi':
        return 'लोड हो रहा है...';
      case 'tr':
        return 'Yükleniyor...';
      default:
        return 'Loading...';
    }
  }

  // Profile Setup
  String get setupProfile {
    switch (languageCode) {
      case 'ar':
        return 'إعداد ملفك الشخصي';
      case 'fr':
        return 'Configurer votre profil';
      case 'es':
        return 'Configurar tu perfil';
      case 'de':
        return 'Profil einrichten';
      case 'it':
        return 'Configura il tuo profilo';
      case 'pt':
        return 'Configurar seu perfil';
      case 'ru':
        return 'Настройка профиля';
      case 'zh':
        return '设置您的个人资料';
      case 'ja':
        return 'プロフィールを設定';
      case 'hi':
        return 'अपनी प्रोफ़ाइल सेट करें';
      case 'tr':
        return 'Profilinizi ayarlayın';
      default:
        return 'Setup Your Profile';
    }
  }

  String get createProfileForSkillExchange {
    switch (languageCode) {
      case 'ar':
        return 'أنشئ ملفك الشخصي لتبادل المهارات';
      case 'fr':
        return 'Créez votre profil pour échanger des compétences';
      case 'es':
        return 'Crea tu perfil para intercambiar habilidades';
      case 'de':
        return 'Erstellen Sie Ihr Profil für den Kompetenzaustausch';
      case 'it':
        return 'Crea il tuo profilo per scambiare competenze';
      case 'pt':
        return 'Crie seu perfil para trocar habilidades';
      case 'ru':
        return 'Создайте профиль для обмена навыками';
      case 'zh':
        return '创建您的个人资料以交换技能';
      case 'ja':
        return 'スキル交換のためのプロフィールを作成';
      case 'hi':
        return 'कौशल विनिमय के लिए अपना प्रोफ़ाइल बनाएं';
      case 'tr':
        return 'Beceri değişimi için profilinizi oluşturun';
      default:
        return 'Create your profile for skill exchange';
    }
  }

  String get bio {
    switch (languageCode) {
      case 'ar':
        return 'نبذة عنك';
      case 'fr':
        return 'À propos de vous';
      case 'es':
        return 'Acerca de ti';
      case 'de':
        return 'Über Sie';
      case 'it':
        return 'Su di te';
      case 'pt':
        return 'Sobre você';
      case 'ru':
        return 'О себе';
      case 'zh':
        return '关于您';
      case 'ja':
        return 'あなたについて';
      case 'hi':
        return 'आपके बारे में';
      case 'tr':
        return 'Hakkınızda';
      default:
        return 'About You';
    }
  }

  String get phoneNumber {
    switch (languageCode) {
      case 'ar':
        return 'رقم الهاتف';
      case 'fr':
        return 'Numéro de téléphone';
      case 'es':
        return 'Número de teléfono';
      case 'de':
        return 'Telefonnummer';
      case 'it':
        return 'Numero di telefono';
      case 'pt':
        return 'Número de telefone';
      case 'ru':
        return 'Номер телефона';
      case 'zh':
        return '电话号码';
      case 'ja':
        return '電話番号';
      case 'hi':
        return 'फ़ोन नंबर';
      case 'tr':
        return 'Telefon numarası';
      default:
        return 'Phone Number';
    }
  }

  String get optional {
    switch (languageCode) {
      case 'ar':
        return '(اختياري)';
      case 'fr':
        return '(Optionnel)';
      case 'es':
        return '(Opcional)';
      case 'de':
        return '(Optional)';
      case 'it':
        return '(Opzionale)';
      case 'pt':
        return '(Opcional)';
      case 'ru':
        return '(Необязательно)';
      case 'zh':
        return '（可选）';
      case 'ja':
        return '（オプション）';
      case 'hi':
        return '(वैकल्पिक)';
      case 'tr':
        return '(İsteğe bağlı)';
      default:
        return '(Optional)';
    }
  }

  String get next {
    switch (languageCode) {
      case 'ar':
        return 'التالي';
      case 'fr':
        return 'Suivant';
      case 'es':
        return 'Siguiente';
      case 'de':
        return 'Weiter';
      case 'it':
        return 'Avanti';
      case 'pt':
        return 'Próximo';
      case 'ru':
        return 'Далее';
      case 'zh':
        return '下一步';
      case 'ja':
        return '次へ';
      case 'hi':
        return 'अगला';
      case 'tr':
        return 'İleri';
      default:
        return 'Next';
    }
  }

  String get previous {
    switch (languageCode) {
      case 'ar':
        return 'السابق';
      case 'fr':
        return 'Précédent';
      case 'es':
        return 'Anterior';
      case 'de':
        return 'Zurück';
      case 'it':
        return 'Precedente';
      case 'pt':
        return 'Anterior';
      case 'ru':
        return 'Назад';
      case 'zh':
        return '上一步';
      case 'ja':
        return '前へ';
      case 'hi':
        return 'पिछला';
      case 'tr':
        return 'Önceki';
      default:
        return 'Previous';
    }
  }

  String get finish {
    switch (languageCode) {
      case 'ar':
        return 'إنهاء';
      case 'fr':
        return 'Terminer';
      case 'es':
        return 'Finalizar';
      case 'de':
        return 'Fertig';
      case 'it':
        return 'Fine';
      case 'pt':
        return 'Finalizar';
      case 'ru':
        return 'Завершить';
      case 'zh':
        return '完成';
      case 'ja':
        return '完了';
      case 'hi':
        return 'समाप्त करें';
      case 'tr':
        return 'Bitir';
      default:
        return 'Finish';
    }
  }

  String get skillsICanTeach {
    switch (languageCode) {
      case 'ar':
        return 'المهارات التي يمكنني تدريسها';
      case 'fr':
        return 'Compétences que je peux enseigner';
      case 'es':
        return 'Habilidades que puedo enseñar';
      case 'de':
        return 'Fähigkeiten, die ich unterrichten kann';
      case 'it':
        return 'Competenze che posso insegnare';
      case 'pt':
        return 'Habilidades que posso ensinar';
      case 'ru':
        return 'Навыки, которым я могу научить';
      case 'zh':
        return '我可以教授的技能';
      case 'ja':
        return '教えられるスキル';
      case 'hi':
        return 'मैं जो कौशल सिखा सकता हूं';
      case 'tr':
        return 'Öğretebileceğim beceriler';
      default:
        return 'Skills I Can Teach';
    }
  }

  String get skillsIWantToLearn {
    switch (languageCode) {
      case 'ar':
        return 'المهارات التي أريد تعلمها';
      case 'fr':
        return 'Compétences que je veux apprendre';
      case 'es':
        return 'Habilidades que quiero aprender';
      case 'de':
        return 'Fähigkeiten, die ich lernen möchte';
      case 'it':
        return 'Competenze che voglio imparare';
      case 'pt':
        return 'Habilidades que quero aprender';
      case 'ru':
        return 'Навыки, которые я хочу изучить';
      case 'zh':
        return '我想学习的技能';
      case 'ja':
        return '学びたいスキル';
      case 'hi':
        return 'मैं जो कौशल सीखना चाहता हूं';
      case 'tr':
        return 'Öğrenmek istediğim beceriler';
      default:
        return 'Skills I Want to Learn';
    }
  }

  String get basicInformation {
    switch (languageCode) {
      case 'ar':
        return 'المعلومات الأساسية';
      case 'fr':
        return 'Informations de base';
      case 'es':
        return 'Información básica';
      case 'de':
        return 'Grundinformationen';
      case 'it':
        return 'Informazioni di base';
      case 'pt':
        return 'Informações básicas';
      case 'ru':
        return 'Основная информация';
      case 'zh':
        return '基本信息';
      case 'ja':
        return '基本情報';
      case 'hi':
        return 'मूल जानकारी';
      case 'tr':
        return 'Temel bilgiler';
      default:
        return 'Basic Information';
    }
  }

  String get editProfile {
    switch (languageCode) {
      case 'ar':
        return 'تعديل الملف الشخصي';
      case 'fr':
        return 'Modifier le profil';
      case 'es':
        return 'Editar perfil';
      case 'de':
        return 'Profil bearbeiten';
      case 'it':
        return 'Modifica profilo';
      case 'pt':
        return 'Editar perfil';
      case 'ru':
        return 'Редактировать профиль';
      case 'zh':
        return '编辑个人资料';
      case 'ja':
        return 'プロフィールを編集';
      case 'hi':
        return 'प्रोफ़ाइल संपादित करें';
      case 'tr':
        return 'Profili düzenle';
      default:
        return 'Edit Profile';
    }
  }

  String get reviews {
    switch (languageCode) {
      case 'ar':
        return 'التقييمات';
      case 'fr':
        return 'Avis';
      case 'es':
        return 'Reseñas';
      case 'de':
        return 'Bewertungen';
      case 'it':
        return 'Recensioni';
      case 'pt':
        return 'Avaliações';
      case 'ru':
        return 'Отзывы';
      case 'zh':
        return '评价';
      case 'ja':
        return 'レビュー';
      case 'hi':
        return 'समीक्षाएं';
      case 'tr':
        return 'Yorumlar';
      default:
        return 'Reviews';
    }
  }

  String get connections {
    switch (languageCode) {
      case 'ar':
        return 'الاتصالات';
      case 'fr':
        return 'Connexions';
      case 'es':
        return 'Conexiones';
      case 'de':
        return 'Verbindungen';
      case 'it':
        return 'Connessioni';
      case 'pt':
        return 'Conexões';
      case 'ru':
        return 'Связи';
      case 'zh':
        return '连接';
      case 'ja':
        return '接続';
      case 'hi':
        return 'कनेक्शन';
      case 'tr':
        return 'Bağlantılar';
      default:
        return 'Connections';
    }
  }

  String get sessions {
    switch (languageCode) {
      case 'ar':
        return 'الجلسات';
      case 'fr':
        return 'Sessions';
      case 'es':
        return 'Sesiones';
      case 'de':
        return 'Sitzungen';
      case 'it':
        return 'Sessioni';
      case 'pt':
        return 'Sessões';
      case 'ru':
        return 'Сессии';
      case 'zh':
        return '会话';
      case 'ja':
        return 'セッション';
      case 'hi':
        return 'सत्र';
      case 'tr':
        return 'Oturumlar';
      default:
        return 'Sessions';
    }
  }

  String get about {
    switch (languageCode) {
      case 'ar':
        return 'حول';
      case 'fr':
        return 'À propos';
      case 'es':
        return 'Acerca de';
      case 'de':
        return 'Über';
      case 'it':
        return 'Informazioni';
      case 'pt':
        return 'Sobre';
      case 'ru':
        return 'О';
      case 'zh':
        return '关于';
      case 'ja':
        return 'について';
      case 'hi':
        return 'के बारे में';
      case 'tr':
        return 'Hakkında';
      default:
        return 'About';
    }
  }

  String get settings {
    switch (languageCode) {
      case 'ar':
        return 'الإعدادات';
      case 'fr':
        return 'Paramètres';
      case 'es':
        return 'Configuración';
      case 'de':
        return 'Einstellungen';
      case 'it':
        return 'Impostazioni';
      case 'pt':
        return 'Configurações';
      case 'ru':
        return 'Настройки';
      case 'zh':
        return '设置';
      case 'ja':
        return '設定';
      case 'hi':
        return 'सेटिंग्स';
      case 'tr':
        return 'Ayarlar';
      default:
        return 'Settings';
    }
  }

  String get logout {
    switch (languageCode) {
      case 'ar':
        return 'تسجيل الخروج';
      case 'fr':
        return 'Déconnexion';
      case 'es':
        return 'Cerrar sesión';
      case 'de':
        return 'Abmelden';
      case 'it':
        return 'Disconnetti';
      case 'pt':
        return 'Sair';
      case 'ru':
        return 'Выйти';
      case 'zh':
        return '登出';
      case 'ja':
        return 'ログアウト';
      case 'hi':
        return 'लॉग आउट';
      case 'tr':
        return 'Çıkış Yap';
      default:
        return 'Logout';
    }
  }

  String get yes {
    switch (languageCode) {
      case 'ar':
        return 'نعم';
      case 'fr':
        return 'Oui';
      case 'es':
        return 'Sí';
      case 'de':
        return 'Ja';
      case 'it':
        return 'Sì';
      case 'pt':
        return 'Sim';
      case 'ru':
        return 'Да';
      case 'zh':
        return '是';
      case 'ja':
        return 'はい';
      case 'hi':
        return 'हाँ';
      case 'tr':
        return 'Evet';
      default:
        return 'Yes';
    }
  }

  String get no {
    switch (languageCode) {
      case 'ar':
        return 'لا';
      case 'fr':
        return 'Non';
      case 'es':
        return 'No';
      case 'de':
        return 'Nein';
      case 'it':
        return 'No';
      case 'pt':
        return 'Não';
      case 'ru':
        return 'Нет';
      case 'zh':
        return '否';
      case 'ja':
        return 'いいえ';
      case 'hi':
        return 'नहीं';
      case 'tr':
        return 'Hayır';
      default:
        return 'No';
    }
  }

  String get ok {
    switch (languageCode) {
      case 'ar':
        return 'موافق';
      case 'fr':
        return 'OK';
      case 'es':
        return 'OK';
      case 'de':
        return 'OK';
      case 'it':
        return 'OK';
      case 'pt':
        return 'OK';
      case 'ru':
        return 'ОК';
      case 'zh':
        return '确定';
      case 'ja':
        return 'OK';
      case 'hi':
        return 'ठीक है';
      case 'tr':
        return 'Tamam';
      default:
        return 'OK';
    }
  }

  String get close {
    switch (languageCode) {
      case 'ar':
        return 'إغلاق';
      case 'fr':
        return 'Fermer';
      case 'es':
        return 'Cerrar';
      case 'de':
        return 'Schließen';
      case 'it':
        return 'Chiudi';
      case 'pt':
        return 'Fechar';
      case 'ru':
        return 'Закрыть';
      case 'zh':
        return '关闭';
      case 'ja':
        return '閉じる';
      case 'hi':
        return 'बंद करें';
      case 'tr':
        return 'Kapat';
      default:
        return 'Close';
    }
  }

  String get done {
    switch (languageCode) {
      case 'ar':
        return 'تم';
      case 'fr':
        return 'Terminé';
      case 'es':
        return 'Hecho';
      case 'de':
        return 'Fertig';
      case 'it':
        return 'Fatto';
      case 'pt':
        return 'Concluído';
      case 'ru':
        return 'Готово';
      case 'zh':
        return '完成';
      case 'ja':
        return '完了';
      case 'hi':
        return 'हो गया';
      case 'tr':
        return 'Tamamlandı';
      default:
        return 'Done';
    }
  }

  String get continueText {
    switch (languageCode) {
      case 'ar':
        return 'متابعة';
      case 'fr':
        return 'Continuer';
      case 'es':
        return 'Continuar';
      case 'de':
        return 'Fortfahren';
      case 'it':
        return 'Continua';
      case 'pt':
        return 'Continuar';
      case 'ru':
        return 'Продолжить';
      case 'zh':
        return '继续';
      case 'ja':
        return '続ける';
      case 'hi':
        return 'जारी रखें';
      case 'tr':
        return 'Devam Et';
      default:
        return 'Continue';
    }
  }

  String get back {
    switch (languageCode) {
      case 'ar':
        return 'رجوع';
      case 'fr':
        return 'Retour';
      case 'es':
        return 'Atrás';
      case 'de':
        return 'Zurück';
      case 'it':
        return 'Indietro';
      case 'pt':
        return 'Voltar';
      case 'ru':
        return 'Назад';
      case 'zh':
        return '返回';
      case 'ja':
        return '戻る';
      case 'hi':
        return 'वापस';
      case 'tr':
        return 'Geri';
      default:
        return 'Back';
    }
  }
}

// Extension to easily access localizations
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations(this);
}
