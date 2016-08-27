module DateSelector exposing (view)

import Date exposing (Date, Month(..), year, month, day)
import Date.Extra as Date exposing (Interval(..))
import Date.Extra.Facts exposing (isLeapYear, daysInMonth, monthFromMonthNumber)
import Html exposing (Html, text, div, table, thead, tbody, tr, th, td, ol, li)
import Html.Attributes exposing (class, classList, property)
import Html.Events exposing (on)
import Json.Decode
import Json.Encode
import VirtualDom as Dom


chunk : Int -> List a -> List (List a)
chunk n list =
  if List.isEmpty list then
    []
  else
    List.take n list :: chunk n (List.drop n list)


isBetween : comparable -> comparable -> comparable -> Bool
isBetween a b x =
  a <= x && x <= b || b <= x && x <= a


monthDates : Int -> Month -> List Date
monthDates y m =
  let
    _ = Debug.log "monthDates" (y, m)
    start = Date.floor Monday <| Date.fromCalendarDate y m 1
  in
    Date.range Day 1 start <| Date.add Day 42 start


dateWithYear : Date -> Int -> Date
dateWithYear date y =
  let
    m = month date
    d = day date
  in
    if m == Feb && d == 29 && not (isLeapYear y) then
      Date.fromCalendarDate y Feb 28
    else
      Date.fromCalendarDate y m d


dateWithMonth : Date -> Month -> Date
dateWithMonth date m =
  let
    y = year date
    d = day date
  in
    Date.fromCalendarDate y m <| Basics.min d (daysInMonth y m)


-- View

view : Date -> Date -> Date -> Html Date
view min max selected =
  div
    [ classList
        [ ("date-selector", True)
        , ("scrollable-year", year max - year min >= 12)
        ]
    ]
    [ div
        [ class "year" ]
        [ viewYearList min max selected ]
    , div
        [ class "month" ]
        [ viewMonthList min max selected ]
    , div
        [ class "date" ]
        [ viewDateTable min max selected ]
    ]
  |> Dom.map (Date.clamp min max)


viewYearList : Date -> Date -> Date -> Html Date
viewYearList min max selected =
  let
    years = [ year min .. year max ]
    selectedYear = year selected
  in
    ol
      [ on "click" <|
        Json.Decode.map
          (dateWithYear selected)
          (Json.Decode.at ["target", "year"] Json.Decode.int)
      ]
      (years |> List.map (\y ->
        li
          [ classList [ ("selected", y == selectedYear) ]
          , property "year" <| Json.Encode.int y
          ]
          [ text (toString y) ]))



monthNames : List String
monthNames =
  [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ]


viewMonthList : Date -> Date -> Date -> Html Date
viewMonthList min max selected =
  let
    first = if year selected == year min then Date.monthNumber min else 1
    last = if year selected == year max then Date.monthNumber max else 12
  in
    ol
      [ on "click" <|
        Json.Decode.map
          (dateWithMonth selected << monthFromMonthNumber)
          (Json.Decode.at [ "target", "monthNumber" ] Json.Decode.int)
      ]
      (monthNames |> List.indexedMap (\i name ->
        let
          n = i + 1
        in
          li
            [ classList
                [ ("selected", n == Date.monthNumber selected)
                , ("disabled", not <| isBetween first last n)
                ]
            , property "monthNumber" <| Json.Encode.int n
            ]
            [ text name ]))


dayOfWeekNames : List String
dayOfWeekNames =
  [ "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" ]


viewDateTable : Date -> Date -> Date -> Html Date
viewDateTable min max selected =
  let
    weeks = monthDates (year selected) (month selected) |> chunk 7
  in
    table []
      [ thead []
          [ tr []
              (dayOfWeekNames |> List.map (\name ->
                th [] [ text name ]))
          ]
      , tbody
          [ on "click" <|
              Json.Decode.map
                Date.fromTime
                (Json.Decode.at [ "target", "time" ] Json.Decode.float)
          ]
          (weeks |> List.map (\week ->
            tr []
              (week |> List.map (\date ->
                td
                  [ classList
                      [ ("selected", Date.equal date selected)
                      , ("dimmed", month date /= month selected)
                      , ("disabled", not <| Date.isBetween min max date)
                      ]
                  , property "time" <| Json.Encode.float (Date.toTime date)
                  ]
                  [ text (day date |> toString) ]))))
      ]
