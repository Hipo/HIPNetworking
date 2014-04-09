HIPNetworking
=============

iOS7 framework for simple and robust network handling, built on NSURLSession.

There are lots of networking libraries out there, but most of them are quite heavy and come with lots of strings attached. HIPNetworking is a simple, robust networking class that solves a few key issues:

* Ability to create multiple network queues isolated from each other
* Proper request cancellation: Every network request can easily be identified and cancelled, or even a whole cluster of requests can be removed from the queue easily
* Image resizing is handled through a UIImage category that asynchronously resizes images according to your specifications
* Easy to use cache handling is available via TMCache


Usage
-----

HIPNetworkClient exposes two key instance methods:

    - (NSURLRequest *)requestWithURL:(NSURL *)url
                              method:(HIPNetworkClientRequestMethod)method
                                data:(NSData *)data;
    
    - (void)performRequest:(NSURLRequest *)request
             withParseMode:(HIPNetworkClientParseMode)parseMode
                identifier:(NSString *)identifier
                 indexPath:(NSIndexPath *)indexPath
              cacheResults:(BOOL)cache
         completionHandler:(void (^)(id parsedData, NSURLResponse *response, NSError *error))completionHandler;

These two methods can be used to generate virtually any HTTP network request, and provide with a lot of freedom for configuration. In addition, a special image loading method is also available:

    - (void)loadImageFromURL:(NSURL *)url
               withScaleMode:(HIPNetworkClientScaleMode)scaleMode
                  targetSize:(CGSize)targetSize
                  identifier:(NSString *)identifier
                   indexPath:(NSIndexPath *)indexPath
           completionHandler:(void (^)(UIImage *image, NSURL *url, NSError *error))completionHandler;

This image loader method can handle loading, caching, resizing and cropping using the given options.

Finally, request cancellation is also easy:

    - (void)cancelTasksWithIdentifier:(NSString *)identifier;

    - (void)cancelTaskWithIdentifier:(NSString *)identifier
                           indexPath:(NSIndexPath *)indexPath;

Using these methods, you can optionally cancel all tasks with a specific identifier, or a single task that matches an identifier an index path. This is very helpful for cancelling tasks while scrolling a table or collection view.

Detailed documentation for all these methods is available within the HIPNetworkClient class. The framework expects you to create a subclass and 


Installation
------------

Copy and include the `HIPNetworking` directory in your own project.


Dependencies
------------

The only dependency is [TMCache](https://github.com/tumblr/TMCache).

If you find any issues, please open an issue here on GitHub, and feel free to send in pull requests with improvements and fixes. You can also get in touch
by emailing us at hello@hipolabs.com.


Credits
-------

HIPNetworking is brought to you by 
[Taylan Pince](http://taylanpince.com) and the [Hipo Team](http://hipolabs.com).


License
-------

HIPNetworking is licensed under the terms of the Apache License, version 2.0. Please see the LICENSE file for full details.
