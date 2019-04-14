import 'package:link_checker/link_checker.dart';
import 'package:test/test.dart';

Matcher _matchBadLinkStatus(BadLinkStatus status) {
  return TypeMatcher<BadLinkStatus>()
      .having((status) => status.link, 'link', status.link)
      .having((status) => status.statusCode, 'status code', status.statusCode);
}

Matcher _matchLinkLocation(LinkLocation location) => TypeMatcher<LinkLocation>()
    .having((location) => location.link, 'link', location.link)
    .having((location) => location.path, 'path', location.path);

Matcher _matchBadLink(BadLink badLink) => TypeMatcher<BadLink>()
    .having((badLink) => badLink.path, 'path', badLink.path)
    .having((badLink) => badLink.link, 'link', badLink.link)
    .having((badLink) => badLink.statusCode, 'status code', badLink.statusCode);

void main() {
  test('this project for dead links', () {
    expect(
        getBadLinksInDirectory(blacklistedFilePaths: [
          'README.md',
          'pubspec.lock',
          '.packages'
        ], blacklistedDirectories: [
          BlacklistedDirectory('test'),
          BlacklistedDirectory('example'),
          BlacklistedDirectory('build'),
          BlacklistedDirectory('.dart_tool'),
          BlacklistedDirectory('.git')
        ], blacklistedLinks: [
          'http://schemas.android.com'
        ]),
        emitsDone);
  }, timeout: Timeout.none);

  group('status code', () {
    test('a good status', () => expect(isGoodStatusCode(202), isTrue));
    test('a bad status code', () => expect(isGoodStatusCode(404), isFalse));
  });

  group('getting the link status', () {
    test(
      'a good link',
      () => expect(getLinkStatus('https://google.com'), completion(isNull)),
    );
    test(
      'a bad link with an existent host',
      () async {
        int statusCode = await getLinkStatus('https://nintendo.com/69DS');
        expect(isGoodStatusCode(statusCode), isFalse);
      },
    );
    test(
        'a bad link with a nonexistent host',
        () => expect(
            getLinkStatus('https://acnlsdjflvdkfjanv.io'), completion(isZero)));
  });

  group('URL parsing', () {
    test("a URL which doesn't need to be modified", () {
      var url = 'https://google.com?q=hello&name=(neel)';
      expect(parseUrl(url), equals(url));
    });
    test('a URL that should be modified', () {
      var url = 'https://google.com';
      expect(parseUrl('$url)'), equals(url));
    });
    test('a parsed URL', () {
      var url = 'https://google.com))';
      String parsedUrl = parseUrl(url);
      expect(parseUrl(parsedUrl), equals(parsedUrl));
    });
  });

  group('getting links in a file', () {
    var path = 'test/files/getting_links_in_a_file/index.html';
    var link1 = 'https://google.com?q=king';
    var link2 = 'http://crazzyfolds.io';
    var link3 = 'http://google.com';
    var link4 = 'https://google.com?q=voila/name=nope';

    test(
        'when there are links',
        () => expect(getLinksInFile(path),
            completion(equals([link1, link2, link3, link4]))));
    test(
        'a binary',
        () => expect(
            getLinksInFile('test/files/getting_links_in_a_file/cat.jpg'),
            completion(isEmpty)));
    test('blacklisted links', () {
      expect(getLinksInFile(path, blacklistedLinks: [link1, link4]),
          completion(equals([link2, link3])));
    });
    test(
        'blacklisted links regexes',
        () => expect(
            getLinksInFile(path,
                blacklistedLinksRegexes: [RegExp('https?:\/\/google\.com.*')]),
            completion(equals([link2]))));
  });

  group('getting bad links in a file', () {
    var path = 'test/files/getting_bad_links_in_a_file/main.py';
    var badLink = 'https://thebestestevabusconductor.eu';

    test(
        'when there are no bad links',
        () => expect(
            getBadLinksInFile(path, blacklistedLinks: [badLink]), emitsDone));
    test(
        'when there are bad links',
        () => expect(
              getBadLinksInFile(path),
              emits(_matchBadLinkStatus(BadLinkStatus(badLink, 0))),
            ));
  });

  group('getting links in a directory', () {
    var path = 'test/files/getting_links_in_a_directory';
    var directory = BlacklistedDirectory('$path/subdirectory');
    var location1 = _matchLinkLocation(
        LinkLocation('$path/first_link.py', 'https://google.com'));
    var location2 = _matchLinkLocation(LinkLocation(
        '$path/subdirectory/Program.java', 'http://alskdjflaksdjfalskj.io'));

    test(
        'getting all links',
        () => expect(
              getLinksInDirectory(path: path),
              emitsInAnyOrder([location1, location2]),
            ));
    test(
        'blacklisted files',
        () => expect(
            getLinksInDirectory(
                path: path, blacklistedFilePaths: ['$path/first_link.py']),
            emits(location2)));
    test(
        'blacklisted directories',
        () => expect(
            getLinksInDirectory(
                path: path, blacklistedDirectories: [directory]),
            emits(location1)));
    test(
        'blacklisted files and blacklisted directories together',
        () => expect(
            getLinksInDirectory(
                path: path,
                blacklistedFilePaths: ['$path/first_link.py'],
                blacklistedDirectories: [directory]),
            emitsDone));
  });

  group('getting bad links in a directory', () {
    var path = 'test/files/getting_bad_links_in_a_directory';
    var badLink =
        _matchBadLink(BadLink('$path/main.cpp', 'http://alkdjsflkaj.in', 0));

    test('getting all links',
        () => expect(getBadLinksInDirectory(path: path), emits(badLink)));
    test(
        'blacklisted links',
        () => expect(
            getBadLinksInDirectory(
                path: path, blacklistedLinksRegexes: [RegExp('http://.*\.in')]),
            emitsDone));
  });

  group('checking whether a link is HTTPS', () {
    test('an HTTP link',
        () => expect(isHttpsLink('http://google.com'), isFalse));
    test('an HTTPS link',
        () => expect(isHttpsLink('https://google.com'), isTrue));
  });

  group('converting a link to HTTPS', () {
    test(
        'an HTTP link',
        () =>
            expect(convertToHttps('http://google.com'), 'https://google.com'));
    test('an HTTPS link', () {
      var link = 'https://google.com';
      expect(convertToHttps(link), link);
    });
  });

  group('checking if a link can use HTTPS', () {
    test('a link that can use HTTPS',
        () => expect(canUseHttps('http://google.com'), completion(isTrue)));
    test('a link that cannot use HTTPS',
        () => expect(canUseHttps('http://neverssl.com/'), completion(isFalse)));
  });
}
