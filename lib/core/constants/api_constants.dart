class ApiConstants {
  // Replace this with your actual cPanel domain or local XAMPP IP
  // If testing on an Android emulator with local XAMPP, use "http://10.0.2.2/srs_api/"
  static const String baseUrl = "http://192.168.1.109/srs_api/";

  static const String loginEndpoint = "auth/login.php";
  static const String registerEndpoint = "auth/register.php";
  static const String getIncidentsEndpoint = "incidents/get_incidents.php";
  static const String uploadIncidentEndpoint = "incidents/upload_incident.php";
}
