=======================
IGIsolatedCookieWebView
=======================

*A WebView subclass that uses its own internal non-permanent cookie storage and does not access or affect the system-wide shared cookie storage.*

**Inner Workings**

As per `this StackOverflow answer <http://stackoverflow.com/questions/364219/how-can-i-have-multiple-instances-of-webkit-without-sharing-cookies/365080#365080>`_, this is a WebView subclass that automatically instantiates a resource loading delegate (a private class), which implements webView:resource:willSendRequest:redirectResponse:fromDataSource: to block normal cookie handling and insert the proper cookies and webView:resource:didReceiveResponse:fromDataSource: to capture returned cookies.  Cookies are only stored in memory, not written to disk, and each instance has its own cookie storage, so cookies only exist while the instance of IGIsolatedCookieWebView exists and only exist for a particular instance of IGIsolatedCookieWebView.

----

 © Copyright 2010, Isaac Greenspan
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
