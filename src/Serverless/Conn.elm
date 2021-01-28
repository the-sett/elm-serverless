module Serverless.Conn exposing
    ( Conn, Id
    , config, model, updateModel
    , request, id, method, header, route
    , respond, updateResponse, send, toSent, unsent, mapUnsent
    , init, jsonEncodedResponse
    , createInteropContext, consumeInteropContext
    )

{-| Functions for querying and updating connections.

@docs Conn, Id


## Table of Contents

  - [Processing Application Data](#processing-application-data)
  - [Querying the Request](#querying-the-request)
  - [Responding](#responding)
  - [Response Body](#response-body)


## Processing Application Data

Query and update your application specific data.

@docs config, model, updateModel


## Querying the Request

Get details about the HTTP request.

@docs request, id, method, header, route


## Responding

Update the response and send it.

@docs respond, updateResponse, send, toSent, unsent, mapUnsent


## Misc

These functions are typically not needed when building an application. They are
used internally by the framework. They may be useful when debugging or writing
unit tests.

@docs init, jsonEncodedResponse
@docs createInteropContext, consumeInteropContext

-}

import Dict exposing (Dict)
import Json.Encode exposing (Value)
import Serverless.Conn.Body as Body exposing (Body)
import Serverless.Conn.Request as Request exposing (Method, Request)
import Serverless.Conn.Response as Response exposing (Response, Status, setBody, setStatus)


{-| A connection with a request and response.

Connections are parameterized with config and model record types which are
specific to the application. Config is loaded once on app startup, while model
is set to a provided initial value for each incomming request.

-}
type Conn config model route msg
    = Conn (Impl config model route msg)


{-| Universally unique connection identifier.
-}
type alias Id =
    String


type alias Impl config model route msg =
    { id : Id
    , config : config
    , req : Request
    , resp : Sendable Response
    , model : model
    , route : route
    , interopSeqNo : Int
    , interopContext : Dict Int (Value -> msg)
    }


type Sendable a
    = Unsent a
    | Sent Json.Encode.Value



-- PROCESSING APPLICATION DATA


{-| Application defined configuration
-}
config : Conn config model route msg -> config
config (Conn conn) =
    conn.config


{-| Application defined model
-}
model : Conn config model route msg -> model
model (Conn conn) =
    conn.model


{-| Transform and update the application defined model stored in the connection.
-}
updateModel : (model -> model) -> Conn config model route msg -> Conn config model route msg
updateModel update (Conn conn) =
    Conn { conn | model = update conn.model }



-- QUERYING THE REQUEST


{-| Request
-}
request : Conn config model route msg -> Request
request (Conn { req }) =
    req


{-| Get a request header by name
-}
header : String -> Conn config model route msg -> Maybe String
header key (Conn { req }) =
    Request.header key req


{-| Request HTTP method
-}
method : Conn config model route msg -> Method
method =
    request >> Request.method


{-| Parsed route
-}
route : Conn config model route msg -> route
route (Conn conn) =
    conn.route



-- RESPONDING


{-| Update a response and send it.

    import Serverless.Conn.Response exposing (setBody, setStatus)
    import TestHelpers exposing (conn, responsePort)

    -- The following two expressions produce the same result
    conn
        |> respond ( 200, textBody "Ok" )
    --> conn
    -->     |> updateResponse
    -->         ((setStatus 200) >> (setBody <| textBody "Ok"))
    -->     |> send

-}
respond :
    ( Status, Body )
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
respond ( status, body ) =
    updateResponse
        (setStatus status >> setBody body)
        >> send


{-| Applies the given transformation to the connection response.

Does not do anything if the response has already been sent.

    import Serverless.Conn.Response exposing (addHeader)
    import TestHelpers exposing (conn, getHeader)

    conn
        |> updateResponse
            (addHeader ( "Cache-Control", "no-cache" ))
        |> getHeader "cache-control"
    --> Just "no-cache"

-}
updateResponse :
    (Response -> Response)
    -> Conn config model route msg
    -> Conn config model route msg
updateResponse updater (Conn conn) =
    Conn <|
        case conn.resp of
            Unsent resp ->
                { conn | resp = Unsent (updater resp) }

            Sent _ ->
                conn


{-| Sends a connection response through the given port
-}
send :
    Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
send conn =
    ( toSent conn, Cmd.none )


{-| Converts a conn to a sent conn, making it immutable.

The connection will be sent once the current update loop completes. This
function is intended to be used by middleware, which cannot issue side-effects.

    import TestHelpers exposing (conn)

    (unsent conn) == Just conn
    --> True

    (unsent <| toSent conn) == Nothing
    --> True

-}
toSent :
    Conn config model route msg
    -> Conn config model route msg
toSent (Conn conn) =
    case conn.resp of
        Unsent resp ->
            Conn
                { conn | resp = Sent <| Response.encode resp }

        Sent _ ->
            Conn conn


{-| Return `Just` the same can if it has not been sent yet.
-}
unsent : Conn config model route msg -> Maybe (Conn config model route msg)
unsent (Conn conn) =
    case conn.resp of
        Sent _ ->
            Nothing

        Unsent _ ->
            Just <| Conn conn


{-| Apply an update function to a conn, but only if the conn is unsent.
-}
mapUnsent :
    (Conn config model route msg -> ( Conn config model route msg, Cmd msg ))
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
mapUnsent func (Conn conn) =
    case conn.resp of
        Sent _ ->
            ( Conn conn, Cmd.none )

        Unsent _ ->
            func (Conn conn)



-- MISC


{-| Universally unique Conn identifier
-}
id : Conn config model route msg -> Id
id (Conn conn) =
    conn.id


{-| Attemps to find the response message builder for an interop port call, by its
unique sequence number, and removes this sequence number from the context store
on the connection.
-}
consumeInteropContext : Int -> Conn config model route msg -> ( Maybe (Value -> msg), Conn config model route msg )
consumeInteropContext seqNo (Conn conn) =
    ( Dict.get seqNo conn.interopContext
    , { conn | interopContext = Dict.remove seqNo conn.interopContext }
        |> Conn
    )


{-| Adds a response message builder for an interop port call, under a unique sequence number
on the connection.
-}
createInteropContext : (Value -> msg) -> Conn config model route msg -> ( Int, Conn config model route msg )
createInteropContext msgFn (Conn conn) =
    let
        nextSeqNo =
            conn.interopSeqNo + 1
    in
    ( nextSeqNo
    , { conn
        | interopSeqNo = nextSeqNo
        , interopContext = Dict.insert nextSeqNo msgFn conn.interopContext
      }
        |> Conn
    )


{-| Initialize a new Conn.
-}
init : Id -> config -> model -> route -> Request -> Conn config model route msg
init givenId givenConfig givenModel givenRoute req =
    Conn
        { id = givenId
        , config = givenConfig
        , req = req
        , resp = Unsent Response.init
        , model = givenModel
        , route = givenRoute
        , interopSeqNo = 0
        , interopContext = Dict.empty
        }


{-| Response as JSON encoded to a string.

This is the format the response takes when it gets sent through the response port.

-}
jsonEncodedResponse : Conn config model route msg -> Json.Encode.Value
jsonEncodedResponse (Conn conn) =
    case conn.resp of
        Unsent resp ->
            Response.encode resp

        Sent encodedValue ->
            encodedValue
