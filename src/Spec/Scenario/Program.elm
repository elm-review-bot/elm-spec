module Spec.Scenario.Program exposing
  ( Config, Model, init, update, view, document, subscriptions
  , with
  , start
  , receivedMessage
  )

import Spec.Subject exposing (Subject)
import Spec.Scenario exposing (Scenario)
import Spec.Scenario.Message as Message
import Spec.Scenario.State exposing (Msg(..), Command(..))
import Spec.Message as Message exposing (Message)
import Spec.Observation.Message as Message
import Spec.Observation.Expectation as Expectation
import Spec.Observation.Report as Report exposing (Report)
import Spec.Scenario.State.Exercise as Exercise
import Spec.Scenario.State.Configure as Configure
import Spec.Scenario.State.Observe as Observe
import Spec.Observer as Observer
import Spec.Helpers exposing (mapDocument)
import Html exposing (Html)
import Json.Decode as Json
import Task
import Browser exposing (Document)
import Browser.Navigation exposing (Key)


type alias Model model msg =
  State model msg


type State model msg
  = Start (Scenario model msg) (Subject model msg)
  | Configure (Configure.Model model msg)
  | Exercise (Exercise.Model model msg)
  | Observe (Observe.Model model msg)
  | Ready


type alias Config msg programMsg =
  { complete: Cmd msg
  , send: Message -> Cmd msg
  , sendToSelf: Msg programMsg -> msg
  , outlet: Message -> Cmd programMsg
  , stop: Cmd msg
  }


with : Maybe Key -> Scenario model msg -> Model model msg
with maybeKey scenario =
  Start scenario (scenario.subjectGenerator maybeKey)


start : Cmd (Msg msg)
start =
  Task.succeed never
    |> Task.perform (always Continue)


continue : Config msg programMsg -> Cmd msg
continue config =
  Task.succeed never
    |> Task.perform (always Continue)
    |> Cmd.map config.sendToSelf


init : Model model msg
init =
  Ready


receivedMessage : Message -> Msg msg
receivedMessage =
  ReceivedMessage


subscriptions : Model model programMsg -> Sub (Msg programMsg)
subscriptions state =
  case state of
    Exercise model ->
      Exercise.subscriptions model
        |> Sub.map ProgramMsg
    _ ->
      Sub.none


view : Model model programMsg -> Html (Msg programMsg)
view state =
  case state of
    Exercise model ->
      Exercise.view model
        |> Html.map ProgramMsg
    Observe model ->
      Observe.view model
        |> Html.map ProgramMsg
    _ ->
      Html.text ""


document : Model model programMsg -> Document (Msg programMsg)
document state =
  case state of
    Exercise model ->
      Exercise.document model
        |> mapDocument ProgramMsg
    Observe model ->
      Observe.document model
        |> mapDocument ProgramMsg
    _ ->
      { title = "", body = [ Html.text "" ] }


update : Config msg programMsg -> Msg programMsg -> Model model programMsg -> ( Model model programMsg, Cmd msg )
update config msg state =
  case msg of
    ReceivedMessage message ->
      if Message.isScenarioMessage message then
        update config (toMsg message) state
      else
        case state of
          Exercise model ->
            exerciseUpdate config msg model
          Observe model ->
            observeUpdate config msg model
          _ ->
            badState config state
        
    ProgramMsg programMsg ->
      case state of
        Exercise model ->
          exerciseUpdate config msg model
        _ ->
          badState config state

    Continue ->
      case state of
        Start scenario subject ->
          case Configure.init scenario subject of
            ( updated, SendMany messages ) ->
              ( Configure updated, Cmd.batch <| List.map config.send messages )
            ( updated, _ ) ->
              badState config state
        Configure model ->
          update config Continue <| Exercise <| Exercise.init model.scenario model.subject
        Exercise model ->
          exerciseUpdate config msg model
        Observe model ->
          observeUpdate config msg model
        Ready ->
          ( Ready, Cmd.none )

    Abort report ->
      case state of
        Exercise model ->
          case Exercise.update config.outlet msg model of
            ( updated, Send message ) ->
              ( Ready, Cmd.batch [ config.stop, config.send message ])
            ( updated, _ ) ->
              badState config state
        _ ->
          ( Ready
          , Cmd.batch 
            [ config.stop
            , Observer.Reject report
                |> Message.observation [] "Scenario Failed"
                |> config.send 
            ]
          )

    OnUrlChange _ ->
      case state of
        Exercise model ->
          exerciseUpdate config msg model
        _ ->
          badState config state

    OnUrlRequest _ ->
      badState config state



exerciseUpdate : Config msg programMsg -> Msg programMsg -> Exercise.Model model programMsg -> ( Model model programMsg, Cmd msg )
exerciseUpdate config msg model =
  case Exercise.update config.outlet msg model of
    ( updated, Do cmd ) ->
      ( Exercise updated, Cmd.map config.sendToSelf cmd )
    ( updated, Send message ) ->
      ( Exercise updated, config.send message )
    ( updated, SendMany messages ) ->
      ( Exercise updated, Cmd.batch <| List.map config.send messages )
    ( updated, Transition ) ->
      update config Continue <| Observe <| Observe.init updated


observeUpdate : Config msg programMsg -> Msg programMsg -> Observe.Model model programMsg -> ( Model model programMsg, Cmd msg )
observeUpdate config msg model =
  case Observe.update msg model of
    ( updated, Send message ) ->
      ( Observe updated, config.send message )
    ( updated, Transition ) ->
      ( Ready, config.complete )
    ( updated, _ ) ->
      badState config <| Observe updated


badState : Config msg programMsg -> Model model programMsg -> ( Model model programMsg, Cmd msg )
badState config model =
  update config (Abort <| Report.note "Unknown scenario state!") model


toMsg : Message -> Msg msg
toMsg message =
  case message.name of
    "state" ->
      Message.decode Json.string message
        |> Maybe.map toStateMsg
        |> Maybe.withDefault (Abort <| Report.note "Unable to parse scenario state event!")
    "abort" ->
      Message.decode Report.decoder message
        |> Maybe.withDefault (Report.note "Unable to parse abort scenario event!")
        |> Abort
    unknown ->
      Abort <| Report.fact "Unknown scenario event" unknown


toStateMsg : String -> Msg msg
toStateMsg specState =
  case specState of
    "CONTINUE" ->
      Continue
    unknown ->
      Abort <| Report.fact "Unknown scenario state" unknown
