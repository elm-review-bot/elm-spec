module Harness.Exercise exposing
  ( Model, Msg(..)
  , Actions
  , ExposedStepsRepository
  , defaultModel
  , init
  , initForInitialCommand
  , wait
  , update
  , subscriptions
  )

import Spec.Message as Message exposing (Message)
import Harness.Types exposing (..)
import Spec.Step exposing (Step)
import Spec.Step.Command as Step
import Spec.Step.Message as Message
import Spec.Step.Context exposing (Context)
import Json.Decode as Json


type alias Model model programMsg =
  { stepsToRun: List (Step model programMsg)
  }


defaultModel : Model model programMsg
defaultModel =
  { stepsToRun = []
  }


type Msg programMsg
  = Continue
  | ReceivedMessage Message


type alias Actions msg programMsg =
  { send: Message -> Cmd msg
  , sendProgramCommand: Cmd programMsg -> Cmd msg
  , storeEffect: Message -> Cmd msg
  , sendToSelf: (Msg programMsg) -> Cmd msg
  , finished: Cmd msg
  , listen: (Message -> Msg programMsg) -> Sub msg
  }


type alias ExposedStepsRepository model msg =
  { get: String -> Maybe (ExposedSteps model msg)
  }


init : Actions msg programMsg -> ExposedStepsRepository model programMsg -> Message -> ( Model model programMsg, Cmd msg )
init actions steps message =
  let
    maybeSteps = Message.decode (Json.field "steps" Json.string) message
      |> Result.toMaybe
      |> Maybe.andThen (\observerName -> steps.get observerName)
    maybeConfig = Message.decode (Json.field "config" Json.value) message
      |> Result.toMaybe
  in
    case Maybe.map2 (<|) maybeSteps maybeConfig of
      Just stepsToRun ->
        ( { defaultModel | stepsToRun = stepsToRun }
        , actions.sendToSelf Continue 
        ) -- This might need to be _harness prepare
        -- Doesn't seem to make a different right now; we need a test to prove we need it I guess
        -- Like, we try to click a button that is revealed only when a port message is received
        -- , actions.send <| Message.prepareHarnessForAction
        -- )
      Nothing ->
        Debug.todo "Could not find steps!"


initForInitialCommand : Actions msg programMsg -> Cmd programMsg -> ( Model model programMsg, Cmd msg )
initForInitialCommand actions command =
  ( { defaultModel | stepsToRun = [ \_ -> Step.sendToProgram command ] }
  , actions.sendToSelf Continue
  )


wait : Actions msg programMsg -> ( Model model programMsg, Cmd msg )
wait actions =
  ( defaultModel
  , actions.send Message.stepComplete
  )


update : Actions msg programMsg -> Context model -> Msg programMsg -> Model model programMsg -> ( Model model programMsg, Cmd msg )
update actions context msg model =
  case msg of
    ReceivedMessage message ->
      ( model
      , Cmd.batch
        [ actions.storeEffect message
        , actions.send Message.stepComplete
        ]
      )
    Continue ->
      case model.stepsToRun of
        [] -> 
          ( model, actions.finished )
        step :: remaining ->
          step context
            |> handleStepCommand actions { model | stepsToRun = remaining }


handleStepCommand : Actions msg programMsg -> Model model programMsg -> Step.Command programMsg -> ( Model model programMsg, Cmd msg)
handleStepCommand actions model command =
  case command of
    Step.SendMessage message ->
      ( model
      , actions.send <| Message.stepMessage message
      )
    Step.SendCommand cmd ->
      ( model
      , actions.sendProgramCommand cmd
      )
    _ ->
      Debug.todo "Try to handle a command we can't yet handle!"


subscriptions : Actions msg programMsg -> Model model programMsg -> Sub msg
subscriptions actions _ =
  actions.listen (\message ->
    if Message.is "_scenario" "state" message then
      case Message.decode Json.string message |> Result.withDefault "" of
        "CONTINUE" ->
          Continue
        _ ->
          Debug.todo "Unknown scenario state message in Exercise state!"
    else
      ReceivedMessage message
  )
