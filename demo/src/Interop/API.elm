port module Interop.API exposing (Conn, Msg(..), Route(..), endpoint, main, requestPort, responsePort, update)

import Json.Encode
import Random
import Serverless
import Serverless.Conn exposing (jsonBody, respond, route)
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

        -- Route /:lowerBound/:upperBound
        , parseRoute =
            oneOf
                [ map Unit (s "unit")
                ]
                |> Url.Parser.parse

        -- Incoming connection handler
        , endpoint = endpoint

        -- Like a SPA update function, but operates on Conn
        , update = update
        }



-- ROUTING


type Route
    = Unit


endpoint : Conn -> ( Conn, Cmd Msg )
endpoint conn =
    case route conn of
        Unit ->
            ( conn
            , Random.generate RandomFloat <|
                Random.float 0 1
            )



-- UPDATE


type Msg
    = RandomFloat Float


update : Msg -> Conn -> ( Conn, Cmd Msg )
update msg conn =
    case msg of
        RandomFloat val ->
            respond ( 200, jsonBody <| Json.Encode.float val ) conn



-- TYPES


type alias Conn =
    Serverless.Conn.Conn () () Route


port requestPort : Serverless.RequestPort msg


port responsePort : Serverless.ResponsePort msg
