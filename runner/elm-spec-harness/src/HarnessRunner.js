
let wrapper = window._elm_spec.startHarness()

const setup = async (name, config) => {
  await wrapper.setup(name, config)
}

const start = async () => {
  await wrapper.start()
}

const observe = async (name, expected) => {
  return await wrapper.observe(name, expected)
}

const runSteps = async (name, config) => {
  return await wrapper.runSteps(name, config)
}

const getElmApp = () => {
  return wrapper.app
}

module.exports = {
  getElmApp,
  setup,
  start,
  observe,
  runSteps
}