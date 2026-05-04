class ApiConfig {
  // --- CONFIGURATION FOR PHYSICAL DEVICE ---
  // 1. Find your computer's IP (type 'ipconfig' in terminal)
  // 2. Replace '10.0.2.2' with that IP (e.g., '192.168.1.15')
  // 3. Ensure both phone and PC are on the same WiFi network
  
  static const String serverIp = "172.20.10.2"; // UPDATED for physical device
  
  static const String performanceApiUrl = "http://$serverIp:5000/predict";
  static const String lstmPerformanceApiUrl = "http://$serverIp:5000/predict_lstm";
  static const String injuryRiskApiUrl = "http://$serverIp:5000/predict-injury-risk";
  
  // Timeout for API calls to prevent UI hanging
  static const Duration requestTimeout = Duration(seconds: 10);
}
