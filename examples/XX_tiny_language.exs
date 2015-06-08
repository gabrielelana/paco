# This is a demonstration of error reporting

# The example is taken directly from the academic paper "Error Reporting in
# Parsing Expression Grammars" by André Murbach Maidl, Sérgio Medeiros, Fabio
# Mascarenhas, Roberto Ierusalimschy

# The cited paper used this language to show problems with error reporting on
# PEGs (Parsing Expression Grammars), since Paco belongs to the same family it
# had the same problems

# I will use the same language to show that Paco is pretty good in error
# reporting

# Tiny      ← CmdSeq
# CmdSeq    ← (Cmd SEMICOLON) (Cmd SEMICOLON)∗
# Cmd       ← IfCmd / RepeatCmd / AssignCmd / ReadCmd / WriteCmd
# IfCmd     ← IF Exp THEN CmdSeq (ELSE CmdSeq / ε) END
# RepeatCmd ← REPEAT CmdSeq UNTIL Exp
# AssignCmd ← NAME ASSIGNMENT Exp
# ReadCmd   ← READ NAME
# WriteCmd  ← WRITE Exp
# Exp       ← SimpleExp ((LESS / EQUAL) SimpleExp / ε)
# SimpleExp ← Term ((ADD / SUB) Term)∗
# Term      ← Factor ((MUL / DIV) Factor )∗
# Factor    ← OPENPAR Exp CLOSEPAR / NUMBER / NAME

import Paco
import Paco.Parser

name = while("abcdefghijklmnopqrstuvwxyz", at_least: 1) |> as("name")
number = while("0123456789", at_least: 1) |> as("number")

expression =
  fn(expression) ->
   multipliable = one_of([expression |> surrounded_by("(", ")"), number, name])
   additionable = multipliable |> separated_by(keep(one_of([lex("*"), lex("/")])))
   comparable = additionable |> separated_by(keep(one_of([lex("+"), lex("-")])))
   comparable |> separated_by(keep(one_of([lex("<"), lex("=")])))
  end
  |> recursive |> as("expression")

command_sequence =
  fn(command_sequence) ->
    assignment = [name, lex(":="), expression] |> as("assignment")
    repeat_command = [lex("repeat"), command_sequence, lex("until"), expression]
    write_command = [lex("write"), expression |> surrounded_by("(", ")")]
    read_command = [lex("read"), expression |> surrounded_by("(", ")")]
    if_command = [lex("if"), expression, lex("then"), command_sequence, maybe([lex("else"), command_sequence]), lex("end")]
    command = one_of([assignment, write_command, read_command, repeat_command, if_command]) |> followed_by(lex(";"))
    one_or_more(command)
  end
  |> recursive

tiny = command_sequence |> followed_by(eof)

program =
  """
  n := 5
  """
parse(tiny, program) |> IO.inspect
# >> {:error, "expected \";\" at 2:1 but got the end of input"}
# Pretty straightforward, but why 2:1 and not 1:7, because lex(";") consumed
# the end of line at 1:7 and expected ";" at 2:1. We can do better with a better
# line terminator definition...

program =
  """
  n :=
  """
parse(tiny, program) |> IO.inspect
# >> {:error, "expected \"(\" (expression < assignment) at 2:1 but got the end of input"}
# Naming things is important, the error message tells us that is expecting an expression
# to complete an assignment.

program =
  """
  writn(n);
  """
parse(tiny, program) |> IO.inspect
# >> {:error, "expected \":=\" (assignment) at 1:6 but got \"(n\""}
# The best failure here is from the assignment parser because it matches the
# whole "writn" compared with the write_command parser that stops at "writ".
# With error recovery techniques we can improve the situation because here (for
# a human) it an obvious typo

program =
  """
  write(n;
  """
parse(tiny, program) |> IO.inspect
# >> {:error, "expected \")\" at 1:8 but got \";\""}
# Good, nothing to say about this

program =
  """
  n := 5;
  repeat
    n := n - 1;
  until n = 0
  """
parse(tiny, program) |> IO.inspect
# >> {:error, "expected the end of input at 2:1"}
# Really bad! need to fix
