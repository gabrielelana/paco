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

name = while("abcdefghijklmnopqrstuvwxyz", {:at_least, 1})
number = while("0123456789", {:at_least, 1})

expression =
  fn(expression) ->
   multipliable = one_of([expression |> surrounded_by("(", ")"), number, name])
   additionable = multipliable |> separated_by(keep(one_of([lex("*"), lex("/")])))
   comparable = additionable |> separated_by(keep(one_of([lex("+"), lex("-")])))
   [comparable, maybe([one_of([lex("<"), lex("=")]), comparable])] |> bind(&flatten_first/1)
  end
  |> recursive

command_sequence =
  fn(command_sequence) ->
    assignment = [name, lex(":="), expression]
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
  n := 5;
  f := 1;
  repeat
    f := f * n;
    n := n - 1;
  until (n < 1);
  write(f);
  """

# explain(tiny, program) |> elem(1) |> IO.puts
parse(tiny, program) |> IO.inspect
