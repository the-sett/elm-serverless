module Serverless exposing
    ( httpApi, HttpApi, Program
    , IO, RequestPort, ResponsePort
    , noConfig, noRoutes, noSideEffects, noPorts
    , InteropRequestPort, InteropResponsePort, interop
    )

{-| Use `httpApi` to define a `Program` that responds to HTTP requests. Take a look
at the [demos](https://github.com/ktonon/elm-serverless/blob/master/demo)
for usage examples.


## Table of Contents

  - [Defining a Program](#defining-a-program)
  - [Port Types](#port-types)
  - [Initialization Helpers](#initialization-helpers)


## Defining a Program

Use `httpApi` to define a headless Elm program.

@docs httpApi, HttpApi, Program


## Port Types

Since a library cannot expose ports, your application must define two ports
with the following signatures. See the
[Hello World Demo](https://github.com/ktonon/elm-serverless/blob/master/demo/src/Hello)
for a usage example.

@docs IO, RequestPort, ResponsePort


## Initialization Helpers

Various aspects of Program may not be needed. These functions are provided as a
convenient way to opt-out.

@docs noConfig, noRoutes, noSideEffects, noPorts


## Interop ports and helpers.

@docs InteropRequestPort, InteropResponsePort, interop

-}

import Json.Decode exposing (Decoder, decodeValue)
import Json.Encode exposing (Value)
import Serverless.Conn as Conn exposing (Conn, Id)
import Serverless.Conn.Body as Body
import Serverless.Conn.Pool as ConnPool
import Serverless.Conn.Request as Request
import Serverless.Conn.Response as Response exposing (Status)
import Url exposing (Url)


{-| Serverless program type.

This maps to a headless elm
[Platform.Program](http://package.elm-lang.org/packages/elm-lang/core/latest/Platform#Program).

-}
type alias Program config model route msg =
    Platform.Program Flags (Model config model route msg) (Msg msg)


{-| Type of flags for program.

`Value` is a
[Json.Encode.Value](http://package.elm-lang.org/packages/elm-lang/core/latest/Json-Encode#Value).
The program configuration (`config`) is passed in as flags.

-}
type alias Flags =
    Json.Encode.Value


{-| Create a program from the given HTTP api.
-}
httpApi :
    HttpApi config model route msg
    -> Program config model route msg
httpApi api =
    Platform.worker
        { init = init_ api
        , update = update_ api
        , subscriptions = sub_ api
        }


{-| Program for an HTTP API.

A Serverless.Program is parameterized by your 5 custom types

  - `config` is a server load-time record of deployment specific values
  - `model` is for whatever you need during the processing of a request
  - `route` represents your application routes
  - `msg` is your app message type

You must provide the following:

  - `configDecoder` decodes a JSON value for your custom config type
  - `requestPort` and `responsePort` must be defined in your app since an elm library cannot expose ports
  - `initialModel` is a value to which new connections will set their model
  - `parseRoute` takes the `request/path/and?query=string` and parses it into a `route`
  - `endpoint` is a function which receives incoming connections
  - `update` the app update function

Notices that `update` and `endpoint` operate on `Conn config model route msg`
and not just on `model`.

-}
type alias HttpApi config model route msg =
    { configDecoder : Decoder config
    , initialModel : model
    , parseRoute : Url -> Maybe route
    , endpoint : Conn config model route msg -> ( Conn config model route msg, Cmd msg )
    , update : msg -> Conn config model route msg -> ( Conn config model route msg, Cmd msg )
    , requestPort : RequestPort (Msg msg)
    , responsePort : ResponsePort (Msg msg)
    , interopPorts : List (InteropResponsePort (Msg msg))
    }


{-| Describes input and output events over ports as a connection id paired with
a data value.
-}
type alias IO =
    ( String, Json.Encode.Value )


{-| Type of port through which the request is received.
Set your request port to this type.

    port requestPort : RequestPort msg

-}
type alias RequestPort msg =
    (IO -> msg) -> Sub msg


{-| Type of port through which the request is sent.
Set your response port to this type.

    port responsePort : ResponsePort msg

-}
type alias ResponsePort msg =
    IO -> Cmd msg



-- OPT-OUT PROGRAM INITIALIZERS


{-| Opt-out of configuration decoding.

    main : Serverless.Program () model route msg
    main =
        Serverless.httpApi
            { configDecoder = noConfig

            -- ...
            }

-}
noConfig : Json.Decode.Decoder ()
noConfig =
    Json.Decode.succeed ()


{-| Opt-out of route parsing.

    main : Serverless.Program config model () msg
    main =
        Serverless.httpApi
            { parseRoute = noRoutes

            -- ...
            }

-}
noRoutes : Url -> Maybe ()
noRoutes _ =
    Just ()


{-| Opt-out of side-effects.

    main : Serverless.Program config model route ()
    main =
        Serverless.httpApi
            { update = noSideEffects

            -- ...
            }

-}
noSideEffects :
    ()
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd () )
noSideEffects _ conn =
    ( conn, Cmd.none )


{-| Opt-out of interop ports.

    main : Serverless.Program config model route ()
    main =
        Serverless.httpApi
            { ports = noPorts

            -- ...
            }

-}
noPorts : List (InteropResponsePort (Msg msg))
noPorts =
    []



-- IMPLEMENTATION


type alias Model config model route msg =
    { pool : ConnPool.Pool config model route msg
    , configResult : Result String config
    }


type Msg msg
    = RequestPortMsg IO
    | HandlerMsg Id msg
    | InteropHandlerMsg Id Int Value
    | HandlerDecodeErr Id Json.Decode.Error


type SlsMsg config model route msg
    = RequestAdd (Conn config model route msg)
    | RequestUpdate Id msg
    | RequestInteropResponse Id Int Value
    | ProcessingError Id Int Bool String


init_ :
    HttpApi config model route msg
    -> Flags
    -> ( Model config model route msg, Cmd (Msg msg) )
init_ api flags =
    case decodeValue api.configDecoder flags of
        Ok config ->
            ( { pool = ConnPool.empty
              , configResult = Ok config
              }
            , Cmd.none
            )

        Err err ->
            ( { pool = ConnPool.empty
              , configResult = Err <| Json.Decode.errorToString err
              }
            , Cmd.none
            )


toSlsMsg :
    HttpApi config model route msg
    -> Result String config
    -> Msg msg
    -> SlsMsg config model route msg
toSlsMsg api configResult rawMsg =
    case ( configResult, rawMsg ) of
        ( Err err, RequestPortMsg ( id, _ ) ) ->
            ProcessingError id 500 True <|
                (++) "Failed to parse configuration flags. " err

        ( Ok config, RequestPortMsg ( id, raw ) ) ->
            case decodeValue Request.decoder raw of
                Ok req ->
                    case
                        Request.url req
                            |> Url.fromString
                            |> Maybe.andThen api.parseRoute
                    of
                        Just route ->
                            RequestAdd <| Conn.init id config api.initialModel route req

                        Nothing ->
                            ProcessingError id 404 False <|
                                (++) "Could not parse route: "
                                    (Request.path req)

                Err err ->
                    ProcessingError id 500 False <|
                        (++) "Misconfigured server. Make sure the elm-serverless npm package version matches the elm package version."
                            (Json.Decode.errorToString err)

        ( _, HandlerMsg id msg ) ->
            RequestUpdate id msg

        ( _, InteropHandlerMsg id seqNo val ) ->
            RequestInteropResponse id seqNo val

        ( _, HandlerDecodeErr id err ) ->
            ProcessingError id 500 False <|
                (++) "Failed to decode interop handler argument."
                    (Json.Decode.errorToString err)


update_ :
    HttpApi config model route msg
    -> Msg msg
    -> Model config model route msg
    -> ( Model config model route msg, Cmd (Msg msg) )
update_ api rawMsg model =
    case toSlsMsg api model.configResult rawMsg of
        RequestAdd conn ->
            updateChildHelper api
                (api.endpoint conn)
                model

        RequestUpdate connId msg ->
            updateChild api connId msg model

        RequestInteropResponse connId seqNo val ->
            updateChildForInteropResponse api connId seqNo val model

        ProcessingError connId status secret err ->
            let
                errMsg =
                    if secret then
                        "Internal Server Error. Check logs for details."

                    else
                        err
            in
            ( model, send api connId status errMsg )


updateChild :
    HttpApi config model route msg
    -> Id
    -> msg
    -> Model config model route msg
    -> ( Model config model route msg, Cmd (Msg msg) )
updateChild api connId msg model =
    case ConnPool.get connId model.pool of
        Just conn ->
            updateChildHelper api (api.update msg conn) model

        _ ->
            ( model
            , send api connId 500 <|
                (++) "No connection in pool with id: " connId
            )


updateChildForInteropResponse :
    HttpApi config model route msg
    -> Id
    -> Int
    -> Value
    -> Model config model route msg
    -> ( Model config model route msg, Cmd (Msg msg) )
updateChildForInteropResponse api connId seqNo val model =
    case ConnPool.get connId model.pool of
        Just conn ->
            let
                -- Find the message builder by seq no.
                -- Clean up the sequence number on the connection.
                ( maybeMsgBuilder, newConn ) =
                    Conn.consumeInteropContext seqNo conn
            in
            case maybeMsgBuilder of
                Just msgBuilder ->
                    -- Run `update` on the connection with the message.
                    updateChildHelper api (api.update (msgBuilder val) newConn) model

                Nothing ->
                    ( model
                    , send api connId 500 <|
                        "No message builder for interop seqNo "
                            ++ String.fromInt seqNo
                            ++ " on pool with id: "
                            ++ connId
                    )

        _ ->
            ( model
            , send api connId 500 <|
                "No connection in pool with id: "
                    ++ connId
            )


updateChildHelper :
    HttpApi config model route msg
    -> ( Conn config model route msg, Cmd msg )
    -> Model config model route msg
    -> ( Model config model route msg, Cmd (Msg msg) )
updateChildHelper api ( conn, cmd ) model =
    case Conn.unsent conn of
        Nothing ->
            ( { model | pool = model.pool |> ConnPool.remove conn }
            , api.responsePort
                ( Conn.id conn
                , Conn.jsonEncodedResponse conn
                )
            )

        Just unsentConn ->
            ( { model
                | pool =
                    ConnPool.replace
                        unsentConn
                        model.pool
              }
            , Cmd.map (HandlerMsg (Conn.id conn)) cmd
            )


sub_ :
    HttpApi config model route msg
    -> Model config model route msg
    -> Sub (Msg msg)
sub_ api model =
    let
        responseMap : InteropResponsePort (Msg msg) -> Sub (Msg msg)
        responseMap interopResponsePort =
            interopResponsePort (\( id, interopSeqNo, val ) -> InteropHandlerMsg id interopSeqNo val)

        interopSubs : List (Sub (Msg msg))
        interopSubs =
            List.map (\interopPort -> responseMap interopPort) api.interopPorts
    in
    Sub.batch
        (api.requestPort RequestPortMsg
            :: interopSubs
        )



-- JS Interop


{-| The type of all incoming interop ports.
-}
type alias InteropResponsePort msg =
    (( String, Int, Json.Encode.Value ) -> msg) -> Sub msg


{-| The type of all outgoing interop ports.
-}
type alias InteropRequestPort a msg =
    ( String, Int, a ) -> Cmd msg


{-| Interop helper that invokes a port that follows the InteropRequestPort model.
This helper function automatically passes the connection id to the port with the
data. The connection id is needed if the port generates a response, in order to send
the response to the correct connection.

Note that it is possible to invoke any port, this is just a helper function for
a default way of doing it.

-}
interop : InteropRequestPort a msg -> a -> (Value -> msg) -> Conn config model route msg -> ( Conn config model route msg, Cmd msg )
interop interopPort arg responseFn conn =
    let
        ( interopSeqNo, connWithContext ) =
            Conn.createInteropContext responseFn conn
    in
    ( connWithContext
    , interopPort ( Conn.id conn, interopSeqNo, arg )
    )



-- HELPERS


send :
    HttpApi config model route msg
    -> Id
    -> Status
    -> String
    -> Cmd (Msg msg)
send { responsePort } id code msg =
    responsePort
        ( id
        , Response.init
            |> Response.setStatus code
            |> Response.setBody (Body.text msg)
            |> Response.encode
        )
