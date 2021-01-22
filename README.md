[![serverless](http://public.serverless.com/badges/v3.svg)](http://www.serverless.com)

**Contacts for Support**
- @rupertlssmith on https://elmlang.slack.com
- @rupert on https://discourse.elm-lang.org

# elm-serverless


Deploy an [Elm](https://elm-lang.org) HTTP API to using the [serverless](https://www.serverless.com/) framework. This can be used to write [AWS Lambda](https://aws.amazon.com/lambda/) functions in Elm. Other cloud serverless functions are supported too, through the serverless framework.

`elm/http` defines an API for making HTTP requests.

`the-sett/elm-serverless` defines an API for receiving HTTP requests, and responding to them.

It can be run standalone on your local machine, which is often used for development and testing purposes. It is usually deployed to the cloud using the [serverless](https://www.serverless.com/) framework.

## npm package - serverless-elm-bridge

Define your API in elm and then use the npm package to bridge the interface between the [serverless][] framework and your Elm program. The npm package is
available here: https://www.npmjs.com/package/@the-sett/serverless-elm-bridge

This can be installed into your `package.json` like this:

```
"dependencies": {
  "@the-sett/serverless-elm-bridge": "^3.0.0",
  ...
```

The same version of the npm bridge package should be used as the Elm package.

## Documentation

* [Example Code](https://github.com/the-sett/elm-serverless-demo) - Best place
to start learning about the framework. Contains several small programs each
demonstrating a separate feature. Each demo is supported by an end-to-end
suite of tests.

    There are instructions there on how to get set up and deploy an Elm serverless
application on AWS.

* [API Docs](https://package.elm-lang.org/packages/the-sett/elm-serverless/latest/) - Hosted on elm-lang packages, detailed per module and function documentation. Examples are doc-tested.
