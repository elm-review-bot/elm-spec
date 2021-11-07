const queryString = require('query-string');
const OpenAPIRequestValidator = require('openapi-request-validator').default
const OpenapiRequestCoercer = require('openapi-request-coercer').default
const OpenApiPath = require('./path')
const { report, line } = require('../../report')
const { tryToParse } = require('./body')

module.exports = class RequestValidator {
  constructor (path, pathData, definitions, components) {
    this.openApiPath = new OpenApiPath(path, pathData)
    this.definitions = definitions
    this.components = components
  }

  validate({ request }) {
    const url = new URL(request.url)
    console.log("Validating request", url.pathname)
    const path = this.openApiPath.match(url)
    if (path.matches) {
      console.log("Found a matching openapi route with params", path.params)
      const parameters = this.parameters(request)
      const typedRequest = this.typedRequest(parameters, url, path.params, request)

      const errors = new OpenAPIRequestValidator({
        parameters,
        requestBody: this.requestBody(request),
        schemas: this.schemas()
      })
      .validateRequest({
        headers: typedRequest.headers,
        params: typedRequest.pathParams,
        query: typedRequest.query,
        body: typedRequest.body
      })
      
      console.log("Validation errors:", errors)
      if (errors) {
        return errorReport(request, errors.errors)
      }
    }
    return null
  }

  schemas() {
    if (this.components) {
      return this.components.schemas
    }
    return this.definitions
  }

  pathParameters() {
    return this.openApiPath.data.parameters || []
  }

  methodParameters(request) {
    return this.openApiPath.operation(request).parameters || []
  }

  parameters(request) {
    return this.pathParameters().concat(this.methodParameters(request))
  }

  requestBody(request) {
    return this.openApiPath.operation(request).requestBody
  }

  typedRequest(parameters, url, pathParams, request) {
    const query = queryString.parse(url.search)
    const headers = request.requestHeaders.getHash()

    new OpenapiRequestCoercer({ parameters })
      .coerce({
        params: pathParams,
        headers,
        query
      })

    console.log("Typed params", pathParams)
    console.log("Types query", query)
    console.log("Typed Headers", headers)

    return {
      pathParams,
      headers,
      query,
      body: tryToParse(request.body)
    }
  }
}

const errorReport = (request, errors) => {
  let lines = [ line("An invalid request was made", `${request.method} ${request.url}`) ]

  for (const error of errors) {
    let message = `${error.path} ${error.message}`
    if (error.errorCode === "required.openapi.requestValidation") {
      message = error.message
    }
    
    switch (error.location) {
      case 'path':
        lines = lines.concat([
          line("Problem with path parameter", message)
        ])
        break
      case 'headers':
        lines = lines.concat([
          line("Problem with headers", message)
        ])
        break
      case 'query':
        lines = lines.concat([
          line("Problem with query", message)
        ])
        break
      case 'body':
        lines = lines.concat([
          line("Problem with body", message)
        ])
        break
    }
  }

  return report(...lines)
}
