module Spec.Message exposing
  ( Message
  , observation
  , startSpec
  , stepComplete
  , specComplete
  )

import Observer exposing (Verdict(..))
import Json.Encode as Encode exposing (Value)


type alias Message =
  { home: String
  , name: String
  , body: Value
  }


startSpec : Message
startSpec =
  { home = "_spec"
  , name = "state"
  , body = Encode.string "START"
  }


stepComplete : Message
stepComplete =
  { home = "_spec"
  , name = "state"
  , body = Encode.string "STEP_COMPLETE"
  }


specComplete : Message
specComplete =
  { home = "_spec"
  , name = "state"
  , body = Encode.string "SPEC_COMPLETE"
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
