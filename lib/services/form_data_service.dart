
class FormDataService {
  static Map<String, dynamic>? initialFormData;

  static void setFormData(Map<String, dynamic> data) {
    initialFormData = data;
  }

  static Map<String, dynamic>? getFormData() {
    final data = initialFormData;
    initialFormData = null; // Limpiar después de obtener
    return data;
  }
}