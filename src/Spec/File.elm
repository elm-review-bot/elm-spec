module Spec.File exposing
  ( FileFixture
  , select
  , loadFrom
  , withBytes
  , withText
  , withMimeType
  , withLastModified
  , Download
  , observeDownloads
  , name
  , text
  , bytes
  , downloadedUrl
  )

{-| Observe and make claims about files during a spec.

# Select Files
@docs FileFixture, select, loadFrom, withBytes, withText, withMimeType, withLastModified

# Observe Downloads
@docs Download, observeDownloads

# Make Claims about Downloads
@docs name, text, bytes, downloadedUrl

-}

import Spec.Observer exposing (Observer)
import Spec.Observer.Internal as Observer
import Spec.Message as Message exposing (Message)
import Spec.Step as Step
import Spec.Step.Command as Command
import Spec.Claim as Claim exposing (Claim)
import Spec.Binary as Binary
import Spec.Report as Report
import Json.Decode as Json
import Json.Encode as Encode
import Bytes exposing (Bytes)


{-| Represents a file.
-}
type FileFixture
  = FileFixture
    { path: String
    , mimeType: String
    , lastModified: Int
    , content: FileContent
    }


type FileContent
  = Disk
  | Memory Bytes


{-| A step that selects a file as input.

    Spec.when "a File is uploaded"
      [ Spec.Markup.target << by [ tag "input", attribute ("type", "file") ]
      , Spec.Markup.Event.click
      , Spec.File.select [ Spec.File.loadFrom "./fixtures/myFile.txt" ]
      ]

A previous step must open a file selector, either by clicking an input element of type `file` or
by taking some action that results in a `File.Select.file` command.

You may select multiple files.

The path to the file is relative to the current working directory of the elm-spec runner.

-}
select : List FileFixture -> Step.Step model msg
select fixtures =
  \context ->
    Message.for "_file" "fetch"
      |> Message.withBody (
        Encode.object
          [ ( "fileFixtures", Encode.list fileFixtureEncoder fixtures )
          ]
        )
      |> Command.sendRequest andThenSelectFile


fileFixtureEncoder : FileFixture -> Encode.Value
fileFixtureEncoder (FileFixture fixture) =
  Encode.object
    [ ("path", Encode.string fixture.path)
    , ("mimeType", Encode.string fixture.mimeType)
    , ("lastModified", Encode.int fixture.lastModified)
    , ("content", encodeFileContent fixture.content)
    ]


encodeFileContent : FileContent -> Encode.Value
encodeFileContent content =
  case content of
    Disk ->
      Encode.object
        [ ("type", Encode.string "disk")
        ]
    Memory binaryContent ->
      Encode.object
        [ ("type", Encode.string "memory")
        , ("bytes", Binary.jsonEncode binaryContent)
        ]


andThenSelectFile : Message -> Step.Command msg
andThenSelectFile message =
  case Message.decode Json.value message of
    Ok fileValues ->
      Message.for "_file" "select"
        |> Message.withBody (
          Encode.object
            [ ( "files", fileValues )
            ]
        )
        |> Command.sendMessage
    Err _ ->
      Command.nothing


{-| Create a FileFixture by loading a file from the local filesystem.

The path is typically relative to the current working directory of the elm-spec runner (but
check the docs for the runner you are using).
-}
loadFrom : String -> FileFixture
loadFrom path =
  FileFixture
    { path = path
    , mimeType = ""
    , lastModified = 0
    , content = Disk
    }


{-| Create a FileFixture with the given name and bytes.
-}
withBytes : String -> Bytes -> FileFixture
withBytes path binaryContent =
  FileFixture
    { path = path
    , mimeType = ""
    , lastModified = 0
    , content = Memory binaryContent
    }


{-| Create a FileFixture with the given name and text content.
-}
withText : String -> String -> FileFixture
withText path textContent =
  FileFixture
    { path = path
    , mimeType = ""
    , lastModified = 0
    , content = Memory <| Binary.encodeString textContent
    }


