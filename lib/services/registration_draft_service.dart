class RegistrationDraftService {
  RegistrationDraftService._();

  static final RegistrationDraftService instance = RegistrationDraftService._();

  final Map<String, dynamic> _draft = <String, dynamic>{};

  Map<String, dynamic> get draft => Map<String, dynamic>.from(_draft);

  void setValues(Map<String, dynamic> values) {
    _draft.addAll(values);
  }

  String readString(String key, {String fallback = ''}) {
    final value = _draft[key];
    if (value == null) return fallback;
    return value.toString();
  }

  void clear() {
    _draft.clear();
  }
}
