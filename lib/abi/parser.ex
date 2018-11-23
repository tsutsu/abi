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

    canonicalize_fn = if opts[:param_names], do: & &1, else: &strip_names/1

    case ast do
      {:type, type} ->
        canonicalize_fn.(type)

      {:selector, selector_parts} ->
        struct!(ABI.FunctionSelector, canonicalize_fn.(selector_parts))
    end
  end

  defp strip_names({:array, type}), do: {:array, strip_names(type)}
  defp strip_names({:array, type, size}), do: {:array, strip_names(type), size}
  defp strip_names({:tuple, types}), do: {:tuple, Enum.map(types, &strip_names/1)}

  defp strip_names(%{function: f, types: t, returns: r}) do
    %{function: f, types: Enum.map(t, &strip_names/1), returns: strip_names(r)}
  end

  defp strip_names({:named_param, type, _name}), do: strip_names(type)
  defp strip_names(other_type), do: other_type
end
