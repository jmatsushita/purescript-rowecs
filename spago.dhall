{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "gdecs"
, dependencies =
  [ "arrays"
  , "console"
  , "debug"
  , "effect"
  , "foldable-traversable"
  , "integers"
  , "intmaps"
  , "prelude"
  , "proxy"
  , "psci-support"
  , "record-extra"
  , "strings"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
