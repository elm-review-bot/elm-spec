module Spec.Port exposing
  ( send
  , observe
  )

{-| Functions for working with ports during a spec.

Suppose your app sends a port command when a button is clicked,
via a function called `my-command-port` that takes a string ("TRIGGER_REQUEST" in
this case), and then displays a message received over a port subscription. You
could write a scenario like so:

    Spec.describe "command ports and subscription ports"
    [ Spec.scenario "send and receive" (
        Spec.given (
          Spec.Setup.withInit (App.init testFlags)
            |> Spec.Setup.withUpdate App.update
            |> Spec.Setup.withView App.view
            |> Spec.Setup.withSubscriptions App.subscriptions
        )
        |> Spec.when "a message is sent out"
          [ Spec.Markup.target << by [ tag "button" ]
          , Spec.Markup.Event.click
          ]
        |> Spec.when "a response is received"
          [ Spec.Port.send "my-subscription-port" <|
              Json.Encode.object
                [ ("message", Encode.string "Have fun!")
                ]
          ]
        |> Spec.observeThat
          [ Spec.it "sent the right message over the port" (
              Spec.Port.observe "my-command-port" Json.Decode.string
                |> Spec.expect (Spec.Claim.isListWhere
                  [ Spec.Claim.isEqual Debug.toString "TRIGGER_REQUEST"
                  ]
                )
            )
          , Spec.it "shows the message received" (
              Spec.Markup.observeElement
                |> Spec.Markup.query << by [ id "message" ]
                |> Spec.expect (
                  Spec.Claim.isSomethingWhere <|
                  Spec.Markup.text <|
                  Spec.Claim.isEqual Debug.toString "Have fun!"
                )
            )
          ]
      )
    ]

# Observe Command Ports
@docs observe

# Simulate Subscription Ports
@docs send

-}

import Spec.Step as Step
import Spec.Step.Command as Command
import Spec.Observer as Observer exposing (Observer)
import Spec.Observer.Internal as Observer
import Spec.Message as Message exposing (Message)
import Spec.Report as Report exposing (Report)
import Json.Encode as Encode
import Json.Decode as Json


sendSubscription : String -> Encode.Value -> Message
sendSubscription name value =
  Message.for "_port" "send"
    |> Message.withBody (
      Encode.object [ ("sub", Encode.string name), ("value", value) ]
    )


{-| A step that sends a message to a port subscription.

Provide the name of the port and an encoded JSON value that should be sent from the JavaScript side.

For example, if you have a port defined in Elm like so:

    port listenForStuff : (String -> msg) -> Sub msg

Then you could send a message through this port during a scenario like so:

    Spec.when "a message is sent to the subscription"
    [ Json.Encode.string "Some words"
        |> Spec.Port.send "listenForStuff"
    ]

-}
send : String -> Encode.Value -> Step.Step model msg
send name value =
  \_ ->
    Command.sendMessage <| sendSubscription name value


type alias PortRecord =
  { name: String
  , value: Json.Value
  }


{-| Observe messages sent out via a command port.

Provide the name of the port (the function name) and a JSON decoder that can decode
messages sent out over the port.

-}
observe : String -> Json.Decoder a -> Observer model (List a)
observe name decoder =
  Observer.observeEffects (\effects ->
    recordsForPort name effects
      |> recordedValues decoder
  )
  |> Observer.mapRejection (\report ->
    Report.batch
    [ Report.fact "Claim rejected for port" name
    , report
    ]
  )
  |> Observer.observeResult


recordsForPort : String -> List Message -> List PortRecord
recordsForPort name effects =
  List.filter (Message.is "_port" "received") effects
    |> List.filterMap (Result.toMaybe << Message.decode recordDecoder)
    |> List.filter (\portRecord -> portRecord.name == name)
    |> List.reverse


recordedValues : Json.Decoder a -> List PortRecord -> Result Report (List a)
recordedValues decoder =
  List.foldl (\portRecord ->
    Result.andThen (\values ->
      Json.decodeValue decoder portRecord.value
        |> Result.map (\value -> List.append values [ value ])
        |> Result.mapError jsonErrorToReport
    )
  ) (Ok [])


jsonErrorToReport : Json.Error -> Report
jsonErrorToReport =
  Report.fact "Unable to decode value sent through port" << Json.errorToString


recordDecoder : Json.Decoder PortRecord
recordDecoder =
  Json.map2 PortRecord
    (Json.field "name" Json.string)
    (Json.field "value" Json.value)