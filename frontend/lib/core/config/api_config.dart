class ApiConfig {
  static const String supabaseUrl = 'https://bhyqkrnfdbrewcwaiomh.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJoeXFrcm5mZGJyZXdjd2Fpb21oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQzOTc2NzksImV4cCI6MjEwOTk3MzY3OX0.6SrJqQaznZbZpGTrv-8bmfa5cJJBkg_Gz_jgxEtz7C4';

  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
      };

  static Uri functionUri(String name) =>
      Uri.parse('$supabaseUrl/functions/v1/$name');
}
