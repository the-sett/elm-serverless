port module Interop.API exposing (Conn, Msg(..), Route(..), endpoint, main, requestPort, responsePort, update)

import Json.Decode
import Json.Encode
import Serverless
import Serverless.Conn exposing (respond, route)
import Serverless.Conn.Body as Body
import Url.Parser exposing ((</>), int, map, oneOf, s, top)


{-| Shows how to use the update function to handle side-effects.
-}
main : Serverless.Program () () Route Msg
main =
    Serverless.httpApi
        { configDecoder = Serverless.noConfig
        , initialModel = ()
        , requestPort = requestPort
        , responsePort = responsePort
        , interopPorts = [ respondRand ]
        , parseRoute =
            oneOf
                [ map Unit (s "unit")
                ]
                |> Url.Parser.parse
        , endpoint = endpoint
        , update = update
        }



-- ROUTING


type Route
    = Unit


endpoint : Conn -> ( Conn, Cmd Msg )
endpoint conn =
    case route conn of
        Unit ->
            Serverless.interop requestRand
                ()
                (\val ->
                    Json.Decode.decodeValue
                        (Json.Decode.map RandomFloat Json.Decode.float)
                        val
                        |> Result.withDefault Error
                )
                conn



-- UPDATE


type Msg
    = RandomFloat Float
    | Error


update : Msg -> Conn -> ( Conn, Cmd Msg )
update msg conn =
    case msg of
        RandomFloat val ->
            respond ( 200, Body.json <| Json.Encode.float val ) conn

        Error ->
            respond ( 500, Body.text "Error during interop." ) conn



-- TYPES


type alias Conn =
    Serverless.Conn.Conn () () Route Msg


port requestPort : Serverless.RequestPort msg


port responsePort : Serverless.ResponsePort msg


port requestRand : Serverless.InteropRequestPort () msg


port respondRand : Serverless.InteropResponsePort msg
