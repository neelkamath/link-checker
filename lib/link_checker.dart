/// Can find links and check if they're dead.
///
/// This library can test most types of files, from Markdown to Java.
///
/// Links must be specified with the HTTP or HTTPS protocol to be found. For
/// example, https://google.com.
///
/// A "bad link" is a link whose status code retrieved upon making a request to
/// it wasn't in the range of 200-299. A list of all the HTTP status codes are
/// here:
/// https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#3xx_Redirection. The
/// only extra status code used in this library is 0, which indicates that a
/// server couldn't be contacted because the website doesn't exist.
library link_checker;

import 'dart:async';
import 'dart:io';

import 'package:markdown/markdown.dart';

/// Checks a directory for bad links.
///
/// If [path] isn't specified, the project's root directory is used.
/// Set [recursive] to false if you don't want to check subdirectories.
/// Set [followLinks] to false if you don't want to follow symbolic links.
/// [blacklistedDirectories] and [blacklistedFilePaths] won't be searched.
/// [blacklistedLinks] are the links which are not to be yielded, even if found.
/// [blacklistedLinksRegexes] are the [RegExp] instances which match links that
/// shouldn't be returned.
Stream<BadLink> getBadLinksInDirectory(
    {String path,
    bool recursive = true,
    bool followLinks = true,
    List<BlacklistedDirectory> blacklistedDirectories,
    List<String> blacklistedFilePaths,
    List<String> blacklistedLinks,
    List<RegExp> blacklistedLinksRegexes}) async* {
  await for (var location in getLinksInDirectory(
      path: path,
      recursive: recursive,
      followLinks: followLinks,
      blacklistedDirectories: blacklistedDirectories,
      blacklistedFilePaths: blacklistedFilePaths,
      blacklistedLinks: blacklistedLinks,
      blacklistedLinksRegexes: blacklistedLinksRegexes)) {
    var statusCode = await getLinkStatus(location.link);
    if (statusCode != null) {
      yield BadLink.fromLinkLocation(location, statusCode);
    }
  }
}

class BlacklistedDirectory {
  /// The path to this blacklisted directory.
  final String path;

  /// If true, subdirectories will also be blacklisted.
  final bool recursive;

  /// If true, symbolic links will be followed.
  final bool followLinks;

  BlacklistedDirectory(this.path,
      {this.recursive = true, this.followLinks = true});
}

/// The path to the file having the bad link, the bad link, and its status code.
class BadLink {
  final String path;
  final String link;
  final int statusCode;

  BadLink(this.path, this.link, this.statusCode);

  BadLink.fromLinkLocation(LinkLocation location, this.statusCode)
      : path = location.path,
        link = location.link;

  BadLink.fromBadLinkStatus(this.path, BadLinkStatus status)
      : link = status.link,
        statusCode = status.statusCode;

  @override
  String toString() => 'Path: $path\nLink: $link\nStatus code: $statusCode';
}

/// Yields the links found in a directory.
///
/// If [path] isn't specified, the project's root directory is used. Set
/// [recursive] to false if you don't want to search subdirectories.
/// Set [followLinks] to false if you don't want to follow symbolic links.
/// [blacklistedDirectories] and [blacklistedFilePaths] won't be searched.
/// [blacklistedLinks] are the links which are not to be yielded, even if found.
/// [blacklistedLinksRegexes] are the [RegExp] instances which match links that
/// shouldn't be returned.
Stream<LinkLocation> getLinksInDirectory(
    {String path,
    bool recursive = true,
    bool followLinks = true,
    List<BlacklistedDirectory> blacklistedDirectories,
    List<String> blacklistedFilePaths,
    List<String> blacklistedLinks,
    List<RegExp> blacklistedLinksRegexes}) async* {
  var directory = path == null ? Directory.current : Directory(path);
  if (blacklistedFilePaths == null) {
    blacklistedFilePaths = [];
  }
  if (blacklistedDirectories != null) {
    blacklistedFilePaths.addAll(
        await _getFilePathsInBlacklistedDirectories(blacklistedDirectories));
  }

  await for (var entity
      in directory.list(recursive: recursive, followLinks: followLinks)) {
    if (entity is File && !_containsPath(blacklistedFilePaths, entity)) {
      for (var link in await getLinksInFile(entity.path,
          blacklistedLinks: blacklistedLinks,
          blacklistedLinksRegexes: blacklistedLinksRegexes)) {
        yield LinkLocation(entity.path, link);
      }
    }
  }
}

