module Spec.Step.Command exposing
  ( Command(..)
  , sendCommand
  , sendMessage
  , sendRequest
  , recordCondition
  , log
  )

import Spec.Message exposing (Message)
import Spec.Report as Report exposing (Report)
import Spec.Message as Message


type Command msg
  = SendMessage Message
  | SendRequest Message (Message -> Command msg)
  | SendCommand (Cmd msg)
  | RecordCondition String
  | DoNothing


sendCommand : Cmd msg -> Command msg
sendCommand cmd =
  if cmd == Cmd.none then
    DoNothing
  else
    SendCommand cmd


sendMessage : Message -> Command msg
sendMessage =
  SendMessage


recordCondition : String -> Command msg
recordCondition =
  RecordCondition


sendRequest : (Message -> Command msg) -> Message -> Command msg
sendRequest responseHandler message =
  SendRequest message responseHandler


log : Report -> Command msg
log report =
  Message.for "_step" "log"
    |> Message.withBody (Report.encode report)
    |> sendMessage