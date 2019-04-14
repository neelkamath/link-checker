import 'package:link_checker/link_checker.dart';
import 'package:test/test.dart';

void main() {
  test('project for dead links', () async {
    var badLinks = <BadLink>[];
    await for (BadLink badLink in getBadLinksInDirectory(blacklistedFilePaths: [
      '.packages',
      'pubspec.lock'
    ], blacklistedDirectories: [
      BlacklistedDirectory('test'),
      BlacklistedDirectory('example'),
      BlacklistedDirectory('.dart_tool')
    ], blacklistedLinks: [
      'http://schemas.android.com'
    ])) {
      badLinks.add(badLink);
    }
    expect(badLinks, isEmpty);
  }, timeout: Timeout.none);
}
