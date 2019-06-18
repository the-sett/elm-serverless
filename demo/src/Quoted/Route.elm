module Quoted.Route exposing (Lang(..), Query, Route(..), Sort(..), lang, query, queryToString, route, sort)

import Url.Parser exposing ((</>), (<?>), Parser, map, oneOf, s, string, top)
import Url.Parser.Query as Query


type Route
    = Home Query
    | Quote Lang
    | Buggy
    | Number


type Lang
    = LangAll
    | Lang String


type Sort
    = Asc
    | Desc


type alias Query =
    { q : String
    , sort : Sort
    }


route : Parser (Route -> a) a
route =
    oneOf
        [ map Home (top </> query)
        , map Quote (s "quote" </> lang)
        , map Buggy (s "buggy")
        , map Number (s "number")
        ]


lang : Parser (Lang -> a) a
lang =
    oneOf
        [ map LangAll top
        , map Lang string
        ]


query : Parser (Query -> a) a
query =
    map Query
        (top
            <?> (Query.string "q" |> Query.map (Maybe.withDefault ""))
            <?> (Query.string "sort" |> Query.map sort)
        )


queryToString : Query -> String
queryToString q =
    "query"


sort : Maybe String -> Sort
sort =
    Maybe.withDefault ""
        >> (\val ->
                if val == "asc" then
                    Asc

                else
                    Desc
           )
