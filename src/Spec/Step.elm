module Spec.Step exposing
  ( Context
  , Command
  , model
  , log
  )

{-| A scenario script is a sequence of steps. A step is a function from a `Context`,
which represents the current scenario state, to a `Command`, which describes an action to be
executed before moving to the next step.

See `Spec.Command`, `Spec.Http`, `Spec.Markup`, `Spec.Markup.Event`, `Spec.Port`, and `Spec.Time` for
steps you can use to build a scenario script.

@docs Context, Command

# Using the Context
@docs model

# Basic Commands
@docs log

-}

import Spec.Message as Message exposing (Message)
import Spec.Step.Command as Command
import Spec.Step.Context as Context
import Spec.Report as Report exposing (Report)


{-| Represents the current state of the program.
-}
type alias Context model =
  Context.Context model


{-| Represents an action to be performed.
-}
type alias Command msg =
  Command.Command msg


{-| Get the current program model from the `Context`.
-}
model : Context model -> model
model =
  Context.model


{-| The spec runner will log the given report to the console.
-}
log : Report -> Command msg
log report =
  Message.for "_scenario" "log"
    |> Message.withBody (Report.encode report)
    |> Command.sendMessage