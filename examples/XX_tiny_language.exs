# Tiny ← CmdSeq
# CmdSeq ← (Cmd SEMICOLON) (Cmd SEMICOLON)∗
# Cmd ← IfCmd / RepeatCmd / AssignCmd / ReadCmd / WriteCmd
# IfCmd ← IF Exp THEN CmdSeq (ELSE CmdSeq / ε) END
# RepeatCmd ← REPEAT CmdSeq UNTIL Exp
# AssignCmd ← NAME ASSIGNMENT Exp
# ReadCmd ← READ NAME
# WriteCmd ← WRITE Exp
# Exp ← SimpleExp ((LESS / EQUAL) SimpleExp / ε)
# SimpleExp ← Term ((ADD / SUB) Term)∗
# Term ← Factor ((MUL / DIV) Factor )∗
# Factor ← OPENPAR Exp CLOSEPAR / NUMBER / NAME

import Paco
import Paco.Parser
import Paco.Transform, only: [flatten_first: 1]

name = while("abcdefghijklmnopqrstuvwxyz", {:at_least, 1}) |> as("NAME")
number = while("0123456789", {:at_least, 1}) |> as("NUMBER")

# expression =
#   fn(expression) ->
#    multipliable = one_of([expression |> surrounded_by("(", ")"), number, name])
#    additionable = multipliable |> separated_by(keep(one_of([lex("*"), lex("/")])))
#    comparable = additionable |> separated_by(keep(one_of([lex("+"), lex("-")])))
#    [comparable, maybe([one_of([lex("<"), lex("=")]), comparable])] |> bind(&flatten_first/1)
#   end
#   |> recursive

# command_sequence =
#   fn(command_sequence) ->
#     assignment = [name, lex(":="), expression]
#     repeat_command = [lex("repeat"), command_sequence, lex("until"), expression]
#     write_command = [lex("write"), expression |> surrounded_by("(", ")")]
#     read_command = [lex("read"), expression |> surrounded_by("(", ")")]
#     if_command = [lex("if"), expression, lex("then"), command_sequence, maybe([lex("else"), command_sequence]), lex("end")]
#     command = one_of([assignment, write_command, read_command, repeat_command, if_command]) |> followed_by(lex(";"))
#     one_or_more(command)
#   end
#   |> recursive

# tiny = command_sequence |> followed_by(eof)

# assignment = [name, lex(":="), number] |> as("ASSIGNMENT")
# assignment = [name, lex(":="), number] |> fail_with("%REASON% because an ASSIGNMENT is NAME := EXPRESSION")
assignment = [name, lex(":="), number]
write_command = [lex("write"), name |> surrounded_by("(", ")")] |> as("WRITE COMMAND")
# write_command = [lex("write"), lex("("), name, lex(")")]
command = one_of([assignment, write_command]) |> followed_by(lex(";"))
tiny = command |> followed_by(eof)

program =
  """
  writn
  """
  # expected "write" (WRITE COMMAND) at 1:1 but got "writn" or expected ":=" (ASSIGNMENT) at 1:7 but got the end of input
  # expected "write" (WRITE COMMAND) at 1:1 but got "writn" or expected ":=" (ASSIGNMENT) at 1:7 but got the end of input
  # stack: [TINY, COMMAND, WRITE_COMMAND, NAME]
  # message: expected NAME at 1:7 but got "1"

# program =
#   """
#   n = 5;
#   """
#   # expected ":=" at 1:3 but got "= 5"

# program =
#   """
#   n := 5
#   """
#   # expected ";" at 2:1 but got the end of input
#   # TODO: when end of input use the end of the preceding line as target
#   # TODO: expected ";" at 1:7 but got the end of input

# program =
#   """
#   n := 5;
#   f := 1;
#   repeat
#     f := f * n;
#     n := n - 1;
#   until (n < 1);
#   write(f);
#   """

# explain(tiny, program) |> elem(1) |> IO.puts
# parse(tiny, program) |> IO.inspect
failure = parse(tiny, program, format: :raw)
IO.puts(failure.message)
