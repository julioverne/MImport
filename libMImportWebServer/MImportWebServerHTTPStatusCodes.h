/*
 Copyright (c) 2012-2015, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
// http://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

#import <Foundation/Foundation.h>

/**
 *  Convenience constants for "informational" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, MImportWebServerInformationalHTTPStatusCode) {
  kMImportWebServerHTTPStatusCode_Continue = 100,
  kMImportWebServerHTTPStatusCode_SwitchingProtocols = 101,
  kMImportWebServerHTTPStatusCode_Processing = 102
};

/**
 *  Convenience constants for "successful" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, MImportWebServerSuccessfulHTTPStatusCode) {
  kMImportWebServerHTTPStatusCode_OK = 200,
  kMImportWebServerHTTPStatusCode_Created = 201,
  kMImportWebServerHTTPStatusCode_Accepted = 202,
  kMImportWebServerHTTPStatusCode_NonAuthoritativeInformation = 203,
  kMImportWebServerHTTPStatusCode_NoContent = 204,
  kMImportWebServerHTTPStatusCode_ResetContent = 205,
  kMImportWebServerHTTPStatusCode_PartialContent = 206,
  kMImportWebServerHTTPStatusCode_MultiStatus = 207,
  kMImportWebServerHTTPStatusCode_AlreadyReported = 208
};

/**
 *  Convenience constants for "redirection" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, MImportWebServerRedirectionHTTPStatusCode) {
  kMImportWebServerHTTPStatusCode_MultipleChoices = 300,
  kMImportWebServerHTTPStatusCode_MovedPermanently = 301,
  kMImportWebServerHTTPStatusCode_Found = 302,
  kMImportWebServerHTTPStatusCode_SeeOther = 303,
  kMImportWebServerHTTPStatusCode_NotModified = 304,
  kMImportWebServerHTTPStatusCode_UseProxy = 305,
  kMImportWebServerHTTPStatusCode_TemporaryRedirect = 307,
  kMImportWebServerHTTPStatusCode_PermanentRedirect = 308
};

/**
 *  Convenience constants for "client error" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, MImportWebServerClientErrorHTTPStatusCode) {
  kMImportWebServerHTTPStatusCode_BadRequest = 400,
  kMImportWebServerHTTPStatusCode_Unauthorized = 401,
  kMImportWebServerHTTPStatusCode_PaymentRequired = 402,
  kMImportWebServerHTTPStatusCode_Forbidden = 403,
  kMImportWebServerHTTPStatusCode_NotFound = 404,
  kMImportWebServerHTTPStatusCode_MethodNotAllowed = 405,
  kMImportWebServerHTTPStatusCode_NotAcceptable = 406,
  kMImportWebServerHTTPStatusCode_ProxyAuthenticationRequired = 407,
  kMImportWebServerHTTPStatusCode_RequestTimeout = 408,
  kMImportWebServerHTTPStatusCode_Conflict = 409,
  kMImportWebServerHTTPStatusCode_Gone = 410,
  kMImportWebServerHTTPStatusCode_LengthRequired = 411,
  kMImportWebServerHTTPStatusCode_PreconditionFailed = 412,
  kMImportWebServerHTTPStatusCode_RequestEntityTooLarge = 413,
  kMImportWebServerHTTPStatusCode_RequestURITooLong = 414,
  kMImportWebServerHTTPStatusCode_UnsupportedMediaType = 415,
  kMImportWebServerHTTPStatusCode_RequestedRangeNotSatisfiable = 416,
  kMImportWebServerHTTPStatusCode_ExpectationFailed = 417,
  kMImportWebServerHTTPStatusCode_UnprocessableEntity = 422,
  kMImportWebServerHTTPStatusCode_Locked = 423,
  kMImportWebServerHTTPStatusCode_FailedDependency = 424,
  kMImportWebServerHTTPStatusCode_UpgradeRequired = 426,
  kMImportWebServerHTTPStatusCode_PreconditionRequired = 428,
  kMImportWebServerHTTPStatusCode_TooManyRequests = 429,
  kMImportWebServerHTTPStatusCode_RequestHeaderFieldsTooLarge = 431
};

/**
 *  Convenience constants for "server error" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, MImportWebServerServerErrorHTTPStatusCode) {
  kMImportWebServerHTTPStatusCode_InternalServerError = 500,
  kMImportWebServerHTTPStatusCode_NotImplemented = 501,
  kMImportWebServerHTTPStatusCode_BadGateway = 502,
  kMImportWebServerHTTPStatusCode_ServiceUnavailable = 503,
  kMImportWebServerHTTPStatusCode_GatewayTimeout = 504,
  kMImportWebServerHTTPStatusCode_HTTPVersionNotSupported = 505,
  kMImportWebServerHTTPStatusCode_InsufficientStorage = 507,
  kMImportWebServerHTTPStatusCode_LoopDetected = 508,
  kMImportWebServerHTTPStatusCode_NotExtended = 510,
  kMImportWebServerHTTPStatusCode_NetworkAuthenticationRequired = 511
};
