class_name GameStateSingleton
extends Node

## Single responsibility: hold the session-scoped state of the running game
## (which screen, which match, which opponent) so systems can read it without
## reaching into each other's scenes.
