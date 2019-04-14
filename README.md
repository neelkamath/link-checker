# link_checker

Can find links and check if they're dead in almost any file.

Are you tired of finding dead links in projects from READMEs to large websites? Yes, yes you are. `link_checker` allows you to test for dead links, whether it be a single link, a file, or an entire project, all with a single line! It can check most types of file, such as Java, Dart, and Markdown (however, since Markdown files are parsed, the links obtained from them may differ from the original links). `link_checker` can efficiently search your entire project by allowing you to blacklist directories, links using regex, etc.

It can also check if existing HTTP links can use HTTPS instead!

You'll probably want the CI to run every twenty-four hours, since broken links aren't created from just your own commits, but external web pages being deleted as well.