const chai = require('chai')
const expect = chai.expect
const {
  expectAccepted,
  expectSpec,
  expectRejected,
  reportLine
} = require("./helpers/SpecHelpers")

describe("file", () => {
  context("selecting a file", () => {
    it("selects files as expected", (done) => {
      expectSpec("FileSpec", "selectFile", done, (observations) => {
        expectAccepted(observations[0])
        expectAccepted(observations[1])
        expectAccepted(observations[2])
        expectAccepted(observations[3])
      })
    })
  })

  context("no file selector open", () => {
    it("reports an error", (done) => {
      expectSpec("FileSpec", "noOpenSelector", done, (observations) => {
        expectRejected(observations[0], [
          reportLine("No open file selector!", "Either click an input element of type file or otherwise take action so that a File.Select.file(s) command is sent by the program under test.")
        ])
      })
    })
  })

  context("no file is selected", () => {
    it("resets the file selector between scenarios", (done) => {
      expectSpec("FileSpec", "noFileSelected", done, (observations) => {
        expectAccepted(observations[0])
        expectRejected(observations[1], [
          reportLine("No open file selector!", "Either click an input element of type file or otherwise take action so that a File.Select.file(s) command is sent by the program under test.")
        ])
      })
    })
  })

  context("bad file selected to upload", () => {
    it("reports an error", (done) => {
      expectSpec("FileSpec", "badFile", done, (observations) => {
        expect(observations[0].summary).to.equal("REJECT")
        expect(observations[0].report[0].statement).to.equal("Unable to read file at")
        expect(observations[0].report[0].detail).to.contain("tests/src/non-existent-file.txt")
      })
    })
  })
})