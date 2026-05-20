class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const configuredUrl = String.fromEnvironment('LIFEPLANNER_API_BASE_URL');
    return AppConfig(
      apiBaseUrl: configuredUrl.isEmpty
          ? 'https://api-lifeplanner.gesu.gay/api'
          : configuredUrl,
    );
  }

  final String apiBaseUrl;
}
