class_name GameLogSingleton
extends Node

## Single responsibility: format levelled diagnostic messages and write them to stdout.
##
## This is the primary window into a running build for anyone who cannot see the
## game window, so every line is plain text on stdout and readable in a headless run.
## Format: [LEVEL][system] message

enum Level {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
}

const _LEVEL_NAMES: Dictionary = {
	Level.DEBUG: "DEBUG",
	Level.INFO: "INFO",
	Level.WARN: "WARN",
	Level.ERROR: "ERROR",
}

## Messages below this level are dropped. Raise to WARN to quieten a noisy rally.
@export var log_level: Level = Level.INFO


func debug(system: String, message: String) -> void:
	_write(Level.DEBUG, system, message)


func info(system: String, message: String) -> void:
	_write(Level.INFO, system, message)


func warn(system: String, message: String) -> void:
	_write(Level.WARN, system, message)


func error(system: String, message: String) -> void:
	_write(Level.ERROR, system, message)


## Returns the line this call would emit, or "" if it is filtered out.
## Exposed so headless tests can assert on formatting without capturing stdout.
func format_line(level: Level, system: String, message: String) -> String:
	if level < log_level:
		return ""
	return "[%s][%s] %s" % [_LEVEL_NAMES[level], system, message]


func _write(level: Level, system: String, message: String) -> void:
	var line: String = format_line(level, system, message)
	if line.is_empty():
		return
	# Deliberately stdout for every level, including ERROR: a headless log capture
	# should read as one ordered stream, not two interleaved ones.
	print(line)
