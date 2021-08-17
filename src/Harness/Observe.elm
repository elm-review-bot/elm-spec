module Harness.Observe exposing 
  ( Model, defaultModel
  , Msg(..)
  , Actions
  , init
  , update
  , ExposedExpectationRepository
  , subscriptions
  )

import Spec.Claim as Claim exposing (Verdict)
import Spec.Step.Context exposing (Context)
import Spec.Step.Message as Message
import Harness.Message as Message
import Spec.Message as Message exposing (Message)
import Spec.Observer.Message as Message
import Spec.Observer.Internal exposing (Judgment(..))
import Harness.Types exposing (..)
import Spec.Report as Report
import Json.Decode as Json


type alias Model model =
  { inquiryHandler: Maybe (Message -> Judgment model)
  , expectation: Maybe (Expectation model)
  }

defaultModel : Model model
defaultModel =
  { inquiryHandler = Nothing
  , expectation = Nothing
  }

type Msg
  = ReceivedMessage Message
  | Continue

type alias Actions msg =
  { send : Message -> Cmd msg
  , finished: Cmd msg
  , listen: (Message -> Msg) -> Sub msg
  , sendToSelf: Msg -> Cmd msg
  }


type alias ExposedExpectationRepository model =
  { get: String -> Maybe (ExposedExpectation model)
  }


init : Actions msg -> ExposedExpectationRepository model -> Model model -> Message -> ( Model model, Cmd msg )
init actions expectations model message =
  let
    maybeExpectation = Message.decode (Json.field "observer" Json.string) message
      |> Result.toMaybe
      |> Maybe.andThen (\observerName -> expectations.get observerName)
    maybeExpected = Message.decode (Json.field "expected" Json.value) message
      |> Result.toMaybe
  in
    case Maybe.map2 (<|) maybeExpectation maybeExpected of
      Just expectation ->
        ( { model | expectation = Just expectation }
        , actions.sendToSelf Continue
        )
      Nothing ->
        Debug.todo "Could not parse the observation!"


update : Actions msg -> Context model -> Msg -> Model model -> ( Model model, Cmd msg )
update actions context msg model =
  case msg of
    ReceivedMessage message ->
      if Message.belongsTo "_observer" message then
        handleObserveMessage actions model message
      else
        ( model, Cmd.none )
    Continue ->
      case model.expectation of
        Just expectation ->
          observe actions context model expectation
        Nothing ->
          ( model, Cmd.none )


observe : Actions msg -> Context model -> Model model -> Expectation model -> ( Model model, Cmd msg )
observe config context model (Expectation expectation) =
  case expectation context of
    Complete verdict ->
      ( model
      , sendVerdict config verdict 
      )
    Inquire message handler ->
      ( { model | inquiryHandler = Just handler }
      , config.send <| Message.inquiry message
      )


handleObserveMessage : Actions msg -> Model model -> Message -> ( Model model, Cmd msg )
handleObserveMessage config model message =
  Message.decode Message.inquiryDecoder message
    |> Result.map .message
    |> Result.map (processInquiryMessage config model)
    |> Result.withDefault ( model, Cmd.none )
      -- (abortObservation actions observeModel <| Report.note "Unable to decode inquiry result!")


processInquiryMessage : Actions msg -> Model model -> Message -> ( Model model, Cmd msg )
processInquiryMessage config model message =
  if Message.is "_scenario" "abort" message then
    Debug.todo "Abort while processing inquiry message!"
  else
    ( { model | inquiryHandler = Nothing }
    , handleInquiry message model.inquiryHandler
        |> sendVerdict config
    )


handleInquiry : Message -> Maybe (Message -> Judgment model) -> Verdict
handleInquiry message maybeHandler =
  maybeHandler
    |> Maybe.map (inquiryResult message)
    |> Maybe.withDefault (Claim.Reject <| Report.note "No Inquiry Handler!")


inquiryResult : Message -> (Message -> Judgment model) -> Verdict
inquiryResult message handler =
  case handler message of
    Complete verdict ->
      verdict
    Inquire _ _ ->
      Claim.Reject <| Report.note "Recursive Inquiry not supported!"


sendVerdict : Actions msg -> Verdict -> Cmd msg
sendVerdict actions verdict =
  Cmd.batch
    [ Message.observation [] "harness observation" verdict
        |> actions.send
    , actions.finished
    ]


subscriptions : Actions msg -> Model model -> Sub msg
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