/// Returns whether [entity] ends with a path in [paths].
bool _containsPath(List<String> paths, FileSystemEntity entity) {
  for (var path in paths) {
    if (entity.path.endsWith(path)) {
      return true;
    }
  }
  return false;
}

/// Returns the files found in [directories].
Future<List<String>> _getFilePathsInBlacklistedDirectories(
    List<BlacklistedDirectory> directories) async {
  var paths = <String>[];
  for (var directory in directories) {
    if (await Directory(directory.path).exists()) {
      await for (var entity in Directory(directory.path).list(
          recursive: directory.recursive, followLinks: directory.followLinks)) {
        if (entity is File) {
          paths.add(entity.path);
        }
      }
    }
  }
  return paths;
}

/// The path to the file containing the link, and the link.
class LinkLocation {
  final String path;
  final String link;

  LinkLocation(this.path, this.link);

  @override
  String toString() => '$path: $link';
}

/// Yields bad links found in the file located at [path].
///
/// [blacklistedLinks] are the links which will not be yielded even if found.
/// [blacklistedLinksRegexes] are the [RegExp] instances which match links that
/// shouldn't be returned.
Stream<BadLinkStatus> getBadLinksInFile(String path,
    {List<String> blacklistedLinks,
    List<RegExp> blacklistedLinksRegexes}) async* {
  List<String> links = await getLinksInFile(
    path,
    blacklistedLinks: blacklistedLinks,
    blacklistedLinksRegexes: blacklistedLinksRegexes,
  );
  for (var link in links) {
    var statusCode = await getLinkStatus(link);
    if (statusCode != null) {
      yield BadLinkStatus(link, statusCode);
    }
  }
}

/// The link a request was made to, and the status code returned.
class BadLinkStatus {
  final String link;
  final int statusCode;

  BadLinkStatus(this.link, this.statusCode);

  @override
  String toString() => '$link: $statusCode';
}

/// Returns the links found in the file at [path].
///
/// [blacklistedLinks] are the links which should not be returned if found.
/// [blacklistedLinksRegexes] are the [RegExp] instances which match links that
/// shouldn't be returned.
Future<List<String>> getLinksInFile(String path,
    {List<String> blacklistedLinks,
    List<RegExp> blacklistedLinksRegexes}) async {
  var matches = <String>[];

  String content;
  try {
    content = await File(path).readAsString();
  } on FileSystemException {
    // The file isn't readable. For example, it's a binary or directory.
    return matches;
  }
  if (_isMarkdownFilePath(path)) {
    content = markdownToHtml(content);
  }

  var linkRegex = r"https?://[A-Za-z0-9-._~:/?#[\]@!$&'()*+,;=`%]+";
  for (var match in RegExp(
    linkRegex,
  ).allMatches(content)) {
    String link = parseUrl(match.input.substring(match.start, match.end));
    if (!RegExp(linkRegex).hasMatch(link) ||
        (blacklistedLinks != null && blacklistedLinks.contains(link)) ||
        (blacklistedLinksRegexes != null &&
            _containsMatch(blacklistedLinksRegexes, link))) {
      continue;
    }
    matches.add(link);
  }
  return matches;
}

/// Returns whether or not the [path] to a file has a Markdown extension.
bool _isMarkdownFilePath(String path) {
  for (var extension in [
    '.markdown',
    '.mdown',
    '.mkdn',
    '.md',
    '.mkd',
    '.mdwn',
    '.mdtxt',
    '.mdtext',
    '.text',
    '.Rmd'
  ]) {
    if (path.endsWith(extension)) {
      return true;
    }
  }
  return false;
}

