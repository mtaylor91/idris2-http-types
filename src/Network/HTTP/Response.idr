module Network.HTTP.Response

import Data.Buffer.Indexed
import Data.ByteString
import Data.IORef
import Data.String
import Network.HTTP.Connection
import Network.HTTP.Headers
import Network.HTTP.Protocol
import Network.HTTP.Request
import Network.Socket


public export
record Status where
  constructor MkStatus
  code : Int
  text : String


public export
Show Status where
  show status = "MkStatus " ++ show status.code ++ " " ++ status.text


public export
record Response b where
  constructor MkResponse
  status : Status
  headers : Headers
  body : b


public export
Show (Response b) where
  show response
    = "MkResponse ("
    ++ show response.status ++ ") "
    ++ show response.headers
    ++ " <Body>"


public export
contentLength : Response b -> Maybe Nat
contentLength response =
  case getHeader "Content-Length" response.headers of
    Just contentLengthString =>
      parsePositive contentLengthString
    Nothing =>
      Nothing


public export
statusContinue : Status
statusContinue = MkStatus 100 "Continue"

public export
statusSwitchingProtocols : Status
statusSwitchingProtocols = MkStatus 101 "Switching Protocols"

public export
statusOK : Status
statusOK = MkStatus 200 "OK"

public export
statusCreated : Status
statusCreated = MkStatus 201 "Created"

public export
statusAccepted : Status
statusAccepted = MkStatus 202 "Accepted"

public export
statusNonAuthoritativeInformation : Status
statusNonAuthoritativeInformation = MkStatus 203 "Non-Authoritative Information"

public export
statusNoContent : Status
statusNoContent = MkStatus 204 "No Content"

public export
statusResetContent : Status
statusResetContent = MkStatus 205 "Reset Content"

public export
statusPartialContent : Status
statusPartialContent = MkStatus 206 "Partial Content"

public export
statusMultipleChoices : Status
statusMultipleChoices = MkStatus 300 "Multiple Choices"

public export
statusMovedPermanently : Status
statusMovedPermanently = MkStatus 301 "Moved Permanently"

public export
statusFound : Status
statusFound = MkStatus 302 "Found"

public export
statusSeeOther : Status
statusSeeOther = MkStatus 303 "See Other"

public export
statusNotModified : Status
statusNotModified = MkStatus 304 "Not Modified"

public export
statusUseProxy : Status
statusUseProxy = MkStatus 305 "Use Proxy"

public export
statusTemporaryRedirect : Status
statusTemporaryRedirect = MkStatus 307 "Temporary Redirect"

public export
statusBadRequest : Status
statusBadRequest = MkStatus 400 "Bad Request"

public export
statusUnauthorized : Status
statusUnauthorized = MkStatus 401 "Unauthorized"

public export
statusPaymentRequired : Status
statusPaymentRequired = MkStatus 402 "Payment Required"

public export
statusForbidden : Status
statusForbidden = MkStatus 403 "Forbidden"

public export
statusNotFound : Status
statusNotFound = MkStatus 404 "Not Found"

public export
statusMethodNotAllowed : Status
statusMethodNotAllowed = MkStatus 405 "Method Not Allowed"

public export
statusNotAcceptable : Status
statusNotAcceptable = MkStatus 406 "Not Acceptable"

public export
statusProxyAuthenticationRequired : Status
statusProxyAuthenticationRequired = MkStatus 407 "Proxy Authentication Required"

public export
statusRequestTimeOut : Status
statusRequestTimeOut = MkStatus 408 "Request Time-out"

public export
statusConflict : Status
statusConflict = MkStatus 409 "Conflict"

public export
statusGone : Status
statusGone = MkStatus 410 "Gone"

public export
statusLengthRequired : Status
statusLengthRequired = MkStatus 411 "Length Required"

public export
statusPreconditionFailed : Status
statusPreconditionFailed = MkStatus 412 "Precondition Failed"

public export
statusRequestEntityTooLarge : Status
statusRequestEntityTooLarge = MkStatus 413 "Request Entity Too Large"

public export
statusRequestURITooLarge : Status
statusRequestURITooLarge = MkStatus 414 "Request-URI Too Large"

public export
statusUnsupportedMediaType : Status
statusUnsupportedMediaType = MkStatus 415 "Unsupported Media Type"

public export
statusRequestedRangeNotSatisfiable : Status
statusRequestedRangeNotSatisfiable = MkStatus 416 "Requested range not satisfiable"

public export
statusExpectationFailed : Status
statusExpectationFailed = MkStatus 417 "Expectation Failed"

public export
statusImATeapot : Status
statusImATeapot = MkStatus 418 "I'm a teapot"

public export
statusInternalServerError : Status
statusInternalServerError = MkStatus 500 "Internal Server Error"

public export
statusNotImplemented : Status
statusNotImplemented = MkStatus 501 "Not Implemented"

public export
statusBadGateway : Status
statusBadGateway = MkStatus 502 "Bad Gateway"

public export
statusServiceUnavailable : Status
statusServiceUnavailable = MkStatus 503 "Service Unavailable"

public export
statusGatewayTimeOut : Status
statusGatewayTimeOut = MkStatus 504 "Gateway Time-out"

public export
statusHTTPVersionNotSupported : Status
statusHTTPVersionNotSupported = MkStatus 505 "HTTP Version not supported"


export
http1ResponseLine : Response b -> String
http1ResponseLine response
  = "HTTP/1.1 "
  ++ show response.status.code ++ " "
  ++ response.status.text


export
http1Response : Response ByteString -> String
http1Response response
  = http1ResponseLine response ++ "\r\n"
  ++ http1Headers response.headers ++ "\r\n"
  ++ toString response.body


export
addHeader : String -> String -> Response b -> Response b
addHeader k v response =
  { headers := addHeader (MkHeader k [v]) response.headers } response


export
withContentLength : Response ByteString -> Response ByteString
withContentLength response =
  if hasHeader "Content-Length" response.headers
     then response
     else addHeader "Content-Length" (show $ length response.body) response


export
readResponseHeaders : Connection -> IO (Either ConnectionError (Response Connection))
readResponseHeaders connection = do
  Right line <- recvLine connection
  | Left error => pure $ Left $ ConnectionSocketError error

  Just ("HTTP/1.1", statusCode, statusText) <- pure $ parseResponseLine $ toString line
  | _ => pure $ Left $ ConnectionProtocolError $ ProtocolErrorMessage "Invalid response"

  Right headers <- recvHeaders connection empty
  | Left error => pure $ Left error

  pure $ Right $ MkResponse (MkStatus statusCode statusText) headers connection


export
readResponseBody : Response Connection -> IO (Either ConnectionError ByteString)
readResponseBody response =
  case contentLength response of
    Just contentLength => do
      Right body <- Network.HTTP.Connection.recvBytes response.body contentLength
      | Left error => pure $ Left $ ConnectionSocketError error
      pure $ Right body
    Nothing => pure $ Left $ ConnectionProtocolError $
      ProtocolErrorMessage "No Content-Length header"
