defmodule ABI.FunctionSelector do
  @moduledoc """
  Module to help parse the ABI function signatures, e.g.
  `my_function(uint64, string[])`.
  """

  require Integer

  @type param :: binding | type
  @type binding :: {:binding, type, map()}

  @type type ::
          {:uint, integer()}
          | :bool
          | :bytes
          | :string
          | :address
          | {:array, param}
          | {:array, param, non_neg_integer}
          | {:tuple, [param]}

  @type t :: %__MODULE__{
          function: String.t(),
          types: [param],
          returns: param
        }

  defstruct [:function, :types, :returns]

  @doc """
  Decodes a function selector to a struct.

  ## Examples

      iex> ABI.FunctionSelector.decode("bark(uint256,bool)")
      %ABI.FunctionSelector{
        function: "bark",
        types: [
          {:uint, 256},
          :bool
        ]
      }

      iex> ABI.FunctionSelector.decode("growl(uint,address,string[])")
      %ABI.FunctionSelector{
        function: "growl",
        types: [
          {:uint, 256},
          :address,
          {:array, :string}
        ]
      }

      iex> ABI.FunctionSelector.decode("rollover()")
      %ABI.FunctionSelector{
        function: "rollover",
        types: []
      }

      iex> ABI.FunctionSelector.decode("do_playDead3()")
      %ABI.FunctionSelector{
        function: "do_playDead3",
        types: []
      }

      iex> ABI.FunctionSelector.decode("pet(address[])")
      %ABI.FunctionSelector{
        function: "pet",
        types: [
          {:array, :address}
        ]
      }

      iex> ABI.FunctionSelector.decode("paw(string[2])")
      %ABI.FunctionSelector{
        function: "paw",
        types: [
          {:array, :string, 2}
        ]
      }

      iex> ABI.FunctionSelector.decode("scram(uint256[])")
      %ABI.FunctionSelector{
        function: "scram",
        types: [
          {:array, {:uint, 256}}
        ]
      }

      iex> ABI.FunctionSelector.decode("shake((string))")
      %ABI.FunctionSelector{
        function: "shake",
        types: [
          {:tuple, [:string]}
        ]
      }
  """
  def decode(signature, parse_opts \\ []) do
    ABI.Parser.parse!(signature, [as: :selector] ++ parse_opts)
  end

  @doc """
  Decodes the given type-string as a simple array of types.

  ## Examples

      iex> ABI.FunctionSelector.decode_raw("string,uint256")
      [:string, {:uint, 256}]

      iex> ABI.FunctionSelector.decode_raw("")
      []
  """
  def decode_raw(type_string) do
    {:tuple, types} = decode_type("(#{type_string})")
    types
  end

  @doc false
  def parse_specification_item(item, return_bindings? \\ false)

  def parse_specification_item(%{"type" => "function"} = item, return_bindings?) do
    %{
      "name" => function_name,
      "inputs" => named_inputs,
      "outputs" => named_outputs
    } = item

    input_types = Enum.map(named_inputs, &parse_specification_type(&1, return_bindings?))
    output_types = Enum.map(named_outputs, &parse_specification_type(&1, return_bindings?))

    %ABI.FunctionSelector{
      function: function_name,
      types: input_types,
      returns: List.first(output_types)
    }
  end

  def parse_specification_item(%{"type" => "fallback"}, _return_bindings?) do
    %ABI.FunctionSelector{
      function: nil,
      types: [],
      returns: nil
    }
  end

  def parse_specification_item(_, _), do: nil

  defp parse_specification_type(%{"type" => typespec} = explicit_opts, return_binding?) do
    {:binding, inner_type, :unnamed} = decode_type(typespec, true)

    annotated_inner_type = case Map.fetch(explicit_opts, "indexed") do
      {:ok, true} -> {:indexed, inner_type}
      _ -> inner_type
    end

    if return_binding? do
      {:binding, annotated_inner_type, Map.get(explicit_opts, "name", :unnamed)}
    else
      annotated_inner_type
    end
  end

  @doc """
  Decodes the given type-string as a single type.

  ## Examples

      iex> ABI.FunctionSelector.decode_type("uint256")
      {:uint, 256}

      iex> ABI.FunctionSelector.decode_type("(bool,address)")
      {:tuple, [:bool, :address]}

      iex> ABI.FunctionSelector.decode_type("address[][3]")
      {:array, {:array, :address}, 3}
  """
  def decode_type(single_type, return_binding? \\ false) do
    ABI.Parser.parse!(single_type, as: :type, bindings: return_binding?)
  end

  @doc """
  Encodes a function call signature.

  ## Examples

      iex> ABI.FunctionSelector.encode(%ABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [
      ...>     {:uint, 256},
      ...>     :bool,
      ...>     {:array, :string},
      ...>     {:array, :string, 3},
      ...>     {:tuple, [{:uint, 256}, :bool]}
      ...>   ]
      ...> })
      "bark(uint256,bool,string[],string[3],(uint256,bool))"
  """
  def encode(function_selector) do
    types = get_types(function_selector) |> Enum.join(",")

    "#{function_selector.function}(#{types})"
  end

  @doc false
  def signature(%__MODULE__{function: f} = function_selector) when is_binary(f) do
    method_id = ABI.TypeEncoder.encode_method_id(function_selector)
    size_range = ABI.TypeSizer.encoded_size_range(function_selector)
    {method_id, size_range}
  end
  def signature(%__MODULE__{function: nil}) do
    {<<>>, {0, :infinity}}
  end

  defp get_types(function_selector) do
    for type <- function_selector.types do
      get_type(type)
    end
  end

  defp get_type(nil), do: nil
  defp get_type({:int, size}), do: "int#{size}"
  defp get_type({:uint, size}), do: "uint#{size}"
  defp get_type(:address), do: "address"
  defp get_type(:bool), do: "bool"
  defp get_type({:fixed, element_count, precision}), do: "fixed#{element_count}x#{precision}"
  defp get_type({:ufixed, element_count, precision}), do: "ufixed#{element_count}x#{precision}"
  defp get_type({:bytes, size}), do: "bytes#{size}"
  defp get_type(:function), do: "function"

  defp get_type({:array, type, element_count}), do: "#{get_type(type)}[#{element_count}]"

  defp get_type(:bytes), do: "bytes"
  defp get_type(:string), do: "string"
  defp get_type({:array, type}), do: "#{get_type(type)}[]"

  defp get_type({:tuple, types}) do
    encoded_types = Enum.map(types, &get_type/1)
    "(#{Enum.join(encoded_types, ",")})"
  end

  # TODO: parameterize get_type for usage in two scenarios:
  #   - canonicalizing params (return inner_type)
  #   - inspecting/exporting params (return "{inner_type} indexed")
  defp get_type({:indexed, inner_type}), do: get_type(inner_type)

  defp get_type({:seq, inner_type}), do: get_type(inner_type)

  defp get_type({:binding, inner_type, _name}), do: get_type(inner_type)

  defp get_type(els), do: raise("Unsupported type: #{inspect(els)}")

  @doc false
  @spec is_dynamic?(ABI.FunctionSelector.type()) :: boolean
  def is_dynamic?(:bytes), do: true
  def is_dynamic?(:string), do: true
  def is_dynamic?({:array, _type}), do: true
  def is_dynamic?({:array, type, len}) when len > 0, do: is_dynamic?(type)
  def is_dynamic?({:tuple, types}), do: Enum.any?(types, &is_dynamic?/1)
  def is_dynamic?({:indexed, inner_type}), do: is_dynamic?(inner_type)
  def is_dynamic?({:seq, inner_type}), do: is_dynamic?(inner_type)
  def is_dynamic?({:binding, inner_type, _name}), do: is_dynamic?(inner_type)
  def is_dynamic?(_), do: false

  @doc false
  @spec is_potentially_dynamic?(ABI.FunctionSelector.type()) :: boolean
  def is_potentially_dynamic?(:bytes), do: true
  def is_potentially_dynamic?(:string), do: true
  def is_potentially_dynamic?({:array, _type}), do: true
  def is_potentially_dynamic?({:array, _type, _len}), do: true
  def is_potentially_dynamic?({:tuple, _types}), do: true
  def is_potentially_dynamic?({:indexed, inner_type}), do: is_potentially_dynamic?(inner_type)
  def is_potentially_dynamic?({:seq, inner_type}), do: is_potentially_dynamic?(inner_type)
  def is_potentially_dynamic?({:binding, inner_type, _name}), do: is_potentially_dynamic?(inner_type)
  def is_potentially_dynamic?(_), do: false
end
