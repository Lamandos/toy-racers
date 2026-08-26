/// Reports an input that does not satisfy the shared compatibility contract.
///
/// The [path] uses JSONPath-like notation so a command-line runner can point
/// to the exact document member that needs to be corrected.
final class CompatibilityFormatException extends FormatException {
  CompatibilityFormatException(this.path, String message)
    : super('$path: $message');

  final String path;
}
