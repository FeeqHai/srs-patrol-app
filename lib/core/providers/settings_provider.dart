import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  Locale _locale = const Locale('ms');
  bool _allowExternalNotifications = true;
  bool _dailyNoteNotifications = true;

  SettingsProvider() {
    _loadSettings();
  }

  Locale get locale => _locale;
  bool get isEnglish => _locale.languageCode == 'en';
  bool get allowExternalNotifications => _allowExternalNotifications;
  bool get dailyNoteNotifications => _dailyNoteNotifications;
  bool get sosAlertsEnabled => true;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Language
    final String? langStr = prefs.getString('languageCode');
    if (langStr == 'en') {
      _locale = const Locale('en');
    } else {
      _locale = const Locale('ms');
    }

    _allowExternalNotifications =
        prefs.getBool('allowExternalNotifications') ?? true;
    _dailyNoteNotifications = prefs.getBool('dailyNoteNotifications') ?? true;

    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    _locale = Locale(langCode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('languageCode', langCode);
  }

  Future<void> setAllowExternalNotifications(bool value) async {
    _allowExternalNotifications = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allowExternalNotifications', value);
  }

  Future<void> setDailyNoteNotifications(bool value) async {
    _dailyNoteNotifications = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyNoteNotifications', value);
  }

  // --- VERY BASIC TRANSLATION MAP ---
  final Map<String, Map<String, String>> _translations = {
    'en': {
      'Kehadiran Saya': 'My Attendance',
      'Rondaan Skuad': 'Squad Patrol',
      'Jana QR Skuad': 'Generate Squad QR',
      'Jana QR Clock Out Skuad': 'Generate Squad Clock Out QR',
      'Jana QR Kehadiran Skuad': 'Generate Squad Attendance QR',
      'Buku Kedatangan Skuad': 'Squad Attendance Book',
      'Log Peralatan Skuad': 'Squad Equipment Log',
      'Skuad/Kampung': 'Squad/Village',
      'Skuad belum ditetapkan': 'Squad not assigned',
      'Paparan dihadkan kepada skuad rondaan anda.':
          'View is limited to your patrol squad.',
      'Mulakan shif, rekod kehadiran ketua, dan paparkan QR untuk ahli skuad.':
          'Start the shift, record leader attendance, and show QR codes to squad members.',
      'Jadual Hari Ini': "Today's Schedule",
      'Tiada jadual rondaan hari ini.': 'No patrol schedule today.',
      'Shif sedang berjalan': 'Shift in progress',
      'Shif belum dimulakan': 'Shift not started',
      'Mula Shif': 'Start Shift',
      'Tamat Shif': 'End Shift',
      'Jana Semula QR Masuk': 'Regenerate Clock-In QR',
      'Jana Semula QR Keluar': 'Regenerate Clock-Out QR',
      'QR Masuk Ahli Skuad': 'Squad Member Clock-In QR',
      'QR Keluar Ahli Skuad': 'Squad Member Clock-Out QR',
      'Penilaian Kehadiran': 'Attendance Assessment',
      'Sahkan status kehadiran ahli skuad untuk jadual rondaan ini.':
          'Confirm squad member attendance status for this patrol schedule.',
      'Disahkan': 'Acknowledged',
      'Hadir': 'Present',
      'Lewat': 'Late',
      'Tidak Hadir': 'Absent',
      'Dikecualikan': 'Excused',
      'Imbas Masuk': 'Clock In Scan',
      'Imbas Keluar': 'Clock Out Scan',
      'Tiada rekod imbas QR.': 'No QR scan record.',
      'Catatan': 'Notes',
      'Contoh: hadir tetapi lewat 10 minit':
          'Example: present but 10 minutes late',
      'Sahkan Kehadiran': 'Acknowledge Attendance',
      'Tiada jadual rondaan untuk dinilai.': 'No patrol schedule to assess.',
      'Minta ahli skuad imbas QR ini untuk mula kehadiran.':
          'Ask squad members to scan this QR to clock in.',
      'Minta ahli skuad imbas QR ini untuk tamatkan kehadiran.':
          'Ask squad members to scan this QR to clock out.',
      'Pantau pinjaman dan pemulangan peralatan skuad anda.':
          'Monitor your squad equipment borrowing and returns.',
      'Papar kod QR pemulangan di pos rondaan skuad dan sahkan peralatan selepas rondaan.':
          'Show the return QR at the squad patrol post and confirm equipment after patrol.',
      'Papar kod QR ini kepada ahli skuad untuk merekod kehadiran rondaan.':
          'Show this QR code to squad members to record patrol attendance.',
      'Papar kod QR pemulangan di pos rondaan dan sahkan peralatan selepas rondaan.':
          'Show the return QR at the patrol post and confirm equipment after patrol.',
      'Peralatan Tersedia': 'Available Equipment',
      'Hari Ini': 'Today',
      'Arkib': 'Archive',
      'Laporan yang telah dihantar tidak boleh dihapuskan.':
          'Submitted reports cannot be deleted.',
      'Terdapat laporan yang telah dihantar dalam pilihan anda.':
          'There are already submitted reports in your selection.',
      'Tamatkan Rondaan Awal': 'End Patrol Early',
      'Adakah anda pasti mahu menamatkan shif rondaan awal?':
          'Are you sure you want to end your patrol shift early?',
      'Baki masa': 'Time remaining',
      'Sahkan Tamat Rondaan': 'Confirm End Patrol',
      'Sila sahkan sekali lagi. Adakah anda benar-benar mahu menamatkan rondaan sekarang?':
          'Please confirm once more. Do you really want to end the patrol now?',
      'Ya, Tamatkan': 'Yes, End Shift',
      'Ya, Sahkan': 'Yes, Confirm',
      'terpilih': 'selected',
      'Mod Batch': 'Batch Mode',
      'Tapis Rekod Insiden': 'Filter Incident Records',
      'Reset': 'Reset',
      'Tapis': 'Filter',
      'Pilih Julat Tarikh': 'Select Date Range',
      'Kemas Kini': 'Update',
      'Preview': 'Preview',
      'Nota': 'Notes',
      'Susunan Prioriti': 'Sort Order',
      'Abjad (Default)': 'Alphabetical (Default)',
      'Paling Banyak Nota': 'Most Notes',
      'Tiada Nota': 'No Notes',
      'Ciri kemas kini sedang dibangunkan.':
          'Update feature is currently under development.',
      'Dashboard': 'Dashboard',
      'Insiden': 'Incidents',
      'Laporan': 'Reports',
      'Rondaan': 'Patrol',
      'Log Insiden': 'Incident Log',
      'Pengesahan Rondaan': 'Patrol Verification',
      'Laporan Peronda': 'Patrol Reports',
      'Suapan Insiden': 'Incident Feed',
      'Pantau Analitik': 'Analytics',
      'Super Admin': 'Super Admin',
      'Pengurusan Lokasi': 'Location Management',
      'Skop Daerah': 'District Scope',
      'Semua Negeri': 'All States',
      'Semua Daerah': 'All Districts',
      'Tukar Kata Laluan': 'Change Password',
      'Kata Laluan Sementara': 'Temporary Password',
      'Sila tetapkan kata laluan baharu sebelum meneruskan.':
          'Please set a new password before continuing.',
      'Kata Laluan Semasa': 'Current Password',
      'Kata Laluan Baharu': 'New Password',
      'Sahkan Kata Laluan Baharu': 'Confirm New Password',
      'Simpan Kata Laluan': 'Save Password',
      'Kata laluan berjaya ditukar': 'Password changed successfully',
      'Kata laluan gagal ditukar': 'Password change failed',
      'Minimum 8 aksara': 'Minimum 8 characters',
      'Kata laluan tidak sepadan': 'Passwords do not match',
      'Medan ini diperlukan': 'This field is required',
      'Edit Profil Ahli': 'Edit Member Profile',
      'Edit Profil': 'Edit Profile',
      'Pindah Lokasi Ahli': 'Transfer Member Location',
      'Pindah Lokasi': 'Transfer Location',
      'Reset Kata Laluan': 'Reset Password',
      'Perlu Tukar Kata Laluan': 'Password Reset',
      'Menunggu Kelulusan': 'Waiting for Approval',
      'Pendaftaran baharu memerlukan semakan':
          'New registration requires review',
      'Jana kata laluan sementara untuk': 'Generate a temporary password for',
      'Cari nama, IC, telefon atau e-mel...':
          'Search name, IC, phone or email...',
      'Quick Access': 'Quick Access',
      'Buka Akses Pantas': 'Open Quick Access',
      'Tutup Akses Pantas': 'Close Quick Access',
      'Namakan Semula': 'Rename',
      'Nyahaktifkan': 'Deactivate',
      'Nyahaktifkan Lokasi': 'Deactivate Location',
      'Lokasi ini digunakan oleh rekod sedia ada':
          'This location is used by existing records',
      'Rekod lama akan dikekalkan, tetapi lokasi ini tidak akan muncul untuk pendaftaran baharu.':
          'Existing records will be preserved, but this location will not appear for new registrations.',
      'Lokasi ini tidak akan muncul untuk pendaftaran baharu.':
          'This location will not appear for new registrations.',
      'Aktifkan': 'Activate',
      'Tambah Negeri': 'Add State',
      'Tambah Daerah': 'Add District',
      'Tambah Zon': 'Add Zone',
      'Kod': 'Code',
      'Kod Negeri': 'State Code',
      'Nama': 'Name',
      'Nama Negeri': 'State Name',
      'Pindah': 'Transfer',
      'Pemantauan semua kawasan SRS': 'Monitoring across all SRS areas',
      'Muat Semula': 'Refresh',
      'Ringkasan Pantas': 'Quick Overview',
      'Belum dikemas kini': 'Not updated yet',
      'Skop Semasa': 'Current Scope',
      'Dikemas kini': 'Updated',
      'Malaysia • Semua Negeri • Semua Daerah • Semua Zon':
          'Malaysia • All States • All Districts • All Zones',
      'Tukar Skop': 'Change Scope',
      'Perlu Tindakan': 'Action Required',
      'Jumlah Pengguna': 'Total Users',
      'Akaun Menunggu': 'Pending Accounts',
      'Akaun baharu memerlukan semakan.': 'New accounts require review.',
      'Pemulangan Menunggu': 'Pending Returns',
      'Pemulangan rondaan menunggu pengesahan.':
          'Patrol returns are awaiting acknowledgement.',
      'Insiden Hari Ini': 'Today\'s Incidents',
      'Catatan hari ini untuk perhatian.': 'Today\'s notes need attention.',
      'Negeri': 'States',
      'Negeri Diliputi': 'States Covered',
      'Senarai Ketua KRT': 'KRT Admin List',
      'Tiada Ketua KRT direkodkan.': 'No KRT admins recorded.',
      'Liputan Daerah': 'District Coverage',
      'Tiada liputan daerah direkodkan.': 'No district coverage recorded.',
      'Pembersihan data diperlukan': 'Data cleanup required',
      '1 lokasi legasi perlu disemak.': '1 legacy location needs review.',
      'lokasi legasi perlu disemak.': '{count} legacy locations need review.',
      'Semak': 'Review',
      'Malaysia': 'Malaysia',
      'Semua negeri, daerah dan zon': 'All states, districts and zones',
      'Negeri • Daerah • Zon': 'State • District • Zone',
      'Penapis skop belum disambungkan.':
          'Scope filters are not connected yet.',
      'Cari Ketua KRT...': 'Search KRT admins...',
      'Cari daerah...': 'Search districts...',
      'Cari rekod...': 'Search records...',
      'Tiada data legasi.': 'No legacy data.',
      'zon': 'zone',
      'ahli': 'members',
      'KRT': 'KRT',
      'Jana Kod QR': 'Generate QR',
      'Laporan Insiden': 'Incident Reports',
      'Laporan Operasi': 'Operation Reports',
      'Jana dokumen demo tanpa meninggalkan dashboard.':
          'Generate demo documents without leaving the dashboard.',
      'Lampiran 6': 'Annex 6',
      'Kedatangan': 'Attendance',
      'Pengurusan Ahli': 'Member Management',
      'Notifikasi': 'Notifications',
      'Tiada notifikasi baharu': 'No new notifications',
      'add_daily_note': 'Add Daily Note',
      'Preparing note...': 'Preparing note...',
      'daily_note_saved': 'Daily note saved',
      'daily_note_saved_message':
          'Daily note saved. Press the send icon in Incident Log to submit it to Ketua KRT.',
      'report_successful': 'Report Successful',
      'daily_note_submitted': 'Daily note submitted to Ketua KRT.',
      'daily_notes_submitted_count':
          'X daily notes were submitted to Ketua KRT.',
      'submit_daily_note': 'Submit Daily Note',
      'save_daily_note': 'Save Daily Note',
      'send_to_krt': 'Send to Ketua KRT',
      'note_pending_submission': 'Pending submission',
      'Jana QR Clock Out': 'Generate Clock Out QR',
      'Penjanaan QR': 'QR Generation',
      'Tekan Clock In atau Clock Out untuk terus menjana kod.':
          'Tap Clock In or Clock Out to generate the code immediately.',
      'Tekan Clock In atau Clock Out untuk menjana QR 60 saat.':
          'Tap Clock In or Clock Out to generate a 60-second QR.',
      'Jana semula QR?': 'Regenerate QR?',
      'Tukar mod QR?': 'Switch QR mode?',
      'QR semasa masih aktif. Jana semula akan membatalkan kod yang sedang berjalan.':
          'The current QR is still active. Regenerating will cancel the running code.',
      'QR semasa masih aktif. Menukar mod akan membatalkan kod yang sedang berjalan.':
          'The current QR is still active. Switching mode will cancel the running code.',
      'Teruskan': 'Continue',
      'Mod QR': 'QR Mode',
      'Tempoh': 'Duration',
      'Papar kod QR ini di pos untuk pengesahan pulang peronda.':
          'Show this QR at the post for patroller return confirmation.',
      'Clock In': 'Clock In',
      'Clock Out': 'Clock Out',
      'Sila jana semula kod QR untuk pemulangan seterusnya.':
          'Please generate a new QR code for the next return.',
      'Pengesahan Pemulangan': 'Return Acknowledgement',
      'Pemulangan': 'Returns',
      'Diminta pada': 'Requested at',
      'Tiada pemulangan menunggu pengesahan.':
          'No returns awaiting acknowledgement.',
      'Tiada peralatan dipinjam': 'No equipment borrowed',
      'Sahkan Pemulangan': 'Acknowledge Return',
      'Pemulangan peronda telah disahkan.': 'Patroller return acknowledged.',
      'Pemulangan telah disahkan.': 'Return has been acknowledged.',
      'Gagal memuatkan pemulangan.': 'Unable to load returns.',
      'Gagal mengesahkan pemulangan.': 'Unable to acknowledge the return.',
      'Gagal memuatkan peralatan dipinjam.':
          'Unable to load borrowed equipment.',
      'Sahkan Pemulangan Peralatan': 'Confirm Equipment Return',
      'Tandakan semua peralatan yang telah diserahkan kepada Ketua KRT.':
          'Tick every item handed back to Ketua KRT.',
      'Tandakan semua peralatan yang telah diserahkan kepada Ketua Peronda atau Ketua KRT.':
          'Tick every item handed back to the squad leader or Ketua KRT.',
      'Tiada peralatan dipinjam untuk shif ini.':
          'No equipment was borrowed for this shift.',
      'Pemulangan tidak dapat disahkan.': 'The return could not be confirmed.',
      'Menunggu pengesahan Ketua KRT.':
          'Waiting for Ketua KRT acknowledgement.',
      'Menunggu Pengesahan Ketua KRT': 'Waiting for Ketua KRT Acknowledgement',
      'Menunggu Pengesahan Ketua Peronda/KRT':
          'Waiting for Squad Leader/Ketua KRT Acknowledgement',
      'Pemulangan anda sedang menunggu pengesahan Ketua KRT.':
          'Your return is waiting for Ketua KRT acknowledgement.',
      'Pemulangan anda sedang menunggu pengesahan Ketua Peronda atau Ketua KRT.':
          'Your return is waiting for squad leader or Ketua KRT acknowledgement.',
      'Pemulangan anda telah dihantar. Sila tunggu Ketua KRT mengesahkan penerimaan peralatan.':
          'Your return has been submitted. Please wait for Ketua KRT to confirm the equipment handover.',
      'Pemulangan anda telah dihantar. Sila tunggu Ketua Peronda atau Ketua KRT mengesahkan penerimaan peralatan.':
          'Your return has been submitted. Please wait for the squad leader or Ketua KRT to confirm the equipment handover.',
      'Semak Status Pemulangan': 'Check Return Status',
      'Sahkan pemulangan peralatan ahli skuad yang telah selesai rondaan.':
          'Acknowledge equipment returns for squad members who finished patrol.',
      'Sila kembali ke pos rondaan untuk imbas QR pulang.':
          'Please return to the patrol post to scan the return QR.',
      'Semua peralatan perlu ditanda sebelum tamat syif.':
          'All equipment must be ticked before ending the shift.',
      'Sistem sedang mengesahkan...': 'System is validating...',
      'Imbas QR Clock In KRT untuk mula': 'Scan the KRT Clock In QR to start',
      'Menunggu KRT': 'Waiting for KRT',
      'Menunggu Pengesahan': 'Waiting for Acknowledgement',
      'MENUNGGU PENGESAHAN': 'WAITING FOR ACKNOWLEDGEMENT',
      'KEMBALI KE PAPAN PEMUKA': 'BACK TO DASHBOARD',
      'Hantar Pemulangan': 'Submit Return',
      'IMBAS QR PULANG': 'SCAN RETURN QR',
      'Imbas QR Clock Out di Pos Utama':
          'Scan the Clock Out QR at the main post',
      'Log Keluar': 'Logout',
      'Profil': 'Profile',
      'Tetapan': 'Settings',
      'Tema': 'Theme',
      'Bahasa': 'Language',
      'Sistem': 'System Default',
      'Cerah': 'Light',
      'Gelap': 'Dark',
      'Tutup': 'Close',
      'Bahasa Melayu': 'Malay',
      'English': 'English',
      'Pantau': 'Monitor',
      'Jana QR': 'Gen QR',
      'Ahli': 'Members',
      'Skuad': 'Squad',
      // Profile Strings
      'account': 'Account',
      'settings': 'Settings',
      'profile_photo': 'Profile photo',
      'remove_profile_photo': 'Remove profile photo',
      'remove_profile_photo_confirmation':
          'Are you sure you want to remove your profile photo?',
      'photo_remove_success': 'Profile photo removed successfully',
      'photo_remove_failed': 'Failed to remove profile photo',
      'notifications': 'Notifications',
      'allow_external_notifications': 'Allow notifications outside the app',
      'daily_note_notifications': 'Daily note notifications',
      'sos_alerts': 'SOS alerts',
      'accessibility': 'Accessibility',
      'language': 'Language',
      'font_size': 'Font size',
      'high_contrast': 'High contrast',
      'coming_soon': 'Coming soon',
      'iRonda': 'iRonda',
      'SKIM RONDAAN SUKARELA': 'VOLUNTARY PATROL SCHEME',
      'Sila log masuk untuk menggunakan fungsi kecemasan.':
          'Please log in to use the emergency function.',
      'Amaran Kecemasan (SOS)': 'Emergency Warning (SOS)',
      'Adakah anda pasti mahu menghantar isyarat kecemasan? Kordinat GPS anda akan dihantar ke bilik gerakan serta-merta.':
          'Are you sure you want to send an emergency signal? Your GPS coordinates will be sent to the control room immediately.',
      'HANTAR SOS': 'SEND SOS',
      'SOS Dihantar': 'SOS Sent',
      'Bantuan sedang dalam perjalanan. Sila pastikan keselamatan diri anda dan hubungi talian 999 jika keadaan kritikal.':
          'Help is on the way. Please ensure your safety and call 999 if the situation is critical.',
      'Pusat Kawalan & Kecemasan': 'Control & Emergency Center',
      'Tekan butang SOS di bawah HANYA pada waktu kecemasan atau ancaman keselamatan.':
          'Press the SOS button below ONLY during emergencies or security threats.',
      'MENGESAN LOKASI...': 'DETECTING LOCATION...',
      'Pilih Bulan dan Tahun': 'Select Month and Year',
      'Tahun': 'Year',
      'Tarikh': 'Date',
      'Masa Bertugas': 'Duty Time',
      'No. KP': 'IC No.',
      'Masa Tamat': 'End Time',
      'PDF masih boleh dijana sebagai borang kosong untuk':
          'PDF can still be generated as a blank form for',
      'Cuba lagi': 'Try again',
      'Bulan Laporan': 'Report Month',
      'Tarikh Laporan': 'Report Date',
      'new_daily_note': 'New Daily Note',
      'daily_note_received': 'Daily note received',
      'no_notifications': 'No notifications',
      'new_notifications': 'New',
      'notification_history': 'History',
      'no_new_notifications': 'No new notifications',
      'no_notification_history': 'No notification history',
      'clear_all': 'Clear all',
      'clear_history': 'Clear History',
      'Clear all notification history?': 'Clear all notification history?',
      'delete_notification': 'Delete Notification',
      'notification_removed': 'Notification removed',
      'unread_notifications': 'Unread notifications',
      'assign_shift': 'Assign Shift',
      'selected_date': 'Selected Date',
      'upcoming_schedules': 'Upcoming',
      'schedule_history': 'History',
      'past_schedules': 'Past Schedules',
      'current_schedules': 'Today',
      'filter_by_zone': 'Filter by Zone',
      'all_zones': 'All Zones',
      'calendar': 'Calendar',
      'today': 'Today',
      'this_month': 'This Month',
      'previous_months': 'Previous Months',
      'completed': 'Completed',
      'upcoming': 'Upcoming',
      'shift_assigned_success': 'Shift assigned successfully',
      'schedule_deleted_success': 'Schedule deleted successfully',
      'schedule_overlap_error':
          'This squad already has a schedule during that time.',
      'choose_squad': 'Choose Squad',
      'choose_date': 'Choose Date',
      'choose_start_time': 'Choose Start Time',
      'choose_end_time': 'Choose End Time',
      'mark_as_read': 'Mark as read',
      'Malay': 'Malay',
      'English Language': 'English',
      'profile': 'Profile',
      'personal_information': 'Personal Information',
      'user_id': 'User ID',
      'account_status': 'Account Status',
      'active': 'Active',
      'pending': 'Pending',
      'inactive': 'Inactive',
      'ic_number': 'IC Number',
      'phone_number': 'Phone Number',
      'email': 'Email',
      'role': 'Role',
      'state': 'State',
      'district': 'District',
      'zone': 'Zone',
      'squad': 'Squad',
      'logout': 'Logout',
      'logout_confirmation_title': 'Log out?',
      'logout_confirmation_message':
          'Are you sure you want to log out of this account?',
      'cancel': 'Cancel',
      'confirm_logout': 'Log out',
      'change_profile_photo': 'Change profile photo',
      'upload_photo': 'Upload photo',
      'choose_photo': 'Choose photo',
      'photo_upload_success': 'Profile photo updated successfully',
      'photo_upload_failed': 'Failed to upload profile photo',
      'invalid_image': 'Invalid image file',
      'image_too_large': 'Image size is too large',
      'Nama Penuh': 'Full Name',
      'No. Kad Pengenalan': 'IC Number',
      'Zon Rondaan': 'Patrol Zone',
      'No. Telefon': 'Phone Number',
      'E-mel': 'Email',
      'Peranan': 'Role',
      'Status Akaun': 'Account Status',
      'Sesi tamat. Sila log masuk semula.':
          'Session expired. Please log in again.',
      'Ralat Pelayan': 'Server Error',
      'Ralat Rangkaian': 'Network Error',
      'Cuba Semula': 'Try Again',
      'Tiada data profil': 'No profile data',
      'Tiada': 'None',
      // Dashboard Strings
      'Selamat Datang': 'Welcome',
      'Ringkasan Aktiviti Anda': 'Your Activity Summary',
      'Tidak Aktif': 'Inactive',
      'Rondaan Anda': 'Your Patrol',
      'Jumlah Nota': 'Total Notes',
      'Status Semasa': 'Current Status',
      'Bersedia Untuk Rondaan': 'Ready for Patrol',
      'Tekan untuk mula': 'Tap to start',
      'Sedang Meronda': 'Currently Patrolling',
      'Papan Pemuka Analitik': 'Analytics Dashboard',
      'Ringkasan insiden dan statistik': 'Incident summary and statistics',
      'Total Insiden (Minggu)': 'Total Incidents (Week)',
      'Total Rondaan (Minggu)': 'Total Patrols (Week)',
      'Sedia Ada': 'Available',
      'Tiada Data Rondaan': 'No Patrol Data',
      'Trend Insiden (7 Hari Terakhir)': 'Incident Trend (Last 7 Days)',
      'memerlukan bantuan!': 'needs help!',
      'Masa': 'Time',
      'Tiada insiden direkodkan.': 'No incidents recorded.',
      'LAPOR INSIDEN': 'REPORT INCIDENT',
      'Tiada Tajuk': 'No Title',
      'MULAKAN SHIF': 'START SHIFT',
      'Tamatkan Shif Awal': 'End Shift Early',
      'Lokasi Diperlukan': 'Location Required',
      'Faham & Tutup': 'Understood & Close',
      // SOS Strings
      'AMARAN SOS': 'SOS WARNING',
      'Adakah anda pasti mahu mencetuskan penggera KECEMASAN?':
          'Are you sure you want to trigger an EMERGENCY alert? This will send your location immediately to all patrollers.',
      'Batal': 'Cancel',
      'SAHKAN SOS': 'CONFIRM SOS',
      'Sedang Mengesan GPS & Menyiarkan SOS...':
          'Detecting GPS Coordinates & Broadcasting SOS...',
      'SOS BERJAYA DISIARKAN!': 'SOS BROADCAST SUCCESSFUL!',
      'RALAT SOS': 'SOS ERROR',
      'GAGAL PENGESANAN GPS': 'GPS DETECTION FAILED',
      'KECEMASAN': 'EMERGENCY!',
      'Seorang peronda memerlukan bantuan SEGERA!':
          'A patroller needs IMMEDIATE help!',
      'Peronda': 'Patroller',
      'Tidak Diketahui': 'Unknown',
      'Lokasi': 'Location',
      'GOOGLE MAPS': 'GOOGLE MAPS',
      'LIHAT LOG': 'VIEW LOG',
      // Login
      'Securing Our Community\nTogether.': 'Securing Our Community\nTogether.',
      'Welcome to the SRS Patrol Portal. Access your dashboard to manage patrols, report incidents, and keep the neighborhood safe.':
          'Welcome to the SRS Patrol Portal. Access your dashboard to manage patrols, report incidents, and keep the neighborhood safe.',
      'SRS Patrol Portal': 'SRS Patrol Portal',
      'Securing Our Community': 'Securing Our Community',
      'Welcome Back': 'Welcome Back',
      'Enter your credentials to access your account':
          'Enter your credentials to access your account',
      'Email Address': 'Email Address',
      'Password': 'Password',
      'Forgot password?': 'Forgot password?',
      'Password Assistance': 'Password Assistance',
      'Please contact Ketua KRT to reset your password or reactivate your account.':
          'Please contact the KRT Head to reset your password or reactivate your account.',
      'SECURE LOGIN': 'SECURE LOGIN',
      "Don't have an account?": "Don't have an account?",
      'Register Here': 'Register Here',
      // Register
      'Create Your Account': 'Create Your Account',
      'Join the SRS patrol team and secure your community':
          'Join the SRS patrol team and secure your community',
      'Full Name': 'Full Name',
      'IC Number': 'IC Number',
      'Patrol Zone': 'Patrol Zone',
      'Phone Number': 'Phone Number',
      'Confirm Password': 'Confirm Password',
      'SUBMIT REGISTRATION': 'SUBMIT REGISTRATION',
      'Already have an account?': 'Already have an account?',
      'Login Here': 'Login Here',
      'Pendaftaran Selesai': 'Registration Complete',
      'Akaun peronda telah direkodkan. Sila hubungi Ketua KRT untuk pengesahan identiti sebelum log masuk.':
          'Your account has been recorded. Please contact the KRT Head to verify your identity before logging in.',
      'Pendaftaran ditolak: Borang tidak lengkap atau zon tidak dipilih.':
          'Registration denied: Form incomplete or zone not selected.',
      // Incidents / Misc
      'Sila pilih kategori insiden': 'Please select incident category',
      'Sila masukkan tajuk': 'Please enter a title',
      'Penerangan tidak boleh dibiarkan kosong': 'Description cannot be empty',
      'Kategori Insiden': 'Incident Category',
      'Tajuk Ringkas': 'Short Title',
      'Cth: Pagar rosak di Lorong 4': 'E.g.: Broken fence at Lane 4',
      'Keterangan Lanjut': 'Further Description',
      'Terangkan butiran kejadian...': 'Describe the incident details...',
      'HANTAR LAPORAN': 'SUBMIT REPORT',
      'Bukti Bergambar': 'Photographic Evidence',
      'Ketua KRT': 'KRT Head',
      'Sedang Dimuatkan...': 'Loading...',
      'Tapis Insiden': 'Filter Incidents',
      'Tekan di sini untuk mula': 'Tap here to start',
      'Ringkasan Aktiviti': 'Activity Summary',
      'Harian': 'Daily',
      'Mingguan': 'Weekly',
      'Semua': 'All',
      // Added missing keys
      'Join Our Patrol\nNetwork.': 'Join Our Patrol\nNetwork.',
      'Click to see available equipment': 'Click to see available equipment',
      'Register as a patroller to start securing the neighborhood, tracking incidents, and contributing to a safer community.':
          'Register as a patroller to start securing the neighborhood, tracking incidents, and contributing to a safer community.',
      'Pendaftaran': 'Registration',
      'Daftar Peronda Baru': 'Register New Patroller',
      'Create Account': 'Create Account',
      'Fill in the details below to register as a patroller.':
          'Fill in the details below to register as a patroller.',
      'Maklumat Identiti': 'Identity Information',
      'Nama Penuh (Mengikut Kad Pengenalan)': 'Full Name (As in IC)',
      'No. Kad Pengenalan (Tanpa Sengkang)': 'IC Number (Without dashes)',
      'Maklumat Operasi': 'Operation Information',
      'No. Telefon (Kecemasan)': 'Phone Number (Emergency)',
      'Pilih Sektor / Zon Rondaan': 'Select Sector / Patrol Zone',
      'Zon rondaan wajib dipilih': 'Patrol zone must be selected',
      'Kredensial Sistem': 'System Credentials',
      'Alamat E-mel': 'Email Address',
      'Kata Laluan': 'Password',
      'Ruangan ini wajib diisi': 'This field is required',
      'Kata laluan mesti sekurang-kurangnya 8 aksara.':
          'Password must be at least 8 characters.',
      'Kata laluan terlalu panjang. Sila gunakan kurang aksara.':
          'Password is too long. Please use fewer characters.',
      'Kata laluan tidak boleh mengandungi aksara kawalan.':
          'Password cannot contain control characters.',
      'Kata laluan mengandungi aksara tidak sah.':
          'Password contains invalid characters.',
      'Masukkan nombor telefon yang sah bermula dengan 0 atau +60 (9 hingga 11 digit dalam format tempatan).':
          'Enter a valid phone number starting with 0 or +60 (9 to 11 digits in local format).',
      'Tarikh lahir dalam nombor MyKad tidak sah.':
          'The birth date in the MyKad number is invalid.',
      'Pendaftaran gagal. Sila cuba lagi.':
          'Registration failed. Please try again.',
      'Tidak dapat menghubungi pelayan. Sila cuba lagi.':
          'Unable to contact the server. Please try again.',
      'Current password is incorrect.': 'Current password is incorrect.',
      'Current password and new password are required.':
          'Current password and new password are required.',
      'HANTAR PERMOHONAN': 'SUBMIT APPLICATION',
      'Pendaftaran Peronda': 'Patroller Registration',
      'Lengkapkan butiran di bawah untuk mendaftar.':
          'Complete the details below to register.',
      'Sertai Rangkaian\nPeronda Kami.': 'Join Our Patrol\nNetwork.',
      'Daftar sebagai peronda SRS untuk membantu menjaga keselamatan dan keharmonian komuniti setempat.':
          'Register as an SRS patroller to help protect the safety and harmony of the local community.',
      'Memuatkan negeri...': 'Loading states...',
      'Pilih Negeri': 'Select State',
      'Pilih Daerah': 'Select District',
      'Pilih Zon Rondaan': 'Select Patrol Zone',
      'Sila pilih negeri': 'Please select a state',
      'Sila pilih daerah': 'Please select a district',
      'Sila pilih zon': 'Please select a zone',
      'Tidak dapat memuatkan senarai negeri.': 'Unable to load the state list.',
      'Tidak dapat memuatkan senarai daerah.':
          'Unable to load the district list.',
      'Tidak dapat memuatkan senarai zon.': 'Unable to load the zone list.',
      'Borang tidak lengkap. Sila isi semua butiran.':
          'The form is incomplete. Please complete all details.',
      'Ralat pelayan semasa menyemak pengesahan identiti.':
          'A server error occurred while checking identity verification.',
      'Pengesahan identiti tidak sah atau telah tamat.':
          'Identity verification is invalid or has expired.',
      'Ralat pelayan semasa menyemak imbasan MyKad.':
          'A server error occurred while checking the MyKad scan.',
      'Imbasan MyKad tidak sah atau telah tamat.':
          'The MyKad scan is invalid or has expired.',
      'Ralat pelayan semasa menyemak lokasi.':
          'A server error occurred while checking the location.',
      'Pilihan negeri, daerah dan zon tidak sah.':
          'The selected state, district, and zone are invalid.',
      'Ralat pelayan semasa menamatkan sesi pengesahan.':
          'A server error occurred while completing the verification session.',
      'No. Kad Pengenalan atau E-mel telah didaftarkan dalam sistem.':
          'The IC number or email has already been registered in the system.',
      'Ralat pangkalan data.': 'A database error occurred.',
      // Identity verification
      'Pendaftaran Berjaya': 'Registration Successful',
      'Sila hubungi Ketua KRT untuk pengesahan akaun sebelum log masuk.':
          'Please contact the KRT Head to approve your account before logging in.',
      'Akaun anda sedang menunggu kelulusan Pentadbir KRT.':
          'Your account is awaiting KRT Administrator approval.',
      'Pendaftaran anda telah ditolak atau akaun telah dinyahaktifkan.':
          'Your registration was rejected or the account has been deactivated.',
      'Invalid credentials.': 'Invalid email or password.',
      'Status akaun berjaya dikemas kini.':
          'The account status was updated successfully.',
      'Status akaun gagal dikemas kini.':
          'The account status could not be updated.',
      'Kembali ke Log Masuk': 'Back to Login',
      'Selesaikan pengesahan MyKad dan wajah sebelum mendaftar.':
          'Complete MyKad and face verification before registering.',
      'Pendaftaran peronda baharu hanya tersedia melalui aplikasi Android iRonda.':
          'New patroller registration is only available through the iRonda Android app.',
      'Pendaftaran memerlukan Android': 'Registration requires Android',
      'Pengesahan MyKad diperlukan': 'MyKad verification required',
      'Identiti telah disahkan': 'Identity verified',
      'Pengesahan MyKad dan wajah menggunakan kamera hanya disokong dalam aplikasi Android iRonda.':
          'Camera-based MyKad and face verification is only supported in the iRonda Android app.',
      'Imbas MyKad dan lengkapkan swafoto serta cabaran rawak. Tiada pilihan untuk melangkau langkah ini.':
          'Scan your MyKad and complete the selfie and random challenge. This step cannot be skipped.',
      'Nama dan nombor MyKad dikunci berdasarkan keputusan pengesahan. Pilih sendiri negeri, daerah dan zon rondaan anda.':
          'The name and MyKad number are locked based on the verification result. Select your operating state, district, and patrol zone.',
      'Selesaikan pengekstrakan nama dan nombor MyKad sebelum mendaftar.':
          'Complete the extraction of the name and MyKad number before registering.',
      'Imbasan MyKad diperlukan': 'MyKad scan required',
      'Data MyKad telah diekstrak': 'MyKad data extracted',
      'Pengimbasan MyKad menggunakan kamera hanya disokong dalam aplikasi Android iRonda.':
          'Camera-based MyKad scanning is only supported in the iRonda Android app.',
      'Imbas MyKad untuk mengekstrak nama penuh dan nombor MyKad. Tiada swafoto atau perbandingan wajah dilakukan.':
          'Scan the MyKad to extract the full name and MyKad number. No selfie or face comparison is performed.',
      'Nama dan nombor MyKad dikunci berdasarkan data yang diekstrak. Pilih sendiri negeri, daerah dan zon rondaan anda.':
          'The name and MyKad number are locked based on the extracted data. Select your operating state, district, and patrol zone.',
      'MULA IMBASAN': 'START SCAN',
      'ULANG IMBASAN': 'SCAN AGAIN',
      'ANDROID DIPERLUKAN': 'ANDROID REQUIRED',
      'MULA PENGESAHAN': 'START VERIFICATION',
      'ULANG PENGESAHAN': 'REPEAT VERIFICATION',
      'Nama Penuh (Mengikut MyKad)': 'Full Name (As on MyKad)',
      'Pengesahan Identiti': 'Identity Verification',
      'Pengekstrakan Data MyKad': 'MyKad Data Extraction',
      'Pengekstrakan prototaip — bukan pengesahan pemilik MyKad':
          'Prototype extraction — not MyKad holder verification',
      'Tujuan: membaca nama penuh dan nombor MyKad untuk mengisi borang pendaftaran.\n\nData diproses: imej MyKad, nama penuh dan nombor MyKad. Tiada swafoto, pengesanan hidup atau perbandingan wajah dilakukan.\n\nPrivasi: imej MyKad diproses pada peranti dan tidak dihantar ke pelayan. Fail imej sementara dipadam apabila proses tamat atau skrin ini ditutup. Anda boleh membatalkan sebelum bersetuju.':
          'Purpose: to read the full name and MyKad number for the registration form.\n\nData processed: MyKad image, full name, and MyKad number. No selfie, liveness detection, or face comparison is performed.\n\nPrivacy: the MyKad image is processed on the device and is not sent to the server. The temporary image file is deleted when processing ends or this screen is closed. You may cancel before consenting.',
      'Pengekstrakan data MyKad hanya tersedia melalui aplikasi Android iRonda.':
          'MyKad data extraction is only available through the iRonda Android app.',
      'Saya bersetuju dengan pemprosesan sementara MyKad untuk mengekstrak nama penuh dan nombor MyKad bagi pendaftaran iRonda.':
          'I consent to the temporary processing of my MyKad to extract the full name and MyKad number for iRonda registration.',
      'Imbas dan baca MyKad': 'Scan and read MyKad',
      'Pegang telefon secara menegak atau melintang. Kualiti imej akan diperiksa sebelum nama penuh dan nombor MyKad dibaca.':
          'Hold your phone in portrait or landscape orientation. Image quality will be checked before the full name and MyKad number are read.',
      'Menyemak kualiti dan membaca nama serta nombor MyKad...':
          'Checking image quality and reading the name and MyKad number...',
      'Semak Maklumat Diekstrak': 'Review Extracted Information',
      'Pastikan nama penuh dan nombor MyKad berikut sepadan dengan kad anda.':
          'Make sure the following full name and MyKad number match your card.',
      'Nombor MyKad': 'MyKad Number',
      'Tiada maklumat dihantar ke pelayan sehingga anda memilih BETUL.':
          'No information is sent to the server until you select CORRECT.',
      'IMBAS SEMULA': 'RESCAN',
      'BETUL': 'CORRECT',
      'Menyediakan sesi pendaftaran...':
          'Preparing the registration session...',
      'Imbasan MyKad telah tamat. Sila imbas semula sebelum mendaftar.':
          'The MyKad scan has expired. Please scan it again before registering.',
      'Selaraskan MyKad di dalam bingkai': 'Align the MyKad inside the frame',
      'Pastikan keempat-empat penjuru kelihatan, teks jelas dan tiada silau sebelum mengambil gambar.':
          'Make sure all four corners are visible, the text is clear, and there is no glare before taking the picture.',
      'AMBIL GAMBAR': 'CAPTURE',
      'Gambar tidak dapat diambil. Sila cuba semula.':
          'The picture could not be taken. Please try again.',
      'Kamera tidak dapat dibuka. Semak kebenaran kamera dan cuba semula.':
          'The camera could not be opened. Check the camera permission and try again.',
      'CUBA SEMULA': 'TRY AGAIN',
      'Pengesahan prototaip — bukan e-KYC rasmi':
          'Prototype verification — not official e-KYC',
      'Tujuan: mengesahkan identiti peronda semasa pendaftaran.\n\nData diproses: imej MyKad, nama, nombor MyKad, swafoto, tindakan hidup dan skor persamaan wajah.\n\nPrivasi: imej dan vektor wajah diproses pada peranti dan tidak dihantar ke pelayan. Pelayan hanya menerima hasil pengesahan dan maklumat pendaftaran yang diperlukan. Fail imej sementara dipadam apabila percubaan tamat atau skrin ini ditutup. Anda boleh membatalkan sebelum bersetuju.':
          'Purpose: to verify a patroller’s identity during registration.\n\nData processed: MyKad image, name, MyKad number, selfie, liveness action, and face-similarity score.\n\nPrivacy: images and face vectors are processed on the device and are not sent to the server. The server only receives the verification result and required registration information. Temporary image files are deleted when the attempt ends or this screen is closed. You may cancel before consenting.',
      'Pendaftaran peronda dengan pengesahan identiti hanya tersedia melalui aplikasi Android iRonda.':
          'Patroller registration with identity verification is only available through the iRonda Android app.',
      'Saya bersetuju dengan pemprosesan sementara MyKad dan wajah seperti yang diterangkan di atas untuk tujuan pendaftaran iRonda. Persetujuan ini diperlukan untuk meneruskan.':
          'I consent to the temporary processing of my MyKad and face as described above for iRonda registration. Consent is required to continue.',
      'Imbas MyKad': 'Scan MyKad',
      'Putar telefon ke kedudukan melintang. Kualiti, OCR dan potret utama MyKad akan diperiksa.':
          'Rotate your phone to landscape. Image quality, OCR, and the main MyKad portrait will be checked.',
      'Swafoto neutral': 'Neutral selfie',
      'Pandang kamera dengan kedua-dua mata terbuka.':
          'Face the camera with both eyes open.',
      'Cabaran rawak': 'Random challenge',
      'Pejamkan kedua-dua mata dan ambil swafoto.':
          'Close both eyes and take a selfie.',
      'Pusingkan kepala ke kiri atau kanan dan ambil swafoto.':
          'Turn your head left or right and take a selfie.',
      'MEMPROSES...': 'PROCESSING...',
      'IMBAS MYKAD': 'SCAN MYKAD',
      'AMBIL SWAFOTO': 'TAKE SELFIE',
      'LAKSANAKAN CABARAN': 'PERFORM CHALLENGE',
      'Sediakan MyKad': 'Prepare your MyKad',
      'Anda boleh memegang telefon secara menegak atau melintang. Letakkan MyKad secara mendatar di dalam bingkai dan pastikan seluruh kad, termasuk keempat-empat penjuru, berada dalam bingkai. Elakkan silau dan pegang telefon dengan stabil.':
          'You may hold your phone in portrait or landscape orientation. Place the MyKad horizontally inside the guide and ensure the entire card, including all four corners, is inside the frame. Avoid glare and hold the phone steady.',
      'BATAL': 'CANCEL',
      'BUKA KAMERA': 'OPEN CAMERA',
      'Menyemak kualiti dan membaca maklumat MyKad...':
          'Checking image quality and reading MyKad information...',
      'MyKad dibaca. Seterusnya, ambil swafoto menghadap kamera.':
          'MyKad read successfully. Next, take a selfie facing the camera.',
      'Mengesan wajah dalam swafoto...': 'Detecting the face in the selfie...',
      'Buka kedua-dua mata untuk swafoto pertama.':
          'Keep both eyes open for the first selfie.',
      'Menyemak tindakan rawak dan persamaan wajah...':
          'Checking the random action and face similarity...',
      'Resolusi imej terlalu rendah.': 'The image resolution is too low.',
      'Keseluruhan kad perlu kelihatan di dalam bingkai.':
          'The entire card must be visible inside the frame.',
      'Imej kabur. Pegang telefon dengan stabil dan cuba semula.':
          'The image is blurry. Hold the phone steady and try again.',
      'Pantulan cahaya terlalu kuat pada MyKad.':
          'There is too much glare on the MyKad.',
      'Fail imej MyKad tidak dapat dibaca.':
          'The MyKad image file could not be read.',
      'Nama atau nombor MyKad tidak dapat dibaca dengan yakin.':
          'The name or MyKad number could not be read reliably.',
      'Pastikan potret utama MyKad jelas dan tiada wajah lain kelihatan di luar kad.':
          'Ensure the main MyKad portrait is clear and no other face is visible outside the card.',
      'Fail swafoto tidak dapat dibaca.': 'The selfie file could not be read.',
      'Pastikan hanya satu wajah kelihatan dalam swafoto.':
          'Ensure only one face is visible in the selfie.',
      'Dekatkan wajah kepada kamera dan cuba semula.':
          'Move your face closer to the camera and try again.',
      'Imej wajah tidak dapat dibaca.': 'The face image could not be read.',
      'Kedudukan wajah dalam imej tidak sah.':
          'The face position in the image is invalid.',
      'Respons sesi pengesahan tidak sah.':
          'The verification-session response is invalid.',
      'Token pengesahan tidak diterima.':
          'The verification token was not received.',
      'Pengesahan identiti gagal.': 'Identity verification failed.',
      'Persetujuan privasi diperlukan sebelum pengesahan.':
          'Privacy consent is required before verification.',
      'Nombor MyKad mesti mengandungi 12 digit.':
          'The MyKad number must contain 12 digits.',
      'Pengecam peranti tidak sah.': 'The device identifier is invalid.',
      'Nombor MyKad ini telah didaftarkan.':
          'This MyKad number has already been registered.',
      'Had permintaan dicapai. Cuba semula kemudian.':
          'The request limit has been reached. Try again later.',
      'Sesi pengesahan telah tamat atau tidak sah. Sila mula semula.':
          'The verification session has expired or is invalid. Please start again.',
      'Pengesahan identiti tidak berjaya. Sila cuba semula.':
          'Identity verification was unsuccessful. Please try again.',
      'Kualiti imej MyKad tidak memenuhi syarat. Sila cuba semula.':
          'The MyKad image quality did not meet the requirements. Please try again.',
      'Sesi pengesahan tidak boleh digunakan semula.':
          'The verification session cannot be reused.',
      'AMARAN KECEMASAN (SOS)': 'EMERGENCY WARNING (SOS)',
      'LIHAT LOKASI': 'VIEW LOCATION',
      'Isn': 'Mon',
      'Sel': 'Tue',
      'Rab': 'Wed',
      'Kha': 'Thu',
      'Jum': 'Fri',
      'Sab': 'Sat',
      'Aha': 'Sun',
      'Bahan bukti diperlukan: Sila ambil gambar insiden.':
          'Evidence required: Please take a photo of the incident.',
      'Ralat Sesi: Sila log masuk semula.':
          'Session Error: Please login again.',
      'Jadual Rondaan': 'Patrol Schedule',
      'Jadual Rondaan Akan Datang': 'Upcoming Patrol Schedule',
      'Kumpulan Rondaan Anda': 'Your Patrol Squad',
      'Ketua Kumpulan': 'Squad Leader',
      'Ahli Rondaan': 'Patroller',
      'HARI INI': 'TODAY',
      'Tiada Jadual Ditugaskan': 'No Schedule Assigned',
      'Sila hubungi Ketua KRT untuk penetapan jadual.':
          'Please contact Ketua KRT for schedule assignment.',
      'Tiada ahli dalam kumpulan ini.': 'No members in this squad.',
      'Klik untuk melihat senarai ahli': 'Click to view squad members list',
      'Ketua': 'Leader',
      'Ahli (Peranan)': 'Member',
      'Menyambung ke GPS & Memuat Naik...': 'Connecting to GPS & Uploading...',
      'Laporan Berjaya': 'Report Successful',
      'Data insiden, gambar bukti, dan kordinat GPS telah selamat dihantar ke pelayan utama.':
          'Incident data, photographic evidence, and GPS coordinates have been safely sent to the main server.',
      'Kembali ke Menu': 'Back to Menu',
      'Tambah': 'Add',
      'Kategori Insiden (Carian JPNIN)': 'Incident Category (JPNIN Search)',
      'Cari kategori (cth: Samun, Dadah)...':
          'Search category (e.g., Robbery, Drugs)...',
      'Lapor Insiden': 'Report Incident',
      'RALAT MUAT NAIK:': 'UPLOAD ERROR:',
      'Butiran Insiden': 'Incident Details',
      'Catatan Tambahan': 'Additional Notes',
      'Tiada catatan tambahan direkodkan.': 'No additional notes recorded.',
      'Tambah catatan...': 'Add a note...',
      'Semua Zon': 'All Zones',
      'Tiada peronda dijumpai.': 'No patroller found.',
      'Cari nama peronda...': 'Search patroller name...',
      'Tiada padanan carian.': 'No search match.',
      'Zon': 'Zone',
      'Gagal mengesan lokasi': 'Failed to detect location',
      'Servis lokasi telefon tidak aktif. Sila hidupkan fungsi lokasi dan cuba semula.':
          'Location services are disabled. Please enable location services and try again.',
      'Kebenaran lokasi diperlukan untuk menjana QR. Sila benarkan akses lokasi.':
          'Location permission is required to generate a QR code. Please allow location access.',
      'Kebenaran lokasi telah disekat. Sila benarkan akses lokasi melalui tetapan telefon.':
          'Location permission has been blocked. Please allow location access in your phone settings.',
      'Lokasi mengambil masa terlalu lama untuk dikesan. Sila cuba semula.':
          'Location is taking too long to detect. Please try again.',
      'Lokasi tidak dapat dikesan. Sila cuba semula.':
          'Unable to detect location. Please try again.',
      'Jana QR Kehadiran': 'Generate Attendance QR',
      'Papar kod QR ini kepada peronda untuk merekod kehadiran.':
          'Show this QR code to patrollers to record attendance.',
      'Tamat Tempoh:': 'Expires:',
      'saat': 'seconds',
      'Kod QR Telah Tamat Tempoh': 'QR Code Expired',
      'Sila jana semula kod QR untuk peronda seterusnya.':
          'Please regenerate QR code for the next patroller.',
      'Lokasi Semasa (Pos Utama)': 'Current Location (Main Post)',
      'Pos Utama KRT': 'KRT Main Post',
      'Jana Semula QR': 'Regenerate QR',
      'Tukar Status': 'Change Status',
      'Tukar Peranan': 'Change Role',
      'Tukar': 'Change',
      'Aktif': 'Active',
      'Nyahaktif': 'Inactive',
      'Menunggu': 'Pending',
      'Lulus': 'Approve',
      'Tolak': 'Reject',
      'Lulus Pendaftaran': 'Approve Registration',
      'Ya, Lulus': 'Yes, Approve',
      'Adakah anda pasti ingin meluluskan pendaftaran ahli ini?':
          'Are you sure you want to approve this member\'s registration?',
      'Tolak Pendaftaran': 'Reject Registration',
      'Ya, Tolak': 'Yes, Reject',
      'Adakah anda pasti ingin menolak pendaftaran ahli ini?':
          'Are you sure you want to reject this member\'s registration?',
      'Tiada ahli menunggu pengesahan.': 'No members awaiting approval.',
      'Semua pendaftaran baharu telah diluluskan.':
          'All new registrations have been approved.',
      'Tiada ahli nyahaktif.': 'No inactive members.',
      'Semua ahli berdaftar adalah aktif atau menunggu pengesahan.':
          'All registered members are active or pending approval.',
      'Tapis Pengurusan Ahli': 'Filter Member Management',
      'Tapis Laporan Insiden': 'Filter Incident Reports',
      'Tapis Kumpulan': 'Filter Squads',
      'Cari kumpulan atau ahli...': 'Search squad or member...',
      'Ketua Peronda': 'Squad Leader',
      'Pilih Ketua Peronda': 'Select Squad Leader',
      'Nama Kumpulan diperlukan.': 'Squad name is required.',
      'Pilih negeri dan daerah untuk kumpulan ini.':
          'Select a state and district for this squad.',
      'Pilih daerah dan ketua peronda dahulu.':
          'Select a district and squad leader first.',
      'Pilih 2 hingga 20 peronda.': 'Select 2 to 20 patrollers.',
      'Maksimum 20 peronda dibenarkan.':
          'A maximum of 20 patrollers is allowed.',
      'Pilih Status Baru': 'Select New Status',
      'Pilih Peranan Baru': 'Select New Role',
      'Kemas kini berjaya': 'Update successful',
      'Kemas kini gagal': 'Update failed',
      'Mengesahkan...': 'Authenticating...',
      'Menyimpan...': 'Saving...',
      'Mendapatkan Kunci Satelit GPS...': 'Acquiring GPS Satellite Lock...',
      'Pilih Peralatan': 'Select Equipment',
      'Tandakan peralatan yang anda ambil dari Pos Utama.':
          'Mark the equipment you take from the Main Post.',
      'Tiada peralatan direkodkan.': 'No equipment recorded.',
      'Tinggal': 'Remaining',
      'Sahkan & Mula Shif': 'Confirm & Start Shift',
      'Inventori': 'Inventory',
      'Rekod Log': 'Usage Logs',
      'Diambil': 'Borrowed',
      'Dipulangkan': 'Returned',
      'Telah Dipulangkan': 'Returned',
      'Sedang Digunakan': 'In Use',
      'Log & Inventori Peralatan': 'Equipment Inventory & Logs',
      'Cuba Lagi': 'Try Again',
      'Urus Peralatan': 'Manage Equipment',
      'Peralatan': 'Equipment',
      'Tambah Peralatan': 'Add Equipment',
      'Nama Peralatan': 'Equipment Name',
      'Kuantiti': 'Quantity',
      'Nama peralatan tidak boleh kosong': 'Equipment name cannot be empty',
      'Kuantiti tidak boleh kosong': 'Quantity cannot be empty',
      'Sila masukkan kuantiti yang sah': 'Please enter a valid quantity',
      'Simpan': 'Save',
      'Kemaskini Peralatan': 'Update Equipment',
      'Padam Peralatan': 'Delete Equipment',
      'Adakah anda pasti mahu memadam peralatan':
          'Are you sure you want to delete equipment',
      'Ini juga akan memadam semua log yang berkaitan.':
          'This will also delete all associated logs.',
      'Tiada rekod penggunaan peralatan.': 'No equipment usage logs recorded.',
      'Jumlah': 'Total',
      'Dipinjam': 'Borrowed',
      'Lihat Semua': 'View All',
      'Senarai Peralatan Dipinjam': 'List of Borrowed Equipment',
      'Monitor & Analitik': 'Monitor & Analytics',
      'Paparan pemantauan rondaan dan trend insiden semasa.':
          'Display of patrol monitoring and current incident trends.',
      'Insiden (Minggu)': 'Incidents (Week)',
      'Shif Aktif': 'Active Shifts',
      'Peronda Terdaftar': 'Registered Patrollers',
      'JANA LAPORAN LAMPIRAN 6': 'Generate monthly report',
      'JANA BUKU KEDATANGAN SRS': 'Generate attendance book',
      'Borang Lampiran D3(C)': 'Monthly Report',
      'Buku Rekod Kedatangan SRS': 'SRS Attendance Record Book',
      'Rondaan Aktif Semasa': 'Current Active Patrols',
      'Tiada rondaan aktif dijalankan ketika ini.':
          'No active patrols running at this time.',
      'Tiada Kumpulan': 'No Squad',
      'Kumpulan': 'Squad',
      'Mula': 'Start',
      'Penjadualan': 'Scheduling',
      'Kumpulan berjaya dicipta!': 'Squad created successfully!',
      'Ralat mencipta kumpulan': 'Error creating squad',
      'Ahli berjaya ditambah!': 'Member added successfully!',
      'Ralat menambah ahli': 'Error adding member',
      'Ahli berjaya dikeluarkan!': 'Member removed successfully!',
      'Ralat mengeluarkan ahli': 'Error removing member',
      'Kumpulan dipadam!': 'Squad deleted!',
      'Ralat memadam kumpulan': 'Error deleting squad',
      'Cipta Kumpulan Baru': 'Create New Squad',
      'Nama Kumpulan': 'Squad Name',
      'Simpan Kumpulan': 'Save Squad',
      'Pilih Peronda': 'Select Patroller',
      'Tiada peronda dijumpai': 'No patrollers found',
      'Telah ditugaskan ke:': 'Already assigned to:',
      'Terkunci': 'Locked',
      'Pilih': 'Select',
      'Ralat memuat senarai:': 'Error loading list:',
      'Tiada Kumpulan Direkodkan': 'No Squads Recorded',
      'Padam Kumpulan': 'Delete Squad',
      'Adakah anda pasti untuk memadam kumpulan':
          'Are you sure you want to delete squad',
      'Semua data ahli dan jadual berkaitan kumpulan ini akan dipadam.':
          'All member data and schedules related to this squad will be deleted.',
      'Belum ada ahli.': 'No members yet.',
      'Keluarkan Ahli': 'Remove Member',
      'Adakah anda pasti untuk mengeluarkan': 'Are you sure you want to remove',
      'daripada kumpulan?': 'from the squad?',
      'Keluarkan': 'Remove',
      'Tambah Ahli': 'Add Member',
      'Jadual berjaya ditetap!': 'Schedule set successfully!',
      'Ralat menetapkan jadual': 'Error setting schedule',
      'Jadual berjaya dipadam!': 'Schedule deleted successfully!',
      'Ralat memadam jadual': 'Error deleting schedule',
      'Ralat memuatkan kumpulan:': 'Error loading squads:',
      'Sila cipta kumpulan terlebih dahulu!': 'Please create a squad first!',
      'Tetapkan Jadual Rondaan': 'Set Patrol Schedule',
      'Pilih Kumpulan': 'Select Squad',
      'Tarikh Rondaan': 'Patrol Date',
      'Masa Mula Rondaan': 'Patrol Start Time',
      'Masa Tamat Rondaan': 'Patrol End Time',
      'Simpan Jadual': 'Save Schedule',
      'Tiada Jadual Rondaan Direkodkan': 'No Patrol Schedules Recorded',
      'Kumpulan Tanpa Nama': 'Unnamed Squad',
      'Adakah anda pasti untuk memadam jadual rondaan bagi kumpulan':
          'Are you sure you want to delete the patrol schedule for squad',
      'pada tarikh': 'on date',
      'Jadual & Skuad': 'Schedules & Squads',
      'Maklumat Peribadi': 'Personal Information',
      'Gagal memuat turun profil.': 'Failed to load profile.',
      'Selamat Pagi': 'Good Morning',
      'Selamat Tengah Hari': 'Good Noon',
      'Selamat Petang': 'Good Afternoon',
      'Selamat Malam': 'Good Night',
      'Laporan Saya': 'My Reports',
      'Sedia': 'Ready',
      'Status': 'Status',
      'Bulanan': 'Monthly',
      'Jenayah Kekerasan': 'Violent Crime',
      'Jenayah Harta Benda': 'Property Crime',
      'Narkotik & Sosial': 'Narcotics & Social Issues',
      'Gejala Sosial': 'Social Issues',
      'Tukarkan Shif': 'Change Shift',
      'Tamatkan Rondaan': 'End Patrol',
      'Sedia Untuk Rondaan': 'Ready for Patrol',
      'Tekan untuk memulakan rondaan': 'Tap to start patrolling',
      'Hotspot Kawasan (Zon)': 'Hotspot Areas (Zones)',
      'Peratusan Kategori Jenayah': 'Crime Category Percentages',
      'Pecahan Mengikut Kategori': 'Breakdown by Category',
      'Rondaan & Keberkesanan': 'Patrols & Effectiveness',
      'Lain-lain': 'Others',
      'QR Tamat Tempoh': 'QR Expired',
      'Kod QR ini telah tamat tempoh pelindungan (60 saat). Sila minta Ketua memaparkan Kod QR yang baharu untuk mengelakkan penipuan tangkapan skrin.':
          'This QR code has expired (60 seconds). Please ask the Leader to display a new QR Code to prevent screenshot fraud.',
    },
    'ms': {
      'Dashboard': 'Dashboard',
      'Insiden': 'Insiden',
      'Laporan': 'Laporan',
      'Rondaan': 'Rondaan',
      'Log Insiden': 'Log Insiden',
      'Pengesahan Rondaan': 'Pengesahan Rondaan',
      'Laporan Peronda': 'Laporan Peronda',
      'Suapan Insiden': 'Suapan Insiden',
      'Pantau Analitik': 'Pantau Analitik',
      'Super Admin': 'Super Admin',
      'Pengurusan Lokasi': 'Pengurusan Lokasi',
      'Skop Daerah': 'Skop Daerah',
      'Semua Negeri': 'Semua Negeri',
      'Semua Daerah': 'Semua Daerah',
      'Tukar Kata Laluan': 'Tukar Kata Laluan',
      'Kata Laluan Sementara': 'Kata Laluan Sementara',
      'Sila tetapkan kata laluan baharu sebelum meneruskan.':
          'Sila tetapkan kata laluan baharu sebelum meneruskan.',
      'Kata Laluan Semasa': 'Kata Laluan Semasa',
      'Kata Laluan Baharu': 'Kata Laluan Baharu',
      'Sahkan Kata Laluan Baharu': 'Sahkan Kata Laluan Baharu',
      'Simpan Kata Laluan': 'Simpan Kata Laluan',
      'Kata laluan berjaya ditukar': 'Kata laluan berjaya ditukar',
      'Kata laluan gagal ditukar': 'Kata laluan gagal ditukar',
      'Minimum 8 aksara': 'Minimum 8 aksara',
      'Kata laluan tidak sepadan': 'Kata laluan tidak sepadan',
      'Medan ini diperlukan': 'Medan ini diperlukan',
      'Edit Profil Ahli': 'Edit Profil Ahli',
      'Edit Profil': 'Edit Profil',
      'Pindah Lokasi Ahli': 'Pindah Lokasi Ahli',
      'Pindah Lokasi': 'Pindah Lokasi',
      'Reset Kata Laluan': 'Reset Kata Laluan',
      'Perlu Tukar Kata Laluan': 'Reset Kata Laluan',
      'Menunggu Kelulusan': 'Menunggu Kelulusan',
      'Pendaftaran baharu memerlukan semakan':
          'Pendaftaran baharu memerlukan semakan',
      'Jana kata laluan sementara untuk': 'Jana kata laluan sementara untuk',
      'Cari nama, IC, telefon atau e-mel...':
          'Cari nama, IC, telefon atau e-mel...',
      'Quick Access': 'Akses Pantas',
      'Buka Akses Pantas': 'Buka Akses Pantas',
      'Tutup Akses Pantas': 'Tutup Akses Pantas',
      'Namakan Semula': 'Namakan Semula',
      'Nyahaktifkan': 'Nyahaktifkan',
      'Nyahaktifkan Lokasi': 'Nyahaktifkan Lokasi',
      'Lokasi ini digunakan oleh rekod sedia ada':
          'Lokasi ini digunakan oleh rekod sedia ada',
      'Rekod lama akan dikekalkan, tetapi lokasi ini tidak akan muncul untuk pendaftaran baharu.':
          'Rekod lama akan dikekalkan, tetapi lokasi ini tidak akan muncul untuk pendaftaran baharu.',
      'Lokasi ini tidak akan muncul untuk pendaftaran baharu.':
          'Lokasi ini tidak akan muncul untuk pendaftaran baharu.',
      'Aktifkan': 'Aktifkan',
      'Tambah Negeri': 'Tambah Negeri',
      'Tambah Daerah': 'Tambah Daerah',
      'Tambah Zon': 'Tambah Zon',
      'Kod': 'Kod',
      'Kod Negeri': 'Kod Negeri',
      'Nama': 'Nama',
      'Nama Negeri': 'Nama Negeri',
      'Pindah': 'Pindah',
      'Pemantauan semua kawasan SRS': 'Pemantauan semua kawasan SRS',
      'Muat Semula': 'Muat Semula',
      'Ringkasan Pantas': 'Ringkasan Pantas',
      'Belum dikemas kini': 'Belum dikemas kini',
      'Skop Semasa': 'Skop Semasa',
      'Dikemas kini': 'Dikemas kini',
      'Malaysia • Semua Negeri • Semua Daerah • Semua Zon':
          'Malaysia • Semua Negeri • Semua Daerah • Semua Zon',
      'Tukar Skop': 'Tukar Skop',
      'Perlu Tindakan': 'Perlu Tindakan',
      'Jumlah Pengguna': 'Jumlah Pengguna',
      'Akaun Menunggu': 'Akaun Menunggu',
      'Akaun baharu memerlukan semakan.': 'Akaun baharu memerlukan semakan.',
      'Pemulangan Menunggu': 'Pemulangan Menunggu',
      'Pemulangan rondaan menunggu pengesahan.':
          'Pemulangan rondaan menunggu pengesahan.',
      'Insiden Hari Ini': 'Insiden Hari Ini',
      'Catatan hari ini untuk perhatian.': 'Catatan hari ini untuk perhatian.',
      'Negeri': 'Negeri',
      'Negeri Diliputi': 'Negeri Diliputi',
      'Senarai Ketua KRT': 'Senarai Ketua KRT',
      'Tiada Ketua KRT direkodkan.': 'Tiada Ketua KRT direkodkan.',
      'Liputan Daerah': 'Liputan Daerah',
      'Tiada liputan daerah direkodkan.': 'Tiada liputan daerah direkodkan.',
      'Pembersihan data diperlukan': 'Pembersihan data diperlukan',
      '1 lokasi legasi perlu disemak.': '1 lokasi legasi perlu disemak.',
      'lokasi legasi perlu disemak.': '{count} lokasi legasi perlu disemak.',
      'Semak': 'Semak',
      'Malaysia': 'Malaysia',
      'Semua negeri, daerah dan zon': 'Semua negeri, daerah dan zon',
      'Negeri • Daerah • Zon': 'Negeri • Daerah • Zon',
      'Penapis skop belum disambungkan.': 'Penapis skop belum disambungkan.',
      'Cari Ketua KRT...': 'Cari Ketua KRT...',
      'Cari daerah...': 'Cari daerah...',
      'Cari rekod...': 'Cari rekod...',
      'Tiada data legasi.': 'Tiada data legasi.',
      'zon': 'zon',
      'ahli': 'ahli',
      'KRT': 'KRT',
      'Jana Kod QR': 'Jana Kod QR',
      'Laporan Insiden': 'Laporan Insiden',
      'Pengurusan Ahli': 'Pengurusan Ahli',
      'Notifikasi': 'Notifikasi',
      'Tiada notifikasi baharu': 'Tiada notifikasi baharu',
      'Jana QR Clock Out': 'Jana QR Clock Out',
      'Penjanaan QR': 'Penjanaan QR',
      'Tekan Clock In atau Clock Out untuk terus menjana kod.':
          'Tekan Clock In atau Clock Out untuk terus menjana kod.',
      'Tekan Clock In atau Clock Out untuk menjana QR 60 saat.':
          'Tekan Clock In atau Clock Out untuk menjana QR 60 saat.',
      'Jana semula QR?': 'Jana semula QR?',
      'Tukar mod QR?': 'Tukar mod QR?',
      'QR semasa masih aktif. Jana semula akan membatalkan kod yang sedang berjalan.':
          'QR semasa masih aktif. Jana semula akan membatalkan kod yang sedang berjalan.',
      'QR semasa masih aktif. Menukar mod akan membatalkan kod yang sedang berjalan.':
          'QR semasa masih aktif. Menukar mod akan membatalkan kod yang sedang berjalan.',
      'Teruskan': 'Teruskan',
      'Mod QR': 'Mod QR',
      'Tempoh': 'Tempoh',
      'Papar kod QR ini di pos untuk pengesahan pulang peronda.':
          'Papar kod QR ini di pos untuk pengesahan pulang peronda.',
      'Clock In': 'Clock In',
      'Clock Out': 'Clock Out',
      'Sila jana semula kod QR untuk pemulangan seterusnya.':
          'Sila jana semula kod QR untuk pemulangan seterusnya.',
      'Pengesahan Pemulangan': 'Pengesahan Pemulangan',
      'Pemulangan': 'Pemulangan',
      'Diminta pada': 'Diminta pada',
      'Tiada pemulangan menunggu pengesahan.':
          'Tiada pemulangan menunggu pengesahan.',
      'Tiada peralatan dipinjam': 'Tiada peralatan dipinjam',
      'Sahkan Pemulangan': 'Sahkan Pemulangan',
      'Pemulangan peronda telah disahkan.':
          'Pemulangan peronda telah disahkan.',
      'Pemulangan telah disahkan.': 'Pemulangan telah disahkan.',
      'Gagal memuatkan pemulangan.': 'Gagal memuatkan pemulangan.',
      'Gagal mengesahkan pemulangan.': 'Gagal mengesahkan pemulangan.',
      'Gagal memuatkan peralatan dipinjam.':
          'Gagal memuatkan peralatan dipinjam.',
      'Sahkan Pemulangan Peralatan': 'Sahkan Pemulangan Peralatan',
      'Tandakan semua peralatan yang telah diserahkan kepada Ketua KRT.':
          'Tandakan semua peralatan yang telah diserahkan kepada Ketua KRT.',
      'Tandakan semua peralatan yang telah diserahkan kepada Ketua Peronda atau Ketua KRT.':
          'Tandakan semua peralatan yang telah diserahkan kepada Ketua Peronda atau Ketua KRT.',
      'Tiada peralatan dipinjam untuk shif ini.':
          'Tiada peralatan dipinjam untuk shif ini.',
      'Pemulangan tidak dapat disahkan.': 'Pemulangan tidak dapat disahkan.',
      'Menunggu pengesahan Ketua KRT.': 'Menunggu pengesahan Ketua KRT.',
      'Menunggu Pengesahan Ketua KRT': 'Menunggu Pengesahan Ketua KRT',
      'Menunggu Pengesahan Ketua Peronda/KRT':
          'Menunggu Pengesahan Ketua Peronda/KRT',
      'Pemulangan anda sedang menunggu pengesahan Ketua KRT.':
          'Pemulangan anda sedang menunggu pengesahan Ketua KRT.',
      'Pemulangan anda sedang menunggu pengesahan Ketua Peronda atau Ketua KRT.':
          'Pemulangan anda sedang menunggu pengesahan Ketua Peronda atau Ketua KRT.',
      'Pemulangan anda telah dihantar. Sila tunggu Ketua KRT mengesahkan penerimaan peralatan.':
          'Pemulangan anda telah dihantar. Sila tunggu Ketua KRT mengesahkan penerimaan peralatan.',
      'Pemulangan anda telah dihantar. Sila tunggu Ketua Peronda atau Ketua KRT mengesahkan penerimaan peralatan.':
          'Pemulangan anda telah dihantar. Sila tunggu Ketua Peronda atau Ketua KRT mengesahkan penerimaan peralatan.',
      'Semak Status Pemulangan': 'Semak Status Pemulangan',
      'Sahkan pemulangan peralatan ahli skuad yang telah selesai rondaan.':
          'Sahkan pemulangan peralatan ahli skuad yang telah selesai rondaan.',
      'Sila kembali ke pos rondaan untuk imbas QR pulang.':
          'Sila kembali ke pos rondaan untuk imbas QR pulang.',
      'Semua peralatan perlu ditanda sebelum tamat syif.':
          'Semua peralatan perlu ditanda sebelum tamat syif.',
      'Sistem sedang mengesahkan...': 'Sistem sedang mengesahkan...',
      'Imbas QR Clock In KRT untuk mula': 'Imbas QR Clock In KRT untuk mula',
      'Menunggu KRT': 'Menunggu KRT',
      'Menunggu Pengesahan': 'Menunggu Pengesahan',
      'MENUNGGU PENGESAHAN': 'MENUNGGU PENGESAHAN',
      'KEMBALI KE PAPAN PEMUKA': 'KEMBALI KE PAPAN PEMUKA',
      'Hantar Pemulangan': 'Hantar Pemulangan',
      'IMBAS QR PULANG': 'IMBAS QR PULANG',
      'Imbas QR Clock Out di Pos Utama': 'Imbas QR Clock Out di Pos Utama',
      'Log Keluar': 'Log Keluar',
      'Profil': 'Profil',
      'Tetapan': 'Tetapan',
      'Tema': 'Tema',
      'Bahasa': 'Bahasa',
      'Sistem': 'Ikut Sistem',
      'Cerah': 'Cerah',
      'Gelap': 'Gelap',
      'Tutup': 'Tutup',
      'Bahasa Melayu': 'Bahasa Melayu',
      'English': 'Bahasa Inggeris',
      'Pantau': 'Pantau',
      'Jana QR': 'Jana QR',
      'Ahli': 'Ahli',
      'Skuad': 'Skuad',
      'Preview': 'Pratonton',
      'Nota': 'Nota',
      'Susunan Prioriti': 'Susunan Prioriti',
      'Abjad (Default)': 'Abjad (Default)',
      'Paling Banyak Nota': 'Paling Banyak Nota',
      'Tiada Nota': 'Tiada Nota',
      // Profile Strings
      'account': 'Akaun',
      'settings': 'Tetapan',
      'profile_photo': 'Gambar Profil',
      'remove_profile_photo': 'Buang Gambar Profil',
      'remove_profile_photo_confirmation':
          'Adakah anda pasti mahu membuang gambar profil anda?',
      'photo_remove_success': 'Gambar profil berjaya dibuang',
      'photo_remove_failed': 'Gagal membuang gambar profil',
      'notifications': 'Notifikasi',
      'allow_external_notifications': 'Benarkan notifikasi luar aplikasi',
      'daily_note_notifications': 'Notifikasi nota harian',
      'sos_alerts': 'Amaran SOS',
      'accessibility': 'Kebolehcapaian',
      'language': 'Bahasa',
      'font_size': 'Saiz Font',
      'high_contrast': 'Kontras Tinggi',
      'coming_soon': 'Akan datang',
      'new_daily_note': 'Nota Harian Baharu',
      'daily_note_received': 'Nota harian diterima',
      'no_notifications': 'Tiada notifikasi',
      'add_daily_note': 'Tambah Nota Harian',
      'Preparing note...': 'Menyediakan nota...',
      'daily_note_saved': 'Nota harian berjaya disimpan',
      'daily_note_saved_message':
          'Nota harian berjaya disimpan. Tekan ikon hantar di Rekod Insiden untuk menghantar kepada Ketua KRT.',
      'report_successful': 'Laporan Berjaya',
      'daily_note_submitted': 'Nota harian berjaya dihantar kepada Ketua KRT.',
      'daily_notes_submitted_count':
          'X nota harian berjaya dihantar kepada Ketua KRT.',
      'submit_daily_note': 'Hantar Nota Harian',
      'save_daily_note': 'Simpan Nota Harian',
      'send_to_krt': 'Hantar kepada Ketua KRT',
      'note_pending_submission': 'Menunggu penghantaran',
      'new_notifications': 'Baharu',
      'notification_history': 'Sejarah',
      'no_new_notifications': 'Tiada notifikasi baharu',
      'no_notification_history': 'Tiada sejarah notifikasi',
      'clear_all': 'Kosongkan Semua',
      'clear_history': 'Sejarah Notifikasi',
      'Clear all notification history?': 'Kosongkan semua sejarah notifikasi?',
      'delete_notification': 'Padam Notifikasi',
      'notification_removed': 'Notifikasi dipadam',
      'unread_notifications': 'Notifikasi belum dibaca',
      'assign_shift': 'Tetapkan Syif',
      'selected_date': 'Tarikh Dipilih',
      'upcoming_schedules': 'Jadual Akan Datang',
      'schedule_history': 'Sejarah Jadual',
      'past_schedules': 'Jadual Lama',
      'current_schedules': 'Jadual Semasa',
      'filter_by_zone': 'Tapis Mengikut Zon',
      'all_zones': 'Semua Zon',
      'calendar': 'Kalendar',
      'today': 'Hari Ini',
      'this_month': 'Bulan Ini',
      'previous_months': 'Bulan Sebelumnya',
      'completed': 'Selesai',
      'upcoming': 'Akan Datang',
      'shift_assigned_success': 'Syif berjaya ditetapkan',
      'schedule_deleted_success': 'Jadual berjaya dipadam',
      'schedule_overlap_error':
          'Skuad ini sudah mempunyai jadual dalam tempoh masa tersebut.',
      'choose_squad': 'Pilih Skuad',
      'choose_date': 'Pilih Tarikh',
      'choose_start_time': 'Pilih Masa Mula',
      'choose_end_time': 'Pilih Masa Tamat',
      'mark_as_read': 'Tanda sudah dibaca',
      'Malay': 'Bahasa Melayu',
      'English Language': 'Bahasa Inggeris',
      'profile': 'Profil',
      'personal_information': 'Maklumat Peribadi',
      'user_id': 'ID Pengguna',
      'account_status': 'Status Akaun',
      'active': 'Aktif',
      'pending': 'Menunggu',
      'inactive': 'Tidak Aktif',
      'ic_number': 'Nombor IC',
      'phone_number': 'Nombor Telefon',
      'email': 'E-mel',
      'role': 'Peranan',
      'state': 'Negeri',
      'district': 'Daerah',
      'zone': 'Zon',
      'squad': 'Skuad',
      'logout': 'Log Keluar',
      'logout_confirmation_title': 'Log Keluar?',
      'logout_confirmation_message':
          'Adakah anda pasti mahu log keluar daripada akaun ini?',
      'cancel': 'Batal',
      'confirm_logout': 'Log Keluar',
      'change_profile_photo': 'Tukar Gambar Profil',
      'upload_photo': 'Muat Naik Gambar',
      'choose_photo': 'Pilih Gambar',
      'photo_upload_success': 'Gambar profil berjaya dikemas kini',
      'photo_upload_failed': 'Gagal memuat naik gambar profil',
      'invalid_image': 'Fail gambar tidak sah',
      'image_too_large': 'Saiz gambar terlalu besar',
      'Nama Penuh': 'Nama Penuh',
      'No. Kad Pengenalan': 'No. Kad Pengenalan',
      'Zon Rondaan': 'Zon Rondaan',
      'No. Telefon': 'No. Telefon',
      'E-mel': 'E-mel',
      'Peranan': 'Peranan',
      'Status Akaun': 'Status Akaun',
      'Sesi tamat. Sila log masuk semula.':
          'Sesi tamat. Sila log masuk semula.',
      'Ralat Pelayan': 'Ralat Pelayan',
      'Ralat Rangkaian': 'Ralat Rangkaian',
      'Cuba Semula': 'Cuba Semula',
      'Tiada data profil': 'Tiada data profil',
      'Tiada': 'Tiada',
      // Dashboard Strings
      'Selamat Datang': 'Selamat Datang',
      'Ringkasan Aktiviti Anda': 'Ringkasan Aktiviti Anda',
      'Tidak Aktif': 'Tidak Aktif',
      'Rondaan Anda': 'Rondaan Anda',
      'Jumlah Nota': 'Jumlah Nota',
      'Status Semasa': 'Status Semasa',
      'Bersedia Untuk Rondaan': 'Bersedia Untuk Rondaan',
      'Tekan untuk mula': 'Tekan untuk mula',
      'Sedang Meronda': 'Sedang Meronda',
      'Papan Pemuka Analitik': 'Papan Pemuka Analitik',
      'Ringkasan insiden dan statistik': 'Ringkasan insiden dan statistik',
      'Total Insiden (Minggu)': 'Total Insiden (Minggu)',
      'Total Rondaan (Minggu)': 'Total Rondaan (Minggu)',
      'Sedia Ada': 'Sedia Ada',
      'Tiada Data Rondaan': 'Tiada Data Rondaan',
      'Trend Insiden (7 Hari Terakhir)': 'Trend Insiden (7 Hari Terakhir)',
      'memerlukan bantuan!': 'memerlukan bantuan!',
      'Masa': 'Masa',
      'Tiada insiden direkodkan.': 'Tiada insiden direkodkan.',
      'LAPOR INSIDEN': 'LAPOR INSIDEN',
      'Tiada Tajuk': 'Tiada Tajuk',
      'MULAKAN SHIF': 'MULAKAN SHIF',
      'Tamatkan Shif Awal': 'Tamatkan Shif Awal',
      'Lokasi Diperlukan': 'Lokasi Diperlukan',
      'Faham & Tutup': 'Faham & Tutup',
      // SOS Strings
      'AMARAN SOS': 'AMARAN SOS',
      'Adakah anda pasti mahu mencetuskan penggera KECEMASAN?':
          'Adakah anda pasti mahu mencetuskan penggera KECEMASAN? Tindakan ini akan menghantar lokasi anda serta-merta kepada semua peronda.',
      'Batal': 'Batal',
      'SAHKAN SOS': 'SAHKAN SOS',
      'Sedang Mengesan GPS & Menyiarkan SOS...':
          'Sedang Mengesan Koordinat GPS & Menyiarkan SOS...',
      'SOS BERJAYA DISIARKAN!': 'SOS BERJAYA DISIARKAN!',
      'RALAT SOS': 'RALAT SOS',
      'GAGAL PENGESANAN GPS': 'GAGAL PENGESANAN GPS',
      'KECEMASAN': 'KECEMASAN!',
      'Seorang peronda memerlukan bantuan SEGERA!':
          'Seorang peronda memerlukan bantuan SEGERA!',
      'Peronda': 'Peronda',
      'Tidak Diketahui': 'Tidak Diketahui',
      'Lokasi': 'Lokasi',
      'GOOGLE MAPS': 'GOOGLE MAPS',
      'LIHAT LOG': 'LIHAT LOG',
      // Login
      'Securing Our Community\nTogether.': 'Bersama Menjaga\nKomuniti Kita.',
      'Welcome to the SRS Patrol Portal. Access your dashboard to manage patrols, report incidents, and keep the neighborhood safe.':
          'Selamat datang ke Portal Rondaan SRS. Log masuk untuk menguruskan rondaan, melapor insiden, dan menjaga keselamatan kawasan.',
      'SRS Patrol Portal': 'Portal Rondaan SRS',
      'Securing Our Community': 'Menjaga Komuniti Kita',
      'Welcome Back': 'Selamat Kembali',
      'Enter your credentials to access your account':
          'Masukkan butiran anda untuk mengakses akaun',
      'Email Address': 'Alamat E-mel',
      'Password': 'Kata Laluan',
      'Forgot password?': 'Lupa kata laluan?',
      'Password Assistance': 'Bantuan Kata Laluan',
      'Please contact Ketua KRT to reset your password or reactivate your account.':
          'Sila hubungi Ketua KRT untuk menetapkan semula kata laluan atau mengaktifkan semula akaun anda.',
      'SECURE LOGIN': 'LOG MASUK',
      "Don't have an account?": 'Tiada akaun?',
      'Register Here': 'Daftar Di Sini',
      // Register
      'Create Your Account': 'Daftar Akaun Anda',
      'Join the SRS patrol team and secure your community':
          'Sertai pasukan rondaan SRS dan jaga komuniti anda',
      'Full Name': 'Nama Penuh',
      'IC Number': 'No. Kad Pengenalan',
      'Patrol Zone': 'Zon Rondaan',
      'Phone Number': 'No. Telefon',
      'Confirm Password': 'Sahkan Kata Laluan',
      'SUBMIT REGISTRATION': 'HANTAR PENDAFTARAN',
      'Already have an account?': 'Sudah mempunyai akaun?',
      'Login Here': 'Log Masuk Di Sini',
      'Pendaftaran Selesai': 'Pendaftaran Selesai',
      'Akaun peronda telah direkodkan. Sila hubungi Ketua KRT untuk pengesahan identiti sebelum log masuk.':
          'Akaun peronda telah direkodkan. Sila hubungi Ketua KRT untuk pengesahan identiti sebelum log masuk.',
      'Pendaftaran ditolak: Borang tidak lengkap atau zon tidak dipilih.':
          'Pendaftaran ditolak: Borang tidak lengkap atau zon tidak dipilih.',
      // Incidents / Misc
      'Sila pilih kategori insiden': 'Sila pilih kategori insiden',
      'Sila masukkan tajuk': 'Sila masukkan tajuk',
      'Penerangan tidak boleh dibiarkan kosong':
          'Penerangan tidak boleh dibiarkan kosong',
      'Kategori Insiden': 'Kategori Insiden',
      'Tajuk Ringkas': 'Tajuk Ringkas',
      'Cth: Pagar rosak di Lorong 4': 'Cth: Pagar rosak di Lorong 4',
      'Keterangan Lanjut': 'Keterangan Lanjut',
      'Terangkan butiran kejadian...': 'Terangkan butiran kejadian...',
      'HANTAR LAPORAN': 'HANTAR LAPORAN',
      'Bukti Bergambar': 'Bukti Bergambar',
      'Ketua KRT': 'Ketua KRT',
      'Sedang Dimuatkan...': 'Sedang Dimuatkan...',
      'Tapis Insiden': 'Tapis Insiden',
      'Tekan di sini untuk mula': 'Tekan di sini untuk mula',
      'Ringkasan Aktiviti': 'Ringkasan Aktiviti',
      'Harian': 'Harian',
      'Mingguan': 'Mingguan',
      'Semua': 'Semua',
      // Added missing keys
      'Join Our Patrol\nNetwork.': 'Sertai Rangkaian\nRondaan Kami.',
      'Click to see available equipment':
          'Klik untuk melihat peralatan tersedia',
      'Register as a patroller to start securing the neighborhood, tracking incidents, and contributing to a safer community.':
          'Daftar sebagai peronda untuk mula menjaga keselamatan kawasan, menjejak insiden, dan menyumbang kepada komuniti yang lebih selamat.',
      'Pendaftaran': 'Pendaftaran',
      'Daftar Peronda Baru': 'Daftar Peronda Baru',
      'Create Account': 'Daftar Akaun',
      'Fill in the details below to register as a patroller.':
          'Lengkapkan butiran di bawah untuk mendaftar sebagai peronda.',
      'Maklumat Identiti': 'Maklumat Identiti',
      'Nama Penuh (Mengikut Kad Pengenalan)':
          'Nama Penuh (Mengikut Kad Pengenalan)',
      'No. Kad Pengenalan (Tanpa Sengkang)':
          'No. Kad Pengenalan (Tanpa Sengkang)',
      'Maklumat Operasi': 'Maklumat Operasi',
      'No. Telefon (Kecemasan)': 'No. Telefon (Kecemasan)',
      'Pilih Sektor / Zon Rondaan': 'Pilih Sektor / Zon Rondaan',
      'Zon rondaan wajib dipilih': 'Zon rondaan wajib dipilih',
      'Kredensial Sistem': 'Kredensial Sistem',
      'Alamat E-mel': 'Alamat E-mel',
      'Kata Laluan': 'Kata Laluan',
      'Ruangan ini wajib diisi': 'Ruangan ini wajib diisi',
      'Kata laluan mesti sekurang-kurangnya 8 aksara.':
          'Kata laluan mesti sekurang-kurangnya 8 aksara.',
      'Kata laluan terlalu panjang. Sila gunakan kurang aksara.':
          'Kata laluan terlalu panjang. Sila gunakan kurang aksara.',
      'Kata laluan tidak boleh mengandungi aksara kawalan.':
          'Kata laluan tidak boleh mengandungi aksara kawalan.',
      'Kata laluan mengandungi aksara tidak sah.':
          'Kata laluan mengandungi aksara tidak sah.',
      'Masukkan nombor telefon yang sah bermula dengan 0 atau +60 (9 hingga 11 digit dalam format tempatan).':
          'Masukkan nombor telefon yang sah bermula dengan 0 atau +60 (9 hingga 11 digit dalam format tempatan).',
      'Tarikh lahir dalam nombor MyKad tidak sah.':
          'Tarikh lahir dalam nombor MyKad tidak sah.',
      'Pendaftaran gagal. Sila cuba lagi.':
          'Pendaftaran gagal. Sila cuba lagi.',
      'Tidak dapat menghubungi pelayan. Sila cuba lagi.':
          'Tidak dapat menghubungi pelayan. Sila cuba lagi.',
      'Current password is incorrect.': 'Kata laluan semasa tidak betul.',
      'Current password and new password are required.':
          'Kata laluan semasa dan kata laluan baharu diperlukan.',
      'HANTAR PERMOHONAN': 'HANTAR PERMOHONAN',
      'Pendaftaran Peronda': 'Pendaftaran Peronda',
      'Lengkapkan butiran di bawah untuk mendaftar.':
          'Lengkapkan butiran di bawah untuk mendaftar.',
      'Sertai Rangkaian\nPeronda Kami.': 'Sertai Rangkaian\nPeronda Kami.',
      'Daftar sebagai peronda SRS untuk membantu menjaga keselamatan dan keharmonian komuniti setempat.':
          'Daftar sebagai peronda SRS untuk membantu menjaga keselamatan dan keharmonian komuniti setempat.',
      'Memuatkan negeri...': 'Memuatkan negeri...',
      'Pilih Negeri': 'Pilih Negeri',
      'Pilih Daerah': 'Pilih Daerah',
      'Pilih Zon Rondaan': 'Pilih Zon Rondaan',
      'Sila pilih negeri': 'Sila pilih negeri',
      'Sila pilih daerah': 'Sila pilih daerah',
      'Sila pilih zon': 'Sila pilih zon',
      'Tidak dapat memuatkan senarai negeri.':
          'Tidak dapat memuatkan senarai negeri.',
      'Tidak dapat memuatkan senarai daerah.':
          'Tidak dapat memuatkan senarai daerah.',
      'Tidak dapat memuatkan senarai zon.':
          'Tidak dapat memuatkan senarai zon.',
      // Pengesahan identiti
      'Pendaftaran Berjaya': 'Pendaftaran Berjaya',
      'Sila hubungi Ketua KRT untuk pengesahan akaun sebelum log masuk.':
          'Sila hubungi Ketua KRT untuk pengesahan akaun sebelum log masuk.',
      'Akaun anda sedang menunggu kelulusan Pentadbir KRT.':
          'Akaun anda sedang menunggu kelulusan Pentadbir KRT.',
      'Pendaftaran anda telah ditolak atau akaun telah dinyahaktifkan.':
          'Pendaftaran anda telah ditolak atau akaun telah dinyahaktifkan.',
      'Invalid credentials.': 'E-mel atau kata laluan tidak sah.',
      'Status akaun berjaya dikemas kini.':
          'Status akaun berjaya dikemas kini.',
      'Status akaun gagal dikemas kini.': 'Status akaun gagal dikemas kini.',
      'Kembali ke Log Masuk': 'Kembali ke Log Masuk',
      'Selesaikan pengesahan MyKad dan wajah sebelum mendaftar.':
          'Selesaikan pengesahan MyKad dan wajah sebelum mendaftar.',
      'Pendaftaran peronda baharu hanya tersedia melalui aplikasi Android iRonda.':
          'Pendaftaran peronda baharu hanya tersedia melalui aplikasi Android iRonda.',
      'Pendaftaran memerlukan Android': 'Pendaftaran memerlukan Android',
      'Pengesahan MyKad diperlukan': 'Pengesahan MyKad diperlukan',
      'Identiti telah disahkan': 'Identiti telah disahkan',
      'Pengesahan MyKad dan wajah menggunakan kamera hanya disokong dalam aplikasi Android iRonda.':
          'Pengesahan MyKad dan wajah menggunakan kamera hanya disokong dalam aplikasi Android iRonda.',
      'Imbas MyKad dan lengkapkan swafoto serta cabaran rawak. Tiada pilihan untuk melangkau langkah ini.':
          'Imbas MyKad dan lengkapkan swafoto serta cabaran rawak. Tiada pilihan untuk melangkau langkah ini.',
      'Nama dan nombor MyKad dikunci berdasarkan keputusan pengesahan. Pilih sendiri negeri, daerah dan zon rondaan anda.':
          'Nama dan nombor MyKad dikunci berdasarkan keputusan pengesahan. Pilih sendiri negeri, daerah dan zon rondaan anda.',
      'Selesaikan pengekstrakan nama dan nombor MyKad sebelum mendaftar.':
          'Selesaikan pengekstrakan nama dan nombor MyKad sebelum mendaftar.',
      'Imbasan MyKad diperlukan': 'Imbasan MyKad diperlukan',
      'Data MyKad telah diekstrak': 'Data MyKad telah diekstrak',
      'Pengimbasan MyKad menggunakan kamera hanya disokong dalam aplikasi Android iRonda.':
          'Pengimbasan MyKad menggunakan kamera hanya disokong dalam aplikasi Android iRonda.',
      'Imbas MyKad untuk mengekstrak nama penuh dan nombor MyKad. Tiada swafoto atau perbandingan wajah dilakukan.':
          'Imbas MyKad untuk mengekstrak nama penuh dan nombor MyKad. Tiada swafoto atau perbandingan wajah dilakukan.',
      'Nama dan nombor MyKad dikunci berdasarkan data yang diekstrak. Pilih sendiri negeri, daerah dan zon rondaan anda.':
          'Nama dan nombor MyKad dikunci berdasarkan data yang diekstrak. Pilih sendiri negeri, daerah dan zon rondaan anda.',
      'MULA IMBASAN': 'MULA IMBASAN',
      'ULANG IMBASAN': 'ULANG IMBASAN',
      'ANDROID DIPERLUKAN': 'ANDROID DIPERLUKAN',
      'MULA PENGESAHAN': 'MULA PENGESAHAN',
      'ULANG PENGESAHAN': 'ULANG PENGESAHAN',
      'Nama Penuh (Mengikut MyKad)': 'Nama Penuh (Mengikut MyKad)',
      'Pengesahan Identiti': 'Pengesahan Identiti',
      'Pengekstrakan Data MyKad': 'Pengekstrakan Data MyKad',
      'Pengekstrakan prototaip — bukan pengesahan pemilik MyKad':
          'Pengekstrakan prototaip — bukan pengesahan pemilik MyKad',
      'Tujuan: membaca nama penuh dan nombor MyKad untuk mengisi borang pendaftaran.\n\nData diproses: imej MyKad, nama penuh dan nombor MyKad. Tiada swafoto, pengesanan hidup atau perbandingan wajah dilakukan.\n\nPrivasi: imej MyKad diproses pada peranti dan tidak dihantar ke pelayan. Fail imej sementara dipadam apabila proses tamat atau skrin ini ditutup. Anda boleh membatalkan sebelum bersetuju.':
          'Tujuan: membaca nama penuh dan nombor MyKad untuk mengisi borang pendaftaran.\n\nData diproses: imej MyKad, nama penuh dan nombor MyKad. Tiada swafoto, pengesanan hidup atau perbandingan wajah dilakukan.\n\nPrivasi: imej MyKad diproses pada peranti dan tidak dihantar ke pelayan. Fail imej sementara dipadam apabila proses tamat atau skrin ini ditutup. Anda boleh membatalkan sebelum bersetuju.',
      'Pengekstrakan data MyKad hanya tersedia melalui aplikasi Android iRonda.':
          'Pengekstrakan data MyKad hanya tersedia melalui aplikasi Android iRonda.',
      'Saya bersetuju dengan pemprosesan sementara MyKad untuk mengekstrak nama penuh dan nombor MyKad bagi pendaftaran iRonda.':
          'Saya bersetuju dengan pemprosesan sementara MyKad untuk mengekstrak nama penuh dan nombor MyKad bagi pendaftaran iRonda.',
      'Imbas dan baca MyKad': 'Imbas dan baca MyKad',
      'Pegang telefon secara menegak atau melintang. Kualiti imej akan diperiksa sebelum nama penuh dan nombor MyKad dibaca.':
          'Pegang telefon secara menegak atau melintang. Kualiti imej akan diperiksa sebelum nama penuh dan nombor MyKad dibaca.',
      'Menyemak kualiti dan membaca nama serta nombor MyKad...':
          'Menyemak kualiti dan membaca nama serta nombor MyKad...',
      'Semak Maklumat Diekstrak': 'Semak Maklumat Diekstrak',
      'Pastikan nama penuh dan nombor MyKad berikut sepadan dengan kad anda.':
          'Pastikan nama penuh dan nombor MyKad berikut sepadan dengan kad anda.',
      'Nombor MyKad': 'Nombor MyKad',
      'Tiada maklumat dihantar ke pelayan sehingga anda memilih BETUL.':
          'Tiada maklumat dihantar ke pelayan sehingga anda memilih BETUL.',
      'IMBAS SEMULA': 'IMBAS SEMULA',
      'BETUL': 'BETUL',
      'Menyediakan sesi pendaftaran...': 'Menyediakan sesi pendaftaran...',
      'Imbasan MyKad telah tamat. Sila imbas semula sebelum mendaftar.':
          'Imbasan MyKad telah tamat. Sila imbas semula sebelum mendaftar.',
      'Selaraskan MyKad di dalam bingkai': 'Selaraskan MyKad di dalam bingkai',
      'Pastikan keempat-empat penjuru kelihatan, teks jelas dan tiada silau sebelum mengambil gambar.':
          'Pastikan keempat-empat penjuru kelihatan, teks jelas dan tiada silau sebelum mengambil gambar.',
      'AMBIL GAMBAR': 'AMBIL GAMBAR',
      'Gambar tidak dapat diambil. Sila cuba semula.':
          'Gambar tidak dapat diambil. Sila cuba semula.',
      'Kamera tidak dapat dibuka. Semak kebenaran kamera dan cuba semula.':
          'Kamera tidak dapat dibuka. Semak kebenaran kamera dan cuba semula.',
      'CUBA SEMULA': 'CUBA SEMULA',
      'Pengesahan prototaip — bukan e-KYC rasmi':
          'Pengesahan prototaip — bukan e-KYC rasmi',
      'Tujuan: mengesahkan identiti peronda semasa pendaftaran.\n\nData diproses: imej MyKad, nama, nombor MyKad, swafoto, tindakan hidup dan skor persamaan wajah.\n\nPrivasi: imej dan vektor wajah diproses pada peranti dan tidak dihantar ke pelayan. Pelayan hanya menerima hasil pengesahan dan maklumat pendaftaran yang diperlukan. Fail imej sementara dipadam apabila percubaan tamat atau skrin ini ditutup. Anda boleh membatalkan sebelum bersetuju.':
          'Tujuan: mengesahkan identiti peronda semasa pendaftaran.\n\nData diproses: imej MyKad, nama, nombor MyKad, swafoto, tindakan hidup dan skor persamaan wajah.\n\nPrivasi: imej dan vektor wajah diproses pada peranti dan tidak dihantar ke pelayan. Pelayan hanya menerima hasil pengesahan dan maklumat pendaftaran yang diperlukan. Fail imej sementara dipadam apabila percubaan tamat atau skrin ini ditutup. Anda boleh membatalkan sebelum bersetuju.',
      'Pendaftaran peronda dengan pengesahan identiti hanya tersedia melalui aplikasi Android iRonda.':
          'Pendaftaran peronda dengan pengesahan identiti hanya tersedia melalui aplikasi Android iRonda.',
      'Saya bersetuju dengan pemprosesan sementara MyKad dan wajah seperti yang diterangkan di atas untuk tujuan pendaftaran iRonda. Persetujuan ini diperlukan untuk meneruskan.':
          'Saya bersetuju dengan pemprosesan sementara MyKad dan wajah seperti yang diterangkan di atas untuk tujuan pendaftaran iRonda. Persetujuan ini diperlukan untuk meneruskan.',
      'Imbas MyKad': 'Imbas MyKad',
      'Putar telefon ke kedudukan melintang. Kualiti, OCR dan potret utama MyKad akan diperiksa.':
          'Putar telefon ke kedudukan melintang. Kualiti, OCR dan potret utama MyKad akan diperiksa.',
      'Swafoto neutral': 'Swafoto neutral',
      'Pandang kamera dengan kedua-dua mata terbuka.':
          'Pandang kamera dengan kedua-dua mata terbuka.',
      'Cabaran rawak': 'Cabaran rawak',
      'Pejamkan kedua-dua mata dan ambil swafoto.':
          'Pejamkan kedua-dua mata dan ambil swafoto.',
      'Pusingkan kepala ke kiri atau kanan dan ambil swafoto.':
          'Pusingkan kepala ke kiri atau kanan dan ambil swafoto.',
      'MEMPROSES...': 'MEMPROSES...',
      'IMBAS MYKAD': 'IMBAS MYKAD',
      'AMBIL SWAFOTO': 'AMBIL SWAFOTO',
      'LAKSANAKAN CABARAN': 'LAKSANAKAN CABARAN',
      'Sediakan MyKad': 'Sediakan MyKad',
      'Anda boleh memegang telefon secara menegak atau melintang. Letakkan MyKad secara mendatar di dalam bingkai dan pastikan seluruh kad, termasuk keempat-empat penjuru, berada dalam bingkai. Elakkan silau dan pegang telefon dengan stabil.':
          'Anda boleh memegang telefon secara menegak atau melintang. Letakkan MyKad secara mendatar di dalam bingkai dan pastikan seluruh kad, termasuk keempat-empat penjuru, berada dalam bingkai. Elakkan silau dan pegang telefon dengan stabil.',
      'BATAL': 'BATAL',
      'BUKA KAMERA': 'BUKA KAMERA',
      'AMARAN KECEMASAN (SOS)': 'AMARAN KECEMASAN (SOS)',
      'LIHAT LOKASI': 'LIHAT LOKASI',
      'Isn': 'Isn',
      'Sel': 'Sel',
      'Rab': 'Rab',
      'Kha': 'Kha',
      'Jum': 'Jum',
      'Sab': 'Sab',
      'Aha': 'Aha',
      'Bahan bukti diperlukan: Sila ambil gambar insiden.':
          'Bahan bukti diperlukan: Sila ambil gambar insiden.',
      'Ralat Sesi: Sila log masuk semula.':
          'Ralat Sesi: Sila log masuk semula.',
      'Jadual Rondaan': 'Jadual Rondaan',
      'Jadual Rondaan Akan Datang': 'Jadual Rondaan Akan Datang',
      'Kumpulan Rondaan Anda': 'Kumpulan Rondaan Anda',
      'Ketua Kumpulan': 'Ketua Kumpulan',
      'Ahli Rondaan': 'Ahli Rondaan',
      'HARI INI': 'HARI INI',
      'Tiada Jadual Ditugaskan': 'Tiada Jadual Ditugaskan',
      'Sila hubungi Ketua KRT untuk penetapan jadual.':
          'Sila hubungi Ketua KRT untuk penetapan jadual.',
      'Tiada ahli dalam kumpulan ini.': 'Tiada ahli dalam kumpulan ini.',
      'Klik untuk melihat senarai ahli': 'Klik untuk melihat senarai ahli',
      'Ketua': 'Ketua',
      'Ahli (Peranan)': 'Ahli',
      'Menyambung ke GPS & Memuat Naik...':
          'Menyambung ke GPS & Memuat Naik...',
      'Laporan Berjaya': 'Laporan Berjaya',
      'Data insiden, gambar bukti, dan kordinat GPS telah selamat dihantar ke pelayan utama.':
          'Data insiden, gambar bukti, dan kordinat GPS telah selamat dihantar ke pelayan utama.',
      'Kembali ke Menu': 'Kembali ke Menu',
      'Tambah': 'Tambah',
      'Kategori Insiden (Carian JPNIN)': 'Kategori Insiden (Carian JPNIN)',
      'Cari kategori (cth: Samun, Dadah)...':
          'Cari kategori (cth: Samun, Dadah)...',
      'Lapor Insiden': 'Lapor Insiden',
      'RALAT MUAT NAIK:': 'RALAT MUAT NAIK:',
      'Butiran Insiden': 'Butiran Insiden',
      'Catatan Tambahan': 'Catatan Tambahan',
      'Tiada catatan tambahan direkodkan.':
          'Tiada catatan tambahan direkodkan.',
      'Tambah catatan...': 'Tambah catatan...',
      'Semua Zon': 'Semua Zon',
      'Tiada peronda dijumpai.': 'Tiada peronda dijumpai.',
      'Cari nama peronda...': 'Cari nama peronda...',
      'Tiada padanan carian.': 'Tiada padanan carian.',
      'Zon': 'Zon',
      'Gagal mengesan lokasi': 'Gagal mengesan lokasi',
      'Jana QR Kehadiran': 'Jana QR Kehadiran',
      'Papar kod QR ini kepada peronda untuk merekod kehadiran.':
          'Papar kod QR ini kepada peronda untuk merekod kehadiran.',
      'Tamat Tempoh:': 'Tamat Tempoh:',
      'saat': 'saat',
      'Kod QR Telah Tamat Tempoh': 'Kod QR Telah Tamat Tempoh',
      'Sila jana semula kod QR untuk peronda seterusnya.':
          'Sila jana semula kod QR untuk peronda seterusnya.',
      'Lokasi Semasa (Pos Utama)': 'Lokasi Semasa (Pos Utama)',
      'Pos Utama KRT': 'Pos Utama KRT',
      'Jana Semula QR': 'Jana Semula QR',
      'Tukar Status': 'Tukar Status',
      'Tukar Peranan': 'Tukar Peranan',
      'Tukar': 'Tukar',
      'Aktif': 'Aktif',
      'Nyahaktif': 'Nyahaktif',
      'Menunggu': 'Menunggu Pengesahan',
      'Lulus': 'Lulus',
      'Tolak': 'Tolak',
      'Lulus Pendaftaran': 'Lulus Pendaftaran',
      'Ya, Lulus': 'Ya, Lulus',
      'Adakah anda pasti ingin meluluskan pendaftaran ahli ini?':
          'Adakah anda pasti ingin meluluskan pendaftaran ahli ini?',
      'Tolak Pendaftaran': 'Tolak Pendaftaran',
      'Ya, Tolak': 'Ya, Tolak',
      'Adakah anda pasti ingin menolak pendaftaran ahli ini?':
          'Adakah anda pasti ingin menolak pendaftaran ahli ini?',
      'Tiada ahli menunggu pengesahan.': 'Tiada ahli menunggu pengesahan.',
      'Semua pendaftaran baharu telah diluluskan.':
          'Semua pendaftaran baharu telah diluluskan.',
      'Tiada ahli nyahaktif.': 'Tiada ahli nyahaktif.',
      'Semua ahli berdaftar adalah aktif atau menunggu pengesahan.':
          'Semua ahli berdaftar adalah aktif atau menunggu pengesahan.',
      'Tapis Pengurusan Ahli': 'Tapis Pengurusan Ahli',
      'Tapis Laporan Insiden': 'Tapis Laporan Insiden',
      'Tapis Kumpulan': 'Tapis Kumpulan',
      'Cari kumpulan atau ahli...': 'Cari kumpulan atau ahli...',
      'Ketua Peronda': 'Ketua Peronda',
      'Pilih Ketua Peronda': 'Pilih Ketua Peronda',
      'Nama Kumpulan diperlukan.': 'Nama Kumpulan diperlukan.',
      'Pilih negeri dan daerah untuk kumpulan ini.':
          'Pilih negeri dan daerah untuk kumpulan ini.',
      'Pilih daerah dan ketua peronda dahulu.':
          'Pilih daerah dan ketua peronda dahulu.',
      'Pilih 2 hingga 20 peronda.': 'Pilih 2 hingga 20 peronda.',
      'Maksimum 20 peronda dibenarkan.': 'Maksimum 20 peronda dibenarkan.',
      'Pilih Status Baru': 'Pilih Status Baru',
      'Pilih Peranan Baru': 'Pilih Peranan Baru',
      'Kemas kini berjaya': 'Kemas kini berjaya',
      'Kemas kini gagal': 'Kemas kini gagal',
      'Mengesahkan...': 'Mengesahkan...',
      'Menyimpan...': 'Menyimpan...',
      'Mendapatkan Kunci Satelit GPS...': 'Mendapatkan Kunci Satelit GPS...',
      'Pilih Peralatan': 'Pilih Peralatan',
      'Tandakan peralatan yang anda ambil dari Pos Utama.':
          'Tandakan peralatan yang anda ambil dari Pos Utama.',
      'Tiada peralatan direkodkan.': 'Tiada peralatan direkodkan.',
      'Tinggal': 'Tinggal',
      'Sahkan & Mula Shif': 'Sahkan & Mula Shif',
      'Inventori': 'Inventori',
      'Rekod Log': 'Rekod Log',
      'Diambil': 'Diambil',
      'Dipulangkan': 'Dipulangkan',
      'Telah Dipulangkan': 'Telah Dipulangkan',
      'Sedang Digunakan': 'Sedang Digunakan',
      'Log & Inventori Peralatan': 'Log & Inventori Peralatan',
      'Cuba Lagi': 'Cuba Lagi',
      'Urus Peralatan': 'Urus Peralatan',
      'Peralatan': 'Peralatan',
      'Tambah Peralatan': 'Tambah Peralatan',
      'Nama Peralatan': 'Nama Peralatan',
      'Kuantiti': 'Kuantiti',
      'Nama peralatan tidak boleh kosong': 'Nama peralatan tidak boleh kosong',
      'Kuantiti tidak boleh kosong': 'Kuantiti tidak boleh kosong',
      'Sila masukkan kuantiti yang sah': 'Sila masukkan kuantiti yang sah',
      'Simpan': 'Simpan',
      'Kemaskini Peralatan': 'Kemaskini Peralatan',
      'Padam Peralatan': 'Padam Peralatan',
      'Adakah anda pasti mahu memadam peralatan':
          'Adakah anda pasti mahu memadam peralatan',
      'Ini juga akan memadam semua log yang berkaitan.':
          'Ini juga akan memadam semua log yang berkaitan.',
      'Terdapat laporan yang telah dihantar dalam pilihan anda.':
          'Terdapat laporan yang telah dihantar dalam pilihan anda.',
      'Tamatkan Rondaan Awal': 'Tamatkan Rondaan Awal',
      'Adakah anda pasti mahu menamatkan shif rondaan awal?':
          'Adakah anda pasti mahu menamatkan shif rondaan awal?',
      'Baki masa': 'Baki masa',
      'Sahkan Tamat Rondaan': 'Sahkan Tamat Rondaan',
      'Sila sahkan sekali lagi. Adakah anda benar-benar mahu menamatkan rondaan sekarang?':
          'Sila sahkan sekali lagi. Adakah anda benar-benar mahu menamatkan rondaan sekarang?',
      'Ya, Tamatkan': 'Ya, Tamatkan',
      'Ya, Sahkan': 'Ya, Sahkan',
      'Tiada rekod penggunaan peralatan.': 'Tiada rekod penggunaan peralatan.',
      'Jumlah': 'Jumlah',
      'Dipinjam': 'Dipinjam',
      'Lihat Semua': 'Lihat Semua',
      'Senarai Peralatan Dipinjam': 'Senarai Peralatan Dipinjam',
      'Monitor & Analitik': 'Monitor & Analitik',
      'Paparan pemantauan rondaan dan trend insiden semasa.':
          'Paparan pemantauan rondaan dan trend insiden semasa.',
      'Insiden (Minggu)': 'Insiden (Minggu)',
      'Shif Aktif': 'Shif Aktif',
      'Peronda Terdaftar': 'Peronda Terdaftar',
      'JANA LAPORAN LAMPIRAN 6': 'Jana Laporan Bulanan',
      'JANA BUKU KEDATANGAN SRS': 'Jana Buku Kedatangan SRS',
      'Borang Lampiran D3(C)': 'Laporan Bulanan',
      'Buku Rekod Kedatangan SRS': 'Buku Rekod Kedatangan SRS',
      'Rondaan Aktif Semasa': 'Rondaan Aktif Semasa',
      'Tiada rondaan aktif dijalankan ketika ini.':
          'Tiada rondaan aktif dijalankan ketika ini.',
      'Tiada Kumpulan': 'Tiada Kumpulan',
      'Kumpulan': 'Kumpulan',
      'Mula': 'Mula',
      'Penjadualan': 'Penjadualan',
      'Kumpulan berjaya dicipta!': 'Kumpulan berjaya dicipta!',
      'Ralat mencipta kumpulan': 'Ralat mencipta kumpulan',
      'Ahli berjaya ditambah!': 'Ahli berjaya ditambah!',
      'Ralat menambah ahli': 'Ralat menambah ahli',
      'Ahli berjaya dikeluarkan!': 'Ahli berjaya dikeluarkan!',
      'Ralat mengeluarkan ahli': 'Ralat mengeluarkan ahli',
      'Kumpulan dipadam!': 'Kumpulan dipadam!',
      'Ralat memadam kumpulan': 'Ralat memadam kumpulan',
      'Cipta Kumpulan Baru': 'Cipta Kumpulan Baru',
      'Nama Kumpulan': 'Nama Kumpulan',
      'Simpan Kumpulan': 'Simpan Kumpulan',
      'Pilih Peronda': 'Pilih Peronda',
      'Tiada peronda dijumpai': 'Tiada peronda dijumpai',
      'Telah ditugaskan ke:': 'Telah ditugaskan ke:',
      'Terkunci': 'Terkunci',
      'Pilih': 'Pilih',
      'Ralat memuat senarai:': 'Ralat memuat senarai:',
      'Tiada Kumpulan Direkodkan': 'Tiada Kumpulan Direkodkan',
      'Padam Kumpulan': 'Padam Kumpulan',
      'Adakah anda pasti untuk memadam kumpulan':
          'Adakah anda pasti untuk memadam kumpulan',
      'Semua data ahli dan jadual berkaitan kumpulan ini akan dipadam.':
          'Semua data ahli dan jadual berkaitan kumpulan ini akan dipadam.',
      'Belum ada ahli.': 'Belum ada ahli.',
      'Keluarkan Ahli': 'Keluarkan Ahli',
      'Adakah anda pasti untuk mengeluarkan':
          'Adakah anda pasti untuk mengeluarkan',
      'daripada kumpulan?': 'daripada kumpulan?',
      'Keluarkan': 'Keluarkan',
      'Tambah Ahli': 'Tambah Ahli',
      'Jadual berjaya ditetap!': 'Jadual berjaya ditetap!',
      'Ralat menetapkan jadual': 'Ralat menetapkan jadual',
      'Jadual berjaya dipadam!': 'Jadual berjaya dipadam!',
      'Ralat memadam jadual': 'Ralat memadam jadual',
      'Ralat memuatkan kumpulan:': 'Ralat memuatkan kumpulan:',
      'Sila cipta kumpulan terlebih dahulu!':
          'Sila cipta kumpulan terlebih dahulu!',
      'Tetapkan Jadual Rondaan': 'Tetapkan Jadual Rondaan',
      'Pilih Kumpulan': 'Pilih Kumpulan',
      'Tarikh Rondaan': 'Tarikh Rondaan',
      'Masa Mula Rondaan': 'Masa Mula Rondaan',
      'Masa Tamat Rondaan': 'Masa Tamat Rondaan',
      'Simpan Jadual': 'Simpan Jadual',
      'Tiada Jadual Rondaan Direkodkan': 'Tiada Jadual Rondaan Direkodkan',
      'Kumpulan Tanpa Nama': 'Kumpulan Tanpa Nama',
      'Adakah anda pasti untuk memadam jadual rondaan bagi kumpulan':
          'Adakah anda pasti untuk memadam jadual rondaan bagi kumpulan',
      'pada tarikh': 'pada tarikh',
      'Jadual & Skuad': 'Jadual & Skuad',
      'Maklumat Peribadi': 'Maklumat Peribadi',
      'Gagal memuat turun profil.': 'Gagal memuat turun profil.',
      'Selamat Pagi': 'Selamat Pagi',
      'Selamat Tengah Hari': 'Selamat Tengah Hari',
      'Selamat Petang': 'Selamat Petang',
      'Selamat Malam': 'Selamat Malam',
      'Laporan Saya': 'Laporan Saya',
      'Sedia': 'Sedia',
      'Status': 'Status',
      'Bulanan': 'Bulanan',
      'Jenayah Kekerasan': 'Jenayah Kekerasan',
      'Jenayah Harta Benda': 'Jenayah Harta Benda',
      'Narkotik & Sosial': 'Narkotik & Sosial',
      'Gejala Sosial': 'Gejala Sosial',
      'Tukarkan Shif': 'Tukarkan Shif',
      'Tamatkan Rondaan': 'Tamatkan Rondaan',
      'Sedia Untuk Rondaan': 'Sedia Untuk Rondaan',
      'Tekan untuk memulakan rondaan': 'Tekan untuk memulakan rondaan',
      'Hotspot Kawasan (Zon)': 'Hotspot Kawasan (Zon)',
      'Peratusan Kategori Jenayah': 'Peratusan Kategori Jenayah',
      'Pecahan Mengikut Kategori': 'Pecahan Mengikut Kategori',
      'Rondaan & Keberkesanan': 'Rondaan & Keberkesanan',
      'Lain-lain': 'Lain-lain',
    },
  };

  /// Retrieves the translated string based on the current locale
  String t(String key) {
    return _translations[_locale.languageCode]?[key] ?? key;
  }
}
