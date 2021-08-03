import test from "tape"
import * as harness from "../../src/HarnessRunner"
import { observe } from "./helpers"

test("initial state of app", async function (t) {
  await harness.setup("withName", { name: "Professor Strange" })
  await harness.start()
  await observe(t, "name", "Professor Strange", "it finds the configured default name")
  await observe(t, "attributes", [ "cool", "fun" ], "it finds the default attributes")
})

test("the view updates", async function(t) {
  await harness.setup("default")
  await harness.start()
  await harness.runSteps("click", 5)
  await observe(t, "count", "5 clicks!", "it counts the number of clicks")
  await harness.runSteps("click", 2)
  await observe(t, "count", "7 clicks!", "it counts the number of clicks again")
})

test("the app is reset", async function(t) {
  await harness.setup("default")
  await harness.start()
  await observe(t, "count", "0 clicks!", "it resets the app at the beginning of each test")
})

test("a message is sent to the app", async function(t) {
  await harness.setup("default")
  await harness.start()
  harness.getElmApp().ports.triggerStuff.send({ name: "Super cool dude" })
  await observe(t, "name", "Super cool dude", "it finds the updated name")
})

test("the iniial command sends an HTTP request", async function(t) {
  await harness.setup("withInitialCommand", [ "apple", "banana", "pear" ])
  await harness.start()
  await observe(t, "stuff", "Got apple, banana, pear (3)", "it runs the initial command")
})

test("the iniial command sends a port message", async function(t) {
  await harness.setup("withInitialPortCommand", [ "surf", "ski" ])
  harness.getElmApp().ports.inform.subscribe(data => {
    t.deepEqual(data, { attributes: [ "surf", "ski" ] }, "it receives the initial port command")
  })
  await harness.start()
})

test("a message is sent in response to a message that is received", async function(t) {
  await harness.setup("default")
  harness.getElmApp().ports.inform.subscribe(data => {
    harness.getElmApp().ports.triggerStuff.send({ name: "Dr. Cool" })
  })
  await harness.start()
  await harness.runSteps("inform")
  await observe(t, "name", "Dr. Cool", "it finds the name updated after the message is received")
})

test("the setup configures the context to stub an HTTP request", async function(t) {
  await harness.setup("withStub", { thing: "trees", count: 17 })
  await harness.start()
  await harness.runSteps("requestStuff")
  await observe(t, "stuff", "Got trees (17)", "it observes that the stubbed response was processed")
})
