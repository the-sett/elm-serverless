module Serverless.Conn.Body exposing
    ( Body
    , text, json, binary, empty
    , asJson, asText, isEmpty, contentType
    , decoder, encode, isBase64Encoded
    )

{-|


## HTTP Body

@docs Body


## Response Body

Use these constructors to create response bodies with different content types.

@docs text, json, binary, empty


## Request Body

Use these functions to check what kind of body a request has.

@docs asJson, asText, isEmpty, contentType


## Misc

These functions are typically not needed when building an application. They are
used internally by the framework. They may be useful when debugging or writing
unit tests.

@docs decoder, encode, isBase64Encoded

-}

import Json.Decode as Decode exposing (Decoder, andThen)
import Json.Encode as Encode


{-| An HTTP request or response body.
-}
type Body
    = Empty
    | Error String
    | Text String
    | Json Encode.Value
    | Binary String String



-- CONSTRUCTORS


{-| Create an empty body.
-}
empty : Body
empty =
    Empty


{-| A plain text body.
-}
text : String -> Body
text =
    Text


{-| A JSON body.
-}
json : Encode.Value -> Body
json =
    Json


{-| A binary file.
-}
binary : String -> String -> Body
binary =
    Binary



-- DESTRUCTURING


{-| Extract the String from the body.
-}
asText : Body -> Result String String
asText body =
    case body of
        Empty ->
            Ok ""

        Error err ->
            Err err

        Text val ->
            Ok val

        Json val ->
            Ok <| Encode.encode 0 val

        Binary _ val ->
            Ok val


{-| Extract the JSON value from the body.
-}
asJson : Body -> Result String Encode.Value
asJson body =
    case body of
        Empty ->
            Ok Encode.null

        Error err ->
            Err err

        Text val ->
            val
                |> Decode.decodeString Decode.value
                |> Result.mapError Decode.errorToString

        Json val ->
            Ok val

        Binary _ val ->
            Decode.decodeString Decode.value val
                |> Result.mapError Decode.errorToString



-- QUERY


{-| The content type of a given body.

    import Json.Encode

    contentType (text "hello")
    --> "text/text"

    contentType (json Json.Encode.null)
    --> "application/json"

-}
contentType : Body -> String
contentType body =
    case body of
        Json _ ->
            "application/json"

        Binary binType _ ->
            binType

        _ ->
            "text/text"


{-| Is the given body empty?

    import Json.Encode exposing (list)

    isEmpty (empty)
    --> True

    isEmpty (text "")
    --> False

    isEmpty (json (list []))
    --> False

-}
isEmpty : Body -> Bool
isEmpty body =
    case body of
        Empty ->
            True

        _ ->
            False


{-| Checks if a body should be base 64 encoded.
-}
isBase64Encoded : Body -> Bool
isBase64Encoded body =
    case body of
        Binary _ _ ->
            True

        _ ->
            False



-- UPDATE


{-| Appends text to a given body if possible.

    import Json.Encode exposing (list)

    text "foo" |> appendText "bar"
    --> Ok (text "foobar")

    empty |> appendText "to empty"
    --> Ok (text "to empty")

    json (list []) |> appendText "will fail"
    --> Err "cannot append text to json"

-}
appendText : String -> Body -> Result String Body
appendText val body =
    case body of
        Empty ->
            Ok (Text val)

        Error err ->
            Err <| "cannot append to body with error: " ++ err

        Text existingVal ->
            Ok (Text (existingVal ++ val))

        Json jval ->
            Err "cannot append text to json"

        Binary _ _ ->
            Err "cannot append text to binary"



-- JSON


{-| A decoder for an HTTP body, to JSON or plain text.
-}
decoder : Maybe String -> Decoder Body
decoder maybeType =
    Decode.nullable Decode.string
        |> andThen
            (\maybeString ->
                case maybeString of
                    Just w ->
                        if maybeType |> Maybe.withDefault "" |> String.startsWith "application/json" then
                            case Decode.decodeString Decode.value w of
                                Ok val ->
                                    Decode.succeed <| Json val

                                Err err ->
                                    err
                                        |> Decode.errorToString
                                        |> Error
                                        |> Decode.succeed

                        else
                            Decode.succeed <| Text w

                    Nothing ->
                        Decode.succeed Empty
            )


{-| An encoder for an HTTP body.
-}
encode : Body -> Encode.Value
encode body =
    case body of
        Empty ->
            Encode.null

        Error err ->
            Encode.string err

        Text w ->
            Encode.string w

        Json j ->
            j

        Binary _ v ->
            Encode.string v
