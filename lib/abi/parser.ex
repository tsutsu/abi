defmodule ABI.Parser do
  @moduledoc false

  @doc false
  def parse!(str, opts \\ []) do
    tokens = lex!(str)

    tokens =
      case opts[:as] do
        nil -> tokens
        :type -> [{:"expecting type", 1} | tokens]
        :selector -> [{:"expecting selector", 1} | tokens]
      end

    {:ok, ast} = :ethereum_abi_parser.parse(tokens)

    canonicalize_fn = if opts[:bindings], do: & &1, else: &strip_bindings/1

    case ast do
      {:type, type} ->
        canonicalize_fn.(type)

      {:selector, selector_parts} ->
        struct!(ABI.FunctionSelector, canonicalize_fn.(selector_parts))
    end
  end

  @doc false
  def lex!(str) do
    {:ok, tokens, _} = str |> String.to_charlist() |> :ethereum_abi_lexer.string()

    [{:begin, 1}] ++ trim_whitespace(tokens, []) ++ [{:end, 1}]
  end

  # Removes all whitespace tokens except between identifier-esques.
  # The remaining whitespace tokens represent significant whitespace
  # (i.e. separating identifier from type, or type from modifiers.)
  defp trim_whitespace([], acc), do:
    Enum.reverse(acc)
  defp trim_whitespace([{:" ", _}=sp | [{_, _, _} | _]=rest], [{_, _, _} | _]=acc), do:
    trim_whitespace(rest, [sp | acc])
  defp trim_whitespace([{:" ", _} | rest], acc), do:
    trim_whitespace(rest, acc)
  defp trim_whitespace([other | rest], acc), do:
    trim_whitespace(rest, [other | acc])

  defp strip_bindings({:array, type}), do: {:array, strip_bindings(type)}
  defp strip_bindings({:array, type, size}), do: {:array, strip_bindings(type), size}
  defp strip_bindings({:tuple, types}), do: {:tuple, Enum.map(types, &strip_bindings/1)}

  defp strip_bindings(%{function: f, types: t, returns: r}) do
    %{function: f, types: Enum.map(t, &strip_bindings/1), returns: strip_bindings(r)}
  end

  defp strip_bindings({:binding, inner_type, _opts}), do: strip_bindings(inner_type)
  defp strip_bindings(other_type), do: other_type
end
