This collection of classes handles remote resource loading (via NSURLRequest) and caching (via EGOCache) for iOS applications.  Requests are queued in either of two singleton instances specifically built for images and text-based data.  The text "feed" loader queue also handles JSON parsing.

In the future, these two queues may end up being combined, and additional parsing for different data-types will probably be added.