/*********************************************************************************
 
 Copyright (c) 2010, Isaac Greenspan
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the <organization> nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 *********************************************************************************/

//
//  IGIsolatedCookieWebView.m
//

#import "IGIsolatedCookieWebView.h"

#pragma mark -
#pragma mark private resourceLoadDelegate class interface

@interface IGIsolatedCookieWebViewResourceLoadDelegate : NSObject {
	NSMutableArray *cookieStore;
}

- (IGIsolatedCookieWebViewResourceLoadDelegate *)init;

- (NSURLRequest *)webView:(WebView *)sender
				 resource:(id)identifier
		  willSendRequest:(NSURLRequest *)request
		 redirectResponse:(NSURLResponse *)redirectResponse
		   fromDataSource:(WebDataSource *)dataSource;
- (void)webView:(WebView *)sender
	   resource:(id)identifier
didReceiveResponse:(NSURLResponse *)response
 fromDataSource:(WebDataSource *)dataSource;

- (void)setCookie:(NSHTTPCookie *)cookie;
- (NSArray *)getCookieArrayForRequest:(NSURLRequest *)request;

@end


#pragma mark -
#pragma mark main class implementation

@implementation IGIsolatedCookieWebView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
		[self awakeFromNib];
    }
    return self;
}

- (void)awakeFromNib
{
//	NSLog(@"=== awakeFromNib ===");
	IGIsolatedCookieWebViewResourceLoadDelegate *resourceLoadDelegate = [[IGIsolatedCookieWebViewResourceLoadDelegate alloc] init];
	[self setResourceLoadDelegate:resourceLoadDelegate];
}

- (void)injectCookie:(NSHTTPCookie *)cookie
{
	[(IGIsolatedCookieWebViewResourceLoadDelegate *)[self resourceLoadDelegate] setCookie:cookie];
}

@end

#pragma mark -
#pragma mark private category on NSHTTPCookie to facilitate testing properties of the cookie

@interface NSHTTPCookie (IGPropertyTesting)

- (BOOL)isExpired;
- (BOOL)isForHost:(NSString *)host;
- (BOOL)isForPath:(NSString *)path;
- (BOOL)isForRequest:(NSURLRequest *)request;

- (BOOL)isEqual:(id)object;

@end

@implementation NSHTTPCookie (IGPropertyTesting)

- (BOOL)isExpired
{
	return [[self expiresDate] timeIntervalSinceNow] < 0;
}

- (BOOL)isForHost:(NSString *)host
{
	return ([[self domain] isEqualToString:host]
			|| ([[self domain] hasPrefix:@"."]
				&& [[NSString stringWithFormat:@".%@",host] hasSuffix:[self domain]])
			);
}

- (BOOL)isForPath:(NSString *)path;
{
	return (path
			&& [path hasPrefix:[self path]]
			);
}

- (BOOL)isForRequest:(NSURLRequest *)request
{
	return (![self isExpired]
			&& [self isForHost:[[request URL] host]]
			&& [self isForPath:[[request URL] path]]
			);
}

- (BOOL)isEqual:(id)object
{
	return ([object isKindOfClass:[self class]]
			&& [[self name] isEqualToString:[object name]]
			&& [[self domain] isEqualToString:[object domain]]
			&& [[self path] isEqualToString:[object path]]
			);
}

@end


#pragma mark -
#pragma mark private resourceLoadDelegate class implementation

@implementation IGIsolatedCookieWebViewResourceLoadDelegate

- (IGIsolatedCookieWebViewResourceLoadDelegate *)init
{
	self = [super init];
	if (self) {
		cookieStore = [[NSMutableArray arrayWithCapacity:0] retain];
	}
	return self;
}

- (void)pullCookiesFromResponse:(NSURLResponse *)response
{
	if ([response respondsToSelector:@selector(allHeaderFields)]) {
		NSDictionary *allHeaders = [(NSHTTPURLResponse *)response allHeaderFields];
		NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:allHeaders
																  forURL:[response URL]];
		for (NSHTTPCookie *aCookie in cookies) {
			[self setCookie:aCookie];
		}
//		NSLog(@"%d %@",[(NSHTTPURLResponse *)response statusCode],[[response URL] absoluteURL]);
	}
}

- (NSURLRequest *)webView:(WebView *)sender
				 resource:(id)identifier
		  willSendRequest:(NSURLRequest *)request
		 redirectResponse:(NSURLResponse *)redirectResponse
		   fromDataSource:(WebDataSource *)dataSource
{
	if (redirectResponse) [self pullCookiesFromResponse:redirectResponse];
	NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:[request URL]
															  cachePolicy:[request cachePolicy]
														  timeoutInterval:[request timeoutInterval]];
	[newRequest setAllHTTPHeaderFields:[request allHTTPHeaderFields]];
	if ([request HTTPBodyStream]) {
		[newRequest setHTTPBodyStream:[request HTTPBodyStream]];
	} else {
		[newRequest setHTTPBody:[request HTTPBody]];
	}
	[newRequest setHTTPMethod:[request HTTPMethod]];
	[newRequest setHTTPShouldHandleCookies:NO];
	[newRequest setMainDocumentURL:[request mainDocumentURL]];
	NSArray *newCookies = [self getCookieArrayForRequest:request];
	if (newCookies
		&& ([newCookies count] > 0)) {
//		NSLog(@"cookies being sent to %@: %@",
//			  [[request URL] absoluteURL],
//			  [NSHTTPCookie requestHeaderFieldsWithCookies:newCookies]);
		NSMutableDictionary *newAllHeaders = [NSMutableDictionary dictionaryWithDictionary:[request allHTTPHeaderFields]];
		[newAllHeaders addEntriesFromDictionary:[NSHTTPCookie requestHeaderFieldsWithCookies:newCookies]];
		[newRequest setAllHTTPHeaderFields:[NSDictionary dictionaryWithDictionary:newAllHeaders]];
	}
	return newRequest;
}

- (void)webView:(WebView *)sender
	   resource:(id)identifier
didReceiveResponse:(NSURLResponse *)response
 fromDataSource:(WebDataSource *)dataSource
{
	[self pullCookiesFromResponse:response];
}

- (void)removeExpiredCookies
{
	for (NSHTTPCookie *aCookie in [NSArray arrayWithArray:cookieStore]) {
		if ([aCookie isExpired]) {
			[cookieStore removeObject:aCookie];
		}
	}
}

- (void)setCookie:(NSHTTPCookie *)cookie
{
//	NSLog(@"should be setting cookie with name '%@' and value '%@' for URL '%@'",
//		  [cookie name], [cookie value], [url absoluteString]);
	[cookieStore removeObject:cookie];
	[cookieStore addObject:cookie];
	[self removeExpiredCookies];
}

- (NSArray *)getCookieArrayForRequest:(NSURLRequest *)request
{
	NSMutableArray *cookiesToSend = [NSMutableArray arrayWithCapacity:0];
	for (NSHTTPCookie *aCookie in cookieStore) {
		if ([aCookie isForRequest:request]) {
			[cookiesToSend addObject:aCookie];
		}
	}
	return [NSArray arrayWithArray:cookiesToSend];
}

@end