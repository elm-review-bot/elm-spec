module Spec.Message exposing
  ( Message
  , IncomingMessageType(..)
  , incoming
  , observation
  , configureComplete
  , stepComplete
  , observationsComplete
  , specComplete
  )

import Observer exposing (Verdict(..))
import Json.Encode as Encode exposing (Value)
import Json.Decode as Json


type alias Message =
  { home: String
  , name: String
  , body: Value
  }


type IncomingMessageType
  = Start
  | NextSpec
  | StartSteps
  | NextStep


incoming : Message -> Maybe IncomingMessageType
incoming message =
  if message.home == "_spec" && message.name == "state" then
    Json.decodeValue Json.string message.body
      |> Result.toMaybe
      |> Maybe.andThen stateToType
  else
    Nothing


stateToType : String -> Maybe IncomingMessageType
stateToType specState =
  case specState of
    "START" ->
      Just Start
    "NEXT_SPEC" ->
      Just NextSpec
    "START_STEPS" ->
      Just StartSteps
    "NEXT_STEP" ->
      Just NextStep
    _ ->
      Nothing


configureComplete : Message
configureComplete =
  specStateMessage "CONFIGURE_COMPLETE"


stepComplete : Message
stepComplete =
  specStateMessage "STEP_COMPLETE"


observationsComplete : Message
observationsComplete =
  specStateMessage "OBSERVATIONS_COMPLETE"


specComplete : Message
specComplete =
  specStateMessage "SPEC_COMPLETE"


specStateMessage : String -> Message
specStateMessage specState =
  { home = "_spec"
  , name = "state"
  , body = Encode.string specState
  }


observation : List String -> (String, Verdict) -> Message
observation conditions (description, verdict) =
  { home = "_spec"
  , name = "observation"
  , body = encodeObservation conditions description verdict
  }


encodeObservation : List String -> String -> Verdict -> Value
encodeObservation conditions description verdict =
  verdictAttributes verdict
    |> List.append
      [ ("conditions", Encode.list Encode.string conditions)
      , ("description", Encode.string description)
      ]
    |> Encode.object


verdictAttributes verdict =
  case verdict of
    Accept ->
      [ ("summary", Encode.string "ACCEPT")
      , ("message", Encode.null)
      ]
    Reject message ->
      [ ("summary", Encode.string "REJECT")
      , ("message", Encode.string message)
      ]
