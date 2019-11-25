module Quoted.Models.Quote exposing (decodeQuote, encodeList, format, request)

import Http
import Json.Decode exposing (Decoder, string, succeed)
import Json.Decode.Pipeline exposing (hardcoded, required)
import Json.Encode as Encode exposing (Value)
import Quoted.Types exposing (Quote)
import Task



-- MODEL


format : String -> Quote -> String
format lineBreak quote =
    quote.text ++ lineBreak ++ "--" ++ quote.author


encodeList : List Quote -> Value
encodeList quotes =
    Encode.object
        [ ( "quotes"
          , quotes
                |> List.map
                    (\quote ->
                        Encode.object
                            [ ( "lang", quote.lang |> Encode.string )
                            , ( "text", quote.text |> Encode.string )
                            , ( "author", quote.author |> Encode.string )
                            ]
                    )
                |> Encode.list identity
          )
        ]



-- DECODER


decodeQuote : String -> Decoder Quote
decodeQuote lang =
    succeed Quote
        |> hardcoded lang
        |> required "quoteText" string
        |> required "quoteAuthor" string


request : String -> Task.Task Http.Error Quote
request lang =
    Http.task
        { method = "GET"
        , headers = []
        , url = "http://api.forismatic.com/api/1.0/?method=getQuote&format=json&lang=" ++ lang
        , body = Http.emptyBody
        , resolver = jsonResolver (decodeQuote lang)
        , timeout = Nothing
        }


jsonResolver : Decoder a -> Http.Resolver Http.Error a
jsonResolver decoder =
    let
        resolveToJson : Http.Response String -> Result Http.Error a
        resolveToJson resp =
            case resp of
                Http.BadUrl_ url ->
                    Err (Http.BadUrl url)

                Http.Timeout_ ->
                    Err Http.Timeout

                Http.NetworkError_ ->
                    Err Http.NetworkError

                Http.BadStatus_ metadata body ->
                    Err (Http.BadStatus metadata.statusCode)

                Http.GoodStatus_ metadata body ->
                    case Json.Decode.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (Http.BadBody (Json.Decode.errorToString err))
    in
    Http.stringResolver resolveToJson
