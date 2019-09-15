module ClickSpec exposing (..)

import Spec exposing (Spec)
import Spec.Subject as Subject
import Spec.Scenario exposing (..)
import Spec.Html as Markup
import Spec.Html.Selector exposing (..)
import Spec.Html.Event as Event
import Runner
import Main as App


clickSpec : Spec App.Model App.Msg
clickSpec =
  Spec.describe "an html program"
  [ scenario "a click event" (
      Subject.initWithModel App.defaultModel
        |> Subject.withUpdate App.update
        |> Subject.withView App.view
    )
    |> when "the button is clicked three times"
      [ Markup.target << by [ id "my-button" ]
      , Event.click
      , Event.click
      , Event.click
      ]
    |> it "renders the count" (
      Markup.select << by [ id "count-results" ]
        |> Markup.expectElement (Markup.hasText "You clicked the button 3 time(s)")
    )
  ]


main =
  Runner.program
    [ clickSpec
    ]