/// Returns whether or not [string] is matched by any regex in [regexes].
bool _containsMatch(List<RegExp> regexes, String string) {
  for (var regex in regexes) {
    if (regex.hasMatch(string)) {
      return true;
    }
  }
  return false;
}

/// Returns [url] after stripping unnecessary delimiters.
///
/// This can be useful if you have a URL from a regex match, and need to deal
/// with potentially invalid URL characters. For example, a regex match for a
/// URL might include a closing parenthesis at the end, even though there is no
/// opening parenthesis. Since this is a delimiter, it isn't part of the URL
/// even though it is a valid URL character.
String parseUrl(String url) {
  while (true) {
    if (_shouldStripTrailingDelimiter(url) || url.endsWith('.')) {
      url = _stripTrailingCharacter(url);
    } else {
      return url;
    }
  }
}

/// Returns [string] without the last character.
String _stripTrailingCharacter(String string) =>
    string.substring(0, string.length - 1);

/// Returns whether or not the URL [url] should have its last character removed.
bool _shouldStripTrailingDelimiter(String url) =>
    _shouldStripTrailingEnclosingDelimiter(url) ||
    _shouldStripTrailingNonEnclosingDelimiter(url);

/// Returns whether or not the URL [url] has a trailing delimiter to be removed.
///
/// A "non-enclosing" delimiter is one which does not come in a pair. For
/// example, ":" is a non-enclosing delimiter, but ")" is.
bool _shouldStripTrailingNonEnclosingDelimiter(String url) {
  for (var delimiter in [
    ':',
    '/',
    '?',
    '#',
    '@',
    '!',
    r'$',
    '&',
    '*',
    '+',
    ',',
    ';',
    '='
  ]) {
    if (url.endsWith(delimiter)) {
      return true;
    }
  }
  return false;
}

/// Returns whether the last character of the URL [url] should be stripped.
///
/// An "enclosing" delimiter is one which does not come in a pair. For example,
/// "]" is an enclosing delimiter, but "," is not.
bool _shouldStripTrailingEnclosingDelimiter(String url) {
  var chars = {'(': ')', '[': ']'};
  var shouldStrip = false;
  chars.forEach((leftChar, rightChar) {
    if ((url.endsWith(leftChar) &&
            _countOccurrences(leftChar, url) <
                _countOccurrences(rightChar, url)) ||
        (url.endsWith(rightChar) &&
            _countOccurrences(leftChar, url) <
                _countOccurrences(rightChar, url))) {
      shouldStrip = true;
    }
  });
  if (url.endsWith("'") && _countOccurrences("'", url).isOdd) {
    shouldStrip = true;
  }
  return shouldStrip;
}

/// Returns the number of times [matcher] is present in [string].
int _countOccurrences(String matcher, String string) {
  var count = 0;
  for (var char in string.split('')) {
    if (char == matcher) {
      ++count;
    }
  }
  return count;
}

/// Returns the status code received after making a request to [link].
///
/// 0 will be returned if the website doesn't exist.
/// null will be returned if [link] isn't bad.
Future<int> getLinkStatus(String link) async {
  HttpClientRequest request;
  try {
    request = await HttpClient().getUrl(Uri.parse(link));
  } on SocketException {
    return 0; // Website doesn't exist.
  } on HandshakeException {
    return -1;
  }
  var response = await request.close();
  return isGoodStatusCode(response.statusCode) ? null : response.statusCode;
}

/// Returns whether [link] uses HTTPS.
bool isHttpsLink(String link) => RegExp(r'https:\/\/.*').hasMatch(link);

/// Returns [link] as an HTTPS link.
String convertToHttps(String link) =>
    isHttpsLink(link) ? link : 'https://${link.substring("http://".length)}';

/// Returns whether [link] can be served over HTTPS.
Future<bool> canUseHttps(String link) async =>
    await getLinkStatus(convertToHttps(link)) == null;

/// Returns whether or not [statusCode] is in the range of 200 and 299.
bool isGoodStatusCode(int statusCode) =>
    RegExp(r'2\d\d').hasMatch(statusCode.toString());
