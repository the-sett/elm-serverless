# Release Notes

## 4.0.0 - ktonon/elm-serverless

* `Conn` and `Plug` are now opaque.
* `Plug` has been greatly simplified.
* Simpler pipelines, just `|>` chains of `Conn -> Conn` functions. However pipelines can still send responses and terminate the connection early.
* A single update function (just like an Elm SPA).
* Proper JavaScript interop.

## 1.0.0 - the-sett/elm-serverless

* Upgraded to Elm 0.19
* Removed JavaScript interop - just use ports. Was needed as used Debug.toString to get the function names to call
and this is not allowed in Elm 0.19.
* Removed Logging - can't put Debug.log calls in an Elm 0.19 package. Will re-instate as a logging port in future release.
* Forked as the-sett/elm-serverless.
* Bridge published to npm as serverless-elm-bridge.
