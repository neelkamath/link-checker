#v4.0.2

- Update link to repo.

#v4.0.1

- Updated README.

#v4.0.0

- Added `isHttpsLink`, `convertToHttps`, and `canUseHttps`.
- Changed `getLinkStatus`.

# v3.0.3

- Fixed CHANGELOG.

# v3.0.2

- Raised minimum Dart environment from `2.0.0-dev.56.0` to `2.1.0`.

# v2.0.2

- Fixed documentation for `BlacklistedDirectory`.

# v2.0.1

- Fixed bug in link parsing where plain protocols (example: just https instead of https://google.com) were considered links.

# v2.0.0

- `getBadLinksInDirectory`
    - Renamed `{String directory}` to `{String path}`.
    - Renamed `{List<String> blacklistedFiles}` to `{List<String> blacklistedFilePaths}`.
    - Added `{List<String> blacklistedLinks}`.
    - Added `{List<RegExp> blacklistedLinksRegexes}`.
- `getLinksInDirectory`
    - Renamed `{String directory}` to `{String path}`.
    - Renamed `{List<String> blacklistedFiles}` to `{List<String> blacklistedFilePaths}`.
    - Added `{List<String> blacklistedLinks}`.
    - Added `{List<RegExp> blacklistedLinksRegexes}`.
- `getBadLinksInFile`
    - Added `{List<String> blacklistedLinks}`.
    - Added `{List<RegExp> blacklistedLinksRegexes}`.
- `getLinksInFile`
    - Changed return type from `Stream<String>` to `Future<List<String>>`.
    - Added `{List<String> blacklistedLinks}`.
    - Added `{List<RegExp> blacklistedLinksRegexes}`.
- Added `String parseUrl(String url)`.
- Added `bool isGoodStatusCode(int statusCode)`.
- Improved link parsing by taking delimiters into account. For example, a file containing the link `https://google.com` as `var link = 'https://google.com';` will now be parsed as `https://google.com` instead of `https://google.com'`.

# v1.1.1

- Lowered the minimum SDK version from `2.0.0-dev.65.0` to `2.0.0-dev.56.0`.

# v1.1.0

- `getBadLinksInDirectory`
    - Added `{bool followLinks = true}`.
- `BlacklistedDirectory`
    - Added `{bool followLinks = true}` to default constructor.
- `getLinksInDirectory`
    - Added `{bool followLinks = true}`.

# v1.0.0

- Released the first version.