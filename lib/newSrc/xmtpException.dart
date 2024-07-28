class XMTPException implements Exception {
  final String message;
  final Exception? cause;

  XMTPException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'XMTPException: $message (Cause: ${cause.toString()})';
    }
    return 'XMTPException: $message';
  }
}
