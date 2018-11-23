defmodule ABI.Parser do
  @moduledoc false

  @doc false
  def parse!(str, opts \\ []) do
    {:ok, tokens, _} = str |> String.to_charlist() |> :ethereum_abi_lexer.string()

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

  defp strip_bindings({:array, type}), do: {:array, strip_bindings(type)}
  defp strip_bindings({:array, type, size}), do: {:array, strip_bindings(type), size}
  defp strip_bindings({:tuple, types}), do: {:tuple, Enum.map(types, &strip_bindings/1)}

  defp strip_bindings(%{function: f, types: t, returns: r}) do
    %{function: f, types: Enum.map(t, &strip_bindings/1), returns: strip_bindings(r)}
  end

  defp strip_bindings({:binding, inner_type, _opts}), do: strip_bindings(inner_type)
  defp strip_bindings(other_type), do: other_type
end
