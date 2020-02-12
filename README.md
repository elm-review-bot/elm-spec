# elm-spec

Use elm-spec to write specs that describe the behavior of your Elm program.

You think TDD/BDD is great, and maybe you're already writing tests in Elm or using tools like Cypress
to test your program end-to-end. Why use elm-spec?

- elm-spec allows you to describe behaviors that involve HTML, browser navigation, HTTP, Time, ports,
commands, and subscriptions -- and there's no need to structure your code in any special way
to do so (although you can if you wish).
- elm-spec does not simulate calls to your program's `view` or `update` functions, and it lets the
Elm runtime handle commands and subscriptions; your program interacts with the Elm runtime just as it
would in production.
- elm-spec exercises your program in a DOM environment (JSDOM or a web browser).
- elm-spec allows you to write specs that describe the behavior of parts of your program in isolation from others. This makes those specs easier to write and easier to understand.

In short, with elm-spec you get the confidence you would from a browser-based
end-to-end testing tool like Cypress, without losing the convenience of elm-based testing tools. You can
still write your specs in Elm and you can still test parts of your code in isolation, but your specs
run in a browser (via Karma) and they exercise your code just like it will be exercised in production.


## Getting Started

1. Create a directory for your specs and initialize a new elm app with `elm init`. Add your program's source
directory to the `source-directories` field of `elm.json`.

2. Install elm-spec: `elm install brian-watkins/elm-spec`.

3. Install any other dependencies your app needs.

3. Add a file called `Runner.elm` to your specs src directory. It should look something like this:

```
port module Runner exposing (program, browserProgram)

import Spec.Runner exposing (Message)

port elmSpecOut : Message -> Cmd msg
port elmSpecIn : (Message -> msg) -> Sub msg
port elmSpecPick : () -> Cmd msg

pick =
  Spec.Runner.pick elmSpecPick

config : Spec.Runner.Config msg
config =
  { send = elmSpecOut
  , outlet = elmSpecOut
  , listen = elmSpecIn
  }

program specs =
  Spec.Runner.program config specs

browserProgram specs =
  Spec.Runner.browserProgram config specs
```

You must create the `elmSpecOut` and `elmSpecIn` ports and provide them to `Spec.Runner.program` or `Spec.Runner.browserProgram` via a `Spec.Runner.Config` value. And, yes, `send` and `outlet` should reference the
very same port, `elmSpecOut`. 

You must also create the `elmSpecPick` port and provide it to `Spec.Runner.pick`.

Now you can write spec modules. Each spec module is an elm program and so must have a `main` function. To construct
the `main` function, just reference `program` or `browserProgram` from your `Runner.elm` and
provide a `List Spec` to run.

During the course of development, it's often useful to run only certain scenarios.
In that case, use `pick` from your `Runner.elm` to designate those scenarios.

Here's an example spec module:

```
module SampleSpec exposing (main)

import Spec exposing (..)
import Spec.Setup as Setup
import Spec.Markup as Markup
import Spec.Markup.Selector exposing (..)
import Spec.Markup.Event as Event
import Spec.Claim as Claim
import Runner
import Main as App


clickSpec : Spec App.Model App.Msg
clickSpec =
  describe "an html program"
  [ scenario "a click event" (
      given (
        Setup.initWithModel App.defaultModel
          |> Setup.withUpdate App.update
          |> Setup.withView App.view
      )
      |> when "the button is clicked three times"
        [ Markup.target << by [ id "my-button" ]
        , Event.click
        , Event.click
        , Event.click
        ]
      |> it "renders the count" (
        Markup.observeElement
          |> Markup.query << by [ id "count-results" ]
          |> expect (
            Claim.isSomethingWhere <|
            Markup.text <|
            Claim.isStringContaining 1 "You clicked the button 3 time(s)"
          )
      )
    )
  ]

main =
  Runner.browserProgram
    [ clickSpec
    ]
```

## Running Specs

To run your specs, you need to install a runner. There are currently two options.

### elm-spec-runner

You can run your specs from the command line in a [JSDOM](https://github.com/jsdom/jsdom) environment.

```
$ npm install --save-dev elm-spec-runner
```

Then just run your specs like so:

```
$ cd specs
$ npx elm-spec --specs './**/*Spec.elm'
```

See [elm-spec-runner](https://github.com/brian-watkins/elm-spec/tree/master/runner/elm-spec-runner) for more
details on command line options.

### karma-elm-spec-framework

You can also run your specs in a real browser via [Karma](http://karma-runner.github.io/latest/).

See [karma-elm-spec-framework](https://github.com/brian-watkins/elm-spec/tree/master/runner/karma-elm-spec-framework)
for more details.


## More Examples

For more examples, see the [docs for elm-spec](https://package.elm-lang.org/packages/brian-watkins/elm-spec/latest/).
In particular, there are examples demonstrating how to describe behavior related to [HTTP requests](https://package.elm-lang.org/packages/brian-watkins/elm-spec/latest/Spec-Http), describe behavior related to [ports](https://package.elm-lang.org/packages/brian-watkins/elm-spec/latest/Spec-Port), control [time](https://package.elm-lang.org/packages/brian-watkins/elm-spec/latest/Spec-Time) during a spec, and use [witnesses](https://package.elm-lang.org/packages/brian-watkins/elm-spec/latest/Spec-Witness) to ensure one part of a program acts in an expected way.

For even more examples, see the [specs for elm-spec](https://github.com/brian-watkins/elm-spec/tree/master/tests/src/Specs).

For a real-world test suite, see the [specs for a simple code-guessing game](https://github.com/brian-watkins/mindmaster).


## Extra

I suggest adding one more file to your spec suite: `Spec/Extra.elm`.

```
module Spec.Extra exposing (equals)

import Spec.Claim as Claim exposing (Claim)

equals : a -> Claim a
equals =
  Claim.isEqual Debug.toString
```

Then, you can import the `equals` function from this library without having to write out
`Claim.isEqual Debug.toString` every time.
