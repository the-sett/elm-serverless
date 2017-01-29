module Custom exposing (..)

import Serverless.Types as Types


type alias Conn =
    Types.Conn Config Model


type alias Config =
    { secret : String
    }


type alias Model =
    { counter : Int
    }
