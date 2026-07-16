class AppConstants {
  static const String appName = 'Starpage';
  static const String primaryDomain = 'starpage.me';
  static const String secondaryDomain = 'starpage.org';
  static const String legacyDomain = 'starpage.app';
  
  static const String baseUrl = 'https://$primaryDomain';
  static const String alternativeBaseUrl = 'https://$secondaryDomain';
  
  static String profileUrl(String userId) => '$baseUrl/profile/$userId';
  static String postUrl(String postId) => '$baseUrl/post/$postId';
}
