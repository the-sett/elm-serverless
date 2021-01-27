module Serverless.Conn.Pool exposing
    ( Pool
    , empty
    , get
    , remove
    , replace
    , size
    )

import Dict exposing (Dict)
import Serverless.Conn as Conn exposing (Conn, Id)


type Pool config model route msg
    = Pool
        { connDict : Dict Id (Conn config model route msg)
        }


empty : Pool config model route msg
empty =
    Pool { connDict = Dict.empty }


get :
    Id
    -> Pool config model route msg
    -> Maybe (Conn config model route msg)
get requestId (Pool { connDict }) =
    Dict.get requestId connDict


replace :
    Conn config model route msg
    -> Pool config model route msg
    -> Pool config model route msg
replace conn (Pool pool) =
    Pool
        { pool
            | connDict =
                Dict.insert
                    (Conn.id conn)
                    conn
                    pool.connDict
        }


remove :
    Conn config model route msg
    -> Pool config model route msg
    -> Pool config model route msg
remove conn (Pool pool) =
    Pool
        { pool
            | connDict =
                pool.connDict
                    |> Dict.remove (Conn.id conn)
        }


size : Pool config model route msg -> Int
size (Pool { connDict }) =
    Dict.size connDict
