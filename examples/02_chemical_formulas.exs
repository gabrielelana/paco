import Paco
import Paco.Parser

uppers = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
lowers = "abcdefghijklmnopqrstuvwxyz"
digits = "0123456789"

# Grammar

# An `element` is a word beginning with one uppercase letter followed by zero
# or more lowercase letters
element = [while(uppers, 1), while(lowers)] |> join

# A `quantity` is a number greater than zero
quantity = while(digits, {:at_least, 1})
           |> bind(&String.to_integer/1)
           |> only_if(&(&1 > 0))

# A `reference` is an element optionally followed by a quantity. If the
# quantity is omitted assume the value of 1 as default
reference = {element, maybe(quantity, default: 1)}

# A chemical formula is just one or more elements
formula = one_or_more(reference)


parse("H2O", formula) |> IO.inspect
# >> {:ok, [{"H", 2}, {"O", 1}]}

parse("NaCl", formula) |> IO.inspect
# >> {:ok, [{"Na", 1}, {"Cl", 1}]}

parse("C6H5OH", formula) |> IO.inspect
# >> {:ok, [{"C", 6}, {"H", 5}, {"O", 1}, {"H", 1}]}


# Calculate molecular weight
atomic_weight = %{
  "O"  => 15.9994,
  "H"  => 1.00794,
  "Na" => 22.9897,
  "Cl" => 35.4527,
  "C"  => 12.0107,
  "S"  => 32.0655,
}

calculate_weight = &(&1 |> Enum.map(fn({e, q}) -> Map.fetch!(atomic_weight, e) * q end)
                        |> Enum.sum)

weight = formula |> bind(calculate_weight)

parse("C6H5OH", weight) |> IO.inspect
# >> {:ok, 94.11124}
