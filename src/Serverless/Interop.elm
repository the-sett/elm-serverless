module Serverless.Interop exposing (..)

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)


type alias Key key =
    { bump : key -> key
    , encode : key -> Value
    , decoder : Decoder key
    }


intKey : Key Int
intKey =
    { bump = (+) 1
    , encode = Encode.int
    , decoder = Decode.int
    }


type alias Store store key msg =
    { create : (Value -> msg) -> store -> ( key, store )
    , consume : key -> store -> ( Maybe (Value -> msg), store )
    }


store key =
    { create = ()
    , consume = ()
    }



-- type alias Interop msg =
--     { interopSeqNo : Int
--     , interopContext : Dict Int (Value -> msg)
--     }
--
--
-- consume : Int -> Interop msg -> ( Maybe (Value -> msg), Interop msg )
-- consume seqNo interop =
--     ( Dict.get seqNo interop.interopContext
--     , { interop | interopContext = Dict.remove seqNo interop.interopContext }
--     )
--
--
-- create : (Value -> msg) -> Interop msg -> ( Int, Interop msg )
-- create msgFn interop =
--     let
--         nextSeqNo =
--             interop.interopSeqNo + 1
--     in
--     ( nextSeqNo
--     , { interop
--         | interopSeqNo = nextSeqNo
--         , interopContext = Dict.insert nextSeqNo msgFn interop.interopContext
--       }
--     )
--
--
-- type alias InteropRequestPort a msg =
--     ( String, Int, a ) -> Cmd msg
--
--
-- connect : InteropRequestPort a msg -> a -> (Value -> msg) -> Interop msg -> ( Interop msg, Cmd msg )
-- connect interopPort arg responseFn interop =
--     let
--         ( interopSeqNo, interopWithContext ) =
--             create responseFn interop
--     in
--     ( interopWithContext
--     , interopPort ( "", interopSeqNo, arg )
--     )