{-| Update a FileFixture to have the given MIME type.
-}
withMimeType : String -> FileFixture -> FileFixture
withMimeType mime (FileFixture file) =
  FileFixture
    { file | mimeType = mime }


{-| Update a FileFixture to have the given last modified
date, specified in milliseconds since the UNIX epoch.
-}
withLastModified : Int -> FileFixture -> FileFixture
withLastModified lastModified (FileFixture file) =
  FileFixture
    { file | lastModified = lastModified }


{-| Represents a file downloaded in the course of a scenario.
-}
type Download
  = Download DownloadData


type alias DownloadData =
  { name: String
  , content: DownloadContent
  }


type DownloadContent
  = Bytes Bytes
  | FromUrl String


{-| Observe downloads tha occurred during a scenario.
-}
observeDownloads : Observer model (List Download)
observeDownloads =
  Observer.observeEffects <|
    \messages ->
      List.filter (Message.is "_file" "download") messages
        |> List.filterMap (Result.toMaybe << Message.decode downloadDecoder)


downloadDecoder : Json.Decoder Download
downloadDecoder =
  Json.map2 DownloadData
    (Json.field "name" Json.string)
    (Json.field "content" downloadContentDecoder)
    |> Json.map Download


downloadContentDecoder : Json.Decoder DownloadContent
downloadContentDecoder =
  Json.field "type" Json.string
    |> Json.andThen (\contentType ->
      case contentType of
        "fromUrl" ->
          Json.field "url" Json.string
            |> Json.map FromUrl
        _ ->
          Json.field "data" Binary.jsonDecoder
            |> Json.map Bytes
    )


{-| Claim that the name of a downloaded file satisfies the given claim.

-}
name : Claim String -> Claim Download
name claim =
  \(Download download) ->
    claim download.name
      |> Claim.mapRejection (\report -> Report.batch
        [ Report.note "Claim rejected for downloaded file name"
        , report
        ]
      )


{-| Claim that the text content of a downloaded file satisfies the given claim.

Note that this claim will fail if the download was created by downloading a URL.
-}
text : Claim String -> Claim Download
text claim =
  \(Download download) ->
    case download.content of
      Bytes binaryContent ->
        Binary.decodeToString binaryContent
          |> Maybe.map (\textContext ->
            claim textContext
              |> Claim.mapRejection (\report -> Report.batch
                [ Report.note "Claim rejected for downloaded text"
                , report
                ]
              )
          )
          |> Maybe.withDefault (Claim.Reject <|
            Report.fact "Claim rejected for downloaded text" "Unable to decode binary data as UTF-8 text."
          )
      FromUrl _ ->
        Claim.Reject <| Report.fact "Claim rejected for downloaded text" "The file was downloaded from a url, so it has no associated text."


{-| Claim that the bytes of a downloaded file satisfy the given claim.

Note that this claim will fail if the download was created by downloading a URL.
-}
bytes : Claim Bytes -> Claim Download
bytes claim =
  \(Download download) ->
    case download.content of
      Bytes byteContent ->
        claim byteContent
          |> Claim.mapRejection (\report -> Report.batch
            [ Report.note "Claim rejected for downloaded bytes"
            , report
            ]
          )
      FromUrl _ ->
        Claim.Reject <|
          Report.fact
            "Claim rejected for downloaded bytes"
            "The file was downloaded from a url, so it has no associated bytes."


{-| Claim that the downloaded URL satisfies the given claim.

Note that this claim will fail if the download was not created by downloading a URL.
-}
downloadedUrl : Claim String -> Claim Download
downloadedUrl claim =
  \(Download download) ->
    case download.content of
      FromUrl url ->
        claim url
        |> Claim.mapRejection (\report -> Report.batch
          [ Report.note "Claim rejected for downloaded url"
          , report
          ]
        )
      _ ->
        Claim.Reject <| Report.fact "Claim rejected for downloaded url" "The file was not downloaded from a url."
